defmodule ViralEngine.Repo.Migrations.CreateUserXp do
  use Ecto.Migration

  def change do
    create table(:user_xp) do
      add :user_id, :integer, null: false

      add :current_xp, :integer, default: 0, null: false
      add :total_xp, :integer, default: 0, null: false
      add :level, :integer, default: 1, null: false

      add :xp_to_next_level, :integer, default: 100, null: false
      add :lifetime_level_ups, :integer, default: 0, null: false

      add :xp_sources, :map, default: "{}"
      add :metadata, :map, default: "{}"

      timestamps()
    end

    # Unique constraint: one XP record per user
    create unique_index(:user_xp, [:user_id])

    # Query indexes
    create index(:user_xp, [:level])
    create index(:user_xp, [:total_xp])
  end
end
