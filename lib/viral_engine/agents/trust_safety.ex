defmodule ViralEngine.Agents.TrustSafety do
  @moduledoc """
  TrustSafety Agent for fraud detection, COPPA/FERPA compliance, and abuse prevention.

  This GenServer manages:
  - Blocklist checking
  - Rate limiting
  - Duplicate detection
  - Fraud scoring
  - COPPA/FERPA compliance checks
  - Content redaction for privacy
  """

  use GenServer
  require Logger
  alias ViralEngine.Repo
  alias ViralEngine.{DeviceFlag, ParentalConsent, Accounts.User}
  import Ecto.Query

  # Configuration - can be overridden in config/config.exs
  @fraud_threshold Application.compile_env(:viral_engine, :fraud_threshold, 7.0)
  @rate_limit_window Application.compile_env(:viral_engine, :rate_limit_window, 60_000)  # 1 minute in ms
  @rate_limit_max Application.compile_env(:viral_engine, :rate_limit_max, 10)
  @coppa_age_threshold Application.compile_env(:viral_engine, :coppa_age_threshold, 13)

  # Client API

  @doc """
  Start the TrustSafety agent.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if an action is allowed based on trust and safety rules.

  ## Parameters
    - context: Map with :user_id, :action_type, :device_id, :ip_address, etc.

  ## Returns
    - {:ok, :allowed} if action passes all checks
    - {:error, reason} if action is blocked
  """
  def check_action(context) do
    GenServer.call(__MODULE__, {:check_action, context})
  end

  @doc """
  Report abuse for a user or content.
  """
  def report_abuse(report) do
    GenServer.cast(__MODULE__, {:report_abuse, report})
  end

  @doc """
  Redact sensitive data from content for privacy compliance.
  """
  def redact_data(content, context) do
    GenServer.call(__MODULE__, {:redact_data, content, context})
  end

  @doc """
  Update user signal for fraud scoring (e.g., successful payment, verified email).
  """
  def update_user_signal(user_id, signal_type, value) do
    GenServer.cast(__MODULE__, {:update_user_signal, user_id, signal_type, value})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      blocklist: MapSet.new(),
      rate_limits: %{},
      user_signals: %{},
      abuse_reports: []
    }

    Logger.info("TrustSafety agent started")
    {:ok, state}
  end

  @impl true
  def handle_call({:check_action, context}, _from, state) do
    result =
      with :ok <- check_blocklist(context, state),
           :ok <- check_rate_limit(context, state),
           :ok <- check_duplicates(context),
           :ok <- check_fraud_score(context, state),
           :ok <- ensure_compliance(context) do
        {:ok, :allowed}
      else
        {:error, reason} -> {:error, reason}
      end

    # Update rate limiting state after successful check
    new_state =
      case result do
        {:ok, :allowed} ->
          update_rate_limit_state(context, state)

        _ ->
          state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:redact_data, content, context}, _from, state) do
    redacted = perform_redaction(content, context)
    {:reply, {:ok, redacted}, state}
  end

  @impl true
  def handle_cast({:report_abuse, report}, state) do
    Logger.warning("Abuse reported: #{inspect(report)}")

    # Add to abuse reports and potentially add to blocklist
    new_state = %{
      state
      | abuse_reports: [report | state.abuse_reports],
        blocklist:
          if should_block_from_report?(report) do
            add_to_blocklist(state.blocklist, report)
          else
            state.blocklist
          end
    }

    # Persist to database
    persist_abuse_report(report)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_user_signal, user_id, signal_type, value}, state) do
    user_signals = Map.update(state.user_signals, user_id, %{}, fn signals ->
      Map.put(signals, signal_type, value)
    end)

    {:noreply, %{state | user_signals: user_signals}}
  end

  # Helper Functions

  defp check_blocklist(%{device_id: device_id} = context, state) do
    cond do
      MapSet.member?(state.blocklist, device_id) ->
        {:error, :device_blocked}

      context[:ip_address] && MapSet.member?(state.blocklist, context.ip_address) ->
        {:error, :ip_blocked}

      context[:user_id] && MapSet.member?(state.blocklist, context.user_id) ->
        {:error, :user_blocked}

      true ->
        # Check database for persistent blocks
        case Repo.get_by(DeviceFlag, device_id: device_id, blocked: true) do
          nil -> :ok
          _flag -> {:error, :device_flagged}
        end
    end
  end

  defp check_rate_limit(%{user_id: user_id, action_type: action_type} = _context, state) do
    key = {user_id, action_type}
    now = System.monotonic_time(:millisecond)

    rate_data = Map.get(state.rate_limits, key, %{count: 0, window_start: now})

    if now - rate_data.window_start > @rate_limit_window do
      # Reset window
      :ok
    else
      if rate_data.count >= @rate_limit_max do
        {:error, :rate_limited}
      else
        :ok
      end
    end
  end

  defp check_duplicates(%{action_type: action_type, user_id: user_id} = context) do
    # Check for duplicate actions within a short time window
    case action_type do
      "signup" ->
        check_duplicate_signup(user_id, context)

      "share" ->
        check_duplicate_share(user_id, context)

      _ ->
        :ok
    end
  end

  defp check_duplicate_signup(user_id, context) do
    # Check if device or IP already signed up recently
    device_id = context[:device_id]
    ip_address = context[:ip_address]
    yesterday = DateTime.add(DateTime.utc_now(), -86400, :second)

    # Check DeviceFlag table for recent signups from same device or IP
    duplicate_query =
      from(d in DeviceFlag,
        where: d.inserted_at >= ^yesterday,
        where: d.flag_type == "signup" or is_nil(d.flag_type)
      )

    duplicate_query =
      if device_id do
        from(d in duplicate_query, or_where: d.device_id == ^device_id)
      else
        duplicate_query
      end

    duplicate_query =
      if ip_address do
        from(d in duplicate_query, or_where: d.ip_address == ^ip_address)
      else
        duplicate_query
      end

    case Repo.one(from(d in duplicate_query, limit: 1)) do
      nil ->
        # No duplicate found, record this signup attempt
        record_signup_attempt(user_id, device_id, ip_address)
        :ok

      _flag ->
        {:error, :duplicate_signup}
    end
  end

  defp check_duplicate_share(user_id, context) do
    # Check for duplicate share actions within short time window
    device_id = context[:device_id]
    five_minutes_ago = DateTime.add(DateTime.utc_now(), -300, :second)

    query =
      from(d in DeviceFlag,
        where: d.flag_type == "share",
        where: d.inserted_at >= ^five_minutes_ago
      )

    query =
      if device_id do
        from(d in query, where: d.device_id == ^device_id)
      else
        query
      end

    case Repo.aggregate(query, :count, :id) do
      count when count >= 5 ->
        {:error, :duplicate_share}

      _ ->
        :ok
    end
  end

  defp record_signup_attempt(user_id, device_id, ip_address) do
    # Record signup attempt in DeviceFlag for future duplicate detection
    if device_id && ip_address do
      attrs = %{
        device_id: device_id,
        ip_address: ip_address,
        flag_type: "signup",
        flag_reason: "Signup attempt recorded",
        risk_score: 0.0,
        blocked: false
      }

      case Repo.insert(DeviceFlag.changeset(%DeviceFlag{}, attrs)) do
        {:ok, _} -> :ok
        {:error, _} -> :ok  # Don't fail signup if recording fails
      end
    end

    :ok
  end

  defp check_fraud_score(context, state) do
    score = calculate_fraud_score(context, state)

    if score > @fraud_threshold do
      Logger.warning("High fraud score detected: #{score} for context #{inspect(context)}")
      {:error, :fraud_detected}
    else
      :ok
    end
  end

  defp calculate_fraud_score(context, state) do
    base_score = 0.0
    user_id = context[:user_id]
    signals = Map.get(state.user_signals, user_id, %{})

    # Positive signals reduce score
    score = base_score
    score = if signals[:verified_email], do: score - 1.0, else: score + 1.5
    score = if signals[:payment_verified], do: score - 2.0, else: score + 1.0
    score = if signals[:phone_verified], do: score - 1.5, else: score + 0.5

    # Device flags increase score
    score =
      case context[:device_id] do
        nil ->
          score + 2.0

        device_id ->
          case Repo.get_by(DeviceFlag, device_id: device_id) do
            nil -> score
            flag -> score + flag.risk_score
          end
      end

    # Multiple signups from same IP
    score =
      if context[:ip_address] do
        recent_signups = count_recent_signups_from_ip(context.ip_address)
        score + recent_signups * 0.5
      else
        score + 1.0
      end

    max(0.0, score)
  end

  defp ensure_compliance(%{user_id: user_id, action_type: action_type} = context) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        # COPPA compliance check
        if requires_parental_consent?(user, action_type) do
          case check_parental_consent(user_id) do
            :ok -> :ok
            {:error, reason} -> {:error, reason}
          end
        else
          :ok
        end
    end
  end

  defp requires_parental_consent?(user, action_type) do
    # Check if user is under 13 and action requires consent
    is_minor = user.age && user.age < @coppa_age_threshold

    sensitive_actions = [
      "share_personal_info",
      "public_profile",
      "social_features",
      "data_export"
    ]

    is_minor && action_type in sensitive_actions
  end

  defp check_parental_consent(user_id) do
    case Repo.get_by(ParentalConsent, user_id: user_id, consent_given: true) do
      nil ->
        {:error, :parental_consent_required}

      consent ->
        if consent.withdrawn_at do
          {:error, :consent_withdrawn}
        else
          :ok
        end
    end
  end

  defp perform_redaction(content, context) do
    # Redact sensitive information based on context
    redacted = content

    # Redact email addresses
    redacted = Regex.replace(~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, redacted, "[EMAIL]")

    # Redact phone numbers
    redacted = Regex.replace(~r/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/, redacted, "[PHONE]")

    # Redact SSN-like patterns
    redacted = Regex.replace(~r/\b\d{3}-\d{2}-\d{4}\b/, redacted, "[SSN]")

    # If user is a minor, be more aggressive
    if context[:user_age] && context.user_age < @coppa_age_threshold do
      # Redact names (simplified)
      redacted = Regex.replace(~r/\b[A-Z][a-z]+ [A-Z][a-z]+\b/, redacted, "[NAME]")
    end

    redacted
  end

  defp should_block_from_report?(report) do
    # Block if severity is high or multiple reports for same entity
    report[:severity] == :high || count_reports_for_entity(report[:entity_id]) > 3
  end

  defp add_to_blocklist(blocklist, report) do
    case report[:entity_type] do
      :device -> MapSet.put(blocklist, report[:entity_id])
      :ip -> MapSet.put(blocklist, report[:entity_id])
      :user -> MapSet.put(blocklist, report[:entity_id])
      _ -> blocklist
    end
  end

  defp persist_abuse_report(report) do
    # Store abuse report in database
    device_flag_attrs = %{
      device_id: report[:device_id] || "unknown",
      ip_address: report[:ip_address] || "unknown",
      flag_type: "abuse",
      flag_reason: report[:reason],
      risk_score: if(report[:severity] == :high, do: 9.0, else: 5.0),
      blocked: report[:severity] == :high
    }

    case Repo.insert(DeviceFlag.changeset(%DeviceFlag{}, device_flag_attrs)) do
      {:ok, _flag} -> :ok
      {:error, changeset} -> Logger.error("Failed to persist abuse report: #{inspect(changeset)}")
    end
  end

  defp count_reports_for_entity(entity_id) do
    # Query database for abuse reports count for this entity
    yesterday = DateTime.add(DateTime.utc_now(), -86400, :second)

    from(d in DeviceFlag,
      where: d.device_id == ^entity_id,
      where: d.flag_type == "abuse",
      where: d.inserted_at >= ^yesterday
    )
    |> Repo.aggregate(:count, :id)
  end

  defp count_recent_signups_from_ip(ip_address) do
    # Query DeviceFlags for recent signups from this IP
    yesterday = DateTime.add(DateTime.utc_now(), -86400, :second)

    from(d in DeviceFlag,
      where: d.ip_address == ^ip_address,
      where: d.inserted_at >= ^yesterday,
      distinct: d.device_id
    )
    |> Repo.aggregate(:count, :id)
  end

  defp update_rate_limit_state(%{user_id: user_id, action_type: action_type}, state) do
    key = {user_id, action_type}
    now = System.monotonic_time(:millisecond)

    rate_data = Map.get(state.rate_limits, key, %{count: 0, window_start: now})

    new_rate_data =
      if now - rate_data.window_start > @rate_limit_window do
        # Reset window
        %{count: 1, window_start: now}
      else
        # Increment count
        %{rate_data | count: rate_data.count + 1}
      end

    # Update state with new rate limit data
    new_rate_limits = Map.put(state.rate_limits, key, new_rate_data)

    # Clean up old entries to prevent memory leak
    cleaned_rate_limits = clean_old_rate_limits(new_rate_limits, now)

    %{state | rate_limits: cleaned_rate_limits}
  end

  defp clean_old_rate_limits(rate_limits, now) do
    # Remove entries older than 2x the rate limit window
    cutoff = now - @rate_limit_window * 2

    Enum.filter(rate_limits, fn {_key, data} ->
      data.window_start > cutoff
    end)
    |> Enum.into(%{})
  end
end
