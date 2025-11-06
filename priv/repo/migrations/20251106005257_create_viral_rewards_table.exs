defmodule ViralEngine.Repo.Migrations.CreateViralRewardsTable do
  use Ecto.Migration

  def change do
    # Viral Rewards table for tracking rewards from viral loops
    create table(:viral_rewards) do
      add(:user_id, :integer, null: false)
      add(:reward_type, :string, null: false)
      add(:amount, :integer, null: false)
      add(:source_loop_id, :string)
      add(:source_event_id, :string)
      add(:redeemed, :boolean, default: false)
      add(:redeemed_at, :utc_datetime)
      add(:expires_at, :utc_datetime)

      timestamps()
    end

    create(index(:viral_rewards, [:user_id]))
    create(index(:viral_rewards, [:reward_type]))
    create(index(:viral_rewards, [:redeemed]))
  end
end
