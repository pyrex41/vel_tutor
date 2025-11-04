defmodule ViralEngine.Repo.Migrations.CreateUserBadges do
  use Ecto.Migration

  def change do
    create table(:user_badges) do
      add :user_id, :integer, null: false
      add :badge_id, :integer, null: false

      add :unlocked_at, :utc_datetime, null: false
      add :progress, :integer, default: 0
      add :is_new, :boolean, default: true
      add :is_shared, :boolean, default: false
      add :shared_at, :utc_datetime

      add :unlock_context, :map, default: "{}"
      add :metadata, :map, default: "{}"

      timestamps()
    end

    # Unique constraint: user can only earn each badge once
    create unique_index(:user_badges, [:user_id, :badge_id])

    # Query indexes
    create index(:user_badges, [:user_id])
    create index(:user_badges, [:badge_id])
    create index(:user_badges, [:user_id, :is_new])
    create index(:user_badges, [:unlocked_at])
  end
end
