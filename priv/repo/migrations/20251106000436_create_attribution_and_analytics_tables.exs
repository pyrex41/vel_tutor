defmodule ViralEngine.Repo.Migrations.CreateAttributionAndAnalyticsTables do
  use Ecto.Migration

  def change do
    # Attribution Events table already exists from earlier migration
    # Only create Analytics Events (for viral loop analytics)
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