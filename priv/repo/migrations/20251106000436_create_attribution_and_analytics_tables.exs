defmodule ViralEngine.Repo.Migrations.CreateAttributionAndAnalyticsTables do
  use Ecto.Migration

  def change do
    # Attribution Events (for tracking clicks, visits, conversions)
    create table(:attribution_events) do
      add :link_id, :integer, null: false
      add :event_type, :string, null: false  # click, visit, signup, conversion
      add :user_id, :integer
      add :session_id, :string

      add :device_fingerprint, :string
      add :ip_address, :string
      add :user_agent, :string

      add :referrer_url, :string
      add :landing_page, :string

      add :metadata, :map, default: %{}
      add :converted, :boolean, default: false
      add :conversion_value, :decimal

      timestamps()
    end

    create index(:attribution_events, [:link_id])
    create index(:attribution_events, [:user_id])
    create index(:attribution_events, [:event_type])
    create index(:attribution_events, [:device_fingerprint])

    # Analytics Events (for viral loop analytics)
    create table(:analytics_events) do
      add :event_type, :string, null: false
      add :user_id, :integer
      add :loop_type, :string
      add :action, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:analytics_events, [:event_type])
    create index(:analytics_events, [:user_id])
    create index(:analytics_events, [:loop_type])
  end
end