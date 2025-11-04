defmodule ViralEngine.Repo.Migrations.CreatePerformanceReports do
  use Ecto.Migration

  def change do
    create table(:performance_reports) do
      add :report_period_start, :date, null: false
      add :report_period_end, :date, null: false
      add :report_type, :string, default: "weekly", null: false

      # K-factor metrics
      add :k_factor, :float, default: 0.0
      add :k_factor_trend, :string
      add :k_factor_change_pct, :float, default: 0.0

      # Conversion metrics
      add :total_conversions, :integer, default: 0
      add :conversion_rate, :float, default: 0.0
      add :conversion_trend, :string

      # Engagement metrics
      add :active_users, :integer, default: 0
      add :viral_links_created, :integer, default: 0
      add :viral_links_clicked, :integer, default: 0

      # Loop performance by source (JSON)
      add :loop_performance, :map, default: "{}"

      # Top referrers (JSON array)
      add :top_referrers, {:array, :map}, default: []

      # Insights and recommendations (text arrays)
      add :insights, {:array, :string}, default: []
      add :recommendations, {:array, :string}, default: []

      # Health and guardrail metrics
      add :health_score, :float, default: 0.0
      add :compliance_rate, :float, default: 0.0
      add :fraud_flags, :integer, default: 0

      # Delivery tracking
      add :delivered_at, :utc_datetime
      add :delivery_status, :string, default: "pending"
      add :recipient_emails, {:array, :string}, default: []

      timestamps()
    end

    create index(:performance_reports, [:report_period_start])
    create index(:performance_reports, [:report_period_end])
    create index(:performance_reports, [:report_type])
    create index(:performance_reports, [:delivery_status])
    create index(:performance_reports, [:inserted_at])
  end
end
