# PHASE 2: First Two Viral Loops + Reward System
**Timeline: Week 3-4 (10 days) | Goal: Buddy Challenge + Results Rally Live with K-Factor Tracking**

## Scope

Add intelligent agents (Personalization, Incentives) and ship two high-impact viral loops:
1. **Buddy Challenge** (Student → Student) - Post-practice skill challenges
2. **Results Rally** (Async → Social) - Diagnostic results with leaderboards

## Deliverables

### 2.1 Personalization Agent (MCP Service)

```elixir
defmodule ViralEngine.Agents.Personalization do
  use GenServer
  require Logger

  @moduledoc """
  Personalizes copy, rewards, and CTAs by persona, subject, and context.
  Uses Claude API for dynamic content generation with fallbacks.
  """

  defmodule State do
    defstruct [
      :claude_client,
      :copy_templates,
      :persona_profiles
    ]
  end

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def personalize(request) do
    GenServer.call(__MODULE__, {:personalize, request}, 15_000)
  end

  # Server Callbacks
  def init(_opts) do
    state = %State{
      claude_client: configure_claude_client(),
      copy_templates: load_copy_templates(),
      persona_profiles: %{}
    }
    {:ok, state}
  end

  def handle_call({:personalize, request}, _from, state) do
    %{
      user_id: user_id,
      loop_type: loop_type,
      context: context
    } = request

    profile = fetch_or_build_profile(user_id, state)
    
    personalized = %{
      headline: personalize_headline(loop_type, profile, context, state),
      body: personalize_body(loop_type, profile, context, state),
      cta: personalize_cta(loop_type, profile, context),
      share_copy: generate_share_copy(loop_type, profile, context, state),
      reward: select_reward(profile, context)
    }

    log_personalization(user_id, loop_type, personalized)

    {:reply, {:ok, personalized}, state}
  end

  # Core Logic
  defp personalize_headline(loop_type, profile, context, state) do
    template = get_template(loop_type, profile.persona, state)
    
    template.headline
    |> String.replace("{{name}}", profile.first_name)
    |> String.replace("{{subject}}", context[:subject] || "this")
    |> String.replace("{{score}}", to_string(context[:score] || ""))
  end

  defp personalize_body(loop_type, profile, context, state) do
    template = get_template(loop_type, profile.persona, state)
    
    template.body
    |> String.replace("{{name}}", profile.first_name)
    |> String.replace("{{achievement}}", context[:achievement] || "great work")
    |> String.replace("{{next_step}}", suggest_next_step(context, profile))
  end

  defp personalize_cta(loop_type, profile, _context) do
    case {loop_type, profile.persona} do
      {:buddy_challenge, :student} -> "Challenge a Friend"
      {:results_rally, :student} -> "Join the Leaderboard"
      {:buddy_challenge, :parent} -> "Have Your Child Challenge Friends"
      {:results_rally, :parent} -> "See Class Rankings"
      _ -> "Share Your Progress"
    end
  end

  defp generate_share_copy(loop_type, profile, context, state) do
    # Try Claude first, fallback to templates
    case generate_with_claude(loop_type, profile, context, state) do
      {:ok, copy} -> copy
      {:error, _} -> fallback_share_copy(loop_type, profile, context)
    end
  end

  defp generate_with_claude(loop_type, profile, context, state) do
    prompt = build_claude_prompt(loop_type, profile, context)
    
    case call_claude(state.claude_client, prompt) do
      {:ok, response} -> 
        {:ok, String.trim(response)}
      {:error, reason} -> 
        Logger.warn("Claude generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_claude_prompt(loop_type, profile, context) do
    """
    Generate shareable social copy for a #{profile.persona} (#{profile.communication_style || "friendly"} tone).

    Context:
    - Loop type: #{loop_type}
    - Subject: #{context[:subject]}
    - Achievement: #{context[:achievement] || "completed practice"}
    - Score: #{context[:score]}%

    Requirements:
    - 1-2 sentences max
    - Authentic and conversational, not salesy
    - Include subtle CTA to try the platform
    - Use emojis sparingly (0-1 max)

    Output only the social copy, nothing else.
    """
  end

  defp fallback_share_copy(loop_type, profile, context) do
    case {loop_type, profile.persona} do
      {:buddy_challenge, :student} ->
        "I just aced #{context[:subject]}! 💪 Can you beat my score? Try this challenge!"
      
      {:results_rally, :student} ->
        "Ranked ##{context[:rank]} in #{context[:subject]}! 🎯 Join the leaderboard and see where you stand!"
      
      _ ->
        "Check out my progress on Varsity Tutors!"
    end
  end

  defp select_reward(profile, context) do
    case profile.persona do
      :student ->
        if context[:high_engagement] do
          %{type: :ai_tutor_minutes, amount: 30, label: "30 min AI Tutor"}
        else
          %{type: :streak_shield, amount: 1, label: "Streak Shield"}
        end
      
      :parent ->
        %{type: :class_pass, amount: 1, label: "Free Live Class"}
      
      :tutor ->
        %{type: :referral_xp, amount: 50, label: "50 Referral XP"}
    end
  end

  # Helpers
  defp fetch_or_build_profile(user_id, _state) do
    # Fetch from DB or build from user record
    user = ViralEngine.Repo.get!(User, user_id)
    
    %{
      user_id: user.id,
      first_name: user.first_name,
      persona: determine_persona(user),
      grade_level: user.grade_level,
      subjects: user.subjects || [],
      engagement_level: calculate_engagement(user),
      communication_style: user.preferences[:communication_style] || "friendly"
    }
  end

  defp determine_persona(user) do
    # Simple heuristic; expand as needed
    cond do
      user.role == :tutor -> :tutor
      user.role == :parent -> :parent
      true -> :student
    end
  end

  defp calculate_engagement(user) do
    # Based on recent activity
    recent_sessions = count_recent_sessions(user.id, days: 7)
    
    cond do
      recent_sessions >= 5 -> :high
      recent_sessions >= 2 -> :medium
      true -> :low
    end
  end

  defp get_template(loop_type, persona, state) do
    state.copy_templates
    |> Map.get(loop_type, %{})
    |> Map.get(persona, default_template())
  end

  defp load_copy_templates do
    %{
      buddy_challenge: %{
        student: %{
          headline: "{{name}}, challenge a friend to beat your score!",
          body: "You nailed {{subject}} with {{score}}%. Think your friends can do better? Challenge them and you'll both get rewards! 🎯"
        },
        parent: %{
          headline: "{{name}}'s doing great! Time to challenge classmates.",
          body: "Your child scored {{score}}% on {{subject}}. Friendly competition helps learning stick!"
        }
      },
      results_rally: %{
        student: %{
          headline: "You're ranked #{{rank}} in {{subject}}!",
          body: "{{achievement}} See how you stack up against your peers and climb the leaderboard."
        },
        parent: %{
          headline: "{{name}} ranked #{{rank}} in class!",
          body: "Your child's {{subject}} skills are improving. Share the progress with other parents!"
        }
      }
    }
  end

  defp default_template do
    %{
      headline: "Great work, {{name}}!",
      body: "Keep it up and share your progress with friends!"
    }
  end

  defp suggest_next_step(context, profile) do
    cond do
      length(context[:skill_gaps] || []) > 0 ->
        "master #{hd(context[:skill_gaps])}"
      
      profile.engagement_level == :low ->
        "keep your streak going"
      
      true ->
        "level up your skills"
    end
  end

  defp configure_claude_client do
    # Configure Anthropic client
    api_key = Application.get_env(:viral_engine, :claude_api_key)
    %{api_key: api_key, model: "claude-sonnet-4-5-20250929"}
  end

  defp call_claude(client, prompt) do
    # Stub for now; implement actual API call
    # For bootcamp, you might use a simple HTTP client
    case HTTPoison.post(
      "https://api.anthropic.com/v1/messages",
      Jason.encode!(%{
        model: client.model,
        max_tokens: 150,
        messages: [%{role: "user", content: prompt}]
      }),
      [
        {"x-api-key", client.api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ]
    ) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"content" => [%{"text" => text}]}} -> {:ok, text}
          _ -> {:error, :invalid_response}
        end
      
      {:ok, %{status_code: status}} ->
        {:error, {:api_error, status}}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp log_personalization(user_id, loop_type, result) do
    ViralEngine.Analytics.log_decision(%{
      agent_name: "personalization",
      user_id: user_id,
      decision_type: "copy_generation",
      rationale: "Generated personalized content for #{loop_type}",
      features: %{
        loop_type: loop_type,
        reward_type: result.reward.type
      },
      outcome: "success",
      timestamp: DateTime.utc_now()
    })
  end

  defp count_recent_sessions(user_id, days: days) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 86400)
    
    ViralEngine.Repo.aggregate(
      from s in Session,
      where: s.user_id == ^user_id and s.completed_at >= ^cutoff,
      :count
    )
  end
end
```

### 2.2 Incentives & Economy Agent (MCP Service)

```elixir
defmodule ViralEngine.Agents.IncentivesEconomy do
  use GenServer
  require Logger

  @moduledoc """
  Manages reward distribution, tracks unit economics, prevents abuse.
  Ensures rewards are immediately usable and tracks redemption.
  """

  defmodule State do
    defstruct [
      :daily_caps,          # Per-user caps by reward type
      :user_balances,       # Cached balances for quick checks
      :cost_tracking        # Track CAC impact of rewards
    ]
  end

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def grant_reward(user_id, reward_type, amount, context \\ %{}) do
    GenServer.call(__MODULE__, {:grant_reward, user_id, reward_type, amount, context})
  end

  def check_balance(user_id, reward_type) do
    GenServer.call(__MODULE__, {:check_balance, user_id, reward_type})
  end

  def redeem_reward(user_id, reward_type, amount) do
    GenServer.call(__MODULE__, {:redeem_reward, user_id, reward_type, amount})
  end

  # Server Callbacks
  def init(_opts) do
    state = %State{
      daily_caps: load_daily_caps(),
      user_balances: %{},
      cost_tracking: %{}
    }
    {:ok, state}
  end

  def handle_call({:grant_reward, user_id, reward_type, amount, context}, _from, state) do
    with {:ok, _} <- check_daily_cap(user_id, reward_type, amount, state),
         {:ok, reward} <- create_reward(user_id, reward_type, amount, context) do
      
      new_state = update_balances(state, user_id, reward_type, amount)
      
      log_grant(user_id, reward_type, amount, context)
      notify_user(user_id, reward)
      
      {:reply, {:ok, reward}, new_state}
    else
      {:error, reason} ->
        Logger.warn("Reward grant failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:check_balance, user_id, reward_type}, _from, state) do
    balance = get_balance(user_id, reward_type)
    {:reply, {:ok, balance}, state}
  end

  def handle_call({:redeem_reward, user_id, reward_type, amount}, _from, state) do
    with {:ok, balance} <- get_balance(user_id, reward_type),
         true <- balance >= amount,
         {:ok, redemption} <- process_redemption(user_id, reward_type, amount) do
      
      new_state = update_balances(state, user_id, reward_type, -amount)
      
      log_redemption(user_id, reward_type, amount)
      
      {:reply, {:ok, redemption}, new_state}
    else
      false ->
        {:reply, {:error, :insufficient_balance}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Core Logic
  defp check_daily_cap(user_id, reward_type, amount, state) do
    cap = get_in(state.daily_caps, [reward_type]) || 1000
    granted_today = count_granted_today(user_id, reward_type)
    
    if granted_today + amount <= cap do
      {:ok, :within_cap}
    else
      {:error, :daily_cap_exceeded}
    end
  end

  defp create_reward(user_id, reward_type, amount, context) do
    reward = %Reward{
      user_id: user_id,
      reward_type: reward_type,
      amount: amount,
      source_loop_id: context[:loop_id],
      source_event_id: context[:event_id],
      redeemed: false,
      expires_at: calculate_expiry(reward_type)
    }

    case ViralEngine.Repo.insert(reward) do
      {:ok, reward} -> {:ok, reward}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_balance(user_id, reward_type) do
    total = ViralEngine.Repo.aggregate(
      from r in Reward,
      where: r.user_id == ^user_id and 
             r.reward_type == ^reward_type and
             r.redeemed == false and
             (is_nil(r.expires_at) or r.expires_at > ^DateTime.utc_now()),
      select: sum(r.amount)
    )

    {:ok, total || 0}
  end

  defp process_redemption(user_id, reward_type, amount) do
    # Mark oldest rewards as redeemed up to amount
    rewards = ViralEngine.Repo.all(
      from r in Reward,
      where: r.user_id == ^user_id and
             r.reward_type == ^reward_type and
             r.redeemed == false,
      order_by: [asc: r.inserted_at],
      limit: 100  # Safety limit
    )

    {redeemed_rewards, remaining} = redeem_up_to_amount(rewards, amount)
    
    # Update rewards as redeemed
    reward_ids = Enum.map(redeemed_rewards, & &1.id)
    
    ViralEngine.Repo.update_all(
      from(r in Reward, where: r.id in ^reward_ids),
      set: [redeemed: true, redeemed_at: DateTime.utc_now()]
    )

    {:ok, %{
      redeemed_amount: amount - remaining,
      reward_ids: reward_ids
    }}
  end

  defp redeem_up_to_amount(rewards, amount, acc \\ [])
  defp redeem_up_to_amount([], remaining, acc), do: {Enum.reverse(acc), remaining}
  defp redeem_up_to_amount([reward | rest], remaining, acc) do
    if reward.amount <= remaining do
      redeem_up_to_amount(rest, remaining - reward.amount, [reward | acc])
    else
      # Partial redemption not supported; skip this reward
      redeem_up_to_amount(rest, remaining, acc)
    end
  end

  # Helpers
  defp load_daily_caps do
    %{
      ai_tutor_minutes: 60,      # Max 60 min/day from viral
      class_pass: 2,             # Max 2 passes/day
      streak_shield: 3,          # Max 3 shields/day
      referral_xp: 500           # Max 500 XP/day
    }
  end

  defp calculate_expiry(reward_type) do
    days = case reward_type do
      :ai_tutor_minutes -> 30
      :class_pass -> 90
      :streak_shield -> 7
      :referral_xp -> nil  # Never expires
    end

    if days, do: DateTime.add(DateTime.utc_now(), days * 86400), else: nil
  end

  defp count_granted_today(user_id, reward_type) do
    today_start = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00])
    
    ViralEngine.Repo.aggregate(
      from r in Reward,
      where: r.user_id == ^user_id and
             r.reward_type == ^reward_type and
             r.inserted_at >= ^today_start,
      select: sum(r.amount)
    ) || 0
  end

  defp update_balances(state, user_id, reward_type, delta) do
    current = get_in(state.user_balances, [user_id, reward_type]) || 0
    put_in(state.user_balances[user_id][reward_type], current + delta)
  end

  defp log_grant(user_id, reward_type, amount, context) do
    ViralEngine.Analytics.log_decision(%{
      agent_name: "incentives_economy",
      user_id: user_id,
      decision_type: "reward_granted",
      rationale: "Granted #{amount} #{reward_type} for #{context[:loop_id]}",
      features: %{
        reward_type: reward_type,
        amount: amount,
        loop_id: context[:loop_id]
      },
      outcome: "success",
      timestamp: DateTime.utc_now()
    })
  end

  defp log_redemption(user_id, reward_type, amount) do
    ViralEngine.Analytics.log(%{
      event_type: "reward_redeemed",
      user_id: user_id,
      properties: %{
        reward_type: reward_type,
        amount: amount
      },
      timestamp: DateTime.utc_now()
    })
  end

  defp notify_user(user_id, reward) do
    # Send push notification or in-app message
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "user:#{user_id}",
      {:reward_granted, reward}
    )
  end
end
```

### 2.3 Enhanced Orchestrator (with Loop Routing)

```elixir
defmodule ViralEngine.Agents.Orchestrator do
  use GenServer
  require Logger

  @moduledoc """
  Phase 2: Routes events to viral loops, coordinates agents via MCP.
  """

  defmodule State do
    defstruct [
      :loop_configs,
      :user_throttles,
      :active_experiments
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def trigger_event(event) do
    GenServer.call(__MODULE__, {:trigger_event, event}, 15_000)
  end

  def init(_opts) do
    state = %State{
      loop_configs: load_loop_configs(),
      user_throttles: %{},
      active_experiments: %{}
    }
    {:ok, state}
  end

  def handle_call({:trigger_event, event}, _from, state) do
    Logger.info("Processing event: #{event.type} for user #{event.user_id}")
    
    with {:ok, eligible_loops} <- find_eligible_loops(event, state),
         {:ok, selected_loop} <- select_best_loop(eligible_loops, event),
         {:ok, _} <- check_throttle(event.user_id, selected_loop, state),
         {:ok, decision} <- execute_loop(selected_loop, event) do
      
      new_state = update_throttle(state, event.user_id, selected_loop)
      
      log_decision(event, selected_loop, decision)
      
      {:reply, {:ok, decision}, new_state}
    else
      {:error, :no_eligible_loops} ->
        {:reply, {:skip, :no_match}, state}
      
      {:error, :throttled} ->
        {:reply, {:skip, :throttled}, state}
      
      {:error, reason} ->
        Logger.warn("Loop execution failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  # Core Logic
  defp find_eligible_loops(event, state) do
    eligible = 
      state.loop_configs
      |> Enum.filter(fn {_id, config} ->
        event.type in config.trigger_events and
        meets_criteria(event, config)
      end)
      |> Enum.map(fn {id, config} -> {id, config} end)

    if Enum.empty?(eligible) do
      {:error, :no_eligible_loops}
    else
      {:ok, eligible}
    end
  end

  defp select_best_loop(eligible_loops, event) do
    selected = 
      eligible_loops
      |> Enum.map(fn {id, config} ->
        score = score_loop(id, config, event)
        {id, config, score}
      end)
      |> Enum.max_by(fn {_id, _config, score} -> score end)

    {:ok, selected}
  end

  defp execute_loop({loop_id, config, _score}, event) do
    case loop_id do
      :buddy_challenge ->
        ViralEngine.Loops.BuddyChallenge.generate(event, config)
      
      :results_rally ->
        ViralEngine.Loops.ResultsRally.generate(event, config)
      
      _ ->
        {:error, :unknown_loop}
    end
  end

  # Helpers
  defp load_loop_configs do
    %{
      buddy_challenge: %{
        trigger_events: [:practice_completed, :diagnostic_completed],
        cooldown_seconds: 3600,
        min_score: 60,
        expected_k: 0.35
      },
      results_rally: %{
        trigger_events: [:diagnostic_completed, :practice_test_completed],
        cooldown_seconds: 86400,
        min_participants: 5,
        expected_k: 0.28
      }
    }
  end

  defp meets_criteria(event, config) do
    case config do
      %{min_score: min_score} ->
        (event.context[:score] || 0) >= min_score
      
      %{min_participants: min_participants} ->
        count_cohort_participants(event.user_id) >= min_participants
      
      _ ->
        true
    end
  end

  defp score_loop(loop_id, config, event) do
    base_score = config.expected_k
    
    # Boost for high engagement
    engagement_boost = if event.context[:high_engagement], do: 0.15, else: 0.0
    
    # Boost for milestones
    milestone_boost = if event.context[:milestone], do: 0.20, else: 0.0
    
    # Penalty for recent use
    recency_penalty = calculate_recency_penalty(loop_id, event.user_id)
    
    base_score + engagement_boost + milestone_boost - recency_penalty
  end

  defp calculate_recency_penalty(loop_id, user_id) do
    # Check when this loop was last used for this user
    case get_last_trigger(loop_id, user_id) do
      nil -> 0.0
      last_time ->
        hours_ago = DateTime.diff(DateTime.utc_now(), last_time) / 3600
        max(0.0, 0.3 - (hours_ago / 48))  # Decay over 48 hours
    end
  end

  defp check_throttle(user_id, {loop_id, config, _score}, state) do
    case get_in(state.user_throttles, [user_id, loop_id]) do
      nil -> {:ok, true}
      last_triggered ->
        if DateTime.diff(DateTime.utc_now(), last_triggered) > config.cooldown_seconds do
          {:ok, true}
        else
          {:error, :throttled}
        end
    end
  end

  defp update_throttle(state, user_id, {loop_id, _config, _score}) do
    put_in(
      state.user_throttles,
      Map.put(state.user_throttles, user_id, %{
        loop_id => DateTime.utc_now()
      })
    )
  end

  defp log_decision(event, {loop_id, config, score}, decision) do
    ViralEngine.Analytics.log_decision(%{
      agent_name: "orchestrator",
      user_id: event.user_id,
      decision_type: "loop_selected",
      rationale: "Selected #{loop_id} with score #{score} for #{event.type}",
      features: %{
        event_type: event.type,
        loop_id: loop_id,
        score: score,
        expected_k: config.expected_k
      },
      outcome: "executed",
      timestamp: DateTime.utc_now()
    })
  end

  defp get_last_trigger(loop_id, user_id) do
    case ViralEngine.Repo.one(
      from d in AgentDecision,
      where: d.agent_name == "orchestrator" and
             fragment("?->>'loop_id' = ?", d.features, ^to_string(loop_id)) and
             d.user_id == ^user_id,
      order_by: [desc: d.timestamp],
      limit: 1,
      select: d.timestamp
    ) do
      nil -> nil
      timestamp -> timestamp
    end
  end

  defp count_cohort_participants(user_id) do
    user = ViralEngine.Repo.get!(User, user_id)
    
    ViralEngine.Repo.aggregate(
      from u in User,
      where: u.cohort_id == ^user.cohort_id and
             u.active == true,
      :count
    )
  end
end
```

### 2.4 Buddy Challenge Loop Implementation

```elixir
defmodule ViralEngine.Loops.BuddyChallenge do
  @moduledoc """
  Student → Student viral loop.
  After practice, challenge friend to beat score on same skill.
  """

  alias ViralEngine.{Attribution, MCP, Analytics}

  def generate(event, _config) do
    user = fetch_user(event.user_id)
    
    # Create 5-question challenge deck
    deck = create_challenge_deck(
      event.context.skill,
      event.context.questions || 5
    )

    # Generate smart link
    {:ok, link_data} = Attribution.create_link(%{
      referrer_id: user.id,
      context: %{
        loop_id: :buddy_challenge,
        deck_id: deck.id,
        skill: event.context.skill,
        referrer_score: event.context.score
      }
    })

    # Get personalized content via MCP
    {:ok, personalization} = MCP.Client.call_agent(
      "personalization-agent",
      "personalize",
      %{
        user_id: user.id,
        loop_type: :buddy_challenge,
        context: event.context
      }
    )

    # Generate share pack
    share_pack = %{
      headline: personalization.headline,
      body: personalization.body,
      cta: personalization.cta,
      share_link: link_data.url,
      deep_link: link_data.deep_link,
      share_card: generate_share_card(user, deck, event),
      share_copy: personalization.share_copy,
      channels: [:sms, :whatsapp, :copy_link],
      reward_preview: personalization.reward
    }

    # Log exposure
    Analytics.log(%{
      event_type: "loop_exposed",
      user_id: user.id,
      properties: %{
        loop_id: :buddy_challenge,
        deck_id: deck.id,
        link_code: link_data.code
      },
      timestamp: DateTime.utc_now()
    })

    {:ok, %{
      action: :show_share_modal,
      share_pack: share_pack
    }}
  end

  def handle_join(link_code, joiner_id) do
    {:ok, link} = Attribution.track_click(link_code)
    
    # Load challenge deck
    deck = ViralEngine.Repo.get!(ChallengeDeck, link.context["deck_id"])
    
    # Create session for joiner
    session = %ChallengeSession{
      deck_id: deck.id,
      user_id: joiner_id,
      referrer_id: link.referrer_id,
      link_id: link.id
    }
    
    {:ok, session} = ViralEngine.Repo.insert(session)

    # Log FVM (first value moment)
    Analytics.log(%{
      event_type: "fvm_reached",
      user_id: joiner_id,
      link_id: link.id,
      properties: %{
        loop_id: :buddy_challenge,
        deck_id: deck.id
      },
      timestamp: DateTime.utc_now()
    })

    {:ok, %{
      deck: deck,
      session: session,
      referrer_score: link.context["referrer_score"]
    }}
  end

  def complete_challenge(session_id, score) do
    session = ViralEngine.Repo.get!(ChallengeSession, session_id)
    
    # Update session
    session = session
    |> Ecto.Changeset.change(%{
      score: score,
      completed_at: DateTime.utc_now()
    })
    |> ViralEngine.Repo.update!()

    # Check if both users should get rewards
    referrer_score = session.link.context["referrer_score"]
    
    if score >= referrer_score * 0.9 do  # Within 10% = success
      # Grant rewards to both
      grant_challenge_rewards(session.referrer_id, session.user_id)
    end

    {:ok, session}
  end

  defp create_challenge_deck(skill, question_count) do
    questions = fetch_questions_for_skill(skill, question_count)
    
    deck = %ChallengeDeck{
      type: :buddy_challenge,
      skill: skill,
      questions: questions,
      expires_at: DateTime.add(DateTime.utc_now(), 48 * 3600)
    }
    
    ViralEngine.Repo.insert!(deck)
  end

  defp generate_share_card(user, deck, event) do
    %{
      type: :buddy_challenge,
      image_url: generate_card_image(user, deck, event),
      title: "Can you beat my #{deck.skill} score?",
      description: "I scored #{event.context.score}% on #{deck.skill}. Think you can do better? 🎯",
      og_tags: %{
        "og:title" => "#{user.first_name}'s #{deck.skill} Challenge",
        "og:description" => "Beat my score and we both win!",
        "og:image" => generate_card_image(user, deck, event)
      }
    }
  end

  defp generate_card_image(user, deck, event) do
    # Generate dynamic image (use Cloudinary, imgix, or similar)
    # For now, return placeholder
    "/images/challenge_cards/#{deck.skill}_#{event.context.score}.png"
  end

  defp grant_challenge_rewards(referrer_id, joiner_id) do
    # Grant to referrer
    MCP.Client.call_agent(
      "incentives-agent",
      "grant_reward",
      %{
        user_id: referrer_id,
        reward_type: :streak_shield,
        amount: 1,
        context: %{loop_id: :buddy_challenge, role: :referrer}
      }
    )

    # Grant to joiner
    MCP.Client.call_agent(
      "incentives-agent",
      "grant_reward",
      %{
        user_id: joiner_id,
        reward_type: :streak_shield,
        amount: 1,
        context: %{loop_id: :buddy_challenge, role: :joiner}
      }
    )
  end

  defp fetch_questions_for_skill(skill, count) do
    # Fetch from question bank
    ViralEngine.Repo.all(
      from q in Question,
      where: q.skill == ^skill and q.difficulty == :medium,
      order_by: fragment("RANDOM()"),
      limit: ^count
    )
  end

  defp fetch_user(user_id) do
    ViralEngine.Repo.get!(User, user_id)
  end
end
```

### 2.5 Results Rally Loop Implementation

```elixir
defmodule ViralEngine.Loops.ResultsRally do
  @moduledoc """
  Async → Social viral loop.
  After diagnostic/practice test, show leaderboard and challenge friends.
  """

  alias ViralEngine.{Attribution, MCP, Analytics, Presence}

  def generate(event, _config) do
    user = fetch_user(event.user_id)
    results = event.context.results
    
    # Get cohort leaderboard
    leaderboard = fetch_cohort_leaderboard(
      user.cohort_id,
      results.subject,
      limit: 25
    )
    
    # Calculate user rank
    user_rank = calculate_rank(user.id, leaderboard)

    # Generate smart link
    {:ok, link_data} = Attribution.create_link(%{
      referrer_id: user.id,
      context: %{
        loop_id: :results_rally,
        subject: results.subject,
        cohort_id: user.cohort_id,
        referrer_rank: user_rank
      }
    })

    # Get personalized content
    {:ok, personalization} = MCP.Client.call_agent(
      "personalization-agent",
      "personalize",
      %{
        user_id: user.id,
        loop_type: :results_rally,
        context: Map.merge(event.context, %{rank: user_rank, leaderboard_size: length(leaderboard)})
      }
    )

    # Build share pack
    share_pack = %{
      headline: personalization.headline,
      body: personalization.body,
      cta: personalization.cta,
      share_link: link_data.url,
      deep_link: link_data.deep_link,
      share_card: generate_leaderboard_card(user, leaderboard, results, user_rank),
      share_copy: personalization.share_copy,
      leaderboard_widget: render_leaderboard_widget(leaderboard, user.id),
      channels: [:copy_link, :sms, :twitter, :instagram_story],
      reward_preview: personalization.reward
    }

    # Log exposure
    Analytics.log(%{
      event_type: "loop_exposed",
      user_id: user.id,
      properties: %{
        loop_id: :results_rally,
        rank: user_rank,
        link_code: link_data.code
      },
      timestamp: DateTime.utc_now()
    })

    {:ok, %{
      action: :show_results_with_social,
      share_pack: share_pack,
      leaderboard: leaderboard,
      user_rank: user_rank
    }}
  end

  def handle_join(link_code, joiner_id) do
    {:ok, link} = Attribution.track_click(link_code)
    
    # Get cohort and subject from link
    cohort_id = link.context["cohort_id"]
    subject = link.context["subject"]
    
    # Show joiner the leaderboard
    leaderboard = fetch_cohort_leaderboard(cohort_id, subject)
    
    # Prompt to take diagnostic
    diagnostic = find_matching_diagnostic(subject)

    # Log FVM
    Analytics.log(%{
      event_type: "fvm_reached",
      user_id: joiner_id,
      link_id: link.id,
      properties: %{
        loop_id: :results_rally,
        subject: subject
      },
      timestamp: DateTime.utc_now()
    })

    {:ok, %{
      leaderboard: leaderboard,
      diagnostic: diagnostic,
      subject: subject,
      referrer_rank: link.context["referrer_rank"]
    }}
  end

  defp fetch_cohort_leaderboard(cohort_id, subject, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    
    # Get active presence
    active_user_ids = Presence.list("cohort:#{cohort_id}")
    |> Map.keys()
    |> Enum.map(&String.to_integer/1)

    ViralEngine.Repo.all(
      from u in User,
      join: r in Result,
      on: r.user_id == u.id,
      where: u.cohort_id == ^cohort_id and r.subject == ^subject,
      order_by: [desc: r.score, asc: r.completed_at],
      limit: ^limit,
      select: %{
        user_id: u.id,
        name: u.first_name,
        score: r.score,
        completed_at: r.completed_at,
        is_online: u.id in ^active_user_ids
      }
    )
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, rank} ->
      Map.put(entry, :rank, rank)
    end)
  end

  defp calculate_rank(user_id, leaderboard) do
    case Enum.find(leaderboard, fn entry -> entry.user_id == user_id end) do
      nil -> nil
      entry -> entry.rank
    end
  end

  defp generate_leaderboard_card(user, leaderboard, results, rank) do
    %{
      type: :results_rally,
      image_url: generate_leaderboard_image(leaderboard, rank),
      title: "Ranked ##{rank} in #{results.subject}!",
      description: "I scored #{results.score}% on #{results.subject}. Can you beat it?",
      og_tags: %{
        "og:title" => "#{user.first_name} is ##{rank} in #{results.subject}",
        "og:description" => "Join the leaderboard and compete!",
        "og:image" => generate_leaderboard_image(leaderboard, rank)
      }
    }
  end

  defp render_leaderboard_widget(leaderboard, current_user_id) do
    # Return HTML/component data for embedding
    %{
      type: :leaderboard,
      entries: Enum.take(leaderboard, 10),  # Top 10
      current_user_id: current_user_id,
      live_updates: true
    }
  end

  defp generate_leaderboard_image(leaderboard, rank) do
    # Generate dynamic image showing top 5 + current user
    "/images/leaderboard_cards/rank_#{rank}.png"
  end

  defp find_matching_diagnostic(subject) do
    ViralEngine.Repo.one(
      from d in Diagnostic,
      where: d.subject == ^subject and d.active == true,
      limit: 1
    )
  end

  defp fetch_user(user_id) do
    ViralEngine.Repo.get!(User, user_id)
  end
end
```

### 2.6 Phase 2 Database Additions

```elixir
# priv/repo/migrations/20250104_phase2_schema.exs

defmodule ViralEngine.Repo.Migrations.Phase2Schema do
  use Ecto.Migration

  def change do
    # Rewards
    create table(:rewards) do
      add :user_id, :integer, null: false
      add :reward_type, :string, null: false
      add :amount, :integer, null: false
      add :source_loop_id, :string
      add :source_event_id, :string
      add :redeemed, :boolean, default: false
      add :redeemed_at, :utc_datetime
      add :expires_at, :utc_datetime
      timestamps()
    end
    create index(:rewards, [:user_id])
    create index(:rewards, [:reward_type])
    create index(:rewards, [:redeemed])

    # Challenge Decks
    create table(:challenge_decks) do
      add :type, :string, null: false
      add :skill, :string
      add :questions, :map  # JSON array of question objects
      add :participant_count, :integer, default: 0
      add :completion_count, :integer, default: 0
      add :expires_at, :utc_datetime
      timestamps()
    end
    create index(:challenge_decks, [:skill])
    create index(:challenge_decks, [:expires_at])

    # Challenge Sessions
    create table(:challenge_sessions) do
      add :deck_id, references(:challenge_decks, on_delete: :delete_all)
      add :user_id, :integer, null: false
      add :referrer_id, :integer
      add :link_id, references(:smart_links, on_delete: :nilify_all)
      add :score, :integer
      add :completed_at, :utc_datetime
      timestamps()
    end
    create index(:challenge_sessions, [:deck_id])
    create index(:challenge_sessions, [:user_id])
    create index(:challenge_sessions, [:referrer_id])
  end
end
```

### 2.7 MCP Deployment Script (Phase 2)

```bash
#!/bin/bash
# deploy_phase2.sh

echo "Deploying Phase 2 Agents to Fly.io..."

# Personalization Agent
fly mcp launch \
  "mix run --no-halt -e ViralEngine.Agents.Personalization" \
  --server personalization-agent \
  --region ord \
  --vm-size shared-cpu-1x \
  --auto-stop 5m \
  --secret CLAUDE_API_KEY="${CLAUDE_API_KEY}" \
  --secret DATABASE_URL="${DATABASE_URL}"

# Incentives & Economy Agent
fly mcp launch \
  "mix run --no-halt -e ViralEngine.Agents.IncentivesEconomy" \
  --server incentives-agent \
  --region ord \
  --vm-size shared-cpu-1x \
  --auto-stop 5m \
  --secret DATABASE_URL="${DATABASE_URL}"

# Re-deploy Orchestrator with Phase 2 logic
fly deploy --config fly.orchestrator.toml

echo "✅ Phase 2 agents deployed"
echo "Test with: fly mcp inspect --server personalization-agent"
```

### 2.8 Phase 2 Integration Tests

```elixir
defmodule ViralEngine.Phase2IntegrationTest do
  use ViralEngine.DataCase
  
  describe "Buddy Challenge Loop" do
    test "complete flow: practice → share → join → complete → rewards" do
      # Setup
      user1 = insert(:user)
      user2 = insert(:user)
      
      # 1. User1 completes practice
      event = %{
        type: :practice_completed,
        user_id: user1.id,
        context: %{
          skill: "Algebra",
          score: 85,
          questions: 5
        }
      }
      
      # 2. Orchestrator triggers loop
      {:ok, decision} = ViralEngine.Agents.Orchestrator.trigger_event(event)
      
      assert decision.action == :show_share_modal
      assert decision.share_pack.share_link =~ "/r/"
      
      # 3. Extract link code and simulate user2 clicking
      link_code = extract_code(decision.share_pack.share_link)
      {:ok, join_data} = ViralEngine.Loops.BuddyChallenge.handle_join(link_code, user2.id)
      
      assert join_data.deck.skill == "Algebra"
      assert length(join_data.deck.questions) == 5
      
      # 4. User2 completes challenge with good score
      {:ok, session} = ViralEngine.Loops.BuddyChallenge.complete_challenge(
        join_data.session.id,
        82  # Within 10% of referrer
      )
      
      # 5. Check rewards granted
      {:ok, user1_balance} = ViralEngine.Agents.IncentivesEconomy.check_balance(
        user1.id,
        :streak_shield
      )
      {:ok, user2_balance} = ViralEngine.Agents.IncentivesEconomy.check_balance(
        user2.id,
        :streak_shield
      )
      
      assert user1_balance == 1
      assert user2_balance == 1
    end
  end
  
  describe "Results Rally Loop" do
    test "complete flow: diagnostic → leaderboard → share → join → FVM" do
      # Setup cohort
      cohort = insert(:cohort)
      users = insert_list(10, :user, cohort_id: cohort.id)
      user1 = hd(users)
      
      # Create results for leaderboard
      Enum.each(users, fn user ->
        insert(:result, user_id: user.id, subject: "Math", score: :rand.uniform(100))
      end)
      
      # 1. User1 completes diagnostic
      event = %{
        type: :diagnostic_completed,
        user_id: user1.id,
        context: %{
          results: %{
            subject: "Math",
            score: 95,
            diagnostic_id: 123
          }
        }
      }
      
      # 2. Orchestrator triggers loop
      {:ok, decision} = ViralEngine.Agents.Orchestrator.trigger_event(event)
      
      assert decision.action == :show_results_with_social
      assert decision.leaderboard != nil
      assert decision.user_rank != nil
      
      # 3. New user joins via link
      new_user = insert(:user, cohort_id: cohort.id)
      link_code = extract_code(decision.share_pack.share_link)
      
      {:ok, join_data} = ViralEngine.Loops.ResultsRally.handle_join(link_code, new_user.id)
      
      assert join_data.subject == "Math"
      assert join_data.diagnostic != nil
      
      # 4. Check FVM logged
      fvm_event = ViralEngine.Repo.one(
        from e in ViralEvent,
        where: e.event_type == "fvm_reached" and e.user_id == ^new_user.id,
        order_by: [desc: e.timestamp],
        limit: 1
      )
      
      assert fvm_event != nil
    end
  end
end
```

## Success Criteria (Phase 2)

- [ ] Personalization Agent deployed and responding <500ms
- [ ] Incentives Agent granting/redeeming rewards correctly
- [ ] Buddy Challenge loop: End-to-end functional
  - [ ] Share modal appears after practice
  - [ ] Link generates correctly
  - [ ] Joiner sees challenge deck
  - [ ] Rewards granted on completion
- [ ] Results Rally loop: End-to-end functional
  - [ ] Leaderboard renders with real-time presence
  - [ ] Share card generates
  - [ ] New user sees leaderboard + diagnostic CTA
- [ ] K-factor tracking infrastructure in place
- [ ] At least 50 test loops executed successfully
- [ ] Agent decision logging shows proper coordination

## Phase 2 Metrics

```elixir
defmodule ViralEngineWeb.Phase2DashboardLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(10_000, self(), :refresh)
    end

    metrics = fetch_phase2_metrics()

    {:ok, assign(socket, :metrics, metrics)}
  end

  defp fetch_phase2_metrics do
    %{
      buddy_challenge: %{
        exposures: count_loop_exposures(:buddy_challenge),
        invites_sent: count_invites(:buddy_challenge),
        joins: count_joins(:buddy_challenge),
        completions: count_completions(:buddy_challenge),
        k_factor: calculate_k_factor(:buddy_challenge, days: 7)
      },
      results_rally: %{
        exposures: count_loop_exposures(:results_rally),
        invites_sent: count_invites(:results_rally),
        joins: count_joins(:results_rally),
        fvm_reached: count_fvm(:results_rally),
        k_factor: calculate_k_factor(:results_rally, days: 7)
      },
      rewards: %{
        granted_today: count_rewards_granted(days: 1),
        redeemed_today: count_rewards_redeemed(days: 1),
        total_value: calculate_reward_value()
      }
    }
  end

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-3xl font-bold mb-6">Phase 2: Viral Loops Active</h1>
      
      <div class="grid grid-cols-2 gap-6 mb-6">
        <!-- Buddy Challenge -->
        <div class="bg-white p-6 rounded-lg shadow">
          <h2 class="text-xl font-bold mb-4">Buddy Challenge</h2>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-gray-600">Exposures:</span>
              <span class="font-bold"><%= @metrics.buddy_challenge.exposures %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Invites Sent:</span>
              <span class="font-bold"><%= @metrics.buddy_challenge.invites_sent %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Joins:</span>
              <span class="font-bold"><%= @metrics.buddy_challenge.joins %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">K-Factor (7d):</span>
              <span class={[
                "font-bold",
                if(@metrics.buddy_challenge.k_factor >= 1.2, do: "text-green-600", else: "text-orange-600")
              ]}>
                <%= Float.round(@metrics.buddy_challenge.k_factor, 3) %>
              </span>
            </div>
          </div>
        </div>

        <!-- Results Rally -->
        <div class="bg-white p-6 rounded-lg shadow">
          <h2 class="text-xl font-bold mb-4">Results Rally</h2>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-gray-600">Exposures:</span>
              <span class="font-bold"><%= @metrics.results_rally.exposures %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Invites Sent:</span>
              <span class="font-bold"><%= @metrics.results_rally.invites_sent %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">FVM Reached:</span>
              <span class="font-bold"><%= @metrics.results_rally.fvm_reached %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">K-Factor (7d):</span>
              <span class={[
                "font-bold",
                if(@metrics.results_rally.k_factor >= 1.2, do: "text-green-600", else: "text-orange-600")
              ]}>
                <%= Float.round(@metrics.results_rally.k_factor, 3) %>
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Rewards Summary -->
      <div class="bg-blue-50 p-6 rounded-lg">
        <h3 class="font-bold text-lg mb-2">Rewards Economy</h3>
        <div class="grid grid-cols-3 gap-4">
          <div>
            <div class="text-sm text-gray-600">Granted Today</div>
            <div class="text-2xl font-bold"><%= @metrics.rewards.granted_today %></div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Redeemed Today</div>
            <div class="text-2xl font-bold"><%= @metrics.rewards.redeemed_today %></div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Total Value (CAC equiv)</div>
            <div class="text-2xl font-bold">$<%= Float.round(@metrics.rewards.total_value, 2) %></div>
          </div>
        </div>
      </div>

      <div class="mt-6 bg-green-50 p-4 rounded">
        <p class="font-semibold">✅ Phase 2 Success = K ≥ 1.20 for at least one loop over 14 days</p>
      </div>
    </div>
    """
  end

  defp calculate_k_factor(loop_id, opts) do
    # Simplified K-factor calc; full implementation in Analytics module
    days = Keyword.get(opts, :days, 14)
    start_date = DateTime.add(DateTime.utc_now(), -days * 86400)

    invites = count_invites_since(loop_id, start_date)
    exposures = count_exposures_since(loop_id, start_date)
    joins = count_joins_since(loop_id, start_date)

    if exposures > 0 and invites > 0 do
      invites_per_user = invites / exposures
      conversion_rate = joins / invites
      invites_per_user * conversion_rate
    else
      0.0
    end
  end
end
```

## Phase 2 Deployment Checklist

- [ ] MCP agents deployed to Fly.io
- [ ] Database migrations run
- [ ] Environment variables set (CLAUDE_API_KEY, etc.)
- [ ] Orchestrator updated with Phase 2 logic
- [ ] Integration tests passing
- [ ] Load test with 100 concurrent users
- [ ] Personalization Agent < 500ms response time
- [ ] Reward granting/redemption tested
- [ ] Share modals rendering correctly
- [ ] Deep links working on iOS/Android
- [ ] Analytics events flowing to dashboard

---

**Ready for Phase 3?** (Proud Parent + Tutor Spotlight + Trust & Safety)
