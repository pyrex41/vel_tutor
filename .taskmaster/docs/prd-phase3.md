# PHASE 3: Parent & Tutor Loops + Trust & Safety + Session Intelligence
**Timeline: Week 5-6 (10 days) | Goal: All 4 Loops Live + COPPA/FERPA Compliant + Session-Triggered Actions**

## Scope

Complete the viral engine with:
1. **Proud Parent Loop** (Parent → Parent) - Weekly progress sharing
2. **Tutor Spotlight Loop** (Tutor → Families) - Post-session referral packs
3. **Trust & Safety Agent** - Fraud detection, compliance, rate limiting
4. **Session Intelligence Pipeline** - Transcription → AI summary → viral actions

## Deliverables

### 3.1 Trust & Safety Agent (Full Implementation)

```elixir
defmodule ViralEngine.Agents.TrustSafety do
  use GenServer
  require Logger

  @moduledoc """
  Trust & Safety Agent for fraud detection, COPPA/FERPA compliance, and abuse prevention.
  Always-on service that vets all viral actions before execution.
  """

  defmodule State do
    defstruct [
      :user_flags,          # %{user_id => %{fraud_score: float, flags: []}}
      :rate_limits,         # %{user_id => %{action_type => count}}
      :reported_actions,    # Abuse reports for undo
      :compliance_rules,    # COPPA/FERPA config
      :daily_caps,          # Global caps per action type
      :blocklist            # Known bad actors
    ]
  end

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def check_action(user_id, action_type, context) do
    GenServer.call(__MODULE__, {:check_action, user_id, action_type, context}, 10_000)
  end

  def report_abuse(reporter_id, action_id, reason) do
    GenServer.call(__MODULE__, {:report_abuse, reporter_id, action_id, reason})
  end

  def redact_data(data, user_id) do
    GenServer.call(__MODULE__, {:redact_data, data, user_id})
  end

  def update_user_signal(user_id, signal_type, value) do
    GenServer.cast(__MODULE__, {:update_signal, user_id, signal_type, value})
  end

  # Server Callbacks
  def init(_opts) do
    state = %State{
      user_flags: %{},
      rate_limits: %{},
      reported_actions: %{},
      compliance_rules: load_compliance_rules(),
      daily_caps: load_daily_caps(),
      blocklist: load_blocklist()
    }

    # Schedule daily cleanup
    schedule_cleanup()

    {:ok, state}
  end

  def handle_call({:check_action, user_id, action_type, context}, _from, state) do
    # Multi-stage check pipeline
    with {:ok, _} <- check_blocklist(user_id, state),
         {:ok, _} <- check_rate_limit(user_id, action_type, state),
         {:ok, _} <- check_duplicate(user_id, context, state),
         {:ok, fraud_score} <- calculate_fraud_score(user_id, context, state),
         {:ok, _} <- check_compliance(user_id, action_type, context, state) do
      
      decision = determine_action(fraud_score, action_type)
      
      new_state = update_rate_limits(state, user_id, action_type)
      
      log_decision(user_id, action_type, decision, fraud_score, context)
      
      {:reply, decision, new_state}
    else
      {:error, reason} = error ->
        log_detection(user_id, action_type, reason, context)
        {:reply, error, state}
    end
  end

  def handle_call({:report_abuse, reporter_id, action_id, reason}, _from, state) do
    Logger.warn("Abuse report: action_id=#{action_id}, reporter=#{reporter_id}, reason=#{reason}")
    
    case fetch_action(action_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      
      action ->
        # Undo the action
        undo_result = undo_action(action)
        
        # Flag user for review
        new_state = flag_user(state, action.user_id, :reported_abuse)
        
        # Log report
        log_abuse_report(reporter_id, action_id, reason)
        
        {:reply, {:ok, undo_result}, new_state}
    end
  end

  def handle_call({:redact_data, data, user_id}, _from, state) do
    user = fetch_user(user_id)
    redacted = apply_redaction(data, user, state.compliance_rules)
    
    {:reply, {:ok, redacted}, state}
  end

  def handle_cast({:update_signal, user_id, signal_type, value}, state) do
    # Update fraud signals from other parts of the system
    new_state = update_user_flags(state, user_id, signal_type, value)
    {:noreply, new_state}
  end

  def handle_info(:cleanup, state) do
    # Daily cleanup of rate limits and expired flags
    new_state = %{state |
      rate_limits: cleanup_rate_limits(state.rate_limits),
      user_flags: cleanup_user_flags(state.user_flags)
    }
    
    schedule_cleanup()
    {:noreply, new_state}
  end

  # Core Logic
  defp check_blocklist(user_id, state) do
    if MapSet.member?(state.blocklist, user_id) do
      {:error, :user_blocked}
    else
      {:ok, :passed}
    end
  end

  defp check_rate_limit(user_id, action_type, state) do
    cap = get_in(state.daily_caps, [action_type]) || 100
    current = get_in(state.rate_limits, [user_id, action_type, :count]) || 0
    
    if current >= cap do
      {:error, :rate_limit_exceeded}
    else
      # Check velocity (actions per hour)
      if check_velocity(user_id, action_type, state) do
        {:ok, :passed}
      else
        {:error, :velocity_exceeded}
      end
    end
  end

  defp check_velocity(user_id, action_type, state) do
    timestamps = get_in(state.rate_limits, [user_id, action_type, :timestamps]) || []
    recent = Enum.filter(timestamps, fn ts ->
      DateTime.diff(DateTime.utc_now(), ts) < 3600
    end)
    
    # Max 10 actions per hour for most types
    length(recent) < 10
  end

  defp check_duplicate(user_id, context, _state) do
    # Check for duplicate devices, emails, IPs
    device_id = context[:device_id]
    email = context[:email]
    ip = context[:ip_address]

    duplicate_checks = [
      check_duplicate_device(user_id, device_id),
      check_duplicate_email(user_id, email),
      check_duplicate_ip(user_id, ip)
    ]

    if Enum.any?(duplicate_checks, fn result -> result == :duplicate end) do
      {:error, :duplicate_detected}
    else
      {:ok, :unique}
    end
  end

  defp check_duplicate_device(_user_id, nil), do: :ok
  defp check_duplicate_device(user_id, device_id) do
    count = ViralEngine.Repo.aggregate(
      from u in User,
      where: u.device_id == ^device_id and u.id != ^user_id,
      :count
    )
    
    if count > 0, do: :duplicate, else: :ok
  end

  defp check_duplicate_email(_user_id, nil), do: :ok
  defp check_duplicate_email(user_id, email) do
    count = ViralEngine.Repo.aggregate(
      from u in User,
      where: u.email == ^email and u.id != ^user_id,
      :count
    )
    
    if count > 0, do: :duplicate, else: :ok
  end

  defp check_duplicate_ip(_user_id, nil), do: :ok
  defp check_duplicate_ip(user_id, ip) do
    # Check recent signups from same IP
    cutoff = DateTime.add(DateTime.utc_now(), -86400)  # 24 hours
    
    count = ViralEngine.Repo.aggregate(
      from u in User,
      where: u.signup_ip == ^ip and u.id != ^user_id and u.inserted_at >= ^cutoff,
      :count
    )
    
    if count > 3, do: :duplicate, else: :ok  # Max 3 signups per IP per day
  end

  defp calculate_fraud_score(user_id, context, state) do
    base_score = get_in(state.user_flags, [user_id, :fraud_score]) || 0.0

    signals = [
      velocity_signal(user_id, state),
      referral_pattern_signal(user_id, context),
      device_signal(context),
      email_domain_signal(context[:email]),
      ip_signal(context[:ip_address]),
      behavioral_signal(user_id, context)
    ]

    fraud_score = (base_score + Enum.sum(signals)) / (1 + length(signals))
    fraud_score = Float.round(min(fraud_score, 1.0), 3)

    {:ok, fraud_score}
  end

  defp velocity_signal(user_id, state) do
    # High action velocity = suspicious
    recent_actions = get_in(state.rate_limits, [user_id]) || %{}
    
    total_actions = 
      recent_actions
      |> Map.values()
      |> Enum.map(fn v -> v[:count] || 0 end)
      |> Enum.sum()

    cond do
      total_actions > 50 -> 0.5
      total_actions > 30 -> 0.3
      total_actions > 20 -> 0.1
      true -> 0.0
    end
  end

  defp referral_pattern_signal(user_id, context) do
    # Check for suspicious referral chains
    chain_length = calculate_referral_chain_length(user_id)
    
    cond do
      chain_length > 10 -> 0.6  # Deep self-referral chain
      chain_length > 5 -> 0.3
      context[:rapid_referrals] -> 0.4  # Many referrals in short time
      true -> 0.0
    end
  end

  defp device_signal(context) do
    # Check against known bad devices/fingerprints
    device_id = context[:device_id]
    
    if device_id do
      # Check if device has been flagged
      flagged = ViralEngine.Repo.exists?(
        from f in DeviceFlag,
        where: f.device_id == ^device_id and f.severity == :high
      )
      
      if flagged, do: 0.8, else: 0.0
    else
      0.1  # No device ID = slightly suspicious
    end
  end

  defp email_domain_signal(nil), do: 0.0
  defp email_domain_signal(email) do
    domain = email |> String.split("@") |> List.last() |> String.downcase()
    
    disposable_domains = [
      "tempmail.com", "yopmail.com", "guerrillamail.com", "10minutemail.com",
      "throwaway.email", "mailinator.com", "temp-mail.org"
    ]

    if domain in disposable_domains, do: 0.5, else: 0.0
  end

  defp ip_signal(nil), do: 0.0
  defp ip_signal(ip) do
    # Check against VPN/proxy/datacenter IPs
    # For bootcamp, simple check; integrate with MaxMind/IPHub in production
    case check_ip_reputation(ip) do
      :high_risk -> 0.4
      :medium_risk -> 0.2
      :low_risk -> 0.0
    end
  end

  defp behavioral_signal(user_id, _context) do
    # Analyze user behavior patterns
    user = fetch_user(user_id)
    
    signals = [
      if user.session_count == 0, do: 0.2, else: 0.0,  # No engagement
      if user.email_verified == false, do: 0.1, else: 0.0,
      if user.phone_verified == false, do: 0.1, else: 0.0,
      if DateTime.diff(DateTime.utc_now(), user.inserted_at) < 3600, do: 0.15, else: 0.0  # Brand new
    ]

    Enum.sum(signals)
  end

  defp check_compliance(user_id, action_type, context, state) do
    user = fetch_user(user_id)
    rules = state.compliance_rules

    # COPPA check (< 13 years old)
    if user.age && user.age < 13 do
      case action_type do
        type when type in [:social_sharing, :public_leaderboard, :invite_minor] ->
          if has_parental_consent?(user) do
            {:ok, :coppa_approved}
          else
            {:error, :coppa_no_consent}
          end
        
        :share_progress ->
          # FERPA: Educational records require consent
          if has_parental_consent?(user) do
            {:ok, :ferpa_approved}
          else
            {:error, :ferpa_violation}
          end
        
        _ ->
          {:ok, :coppa_exempt}
      end
    # FERPA check (< 18 years old)
    elsif user.age && user.age < 18 do
      case action_type do
        :share_progress ->
          if context[:educational_record] do
            {:error, :ferpa_violation}  # Don't share ed records for minors
          else
            {:ok, :ferpa_safe}
          end
        
        _ ->
          {:ok, :ferpa_exempt}
      end
    else
      {:ok, :adult_user}
    end
  end

  defp determine_action(fraud_score, action_type) do
    cond do
      fraud_score >= 0.8 ->
        {:error, :fraud_high_confidence}
      
      fraud_score >= 0.6 ->
        {:error, :fraud_likely}
      
      fraud_score >= 0.4 ->
        # Allow but flag for review
        {:ok, :approved_with_flag}
      
      fraud_score >= 0.2 ->
        # Allow but monitor
        {:ok, :approved_monitored}
      
      true ->
        {:ok, :approved}
    end
  end

  defp apply_redaction(data, user, rules) do
    if user.age && user.age < 18 do
      data
      |> Map.update(:content, "", &redact_pii/1)
      |> Map.put(:full_name, "#{user.first_name} #{String.first(user.last_name)}.")
      |> Map.put(:email, nil)
      |> Map.put(:phone, nil)
      |> Map.update(:photo_url, "/images/default_avatar.png", fn url ->
        if rules[:allow_photos_for_minors], do: url, else: "/images/default_avatar.png"
      end)
    else
      data
    end
  end

  defp redact_pii(content) do
    content
    |> String.replace(~r/\b[A-Z][a-z]+ [A-Z][a-z]+\b/, "[NAME]")
    |> String.replace(~r/\b[\w\.-]+@[\w\.-]+\.\w+\b/, "[EMAIL]")
    |> String.replace(~r/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/, "[PHONE]")
    |> String.replace(~r/\b\d{3}-\d{2}-\d{4}\b/, "[SSN]")
    |> String.replace(~r/\b\d{1,5}\s\w+\s(?:street|st|avenue|ave|road|rd|drive|dr|lane|ln|court|ct|way)\b/i, "[ADDRESS]")
  end

  defp undo_action(action) do
    case action.type do
      :reward_granted ->
        # Revoke reward
        ViralEngine.MCP.Client.call_agent(
          "incentives-agent",
          "revoke_reward",
          %{
            user_id: action.user_id,
            reward_id: action.reward_id
          }
        )
      
      :invite_sent ->
        # Invalidate smart link
        ViralEngine.Repo.update_all(
          from(l in SmartLink, where: l.id == ^action.link_id),
          set: [active: false, deactivated_reason: "abuse_report"]
        )
      
      :loop_triggered ->
        # Mark as invalid
        ViralEngine.Repo.update_all(
          from(e in ViralEvent, where: e.id == ^action.event_id),
          set: [invalid: true, invalid_reason: "abuse_report"]
        )
      
      _ ->
        {:ok, :no_action_needed}
    end
  end

  # Helpers
  defp load_compliance_rules do
    %{
      coppa_restricted: [:social_sharing, :public_leaderboard, :invite_minor],
      ferpa_sensitive: [:share_progress, :publish_records],
      allow_photos_for_minors: false,
      require_parental_consent_under: 13
    }
  end

  defp load_daily_caps do
    %{
      send_invite: 10,
      trigger_loop: 20,
      create_challenge: 5,
      share_progress: 15
    }
  end

  defp load_blocklist do
    # Load from DB
    user_ids = ViralEngine.Repo.all(
      from u in User,
      where: u.blocked == true,
      select: u.id
    )
    
    MapSet.new(user_ids)
  end

  defp has_parental_consent?(user) do
    ViralEngine.Repo.exists?(
      from c in ParentalConsent,
      where: c.user_id == ^user.id and c.granted == true
    )
  end

  defp calculate_referral_chain_length(user_id) do
    # BFS to find referral chain depth
    max_depth = 0
    queue = [{user_id, 0}]
    visited = MapSet.new([user_id])

    calculate_chain_recursive(queue, visited, max_depth)
  end

  defp calculate_chain_recursive([], _visited, max_depth), do: max_depth
  defp calculate_chain_recursive([{user_id, depth} | rest], visited, max_depth) do
    # Get users referred by this user
    referrals = ViralEngine.Repo.all(
      from a in Attribution,
      where: a.referrer_id == ^user_id,
      select: a.referee_id
    )

    new_queue_items = 
      referrals
      |> Enum.reject(&MapSet.member?(visited, &1))
      |> Enum.map(&{&1, depth + 1})

    new_visited = Enum.reduce(referrals, visited, &MapSet.put(&2, &1))
    new_max = max(max_depth, depth)

    calculate_chain_recursive(rest ++ new_queue_items, new_visited, new_max)
  end

  defp check_ip_reputation(_ip) do
    # Stub for bootcamp; integrate with IP reputation service
    :low_risk
  end

  defp update_rate_limits(state, user_id, action_type) do
    now = DateTime.utc_now()
    
    current = get_in(state.rate_limits, [user_id, action_type]) || %{count: 0, timestamps: []}
    
    updated = %{
      count: current.count + 1,
      timestamps: [now | current.timestamps] |> Enum.take(100)  # Keep last 100
    }

    put_in(state.rate_limits, Map.put(state.rate_limits, user_id, Map.put(Map.get(state.rate_limits, user_id, %{}), action_type, updated)))
  end

  defp flag_user(state, user_id, flag_type) do
    current_flags = get_in(state.user_flags, [user_id, :flags]) || []
    new_flags = [flag_type | current_flags] |> Enum.uniq()
    
    # Recalculate fraud score
    new_score = calculate_flag_score(new_flags)
    
    put_in(state.user_flags, Map.put(state.user_flags, user_id, %{
      fraud_score: new_score,
      flags: new_flags,
      updated_at: DateTime.utc_now()
    }))
  end

  defp calculate_flag_score(flags) do
    weights = %{
      reported_abuse: 0.4,
      duplicate_device: 0.3,
      suspicious_referrals: 0.3,
      velocity_exceeded: 0.2
    }

    flags
    |> Enum.map(&Map.get(weights, &1, 0.1))
    |> Enum.sum()
    |> min(1.0)
  end

  defp update_user_flags(state, user_id, signal_type, value) do
    current = get_in(state.user_flags, [user_id]) || %{fraud_score: 0.0, flags: []}
    
    updated = case signal_type do
      :fraud_score ->
        %{current | fraud_score: value}
      
      :add_flag ->
        %{current | flags: [value | current.flags] |> Enum.uniq()}
      
      :remove_flag ->
        %{current | flags: List.delete(current.flags, value)}
    end

    put_in(state.user_flags, Map.put(state.user_flags, user_id, updated))
  end

  defp cleanup_rate_limits(rate_limits) do
    # Remove entries older than 24 hours
    cutoff = DateTime.add(DateTime.utc_now(), -86400)
    
    rate_limits
    |> Enum.map(fn {user_id, actions} ->
      cleaned_actions = 
        actions
        |> Enum.map(fn {action_type, data} ->
          cleaned_timestamps = Enum.filter(data.timestamps, &(DateTime.compare(&1, cutoff) == :gt))
          {action_type, %{data | timestamps: cleaned_timestamps, count: length(cleaned_timestamps)}}
        end)
        |> Enum.into(%{})
      
      {user_id, cleaned_actions}
    end)
    |> Enum.into(%{})
  end

  defp cleanup_user_flags(user_flags) do
    # Remove flags older than 7 days if fraud score is low
    cutoff = DateTime.add(DateTime.utc_now(), -7 * 86400)
    
    user_flags
    |> Enum.reject(fn {_user_id, data} ->
      data.fraud_score < 0.2 and 
      data.updated_at && DateTime.compare(data.updated_at, cutoff) == :lt
    end)
    |> Enum.into(%{})
  end

  defp schedule_cleanup do
    # Run cleanup at 3 AM daily
    Process.send_after(self(), :cleanup, 86400 * 1000)
  end

  defp log_decision(user_id, action_type, decision, score, context) do
    ViralEngine.Analytics.log_decision(%{
      agent_name: "trust_safety",
      user_id: user_id,
      decision_type: "safety_check",
      rationale: "#{action_type} check: #{inspect(decision)} (score: #{score})",
      features: %{
        action_type: action_type,
        fraud_score: score,
        device_id: context[:device_id],
        ip: context[:ip_address]
      },
      outcome: elem(decision, 0),
      timestamp: DateTime.utc_now()
    })
  end

  defp log_detection(user_id, action_type, reason, context) do
    Logger.warn("""
    T&S BLOCKED ACTION:
    User: #{user_id}
    Action: #{action_type}
    Reason: #{reason}
    Context: #{inspect(context)}
    """)

    ViralEngine.Analytics.log(%{
      event_type: "ts_detection",
      user_id: user_id,
      properties: %{
        action_type: action_type,
        reason: reason,
        context: context
      },
      timestamp: DateTime.utc_now()
    })
  end

  defp log_abuse_report(reporter_id, action_id, reason) do
    ViralEngine.Analytics.log(%{
      event_type: "abuse_report",
      user_id: reporter_id,
      properties: %{
        action_id: action_id,
        reason: reason
      },
      timestamp: DateTime.utc_now()
    })
  end

  defp fetch_user(user_id) do
    ViralEngine.Repo.get!(User, user_id)
  end

  defp fetch_action(action_id) do
    # Fetch from viral_events or a dedicated actions table
    ViralEngine.Repo.get(ViralEvent, action_id)
  end
end
```

### 3.2 Session Intelligence Pipeline

```elixir
defmodule ViralEngine.SessionPipeline do
  use Oban.Worker, queue: :sessions, max_attempts: 3

  @moduledoc """
  Process tutoring sessions: transcribe → summarize → generate agentic actions.
  Triggers viral loops based on session insights.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id}}) do
    Logger.info("Processing session #{session_id}")
    
    with {:ok, session} <- fetch_session(session_id),
         {:ok, transcript} <- transcribe_audio(session),
         {:ok, summary} <- summarize_with_claude(transcript, session),
         {:ok, actions} <- generate_agentic_actions(summary, session) do
      
      # Store summary
      update_session_summary(session, summary)
      
      # Trigger viral actions
      Enum.each(actions, &trigger_viral_action/1)
      
      Logger.info("Session #{session_id} processed: #{length(actions)} actions generated")
      
      :ok
    else
      {:error, reason} ->
        Logger.error("Session pipeline failed for #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp transcribe_audio(session) do
    # Use AssemblyAI, Whisper, or similar
    case call_transcription_service(session.audio_url) do
      {:ok, transcript} ->
        {:ok, transcript}
      {:error, reason} ->
        Logger.error("Transcription failed: #{inspect(reason)}")
        {:error, :transcription_failed}
    end
  end

  defp summarize_with_claude(transcript, session) do
    prompt = """
    Analyze this tutoring session transcript and extract structured insights.

    Session Context:
    - Subject: #{session.subject}
    - Student Grade: #{session.student_grade}
    - Duration: #{session.duration_minutes} minutes

    Transcript:
    #{transcript}

    Extract the following as JSON:
    {
      "key_concepts": ["concept1", "concept2"],
      "skill_gaps": ["gap1", "gap2"],
      "breakthroughs": ["moment1", "moment2"],
      "homework_items": ["task1", "task2"],
      "session_quality": 1-5,
      "student_engagement": "low|medium|high",
      "recommended_next_topic": "topic name",
      "viral_moments": [
        {"type": "achievement", "description": "what happened"},
        {"type": "struggle_overcome", "description": "what happened"}
      ]
    }

    Be concise. Focus on actionable insights.
    """

    case call_claude(prompt) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, summary} -> {:ok, summary}
          {:error, _} -> {:error, :invalid_json}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_agentic_actions(summary, session) do
    actions = []

    # Student actions (≥2)
    actions = actions ++ generate_student_actions(summary, session)

    # Tutor actions (≥2)
    actions = actions ++ generate_tutor_actions(summary, session)

    # Parent actions (if applicable)
    if session.parent_id do
      actions = actions ++ generate_parent_actions(summary, session)
    end

    {:ok, actions}
  end

  defp generate_student_actions(summary, session) do
    actions = []

    # Action 1: Beat-My-Skill Challenge (if skill gaps identified)
    if length(summary["skill_gaps"] || []) > 0 do
      primary_gap = hd(summary["skill_gaps"])
      
      actions = actions ++ [%{
        type: :buddy_challenge,
        user_id: session.student_id,
        persona: :student,
        context: %{
          skill: primary_gap,
          trigger: "post_session_gap",
          session_id: session.id,
          urgency: :medium
        }
      }]
    end

    # Action 2: Study Buddy Nudge (if homework assigned)
    if length(summary["homework_items"] || []) > 0 do
      actions = actions ++ [%{
        type: :study_buddy_nudge,
        user_id: session.student_id,
        persona: :student,
        context: %{
          homework: summary["homework_items"],
          recommended_topic: summary["recommended_next_topic"],
          deadline: calculate_homework_deadline(),
          urgency: :high
        }
      }]
    end

    # Action 3: Celebration Share (if breakthrough moment)
    if length(summary["breakthroughs"] || []) > 0 do
      actions = actions ++ [%{
        type: :achievement_share,
        user_id: session.student_id,
        persona: :student,
        context: %{
          achievement: hd(summary["breakthroughs"]),
          session_quality: summary["session_quality"],
          trigger: "post_session_win"
        }
      }]
    end

    actions
  end

  defp generate_tutor_actions(summary, session) do
    actions = []

    # Action 1: Parent Progress Reel (if high-quality session)
    if summary["session_quality"] >= 4 do
      actions = actions ++ [%{
        type: :parent_progress_reel,
        user_id: session.tutor_id,
        persona: :tutor,
        context: %{
          session_id: session.id,
          highlights: summary["breakthroughs"] || [],
          concepts_covered: summary["key_concepts"] || [],
          quality: summary["session_quality"],
          student_id: session.student_id,
          parent_id: session.parent_id
        }
      }]
    end

    # Action 2: Tutor Share Pack (always, for referrals)
    actions = actions ++ [%{
      type: :tutor_spotlight,
      user_id: session.tutor_id,
      persona: :tutor,
      context: %{
        session_id: session.id,
        subject: session.subject,
        session_quality: summary["session_quality"],
        trigger: "post_session_referral"
      }
    }]

    actions
  end

  defp generate_parent_actions(summary, session) do
    # Parent action: Weekly recap (deferred until weekly job)
    # For now, just log that parent should get a recap
    []
  end

  defp trigger_viral_action(action) do
    # Check with Trust & Safety first
    case ViralEngine.Agents.TrustSafety.check_action(
      action.user_id,
      :trigger_loop,
      action.context
    ) do
      {:ok, _} ->
        # Convert to event and trigger orchestrator
        event = %{
          type: :agentic_action_triggered,
          user_id: action.user_id,
          context: Map.merge(action.context, %{
            action_type: action.type,
            persona: action.persona
          }),
          timestamp: DateTime.utc_now()
        }

        ViralEngine.Agents.Orchestrator.trigger_event(event)
      
      {:error, reason} ->
        Logger.warn("T&S blocked action: #{inspect(reason)}")
        :ok
    end
  end

  # Helpers
  defp fetch_session(session_id) do
    case ViralEngine.Repo.get(TutoringSession, session_id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  defp update_session_summary(session, summary) do
    session
    |> Ecto.Changeset.change(%{
      summary: summary,
      processed_at: DateTime.utc_now()
    })
    |> ViralEngine.Repo.update!()
  end

  defp call_transcription_service(audio_url) do
    # Stub for bootcamp; implement with AssemblyAI or similar
    # For now, return mock transcript
    {:ok, "Mock transcript: Student struggled with quadratic equations but had breakthrough with factoring method..."}
  end

  defp call_claude(prompt) do
    api_key = Application.get_env(:viral_engine, :claude_api_key)
    
    body = Jason.encode!(%{
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 1000,
      messages: [%{role: "user", content: prompt}]
    })

    case HTTPoison.post(
      "https://api.anthropic.com/v1/messages",
      body,
      [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ]
    ) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"content" => [%{"text" => text}]}} ->
            {:ok, text}
          _ ->
            {:error, :invalid_response}
        end
      
      {:ok, %{status_code: status}} ->
        {:error, {:api_error, status}}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_homework_deadline do
    # Default: 48 hours
    DateTime.add(DateTime.utc_now(), 48 * 3600)
  end
end

# Schedule session processing after completion
defmodule ViralEngine.Sessions do
  def complete_session(session_id) do
    # ... existing completion logic ...

    # Queue for processing
    %{session_id: session_id}
    |> ViralEngine.SessionPipeline.new()
    |> Oban.insert()

    :ok
  end
end
```

### 3.3 Proud Parent Loop

```elixir
defmodule ViralEngine.Loops.ProudParent do
  @moduledoc """
  Parent → Parent viral loop.
  Weekly progress recap with shareable reel and invite for class pass.
  """

  alias ViralEngine.{Attribution, MCP, Analytics}

  def generate(event, _config) do
    parent = fetch_user(event.user_id)
    student = fetch_student(parent.student_id)
    recap = event.context.weekly_recap

    # Check T&S compliance
    case MCP.Client.call_agent("trust-safety-agent", "check_action", %{
      user_id: parent.id,
      action_type: :share_progress,
      context: %{educational_record: false}  # Just highlights, not full records
    }) do
      {:ok, _} ->
        proceed_with_loop(parent, student, recap)
      
      {:error, reason} ->
        Logger.warn("Proud Parent loop blocked: #{inspect(reason)}")
        {:skip, reason}
    end
  end

  defp proceed_with_loop(parent, student, recap) do
    # Generate progress reel (privacy-safe)
    reel = generate_progress_reel(student, recap)

    # Create smart link
    {:ok, link_data} = Attribution.create_link(%{
      referrer_id: parent.id,
      context: %{
        loop_id: :proud_parent,
        student_first_name: student.first_name,
        week: recap.week_number
      }
    })

    # Personalize
    {:ok, personalization} = MCP.Client.call_agent(
      "personalization-agent",
      "personalize",
      %{
        user_id: parent.id,
        loop_type: :proud_parent,
        context: %{
          student_name: student.first_name,
          achievements: recap.achievements,
          improvement: recap.improvement_percentage,
          sessions_completed: recap.sessions_completed
        }
      }
    )

    share_pack = %{
      headline: personalization.headline,
      body: personalization.body,
      cta: "Give another parent a free class",
      share_link: link_data.url,
      deep_link: link_data.deep_link,
      progress_reel: reel,
      share_copy: personalization.share_copy,
      reward_for_joiner: %{
        type: :class_pass,
        amount: 1,
        description: "Free live class for your child"
      },
      reward_for_referrer: personalization.reward,
      channels: [:sms, :whatsapp, :facebook, :email],
      email_template: generate_email_template(parent, student, recap, link_data)
    }

    # Log exposure
    Analytics.log(%{
      event_type: "loop_exposed",
      user_id: parent.id,
      properties: %{
        loop_id: :proud_parent,
        week: recap.week_number,
        link_code: link_data.code
      },
      timestamp: DateTime.utc_now()
    })

    {:ok, %{
      action: :show_parent_share_modal,
      share_pack: share_pack
    }}
  end

  def handle_join(link_code, joiner_id) do
    {:ok, link} = Attribution.track_click(link_code)
    
    joiner = fetch_user(joiner_id)
    
    # Show benefit: free class pass
    reward_preview = %{
      type: :class_pass,
      amount: 1,
      description: "Free live class for your child",
      expires_in_days: 30
    }

    # Log FVM
    Analytics.log(%{
      event_type: "fvm_reached",
      user_id: joiner_id,
      link_id: link.id,
      properties: %{
        loop_id: :proud_parent,
        referrer_student: link.context["student_first_name"]
      },
      timestamp: DateTime.utc_now()
    })

    {:ok, %{
      reward_preview: reward_preview,
      onboarding_flow: :parent_signup,
      referrer_context: link.context
    }}
  end

  def complete_signup(link_code, new_parent_id, child_info) do
    {:ok, link} = Attribution.get_link(link_code)
    
    # Create attribution
    {:ok, _attr} = Attribution.attribute_signup(link_code, new_parent_id)

    # Grant rewards
    grant_proud_parent_rewards(link.referrer_id, new_parent_id)

    {:ok, :completed}
  end

  defp generate_progress_reel(student, recap) do
    # Privacy-safe 20-30 second highlights
    highlights = []

    # Sessions completed
    if recap.sessions_completed > 0 do
      highlights = highlights ++ [%{
        type: :stat,
        text: "#{recap.sessions_completed} sessions this week",
        icon: "📚",
        duration_ms: 3000
      }]
    end

    # Skills mastered
    if length(recap.skills_mastered) > 0 do
      highlights = highlights ++ [%{
        type: :achievement,
        text: "Mastered #{length(recap.skills_mastered)} new skills",
        skills: Enum.take(recap.skills_mastered, 3),
        icon: "🎯",
        duration_ms: 4000
      }]
    end

    # Improvement percentage
    if recap.improvement_percentage > 0 do
      highlights = highlights ++ [%{
        type: :improvement,
        text: "#{recap.subject} score up #{recap.improvement_percentage}%",
        chart_data: recap.score_progression,
        icon: "📈",
        duration_ms: 4000
      }]
    end

    # Streak
    if recap.current_streak > 3 do
      highlights = highlights ++ [%{
        type: :streak,
        text: "#{recap.current_streak}-day learning streak!",
        icon: "🔥",
        duration_ms: 3000
      }]
    end

    %{
      highlights: highlights,
      total_duration_ms: Enum.sum(Enum.map(highlights, & &1.duration_ms)),
      student_first_name: student.first_name,
      privacy_safe: true
    }
  end

  defp generate_email_template(parent, student, recap, link_data) do
    %{
      subject: "#{student.first_name}'s amazing progress this week! 🎉",
      body: """
      Hi #{parent.first_name},

      #{student.first_name} had a fantastic week on Varsity Tutors:

      #{format_achievements(recap.achievements)}

      I thought you'd want to share this progress with other parents. As a thank you, 
      any parent who joins through your link gets a free live class for their child!

      Share your link:
      #{link_data.url}

      Keep up the great work!
      
      The Varsity Tutors Team
      """,
      cta_text: "Share with Parents",
      cta_url: link_data.url
    }
  end

  defp format_achievements(achievements) do
    achievements
    |> Enum.take(3)
    |> Enum.map(fn a -> "  • #{a}" end)
    |> Enum.join("\n")
  end

  defp grant_proud_parent_rewards(referrer_id, joiner_id) do
    # Referrer gets AI tutor minutes for their child
    MCP.Client.call_agent(
      "incentives-agent",
      "grant_reward",
      %{
        user_id: referrer_id,
        reward_type: :ai_tutor_minutes,
        amount: 30,
        context: %{loop_id: :proud_parent, role: :referrer}
      }
    )

    # Joiner gets class pass
    MCP.Client.call_agent(
      "incentives-agent",
      "grant_reward",
      %{
        user_id: joiner_id,
        reward_type: :class_pass,
        amount: 1,
        context: %{loop_id: :proud_parent, role: :joiner}
      }
    )
  end

  defp fetch_user(user_id), do: ViralEngine.Repo.get!(User, user_id)
  defp fetch_student(student_id), do: ViralEngine.Repo.get!(User, student_id)
end

# Weekly recap generator (cron job)
defmodule ViralEngine.Jobs.WeeklyRecapGenerator do
  use Oban.Worker, queue: :recaps

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Find all parents with students who had activity this week
    parents = find_active_parents()

    Enum.each(parents, fn parent ->
      recap = generate_recap_for_parent(parent)
      
      # Trigger Proud Parent loop
      event = %{
        type: :weekly_recap_generated,
        user_id: parent.id,
        context: %{
          weekly_recap: recap
        }
      }

      ViralEngine.Agents.Orchestrator.trigger_event(event)
    end)

    :ok
  end

  defp find_active_parents do
    week_ago = DateTime.add(DateTime.utc_now(), -7 * 86400)
    
    ViralEngine.Repo.all(
      from p in User,
      join: s in User, on: s.parent_id == p.id,
      join: sess in TutoringSession, on: sess.student_id == s.id,
      where: p.role == :parent and sess.completed_at >= ^week_ago,
      distinct: p.id,
      select: p
    )
  end

  defp generate_recap_for_parent(parent) do
    student = fetch_student(parent.student_id)
    week_ago = DateTime.add(DateTime.utc_now(), -7 * 86400)

    %{
      week_number: current_week_number(),
      sessions_completed: count_sessions(student.id, week_ago),
      skills_mastered: fetch_skills_mastered(student.id, week_ago),
      improvement_percentage: calculate_improvement(student.id, week_ago),
      achievements: fetch_achievements(student.id, week_ago),
      current_streak: student.current_streak,
      subject: student.primary_subject,
      score_progression: fetch_score_progression(student.id, week_ago)
    }
  end

  defp count_sessions(student_id, since) do
    ViralEngine.Repo.aggregate(
      from s in TutoringSession,
      where: s.student_id == ^student_id and s.completed_at >= ^since,
      :count
    )
  end

  defp fetch_skills_mastered(student_id, since) do
    ViralEngine.Repo.all(
      from sm in SkillMastery,
      where: sm.user_id == ^student_id and sm.mastered_at >= ^since,
      select: sm.skill_name
    )
  end

  defp calculate_improvement(student_id, since) do
    # Compare average score this week vs last week
    scores = ViralEngine.Repo.all(
      from r in Result,
      where: r.user_id == ^student_id,
      order_by: [desc: r.completed_at],
      limit: 10,
      select: %{score: r.score, completed_at: r.completed_at}
    )

    recent = Enum.filter(scores, &(DateTime.compare(&1.completed_at, since) == :gt))
    older = Enum.filter(scores, &(DateTime.compare(&1.completed_at, since) == :lt))

    if length(recent) > 0 and length(older) > 0 do
      avg_recent = Enum.sum(Enum.map(recent, & &1.score)) / length(recent)
      avg_older = Enum.sum(Enum.map(older, & &1.score)) / length(older)
      round(((avg_recent - avg_older) / avg_older) * 100)
    else
      0
    end
  end

  defp fetch_achievements(student_id, since) do
    ViralEngine.Repo.all(
      from a in Achievement,
      where: a.user_id == ^student_id and a.earned_at >= ^since,
      select: a.description
    )
  end

  defp fetch_score_progression(student_id, since) do
    ViralEngine.Repo.all(
      from r in Result,
      where: r.user_id == ^student_id and r.completed_at >= ^since,
      order_by: [asc: r.completed_at],
      select: %{date: r.completed_at, score: r.score}
    )
  end

  defp current_week_number do
    Date.utc_today() |> Date.day_of_year() |> div(7) + 1
  end

  defp fetch_student(student_id), do: ViralEngine.Repo.get!(User, student_id)
end
```

### 3.4 Tutor Spotlight Loop

```elixir
defmodule ViralEngine.Loops.TutorSpotlight do
  @moduledoc """
  Tutor → Families/Peers viral loop.
  After 5-star session, generate tutor card with invite link.
  """

  alias ViralEngine.{Attribution, MCP, Analytics}

  def generate(event, _config) do
    tutor = fetch_user(event.user_id)
    session = fetch_session(event.context.session_id)

    # Generate tutor card
    tutor_card = generate_tutor_card(tutor, session)

    # Create smart link
    {:ok, link_data} = Attribution.create_link(%{
      referrer_id: tutor.id,
      context: %{
        loop_id: :tutor_spotlight,
        session_id: session.id,
        subject: session.subject,
        rating: 5
      }
    })

    # Personalize
    {:ok, personalization} = MCP.Client.call_agent(
      "personalization-agent",
      "personalize",
      %{
        user_id: tutor.id,
        loop_type: :tutor_spotlight,
        context: %{
          session_rating: 5,
          subject: session.subject,
          student_feedback: session.feedback
        }
      }
    )

    share_pack = %{
      headline: personalization.headline,
      body: personalization.body,
      cta: "Share with families",
      share_link: link_data.url,
      deep_link: link_data.deep_link,
      tutor_card: tutor_card,
      share_copy: personalization.share_copy,
      reward_for_referrer: personalization.reward,
      one_tap_channels: [
        {:whatsapp, generate_whatsapp_link(link_data, personalization)},
        {:sms, generate_sms_link(link_data, personalization)},
        {:email, generate_email_template(link_data, tutor, session)}
      ],
      channels: [:whatsapp, :sms, :email, :copy_link]
    }

    # Log exposure
    Analytics.log(%{
      event_type: "loop_exposed",
      user_id: tutor.id,
      properties: %{
        loop_id: :tutor_spotlight,
        session_id: session.id,
        link_code: link_data.code
      },
      timestamp: DateTime.utc_now()
    })

    {:ok, %{
      action: :show_tutor_share_pack,
      share_pack: share_pack
    }}
  end

  def handle_join(link_code, joiner_id) do
    {:ok, link} = Attribution.track_click(link_code)
    
    tutor_id = link.referrer_id
    tutor = fetch_user(tutor_id)
    session = fetch_session(link.context["session_id"])

    # Show tutor profile and book option
    tutor_profile = %{
      id: tutor.id,
      name: tutor.full_name,
      photo_url: tutor.photo_url,
      subjects: tutor.subjects,
      average_rating: tutor.average_rating,
      session_count: tutor.total_sessions,
      bio: tutor.bio,
      recent_feedback: fetch_recent_feedback(tutor.id, limit: 3)
    }

    # Offer first session discount
    incentive = %{
      type: :first_session_discount,
      amount: 50,  # 50% off
      description: "50% off your first session with #{tutor.first_name}"
    }

    # Log FVM
    Analytics.log(%{
      event_type: "fvm_reached",
      user_id: joiner_id,
      link_id: link.id,
      properties: %{
        loop_id: :tutor_spotlight,
        tutor_id: tutor.id,
        subject: link.context["subject"]
      },
      timestamp: DateTime.utc_now()
    })

    {:ok, %{
      tutor_profile: tutor_profile,
      incentive: incentive,
      subject: link.context["subject"]
    }}
  end

  def complete_booking(link_code, student_id, booking_details) do
    {:ok, link} = Attribution.get_link(link_code)
    
    # Create attribution (student's parent is the new user)
    parent_id = get_parent_id(student_id)
    {:ok, _attr} = Attribution.attribute_signup(link_code, parent_id)

    # Grant rewards
    grant_tutor_spotlight_rewards(link.referrer_id, parent_id)

    {:ok, :booking_completed}
  end

  defp generate_tutor_card(tutor, session) do
    %{
      type: :tutor_spotlight,
      tutor_name: tutor.full_name,
      tutor_photo_url: tutor.photo_url,
      subjects: tutor.subjects,
      rating: tutor.average_rating,
      session_count: tutor.total_sessions,
      recent_feedback: session.feedback,
      badge_url: "/images/5star_badge.png",
      headline: "5⭐ Session with #{tutor.first_name}",
      og_tags: %{
        "og:title" => "Learn #{session.subject} with #{tutor.first_name}",
        "og:description" => "Highly rated tutor • #{tutor.total_sessions}+ sessions",
        "og:image" => tutor.photo_url
      }
    }
  end

  defp generate_whatsapp_link(link_data, personalization) do
    text = URI.encode_www_form(
      "#{personalization.share_copy}\n\n#{link_data.url}"
    )
    "https://wa.me/?text=#{text}"
  end

  defp generate_sms_link(link_data, personalization) do
    text = URI.encode_www_form(
      "#{personalization.share_copy} #{link_data.url}"
    )
    "sms:?body=#{text}"
  end

  defp generate_email_template(link_data, tutor, session) do
    %{
      subject: "Try a session with #{tutor.first_name} - 50% off!",
      body: """
      Hi,

      I just had an amazing #{session.subject} session with #{tutor.first_name} on Varsity Tutors.

      #{tutor.first_name} is a highly rated tutor with #{tutor.total_sessions}+ sessions and a #{tutor.average_rating}⭐ rating.

      If you're looking for help with #{session.subject}, check out #{tutor.first_name}'s profile:
      #{link_data.url}

      As a special offer, you'll get 50% off your first session!

      Hope this helps!
      """,
      cta_text: "Book a Session",
      cta_url: link_data.url
    }
  end

  defp grant_tutor_spotlight_rewards(tutor_id, parent_id) do
    # Tutor gets XP and leaderboard boost
    MCP.Client.call_agent(
      "incentives-agent",
      "grant_reward",
      %{
        user_id: tutor_id,
        reward_type: :referral_xp,
        amount: 50,
        context: %{loop_id: :tutor_spotlight, role: :referrer}
      }
    )

    # Parent gets first session discount (handled in booking flow)
    # Just log it here
    Analytics.log(%{
      event_type: "reward_granted",
      user_id: parent_id,
      properties: %{
        reward_type: :first_session_discount,
        amount: 50,
        loop_id: :tutor_spotlight
      },
      timestamp: DateTime.utc_now()
    })
  end

  defp fetch_recent_feedback(tutor_id, opts) do
    limit = Keyword.get(opts, :limit, 5)
    
    ViralEngine.Repo.all(
      from s in TutoringSession,
      where: s.tutor_id == ^tutor_id and not is_nil(s.feedback) and s.rating >= 4,
      order_by: [desc: s.completed_at],
      limit: ^limit,
      select: %{
        feedback: s.feedback,
        rating: s.rating,
        student_name: s.student_first_name,
        date: s.completed_at
      }
    )
  end

  defp get_parent_id(student_id) do
    case ViralEngine.Repo.one(
      from u in User,
      where: u.id == ^student_id,
      select: u.parent_id
    ) do
      nil -> student_id  # Student is their own account
      parent_id -> parent_id
    end
  end

  defp fetch_user(user_id), do: ViralEngine.Repo.get!(User, user_id)
  defp fetch_session(session_id), do: ViralEngine.Repo.get!(TutoringSession, session_id)
end
```

### 3.5 Phase 3 Database Schema Additions

```elixir
# priv/repo/migrations/20250105_phase3_schema.exs

defmodule ViralEngine.Repo.Migrations.Phase3Schema do
  use Ecto.Migration

  def change do
    # Parental Consent
    create table(:parental_consents) do
      add :user_id, :integer, null: false
      add :parent_email, :string
      add :granted, :boolean, default: false
      add :consent_type, :string  # :coppa, :ferpa, :general
      add :granted_at, :utc_datetime
      add :ip_address, :string
      timestamps()
    end
    create index(:parental_consents, [:user_id])
    create index(:parental_consents, [:granted])

    # Device Flags (for fraud detection)
    create table(:device_flags) do
      add :device_id, :string, null: false
      add :flag_type, :string
      add :severity, :string  # :low, :medium, :high
      add :reason, :text
      add :flagged_at, :utc_datetime
      timestamps()
    end
    create index(:device_flags, [:device_id])
    create index(:device_flags, [:severity])

    # Tutoring Sessions (if not existing)
    create_if_not_exists table(:tutoring_sessions) do
      add :tutor_id, :integer, null: false
      add :student_id, :integer, null: false
      add :parent_id, :integer
      add :subject, :string
      add :duration_minutes, :integer
      add :audio_url, :string
      add :transcript, :text
      add :summary, :map
      add :feedback, :text
      add :rating, :integer
      add :completed_at, :utc_datetime
      add :processed_at, :utc_datetime
      timestamps()
    end
    create_if_not_exists index(:tutoring_sessions, [:tutor_id])
    create_if_not_exists index(:tutoring_sessions, [:student_id])
    create_if_not_exists index(:tutoring_sessions, [:completed_at])

    # Weekly Recaps
    create table(:weekly_recaps) do
      add :parent_id, :integer, null: false
      add :student_id, :integer, null: false
      add :week_number, :integer
      add :year, :integer
      add :data, :map  # JSON with all recap data
      add :generated_at, :utc_datetime
      timestamps()
    end
    create index(:weekly_recaps, [:parent_id])
    create index(:weekly_recaps, [:week_number, :year])

    # Achievements
    create_if_not_exists table(:achievements) do
      add :user_id, :integer, null: false
      add :achievement_type, :string
      add :description, :string
      add :earned_at, :utc_datetime
      timestamps()
    end
    create_if_not_exists index(:achievements, [:user_id])
    create_if_not_exists index(:achievements, [:earned_at])
  end

  defp create_if_not_exists(statement) do
    # Helper to avoid errors if table exists
    # In production, manage this with proper migration ordering
    statement
  rescue
    _ -> :ok
  end
end
```

### 3.6 MCP Deployment (Phase 3)

```bash
#!/bin/bash
# deploy_phase3.sh

echo "Deploying Phase 3: Trust & Safety + Session Intelligence + Loops 3 & 4"

# Trust & Safety Agent (always-on)
fly mcp launch \
  "mix run --no-halt -e ViralEngine.Agents.TrustSafety" \
  --server trust-safety-agent \
  --region ord \
  --vm-size shared-cpu-1x \
  --auto-stop 0 \
  --secret DATABASE_URL="${DATABASE_URL}"

# Update Orchestrator to include new loops
fly deploy --config fly.orchestrator.toml

echo "✅ Phase 3 agents deployed"

# Schedule weekly recap job (cron)
echo "Setting up weekly recap cron job..."
# Add to fly.toml or use external cron service
```

### 3.7 Compliance Middleware

```elixir
defmodule ViralEngineWeb.ComplianceMiddleware do
  @moduledoc """
  Phoenix plug to enforce COPPA/FERPA compliance on sensitive endpoints.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    
    if user_id && requires_compliance_check?(conn.request_path) do
      case ViralEngine.Agents.TrustSafety.check_action(
        user_id,
        action_type_from_path(conn.request_path),
        extract_context(conn)
      ) do
        {:ok, _} ->
          conn
        
        {:error, :coppa_no_consent} ->
          conn
          |> put_status(:forbidden)
          |> Phoenix.Controller.json(%{error: "Parental consent required"})
          |> halt()
        
        {:error, :ferpa_violation} ->
          conn
          |> put_status(:forbidden)
          |> Phoenix.Controller.json(%{error: "Educational records cannot be shared"})
          |> halt()
        
        {:error, reason} ->
          Logger.warn("Compliance check failed: #{inspect(reason)}")
          conn
          |> put_status(:forbidden)
          |> Phoenix.Controller.json(%{error: "Action not permitted"})
          |> halt()
      end
    else
      conn
    end
  end

  defp requires_compliance_check?(path) do
    path =~ ~r{/(share|invite|leaderboard)}
  end

  defp action_type_from_path(path) do
    cond do
      path =~ ~r{/share} -> :share_progress
      path =~ ~r{/invite} -> :send_invite
      path =~ ~r{/leaderboard} -> :public_leaderboard
      true -> :unknown
    end
  end

  defp extract_context(conn) do
    %{
      device_id: get_req_header(conn, "x-device-id") |> List.first(),
      ip_address: get_peer_ip(conn),
      user_agent: get_req_header(conn, "user-agent") |> List.first()
    }
  end

  defp get_peer_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end
end
```

### 3.8 Phase 3 Integration Tests

```elixir
defmodule ViralEngine.Phase3IntegrationTest do
  use ViralEngine.DataCase

  describe "Trust & Safety Agent" do
    test "blocks action when fraud score too high" do
      user = insert(:user, %{device_id: "known_bad_device"})
      
      # Flag device
      insert(:device_flag, %{device_id: "known_bad_device", severity: :high})

      # Try to trigger loop
      result = ViralEngine.Agents.TrustSafety.check_action(
        user.id,
        :send_invite,
        %{device_id: "known_bad_device"}
      )

      assert {:error, _reason} = result
    end

    test "requires parental consent for minor" do
      minor = insert(:user, %{age: 12, email_verified: true})
      
      result = ViralEngine.Agents.TrustSafety.check_action(
        minor.id,
        :social_sharing,
        %{}
      )

      assert {:error, :coppa_no_consent} = result
    end

    test "allows action with consent" do
      minor = insert(:user, %{age: 12})
      insert(:parental_consent, %{user_id: minor.id, granted: true})

      result = ViralEngine.Agents.TrustSafety.check_action(
        minor.id,
        :social_sharing,
        %{}
      )

      assert {:ok, _} = result
    end

    test "redacts PII for minors" do
      minor = insert(:user, %{age: 15, first_name: "Jane", last_name: "Smith"})
      
      data = %{
        content: "Contact me at jane.smith@email.com or 555-123-4567",
        full_name: "Jane Smith",
        email: "jane.smith@email.com"
      }

      {:ok, redacted} = ViralEngine.Agents.TrustSafety.redact_data(data, minor.id)

      assert redacted.email == nil
      assert redacted.content =~ "[EMAIL]"
      assert redacted.content =~ "[PHONE]"
    end
  end

  describe "Session Intelligence Pipeline" do
    test "processes session and generates student actions" do
      tutor = insert(:user, role: :tutor)
      student = insert(:user, role: :student)
      
      session = insert(:tutoring_session, %{
        tutor_id: tutor.id,
        student_id: student.id,
        subject: "Algebra",
        audio_url: "https://example.com/session.mp3"
      })

      # Process session
      result = ViralEngine.SessionPipeline.perform(%{args: %{"session_id" => session.id}})

      assert result == :ok

      # Check that actions were triggered
      events = ViralEngine.Repo.all(
        from e in ViralEvent,
        where: e.event_type == "agentic_action_triggered" and e.user_id == ^student.id
      )

      assert length(events) >= 2  # At least 2 student actions
    end
  end

  describe "Proud Parent Loop" do
    test "generates weekly recap and triggers share" do
      parent = insert(:user, role: :parent)
      student = insert(:user, role: :student, parent_id: parent.id)
      
      # Create activity for the week
      Enum.each(1..5, fn _ ->
        insert(:tutoring_session, %{student_id: student.id, completed_at: DateTime.utc_now()})
      end)

      # Generate recap
      recap = ViralEngine.Jobs.WeeklyRecapGenerator.generate_recap_for_parent(parent)

      assert recap.sessions_completed == 5

      # Trigger loop
      event = %{
        type: :weekly_recap_generated,
        user_id: parent.id,
        context: %{weekly_recap: recap}
      }

      {:ok, decision} = ViralEngine.Agents.Orchestrator.trigger_event(event)

      assert decision.action == :show_parent_share_modal
      assert decision.share_pack.progress_reel != nil
    end
  end

  describe "Tutor Spotlight Loop" do
    test "generates tutor share pack after 5-star session" do
      tutor = insert(:user, role: :tutor)
      session = insert(:tutoring_session, %{tutor_id: tutor.id, rating: 5})

      event = %{
        type: :session_rated_five_stars,
        user_id: tutor.id,
        context: %{session_id: session.id}
      }

      {:ok, decision} = ViralEngine.Agents.Orchestrator.trigger_event(event)

      assert decision.action == :show_tutor_share_pack
      assert decision.share_pack.tutor_card != nil
      assert decision.share_pack.one_tap_channels != nil
    end
  end
end
```

## Success Criteria (Phase 3)

- [ ] Trust & Safety Agent deployed and protecting all loops
- [ ] Fraud detection catching synthetic signups (test with dummy data)
- [ ] COPPA/FERPA compliance enforced (test with minor accounts)
- [ ] Session transcription pipeline working
- [ ] ≥4 agentic actions generated per session
- [ ] Proud Parent loop functional end-to-end
- [ ] Tutor Spotlight loop functional end-to-end
- [ ] Weekly recap job running on schedule
- [ ] All 4 loops live and measurable
- [ ] Abuse rate < 0.5%
- [ ] Opt-out rate < 1%

## Phase 3 Metrics Dashboard

```elixir
defmodule ViralEngineWeb.Phase3DashboardLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(10_000, self(), :refresh)
    end

    metrics = fetch_comprehensive_metrics()

    {:ok, assign(socket, :metrics, metrics)}
  end

  defp fetch_comprehensive_metrics do
    %{
      all_loops: %{
        buddy_challenge: fetch_loop_metrics(:buddy_challenge),
        results_rally: fetch_loop_metrics(:results_rally),
        proud_parent: fetch_loop_metrics(:proud_parent),
        tutor_spotlight: fetch_loop_metrics(:tutor_spotlight)
      },
      trust_safety: %{
        total_checks: count_ts_checks(),
        blocked_actions: count_blocked_actions(),
        fraud_rate: calculate_fraud_rate(),
        abuse_reports: count_abuse_reports()
      },
      session_intelligence: %{
        sessions_processed: count_processed_sessions(),
        actions_generated: count_agentic_actions(),
        avg_actions_per_session: calculate_avg_actions()
      },
      compliance: %{
        coppa_checks: count_coppa_checks(),
        ferpa_checks: count_ferpa_checks(),
        consent_rate: calculate_consent_rate()
      }
    }
  end

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-3xl font-bold mb-6">Phase 3: Complete Viral Engine</h1>
      
      <!-- All 4 Loops Summary -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <%= for {loop_id, metrics} <- @metrics.all_loops do %>
          <div class="bg-white p-4 rounded-lg shadow">
            <h3 class="font-bold mb-2"><%= format_loop_name(loop_id) %></h3>
            <div class="text-sm space-y-1">
              <div class="flex justify-between">
                <span>K-Factor:</span>
                <span class={k_factor_class(metrics.k_factor)}>
                  <%= Float.round(metrics.k_factor, 3) %>
                </span>
              </div>
              <div class="flex justify-between">
                <span>Invites:</span>
                <span><%= metrics.invites %></span>
              </div>
              <div class="flex justify-between">
                <span>Joins:</span>
                <span><%= metrics.joins %></span>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Trust & Safety -->
      <div class="bg-yellow-50 p-6 rounded-lg mb-6">
        <h2 class="text-xl font-bold mb-4">Trust & Safety</h2>
        <div class="grid grid-cols-4 gap-4">
          <div>
            <div class="text-sm text-gray-600">Total Checks</div>
            <div class="text-2xl font-bold"><%= @metrics.trust_safety.total_checks %></div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Blocked</div>
            <div class="text-2xl font-bold text-red-600"><%= @metrics.trust_safety.blocked_actions %></div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Fraud Rate</div>
            <div class={[
              "text-2xl font-bold",
              if(@metrics.trust_safety.fraud_rate < 0.5, do: "text-green-600", else: "text-red-600")
            ]}>
              <%= Float.round(@metrics.trust_safety.fraud_rate, 2) %>%
            </div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Abuse Reports</div>
            <div class="text-2xl font-bold"><%= @metrics.trust_safety.abuse_reports %></div>
          </div>
        </div>
      </div>

      <!-- Session Intelligence -->
      <div class="bg-blue-50 p-6 rounded-lg">
        <h2 class="text-xl font-bold mb-4">Session Intelligence</h2>
        <div class="grid grid-cols-3 gap-4">
          <div>
            <div class="text-sm text-gray-600">Sessions Processed</div>
            <div class="text-2xl font-bold"><%= @metrics.session_intelligence.sessions_processed %></div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Actions Generated</div>
            <div class="text-2xl font-bold"><%= @metrics.session_intelligence.actions_generated %></div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Avg per Session</div>
            <div class="text-2xl font-bold"><%= Float.round(@metrics.session_intelligence.avg_actions_per_session, 1) %></div>
          </div>
        </div>
      </div>

      <div class="mt-6 bg-green-50 p-4 rounded">
        <p class="font-semibold">✅ Phase 3 Complete!</p>
        <p class="text-sm mt-2">All 4 viral loops operational. Ready for Phase 4: Real-time & Scale.</p>
      </div>
    </div>
    """
  end

  defp format_loop_name(loop_id) do
    loop_id
    |> to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp k_factor_class(k) do
    cond do
      k >= 1.2 -> "font-bold text-green-600"
      k >= 1.0 -> "font-bold text-yellow-600"
      true -> "font-bold text-red-600"
    end
  end
end
```

---

**Next: Phase 4** (Real-time "Alive" Layer + Phoenix Presence + Scale Testing + Final Polish)
