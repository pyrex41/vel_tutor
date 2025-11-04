defmodule ViralEngine.PerformanceReportContext do
  @moduledoc """
  Context for generating and managing weekly viral loop performance reports.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, PerformanceReport}
  alias ViralEngine.{ViralMetricsContext, GuardrailMetricsContext}
  require Logger

  @doc """
  Generates a comprehensive weekly performance report.
  """
  def generate_weekly_report(opts \\ []) do
    # Default to last 7 days
    end_date = opts[:end_date] || Date.utc_today()
    start_date = opts[:start_date] || Date.add(end_date, -7)

    days = Date.diff(end_date, start_date)

    # Gather all metrics
    k_factor_data = ViralMetricsContext.compute_k_factor(days: days)
    k_by_source = ViralMetricsContext.compute_k_factor_by_source(days)
    top_referrers = ViralMetricsContext.get_top_referrers(days: days, limit: 10)
    _timeline = ViralMetricsContext.get_growth_timeline(days)
    health_data = GuardrailMetricsContext.compute_health_score(days: days)

    # Compare with previous period for trends
    previous_k_factor = ViralMetricsContext.compute_k_factor(
      days: days,
      offset_days: days
    )

    k_factor_trend = determine_trend(k_factor_data.k_factor, previous_k_factor.k_factor)
    k_factor_change_pct = calculate_change_percentage(
      k_factor_data.k_factor,
      previous_k_factor.k_factor
    )

    conversion_trend = determine_trend(
      k_factor_data.conversion_rate,
      previous_k_factor.conversion_rate
    )

    # Format loop performance by source
    loop_performance = k_by_source
    |> Enum.map(fn source_data ->
      {source_data.source, %{
        invites: source_data.total_invites,
        conversions: source_data.total_conversions,
        k_factor: source_data.k_factor,
        conversion_rate: source_data.conversion_rate
      }}
    end)
    |> Enum.into(%{})

    # Generate insights
    insights = generate_insights(%{
      k_factor: k_factor_data,
      k_factor_trend: k_factor_trend,
      loop_performance: loop_performance,
      health_data: health_data,
      top_referrers: top_referrers
    })

    # Generate recommendations
    recommendations = generate_recommendations(%{
      k_factor: k_factor_data,
      loop_performance: loop_performance,
      health_data: health_data
    })

    # Create report record
    report_attrs = %{
      report_period_start: start_date,
      report_period_end: end_date,
      report_type: "weekly",
      k_factor: k_factor_data.k_factor,
      k_factor_trend: k_factor_trend,
      k_factor_change_pct: k_factor_change_pct,
      total_conversions: k_factor_data.total_conversions,
      conversion_rate: k_factor_data.conversion_rate,
      conversion_trend: conversion_trend,
      active_users: k_factor_data.active_users,
      viral_links_created: k_factor_data.total_invites,
      viral_links_clicked: k_factor_data.total_clicks,
      loop_performance: loop_performance,
      top_referrers: format_top_referrers(top_referrers),
      insights: insights,
      recommendations: recommendations,
      health_score: health_data.health_score,
      compliance_rate: health_data.components.coppa.overall_compliance_rate,
      fraud_flags: health_data.components.fraud.total_flagged_ips +
                   health_data.components.bots.total_flagged_devices
    }

    case Repo.insert(PerformanceReport.changeset(%PerformanceReport{}, report_attrs)) do
      {:ok, report} ->
        Logger.info("Generated weekly performance report: #{report.id}")
        {:ok, report}

      {:error, changeset} ->
        Logger.error("Failed to generate report: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Gets all reports with optional filters.
  """
  def list_reports(opts \\ []) do
    limit = opts[:limit] || 10
    report_type = opts[:report_type]

    query = from(r in PerformanceReport,
      order_by: [desc: r.report_period_end],
      limit: ^limit
    )

    query = if report_type do
      from(r in query, where: r.report_type == ^report_type)
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Gets a specific report by ID.
  """
  def get_report(report_id) do
    Repo.get(PerformanceReport, report_id)
  end

  @doc """
  Marks a report as delivered.
  """
  def mark_delivered(report_id, recipients \\ []) do
    report = Repo.get(PerformanceReport, report_id)

    if report do
      report
      |> PerformanceReport.changeset(%{
        delivery_status: "delivered",
        delivered_at: DateTime.utc_now(),
        recipient_emails: recipients
      })
      |> Repo.update()
    else
      {:error, :not_found}
    end
  end

  @doc """
  Sends report via email (placeholder - integrate with actual email service).
  """
  def deliver_report(report_id, recipient_emails) do
    report = get_report(report_id)

    if report do
      # In production, integrate with email service (e.g., Swoosh, SendGrid)
      # For now, just log
      Logger.info("Delivering report #{report_id} to #{inspect(recipient_emails)}")

      # Simulate email sending
      email_content = format_email_content(report)

      # TODO: Replace with actual email sending
      # Example:
      # Email.deliver(
      #   to: recipient_emails,
      #   subject: "Weekly Viral Loop Performance Report",
      #   html: email_content
      # )

      Logger.info("Report email content:\n#{email_content}")

      # Mark as delivered
      mark_delivered(report_id, recipient_emails)
    else
      {:error, :not_found}
    end
  end

  # Private helpers

  defp determine_trend(current, previous) when is_float(current) and is_float(previous) do
    diff = current - previous
    threshold = 0.05  # 5% threshold for "stable"

    cond do
      diff > threshold -> "up"
      diff < -threshold -> "down"
      true -> "stable"
    end
  end
  defp determine_trend(_, _), do: "stable"

  defp calculate_change_percentage(current, previous) when is_float(previous) and previous != 0.0 do
    Float.round((current - previous) / previous * 100, 2)
  end
  defp calculate_change_percentage(_, _), do: 0.0

  defp generate_insights(data) do
    insights = []

    # K-factor insights
    k_factor = data.k_factor.k_factor
    insights = insights ++ [
      if k_factor >= 1.0 do
        "🚀 Viral threshold achieved! K-factor of #{Float.round(k_factor, 2)} means exponential growth is occurring."
      else
        "📊 K-factor is #{Float.round(k_factor, 2)}. #{Float.round((1.0 - k_factor) * 100, 0)}% improvement needed to reach viral threshold."
      end
    ]

    # Trend insights
    insights = if data.k_factor_trend == "up" do
      insights ++ ["📈 K-factor is trending upward - growth is accelerating!"]
    else if data.k_factor_trend == "down" do
      insights ++ ["⚠️ K-factor is declining - review recent changes and engagement strategies"]
    else
      insights
    end
    end

    # Loop performance insights
    top_loop = data.loop_performance
    |> Enum.max_by(fn {_source, perf} -> perf[:k_factor] || 0.0 end, fn -> nil end)

    insights = if top_loop do
      {source, perf} = top_loop
      source_name = source_display_name(source)
      insights ++ [
        "🏆 Top performing loop: #{source_name} with K-factor of #{Float.round(perf[:k_factor] || 0.0, 2)}"
      ]
    else
      insights
    end

    # Health insights
    health_score = data.health_data.health_score
    insights = if health_score < 75 do
      insights ++ [
        "⚠️ System health score is #{health_score}/100 - review guardrail metrics and address flagged issues"
      ]
    else
      insights ++ [
        "✅ System health is strong at #{health_score}/100 - all viral loops operating within healthy parameters"
      ]
    end

    # Top referrer insights
    insights = if length(data.top_referrers) > 0 do
      top_ref = hd(data.top_referrers)
      insights ++ [
        "🌟 Top referrer contributed #{top_ref.total_conversions} conversions with a #{Float.round(top_ref.conversion_rate || 0.0, 1)}% conversion rate"
      ]
    else
      insights
    end

    insights
  end

  defp generate_recommendations(data) do
    k_factor = data.k_factor.k_factor

    # K-factor recommendations
    recommendations = cond do
      k_factor < 0.3 ->
        [
          "Focus on increasing both invitation frequency and conversion rates",
          "Review user onboarding flow to improve first-time experience",
          "Consider incentivizing referrals with rewards or gamification"
        ]

      k_factor < 0.7 ->
        [
          "Optimize invitation messaging and call-to-action placement",
          "A/B test different viral loop entry points",
          "Reduce friction in the invitation acceptance flow"
        ]

      k_factor < 1.0 ->
        [
          "You're close to viral threshold! Focus on small optimizations",
          "Identify and replicate patterns from top-performing users",
          "Consider seasonal or event-based campaigns to push over 1.0"
        ]

      true ->
        [
          "Maintain viral momentum while monitoring for sustainable growth",
          "Scale infrastructure to handle exponential user growth",
          "Continue optimizing loop performance to increase K-factor further"
        ]
    end

    # Loop-specific recommendations
    weak_loops = data.loop_performance
    |> Enum.filter(fn {_source, perf} -> (perf[:k_factor] || 0.0) < 0.3 end)

    recommendations = if length(weak_loops) > 0 do
      loop_recommendations = Enum.map(weak_loops, fn {source, _perf} ->
        source_name = source_display_name(source)
        "Improve #{source_name} loop performance through better messaging and timing"
      end)
      recommendations ++ loop_recommendations
    else
      recommendations
    end

    # Health-based recommendations
    health_score = data.health_data.health_score
    recommendations = if health_score < 75 do
      recommendations ++ [
        "Address guardrail issues to improve system health",
        "Review fraud detection and compliance metrics"
      ]
    else
      recommendations
    end

    recommendations
  end

  defp format_top_referrers(referrers) do
    Enum.map(referrers, fn ref ->
      %{
        user_id: ref.user_id,
        invites: ref.total_invites,
        conversions: ref.total_conversions,
        k_contribution: Float.round((ref.total_conversions || 0) / max(ref.total_invites || 1, 1), 2),
        conversion_rate: ref.conversion_rate
      }
    end)
  end

  defp format_email_content(report) do
    """
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
        .content { padding: 20px; }
        .metric { background: #f4f4f4; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .metric-label { font-weight: bold; color: #666; }
        .metric-value { font-size: 24px; font-weight: bold; color: #667eea; }
        .trend-up { color: #10b981; }
        .trend-down { color: #ef4444; }
        .insight { background: #e0e7ff; padding: 12px; margin: 8px 0; border-left: 4px solid #667eea; }
        .recommendation { background: #fef3c7; padding: 12px; margin: 8px 0; border-left: 4px solid #f59e0b; }
        .footer { background: #f9fafb; padding: 20px; text-align: center; color: #666; margin-top: 30px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>📊 Weekly Viral Loop Performance Report</h1>
        <p>#{Date.to_string(report.report_period_start)} - #{Date.to_string(report.report_period_end)}</p>
      </div>

      <div class="content">
        <h2>Key Metrics</h2>

        <div class="metric">
          <div class="metric-label">K-Factor</div>
          <div class="metric-value">#{Float.round(report.k_factor, 2)}</div>
          <div class="#{trend_class(report.k_factor_trend)}">
            #{trend_icon(report.k_factor_trend)} #{report.k_factor_change_pct}% vs last period
          </div>
        </div>

        <div class="metric">
          <div class="metric-label">Total Conversions</div>
          <div class="metric-value">#{report.total_conversions}</div>
          <div>Conversion Rate: #{Float.round(report.conversion_rate, 2)}%</div>
        </div>

        <div class="metric">
          <div class="metric-label">Active Users</div>
          <div class="metric-value">#{report.active_users}</div>
        </div>

        <div class="metric">
          <div class="metric-label">Viral Links</div>
          <div class="metric-value">#{report.viral_links_created}</div>
          <div>Clicked: #{report.viral_links_clicked} (#{click_through_rate(report)}% CTR)</div>
        </div>

        <div class="metric">
          <div class="metric-label">System Health</div>
          <div class="metric-value">#{Float.round(report.health_score, 1)}/100</div>
          <div>Compliance: #{Float.round(report.compliance_rate, 1)}% | Fraud Flags: #{report.fraud_flags}</div>
        </div>

        <h2>Loop Performance by Source</h2>
        #{format_loop_performance(report.loop_performance)}

        <h2>Key Insights</h2>
        #{Enum.map(report.insights, fn insight ->
          "<div class='insight'>#{insight}</div>"
        end) |> Enum.join("\n")}

        <h2>Recommendations</h2>
        #{Enum.map(report.recommendations, fn rec ->
          "<div class='recommendation'>#{rec}</div>"
        end) |> Enum.join("\n")}

        <h2>Top Referrers</h2>
        <table style="width: 100%; border-collapse: collapse;">
          <tr style="background: #f4f4f4;">
            <th style="padding: 10px; text-align: left;">User ID</th>
            <th style="padding: 10px; text-align: right;">Invites</th>
            <th style="padding: 10px; text-align: right;">Conversions</th>
            <th style="padding: 10px; text-align: right;">Conv Rate</th>
          </tr>
          #{Enum.map(Enum.take(report.top_referrers, 5), fn ref ->
            "<tr>
              <td style='padding: 10px;'>#{ref["user_id"] || ref[:user_id]}</td>
              <td style='padding: 10px; text-align: right;'>#{ref["invites"] || ref[:invites]}</td>
              <td style='padding: 10px; text-align: right;'>#{ref["conversions"] || ref[:conversions]}</td>
              <td style='padding: 10px; text-align: right;'>#{Float.round((ref["conversion_rate"] || ref[:conversion_rate] || 0.0) * 1.0, 1)}%</td>
            </tr>"
          end) |> Enum.join("\n")}
        </table>
      </div>

      <div class="footer">
        <p>Generated automatically by Vel Tutor Viral Engine</p>
        <p>Questions? Contact your product team.</p>
      </div>
    </body>
    </html>
    """
  end

  defp trend_class("up"), do: "trend-up"
  defp trend_class("down"), do: "trend-down"
  defp trend_class(_), do: ""

  defp trend_icon("up"), do: "↑"
  defp trend_icon("down"), do: "↓"
  defp trend_icon(_), do: "→"

  defp click_through_rate(report) do
    if report.viral_links_created > 0 do
      Float.round(report.viral_links_clicked / report.viral_links_created * 100, 1)
    else
      0.0
    end
  end

  defp format_loop_performance(loop_perf) when is_map(loop_perf) do
    loop_perf
    |> Enum.map(fn {source, perf} ->
      source_name = source_display_name(source)
      k_factor = perf["k_factor"] || perf[:k_factor] || 0.0
      invites = perf["invites"] || perf[:invites] || 0
      conversions = perf["conversions"] || perf[:conversions] || 0

      """
      <div style="margin: 10px 0; padding: 10px; background: #f9fafb; border-radius: 5px;">
        <strong>#{source_name}</strong>: K-factor #{Float.round(k_factor, 2)} | #{invites} invites → #{conversions} conversions
      </div>
      """
    end)
    |> Enum.join("\n")
  end
  defp format_loop_performance(_), do: "<p>No loop performance data available</p>"

  defp source_display_name(source) do
    case source do
      "buddy_challenge" -> "Buddy Challenges"
      "results_rally" -> "Results Rallies"
      "parent_share" -> "Parent Shares"
      "prep_pack" -> "Prep Packs"
      "study_session" -> "Study Sessions"
      "auto_challenge" -> "Auto Challenges"
      "progress_reel" -> "Progress Reels"
      _ -> String.capitalize(to_string(source))
    end
  end
end
