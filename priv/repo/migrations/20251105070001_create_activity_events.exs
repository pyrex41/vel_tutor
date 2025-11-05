defmodule ViralEngine.Repo.Migrations.CreateActivityEvents do
  use Ecto.Migration

  def change do
    create table(:activity_events) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subject_id, :integer  # Will be converted to reference when subjects table exists
      add :event_type, :string, null: false
      add :data, :map, default: %{}
      add :visibility, :string, default: "public"
      add :reactions_count, :integer, default: 0

      timestamps()
    end

    create index(:activity_events, [:user_id])
    create index(:activity_events, [:subject_id])
    create index(:activity_events, [:event_type])
    create index(:activity_events, [:inserted_at])
    create index(:activity_events, [:visibility])

    create table(:activity_reactions) do
      add :activity_event_id, references(:activity_events, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :reaction, :string, null: false

      timestamps()
    end

    create unique_index(:activity_reactions, [:activity_event_id, :user_id])
    create index(:activity_reactions, [:user_id])
  end
end
