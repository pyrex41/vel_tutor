defmodule ViralEngine.Repo.Migrations.CreateBadges do
  use Ecto.Migration

  def change do
    create table(:badges) do
      add :name, :string, null: false
      add :description, :text
      add :badge_type, :string, null: false
      add :category, :string, null: false

      add :icon, :string
      add :color, :string
      add :rarity, :string, default: "common"

      add :criteria, :map, null: false
      add :reward_xp, :integer, default: 0
      add :metadata, :map, default: "{}"

      add :is_active, :boolean, default: true
      add :is_secret, :boolean, default: false
      add :order, :integer, default: 0

      timestamps()
    end

    # Unique badge names
    create unique_index(:badges, [:name])

    # Query indexes
    create index(:badges, [:badge_type])
    create index(:badges, [:category])
    create index(:badges, [:rarity])
    create index(:badges, [:is_active])
    create index(:badges, [:order])
  end
end
