defmodule ViralEngine.LoopOrchestrator do
  @moduledoc """
  Loop Orchestrator - Manages viral prompt triggers with throttling, A/B testing, and fallback logic.

  This module coordinates viral loop prompts across the application, deciding when and which
  prompts to show based on user behavior, throttling rules, and experimentation variants.
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias ViralEngine.{Repo, ViralPromptLog}
  alias Phoenix.PubSub

  @pubsub_topic "viral:loops"
  @throttle_window_hours 24
  @max_prompts_per_day 3

  # Viral loop types
  @loop_types %{
    buddy_challenge: %{
      trigger: :practice_completed,
      priority: :high,
      default_prompt: "Challenge a friend to beat your score!",
      cooldown_hours: 4
    },
    results_rally: %{
      trigger: :diagnostic_completed,
      priority: :high,
      default_prompt: "Share your results and see how you compare!",
      cooldown_hours: 6
    },
    proud_parent: %{
      trigger: :achievement_unlocked,
      priority: :medium,
      default_prompt: "Share your achievement with family!",
      cooldown_hours: 12
    },
    streak_rescue: %{
      trigger: :streak_at_risk,
      priority: :high,
      default_prompt: "Don't break your streak! Study now.",
      cooldown_hours: 24
    },
    flashcard_master: %{
      trigger: :flashcard_session_completed,
      priority: :medium,
      default_prompt: "You're on fire! Share your progress.",
      cooldown_hours: 8
    }
  }

  # A/B test variants
  @ab_variants %{
    buddy_challenge: [
      %{variant: "control", prompt: "Challenge a friend to beat your score!", weight: 0.5},
      %{variant: "competitive", prompt: "Think you're the smartest? Challenge someone to prove it!", weight: 0.25},
      %{variant: "collaborative", prompt: "Invite a friend to learn together and grow smarter!", weight: 0.25}
    ],
    results_rally: [
      %{variant: "control", prompt: "Share your results and see how you compare!", weight: 0.5},
      %{variant: "social_proof", prompt: "Join 1,000+ students sharing their progress!", weight: 0.25},
      %{variant: "achievement", prompt: "Show off your amazing results!", weight: 0.25}
    ]
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers a viral loop evaluation for the given event.

  ## Parameters
  - event_type: Atom representing the event (e.g., :practice_completed)
  - user_id: Integer user ID
  - data: Map of additional event data

  ## Returns
  - {:ok, prompt} - Prompt to display
  - {:throttled, reason} - User is throttled
  - {:no_prompt, reason} - No prompt selected
  """
  def trigger_loop(event_type, user_id, data \\ %{}) do
    GenServer.call(__MODULE__, {:trigger_loop, event_type, user_id, data})
  end

  @doc """
  Gets A/B test variant for a user and loop type.
  """
  def get_variant(user_id, loop_type) do
    GenServer.call(__MODULE__, {:get_variant, user_id, loop_type})
  end

  @doc """
  Broadcasts a viral event to subscribers.
  """
  def broadcast_event(event_type, user_id, data) do
    PubSub.broadcast(
      ViralEngine.PubSub,
      @pubsub_topic,
      {:viral_event, %{type: event_type, user_id: user_id, data: data}}
    )
  end

  @doc """
  Checks if a user is throttled for prompts.
  """
  def check_throttle(user_id) do
    GenServer.call(__MODULE__, {:check_throttle, user_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Subscribe to PubSub topic for viral events
    PubSub.subscribe(ViralEngine.PubSub, @pubsub_topic)

    state = %{
      loop_types: @loop_types,
      ab_variants: @ab_variants,
      throttle_cache: %{},
      variant_cache: %{},
      stats: %{
        total_events: 0,
        prompts_shown: 0,
        throttled: 0
      }
    }

    Logger.info("Loop Orchestrator started and subscribed to #{@pubsub_topic}")
    {:ok, state}
  end

  @impl true
  def handle_call({:trigger_loop, event_type, user_id, data}, _from, state) do
    result = evaluate_loop(event_type, user_id, data, state)

    new_stats = %{state.stats |
      total_events: state.stats.total_events + 1,
      prompts_shown: state.stats.prompts_shown + (if match?({:ok, _}, result), do: 1, else: 0),
      throttled: state.stats.throttled + (if match?({:throttled, _}, result), do: 1, else: 0)
    }

    {:reply, result, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:get_variant, user_id, loop_type}, _from, state) do
    variant = get_or_assign_variant(user_id, loop_type, state)
    {:reply, variant, state}
  end

  @impl true
  def handle_call({:check_throttle, user_id}, _from, state) do
    throttled = is_throttled?(user_id, state)
    {:reply, {:ok, throttled}, state}
  end

  @impl true
  def handle_info({:viral_event, %{type: event_type, user_id: user_id, data: data}}, state) do
    # Handle PubSub messages
    Logger.info("Received viral event: #{event_type} for user #{user_id}")

    # Evaluate loop asynchronously
    Task.start(fn ->
      evaluate_loop(event_type, user_id, data, state)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp evaluate_loop(event_type, user_id, data, state) do
    # Find matching loop type
    matching_loop = find_matching_loop(event_type, state.loop_types)

    case matching_loop do
      nil ->
        {:no_prompt, :no_matching_loop}

      {loop_type, loop_config} ->
        # Check throttling
        if is_throttled?(user_id, state) do
          {:throttled, :max_daily_limit}
        else
          # Check loop-specific cooldown
          if is_in_cooldown?(user_id, loop_type, loop_config.cooldown_hours) do
            {:throttled, :loop_cooldown}
          else
            # Get A/B test variant
            variant = get_or_assign_variant(user_id, loop_type, state)

            # Get prompt text
            prompt = get_prompt_text(loop_type, variant, loop_config, state)

            # Log the prompt
            log_prompt(user_id, loop_type, variant, prompt, data)

            # Return prompt with metadata
            {:ok, %{
              loop_type: loop_type,
              variant: variant,
              prompt: prompt,
              priority: loop_config.priority,
              data: data
            }}
          end
        end
    end
  end

  defp find_matching_loop(event_type, loop_types) do
    Enum.find(loop_types, fn {_loop_type, config} ->
      config.trigger == event_type
    end)
  end

  defp is_throttled?(user_id, _state) do
    # Check database for recent prompts
    cutoff = DateTime.utc_now() |> DateTime.add(-@throttle_window_hours * 3600, :second)

    count = Repo.one(
      from(p in ViralPromptLog,
        where: p.user_id == ^user_id and p.inserted_at >= ^cutoff,
        select: count(p.id)
      )
    )

    count >= @max_prompts_per_day
  end

  defp is_in_cooldown?(user_id, loop_type, cooldown_hours) do
    cutoff = DateTime.utc_now() |> DateTime.add(-cooldown_hours * 3600, :second)

    exists? = Repo.exists?(
      from(p in ViralPromptLog,
        where: p.user_id == ^user_id and
               p.loop_type == ^to_string(loop_type) and
               p.inserted_at >= ^cutoff
      )
    )

    exists?
  end

  defp get_or_assign_variant(user_id, loop_type, state) do
    # Check if variant already assigned
    cache_key = {user_id, loop_type}

    case Map.get(state.variant_cache, cache_key) do
      nil ->
        # Assign new variant based on weights
        variant = assign_variant(user_id, loop_type, state.ab_variants)
        # Cache variant (in production, would persist to DB)
        variant

      cached_variant ->
        cached_variant
    end
  end

  defp assign_variant(user_id, loop_type, ab_variants) do
    variants = Map.get(ab_variants, loop_type, [])

    if Enum.empty?(variants) do
      "default"
    else
      # Use user_id as seed for consistent assignment
      :rand.seed(:exsss, {user_id, loop_type, 42})
      random = :rand.uniform()

      # Select variant based on cumulative weights
      select_weighted_variant(variants, random, 0.0)
    end
  end

  defp select_weighted_variant([variant | rest], random, cumulative) do
    new_cumulative = cumulative + variant.weight

    if random <= new_cumulative do
      variant.variant
    else
      select_weighted_variant(rest, random, new_cumulative)
    end
  end

  defp select_weighted_variant([], _random, _cumulative) do
    "default"
  end

  defp get_prompt_text(loop_type, variant, loop_config, state) do
    # Get variant-specific prompt if available
    variants = Map.get(state.ab_variants, loop_type, [])
    variant_data = Enum.find(variants, fn v -> v.variant == variant end)

    case variant_data do
      nil -> loop_config.default_prompt
      v -> v.prompt
    end
  end

  defp log_prompt(user_id, loop_type, variant, prompt, data) do
    # Insert prompt log asynchronously
    Task.start(fn ->
      %ViralPromptLog{
        user_id: user_id,
        loop_type: to_string(loop_type),
        variant: variant,
        prompt_text: prompt,
        event_data: data,
        shown_at: DateTime.utc_now()
      }
      |> Repo.insert()
    end)
  end
end
