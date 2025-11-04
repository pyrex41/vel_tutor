defmodule ViralEngine.Repo.Migrations.AddFraudDetectionIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # Index for IP address lookups in fraud detection
    create_if_not_exists index(:attribution_events, [:ip_address], concurrently: true, name: :idx_attribution_events_ip_address)

    # Composite index for fraud detection queries (date grouping + IP filtering)
    create_if_not_exists index(
      :attribution_events,
      [:inserted_at, :ip_address, :event_type],
      concurrently: true,
      name: :idx_attribution_events_fraud_detection,
      where: "event_type = 'click'"
    )

    # Index for referrer-based queries in conversion anomaly detection
    create_if_not_exists index(
      :attribution_events,
      [:referrer_id, :event_type, :inserted_at],
      concurrently: true,
      name: :idx_attribution_events_referrer_conversion
    )
  end
end
