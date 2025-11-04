defmodule ViralEngine.Repo.Migrations.AddBotDetectionIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # Index for device fingerprint lookups in bot detection
    create_if_not_exists index(:attribution_events, [:device_fingerprint], concurrently: true, name: :idx_attribution_events_device_fingerprint)

    # Composite index for bot detection queries (device grouping + timestamp ordering)
    create_if_not_exists index(
      :attribution_events,
      [:device_fingerprint, :inserted_at, :event_type],
      concurrently: true,
      name: :idx_attribution_events_bot_detection,
      where: "event_type = 'click' AND device_fingerprint IS NOT NULL"
    )
  end
end
