defmodule ViralEngine.Repo.Migrations.AddMultiTouchAttribution do
  use Ecto.Migration

  def change do
    create table(:attribution_touchpoints) do
      add :user_id, :integer, null: false
      add :link_id, :integer, null: false
      add :source, :string, null: false
      add :touched_at, :utc_datetime, null: false
      add :attribution_weight, :float, default: 1.0
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:attribution_touchpoints, [:user_id])
    create index(:attribution_touchpoints, [:link_id])
    create index(:attribution_touchpoints, [:touched_at])
  end
end
