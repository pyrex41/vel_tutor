defmodule ViralEngine.ViralPrompts do
  @moduledoc """
  Context module for viral prompts and loop orchestration.

  Provides helper functions for triggering viral prompts from LiveViews
  and tracking user interactions.
  """

  alias ViralEngine.{LoopOrchestrator, ViralPromptLog, Repo}
  alias Phoenix.PubSub

  @doc """
  Triggers a viral prompt for a user event.

  ## Parameters
  - event_type: Atom (e.g., :practice_completed, :diagnostic_completed)
  - user_id: Integer user ID
  - data: Map of additional event data

  ## Returns
  - {:ok, prompt_data} - Prompt to display
  - {:throttled, reason} - User is throttled
  - {:no_prompt, reason} - No prompt available

  ## Examples

      iex> trigger_prompt(:practice_completed, 123, %{score: 95})
      {:ok, %{loop_type: :buddy_challenge, variant: "competitive", prompt: "..."}}

      iex> trigger_prompt(:practice_completed, 123, %{})
      {:throttled, :max_daily_limit}
  """
  def trigger_prompt(event_type, user_id, data \\ %{}) do
    LoopOrchestrator.trigger_loop(event_type, user_id, data)
  end

  @doc """
  Records a click on a viral prompt.
  """
  def record_click(prompt_log_id) when is_integer(prompt_log_id) do
    ViralPromptLog.mark_clicked(prompt_log_id)
  end

  @doc """
  Records a conversion (user completed the viral action).
  """
  def record_conversion(prompt_log_id) when is_integer(prompt_log_id) do
    ViralPromptLog.mark_converted(prompt_log_id)
  end

  @doc """
  Gets conversion stats for A/B testing analysis.
  """
  def get_conversion_stats(loop_type, variant) do
    ViralPromptLog.get_conversion_rate(loop_type, variant)
  end

  @doc """
  Broadcasts a viral event to all subscribers.

  This can be used to notify the Loop Orchestrator of events.
  """
  def broadcast_event(event_type, user_id, data \\ %{}) do
    LoopOrchestrator.broadcast_event(event_type, user_id, data)
  end

  @doc """
  Gets the A/B test variant for a user and loop type.
  """
  def get_variant(user_id, loop_type) do
    LoopOrchestrator.get_variant(user_id, loop_type)
  end

  @doc """
  Checks if a user is currently throttled from receiving prompts.
  """
  def is_throttled?(user_id) do
    case LoopOrchestrator.check_throttle(user_id) do
      {:ok, throttled} -> throttled
      _ -> false
    end
  end

  @doc """
  Gets recent prompts shown to a user.
  """
  def get_recent_prompts(user_id, limit \\ 10) do
    import Ecto.Query

    from(p in ViralPromptLog,
      where: p.user_id == ^user_id,
      order_by: [desc: p.shown_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets prompt performance metrics for dashboard.
  """
  def get_performance_metrics(loop_type \\ nil, date_range \\ 7) do
    import Ecto.Query

    cutoff = DateTime.utc_now() |> DateTime.add(-date_range * 24 * 3600, :second)

    base_query = from(p in ViralPromptLog,
      where: p.shown_at >= ^cutoff
    )

    query = if loop_type do
      from(p in base_query, where: p.loop_type == ^loop_type)
    else
      base_query
    end

    metrics = from(p in query,
      group_by: [p.loop_type, p.variant],
      select: %{
        loop_type: p.loop_type,
        variant: p.variant,
        total_shown: count(p.id),
        total_clicked: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", p.clicked)),
        total_converted: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", p.converted))
      }
    )
    |> Repo.all()

    # Calculate rates
    Enum.map(metrics, fn m ->
      click_rate = if m.total_shown > 0, do: (m.total_clicked || 0) / m.total_shown * 100, else: 0.0
      conversion_rate = if m.total_shown > 0, do: (m.total_converted || 0) / m.total_shown * 100, else: 0.0

      %{
        loop_type: m.loop_type,
        variant: m.variant,
        total_shown: m.total_shown,
        total_clicked: m.total_clicked || 0,
        total_converted: m.total_converted || 0,
        click_rate: Float.round(click_rate, 2),
        conversion_rate: Float.round(conversion_rate, 2)
      }
    end)
  end

  @doc """
  Default fallback prompts when Loop Orchestrator is unavailable.
  """
  def get_default_prompt(event_type) do
    case event_type do
      :practice_completed ->
        %{
          loop_type: :buddy_challenge,
          variant: "default",
          prompt: "Great job! Challenge a friend to beat your score!",
          priority: :high,
          data: %{}
        }

      :diagnostic_completed ->
        %{
          loop_type: :results_rally,
          variant: "default",
          prompt: "Amazing results! Share them with your friends!",
          priority: :high,
          data: %{}
        }

      :flashcard_session_completed ->
        %{
          loop_type: :flashcard_master,
          variant: "default",
          prompt: "You're on fire! Share your progress!",
          priority: :medium,
          data: %{}
        }

      :achievement_unlocked ->
        %{
          loop_type: :proud_parent,
          variant: "default",
          prompt: "Share your achievement with family!",
          priority: :medium,
          data: %{}
        }

      _ ->
        nil
    end
  end
end
