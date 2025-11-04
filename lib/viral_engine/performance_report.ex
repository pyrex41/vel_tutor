defmodule ViralEngine.PerformanceReport do
  @moduledoc """
  Schema for weekly viral loop performance reports.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "performance_reports" do
    field(:report_period_start, :date)
    field(:report_period_end, :date)
    field(:report_type, :string, default: "weekly")  # weekly, monthly, custom

    # K-factor metrics
    field(:k_factor, :float)
    field(:k_factor_trend, :string)  # up, down, stable
    field(:k_factor_change_pct, :float)

    # Conversion metrics
    field(:total_conversions, :integer, default: 0)
    field(:conversion_rate, :float)
    field(:conversion_trend, :string)

    # Engagement metrics
    field(:active_users, :integer, default: 0)
    field(:viral_links_created, :integer, default: 0)
    field(:viral_links_clicked, :integer, default: 0)

    # Loop performance by source
    field(:loop_performance, :map, default: %{})
    # %{
    #   "buddy_challenge" => %{invites: 120, conversions: 45, k_factor: 0.82},
    #   "results_rally" => %{invites: 89, conversions: 32, k_factor: 0.71},
    #   ...
    # }

    # Top performers
    field(:top_referrers, {:array, :map}, default: [])
    # [%{user_id: 123, invites: 45, conversions: 20, k_contribution: 0.44}, ...]

    # Insights and recommendations
    field(:insights, {:array, :string}, default: [])
    field(:recommendations, {:array, :string}, default: [])

    # Health and guardrail metrics
    field(:health_score, :float)
    field(:compliance_rate, :float)
    field(:fraud_flags, :integer, default: 0)

    # Delivery tracking
    field(:delivered_at, :utc_datetime)
    field(:delivery_status, :string, default: "pending")  # pending, delivered, failed
    field(:recipient_emails, {:array, :string}, default: [])

    timestamps()
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :report_period_start,
      :report_period_end,
      :report_type,
      :k_factor,
      :k_factor_trend,
      :k_factor_change_pct,
      :total_conversions,
      :conversion_rate,
      :conversion_trend,
      :active_users,
      :viral_links_created,
      :viral_links_clicked,
      :loop_performance,
      :top_referrers,
      :insights,
      :recommendations,
      :health_score,
      :compliance_rate,
      :fraud_flags,
      :delivered_at,
      :delivery_status,
      :recipient_emails
    ])
    |> validate_required([:report_period_start, :report_period_end])
    |> validate_inclusion(:report_type, ["weekly", "monthly", "custom"])
    |> validate_inclusion(:delivery_status, ["pending", "delivered", "failed"])
  end
end
