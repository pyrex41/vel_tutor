defmodule ViralEngine.Repo.Migrations.CreateUserRewards do
  use Ecto.Migration

  def change do
    create table(:user_rewards) do
      add :user_id, :integer, null: false
      add :reward_id, :integer, null: false

      add :claimed_at, :utc_datetime, null: false
      add :xp_spent, :integer, null: false

      add :is_equipped, :boolean, default: false
      add :is_active, :boolean, default: false
      add :uses_remaining, :integer
      add :expires_at, :utc_datetime

      add :metadata, :map, default: "{}"

      timestamps()
    end

    # Query indexes
    create index(:user_rewards, [:user_id])
    create index(:user_rewards, [:reward_id])
    create index(:user_rewards, [:user_id, :is_equipped])
    create index(:user_rewards, [:user_id, :is_active])
    create index(:user_rewards, [:claimed_at])
  end
end
