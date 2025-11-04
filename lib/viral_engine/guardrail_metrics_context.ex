defmodule ViralEngine.GuardrailMetricsContext do
  @moduledoc """
  Context for monitoring fraud, compliance, and guardrail metrics.
  """

  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.{
    AttributionEvent,
    AttributionLink,
    ViralLink,
    Experiment,
    ExperimentAssignment,
    StudySession,
    ProgressReel,
    ParentShare
  }

  require Logger

  @doc """
  Detects suspicious click patterns that may indicate fraud.
  """
  def detect_suspicious_clicks(opts \\ []) do
    days = opts[:days] || 7
    threshold = opts[:threshold] || 10  # Clicks per IP per day

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    # Group clicks by IP address and date
    suspicious_ips = from(ae in AttributionEvent,
      where: ae.event_type == "click" and ae.inserted_at >= ^cutoff,
      group_by: [fragment("DATE(?)", ae.inserted_at), ae.ip_address],
      select: %{
        date: fragment("DATE(?)", ae.inserted_at),
        ip_address: ae.ip_address,
        click_count: count(ae.id)
      },
      having: count(ae.id) > ^threshold
    )
    |> Repo.all()

    %{
      suspicious_ips: suspicious_ips,
      total_flagged_ips: length(suspicious_ips),
      threshold_used: threshold
    }
  end

  @doc """
  Detects bot-like behavior based on rapid sequential clicks.
  """
  def detect_bot_behavior(opts \\ []) do
    days = opts[:days] || 7
    time_window_seconds = opts[:time_window] || 5  # 5 seconds
    min_clicks = opts[:min_clicks] || 3  # 3+ clicks in 5 seconds

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    # Find device fingerprints with rapid clicks
    bot_like_devices = from(ae in AttributionEvent,
      where: ae.event_type == "click" and ae.inserted_at >= ^cutoff,
      order_by: [asc: ae.device_fingerprint, asc: ae.inserted_at]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.device_fingerprint)
    |> Enum.filter(fn {_device, events} ->
      # Check for rapid sequential clicks
      events
      |> Enum.chunk_every(min_clicks, 1, :discard)
      |> Enum.any?(fn chunk ->
        first_time = hd(chunk).inserted_at
        last_time = List.last(chunk).inserted_at
        DateTime.diff(last_time, first_time) <= time_window_seconds
      end)
    end)
    |> Enum.map(fn {device, events} ->
      %{
        device_fingerprint: device,
        total_clicks: length(events),
        first_seen: hd(events).inserted_at,
        last_seen: List.last(events).inserted_at
      }
    end)

    %{
      bot_like_devices: bot_like_devices,
      total_flagged_devices: length(bot_like_devices),
      detection_params: %{
        time_window_seconds: time_window_seconds,
        min_clicks: min_clicks
      }
    }
  end

  @doc """
  Tracks opt-out rates for viral features.
  """
  def compute_opt_out_rates(opts \\ []) do
    days = opts[:days] || 30
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    # Note: In a real implementation, you'd have opt_out tables/fields
    # For now, we'll simulate with existing data patterns

    # Study session opt-outs (users who were invited but never joined)
    study_session_stats = from(ss in StudySession,
      where: ss.inserted_at >= ^cutoff,
      select: %{
        total_sessions: count(ss.id),
        avg_participants: avg(fragment("array_length(?, 1)", ss.participant_ids))
      }
    )
    |> Repo.one()

    # Parent share opt-outs (shares marked as opt-out or never viewed)
    parent_share_stats = from(ps in ParentShare,
      where: ps.inserted_at >= ^cutoff,
      select: %{
        total_shares: count(ps.id),
        never_viewed: fragment("COUNT(*) FILTER (WHERE ? = 0)", ps.view_count)
      }
    )
    |> Repo.one()

    # Attribution link opt-outs (links with 0 clicks)
    attribution_stats = from(al in AttributionLink,
      where: al.inserted_at >= ^cutoff,
      select: %{
        total_links: count(al.id),
        zero_clicks: fragment("COUNT(*) FILTER (WHERE ? = 0)", al.click_count)
      }
    )
    |> Repo.one()

    %{
      period_days: days,
      study_sessions: %{
        total: study_session_stats[:total_sessions] || 0,
        avg_participants: Float.round((study_session_stats[:avg_participants] || 0.0) * 1.0, 2)
      },
      parent_shares: %{
        total: parent_share_stats[:total_shares] || 0,
        never_viewed: parent_share_stats[:never_viewed] || 0,
        opt_out_rate: calculate_percentage(
          parent_share_stats[:never_viewed] || 0,
          parent_share_stats[:total_shares] || 0
        )
      },
      attribution_links: %{
        total: attribution_stats[:total_links] || 0,
        zero_clicks: attribution_stats[:zero_clicks] || 0,
        opt_out_rate: calculate_percentage(
          attribution_stats[:zero_clicks] || 0,
          attribution_stats[:total_links] || 0
        )
      }
    }
  end

  @doc """
  Monitors COPPA compliance metrics.
  """
  def monitor_coppa_compliance(opts \\ []) do
    days = opts[:days] || 30
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    # Parent shares should only contain approved data fields
    parent_shares = from(ps in ParentShare,
      where: ps.inserted_at >= ^cutoff,
      select: ps
    )
    |> Repo.all()

    # Check for any PII leaks in share_data
    violations = Enum.filter(parent_shares, fn share ->
      detect_pii_in_data(share.share_data)
    end)

    # Progress reels should be privacy-safe
    progress_reels = from(pr in ProgressReel,
      where: pr.inserted_at >= ^cutoff,
      select: pr
    )
    |> Repo.all()

    reel_violations = Enum.filter(progress_reels, fn reel ->
      detect_pii_in_data(reel.reel_data)
    end)

    %{
      period_days: days,
      parent_shares: %{
        total_checked: length(parent_shares),
        violations_found: length(violations),
        compliance_rate: calculate_percentage(
          length(parent_shares) - length(violations),
          length(parent_shares)
        )
      },
      progress_reels: %{
        total_checked: length(progress_reels),
        violations_found: length(reel_violations),
        compliance_rate: calculate_percentage(
          length(progress_reels) - length(reel_violations),
          length(progress_reels)
        )
      },
      overall_compliance_rate: calculate_percentage(
        (length(parent_shares) + length(progress_reels)) -
        (length(violations) + length(reel_violations)),
        length(parent_shares) + length(progress_reels)
      )
    }
  end

  @doc """
  Tracks conversion anomalies that may indicate fraud.
  """
  def detect_conversion_anomalies(opts \\ []) do
    days = opts[:days] || 7
    threshold = opts[:threshold] || 10  # Conversions per referrer per day

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    # Group conversions by referrer and date
    suspicious_referrers = from(ae in AttributionEvent,
      where: ae.event_type == "conversion" and ae.inserted_at >= ^cutoff,
      group_by: [fragment("DATE(?)", ae.inserted_at), ae.referrer_id],
      select: %{
        date: fragment("DATE(?)", ae.inserted_at),
        referrer_id: ae.referrer_id,
        conversion_count: count(ae.id)
      },
      having: count(ae.id) > ^threshold
    )
    |> Repo.all()

    # Also check conversion rate anomalies (too high = suspicious)
    referrer_stats = from(ae in AttributionEvent,
      where: ae.inserted_at >= ^cutoff,
      group_by: ae.referrer_id,
      select: %{
        referrer_id: ae.referrer_id,
        total_clicks: fragment("COUNT(*) FILTER (WHERE ? = 'click')", ae.event_type),
        total_conversions: fragment("COUNT(*) FILTER (WHERE ? = 'conversion')", ae.event_type)
      }
    )
    |> Repo.all()
    |> Enum.map(fn stat ->
      conv_rate = if stat.total_clicks > 0 do
        stat.total_conversions / stat.total_clicks * 100
      else
        0.0
      end

      Map.put(stat, :conversion_rate, Float.round(conv_rate, 2))
    end)
    |> Enum.filter(fn stat ->
      # Flag conversion rates above 80% as suspicious
      stat.conversion_rate > 80.0
    end)

    %{
      suspicious_referrers: suspicious_referrers,
      high_conversion_rate_referrers: referrer_stats,
      total_flagged: length(suspicious_referrers) + length(referrer_stats)
    }
  end

  @doc """
  Generates overall health score for viral features.
  """
  def compute_health_score(opts \\ []) do
    days = opts[:days] || 7

    fraud_data = detect_suspicious_clicks(days: days)
    bot_data = detect_bot_behavior(days: days)
    opt_out_data = compute_opt_out_rates(days: days)
    coppa_data = monitor_coppa_compliance(days: days)
    anomaly_data = detect_conversion_anomalies(days: days)

    # Compute health score (0-100)
    # Deductions for issues found
    health_score = 100.0

    # Deduct for fraud indicators (up to 30 points)
    fraud_deduction = min(fraud_data.total_flagged_ips * 2, 30)
    health_score = health_score - fraud_deduction

    # Deduct for bot behavior (up to 20 points)
    bot_deduction = min(bot_data.total_flagged_devices * 2, 20)
    health_score = health_score - bot_deduction

    # Deduct for high opt-out rates (up to 20 points)
    avg_opt_out = (opt_out_data.parent_shares.opt_out_rate +
                   opt_out_data.attribution_links.opt_out_rate) / 2
    opt_out_deduction = min(avg_opt_out / 5, 20)
    health_score = health_score - opt_out_deduction

    # Deduct for COPPA violations (up to 30 points - most serious)
    coppa_deduction = min((100 - coppa_data.overall_compliance_rate) / 3, 30)
    health_score = health_score - coppa_deduction

    health_score = max(health_score, 0.0) |> Float.round(1)

    health_status = cond do
      health_score >= 90 -> :excellent
      health_score >= 75 -> :good
      health_score >= 60 -> :fair
      health_score >= 40 -> :warning
      true -> :critical
    end

    %{
      health_score: health_score,
      health_status: health_status,
      deductions: %{
        fraud: fraud_deduction,
        bot_behavior: bot_deduction,
        opt_out_rate: Float.round(opt_out_deduction, 1),
        coppa_violations: Float.round(coppa_deduction, 1)
      },
      components: %{
        fraud: fraud_data,
        bots: bot_data,
        opt_outs: opt_out_data,
        coppa: coppa_data,
        anomalies: anomaly_data
      }
    }
  end

  @doc """
  Gets alerts that need attention.
  """
  def get_active_alerts(opts \\ []) do
    days = opts[:days] || 7
    health_data = compute_health_score(days: days)

    alerts = []

    # Critical COPPA violations
    if health_data.components.coppa.parent_shares.violations_found > 0 do
      alerts = alerts ++ [%{
        severity: :critical,
        type: :coppa_violation,
        message: "#{health_data.components.coppa.parent_shares.violations_found} COPPA violations detected in parent shares",
        timestamp: DateTime.utc_now()
      }]
    end

    # Fraud alerts
    if health_data.components.fraud.total_flagged_ips > 5 do
      alerts = alerts ++ [%{
        severity: :high,
        type: :fraud_detection,
        message: "#{health_data.components.fraud.total_flagged_ips} suspicious IPs detected",
        timestamp: DateTime.utc_now()
      }]
    end

    # Bot behavior
    if health_data.components.bots.total_flagged_devices > 3 do
      alerts = alerts ++ [%{
        severity: :medium,
        type: :bot_detection,
        message: "#{health_data.components.bots.total_flagged_devices} bot-like devices detected",
        timestamp: DateTime.utc_now()
      }]
    end

    # High opt-out rates
    parent_opt_out = health_data.components.opt_outs.parent_shares.opt_out_rate
    if parent_opt_out > 30 do
      alerts = alerts ++ [%{
        severity: :medium,
        type: :high_opt_out,
        message: "Parent share opt-out rate is #{parent_opt_out}%",
        timestamp: DateTime.utc_now()
      }]
    end

    # Conversion anomalies
    if health_data.components.anomalies.total_flagged > 0 do
      alerts = alerts ++ [%{
        severity: :high,
        type: :conversion_anomaly,
        message: "#{health_data.components.anomalies.total_flagged} suspicious conversion patterns detected",
        timestamp: DateTime.utc_now()
      }]
    end

    %{
      total_alerts: length(alerts),
      alerts: alerts,
      health_score: health_data.health_score,
      health_status: health_data.health_status
    }
  end

  # Private helpers

  defp detect_pii_in_data(data) when is_map(data) do
    # Check for common PII fields
    pii_fields = ["email", "phone", "address", "ssn", "full_name", "password"]

    # Convert map keys to strings and check
    string_keys = data
    |> Map.keys()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.downcase/1)

    Enum.any?(pii_fields, fn pii_field ->
      Enum.any?(string_keys, &String.contains?(&1, pii_field))
    end)
  end
  defp detect_pii_in_data(_), do: false

  defp calculate_percentage(numerator, denominator) when denominator > 0 do
    Float.round(numerator / denominator * 100, 2)
  end
  defp calculate_percentage(_, _), do: 0.0
end
