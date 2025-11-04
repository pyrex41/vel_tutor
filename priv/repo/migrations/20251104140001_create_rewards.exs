defmodule ViralEngine.Repo.Migrations.CreateRewards do
  use Ecto.Migration

  def change do
    create table(:rewards) do
      add :name, :string, null: false
      add :description, :text
      add :reward_type, :string, null: false

      add :icon, :string
      add :image_url, :string
      add :rarity, :string, default: "common"

      add :xp_cost, :integer, default: 0, null: false
      add :level_required, :integer, default: 1, null: false

      add :is_active, :boolean, default: true
      add :is_limited, :boolean, default: false
      add :stock, :integer
      add :expires_at, :utc_datetime

      add :metadata, :map, default: "{}"
      add :order, :integer, default: 0

      timestamps()
    end

    # Query indexes
    create index(:rewards, [:reward_type])
    create index(:rewards, [:rarity])
    create index(:rewards, [:is_active])
    create index(:rewards, [:xp_cost])
    create index(:rewards, [:level_required])
    create index(:rewards, [:order])
  end
end
