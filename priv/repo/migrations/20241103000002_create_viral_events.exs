defmodule ViralEngine.Repo.Migrations.CreateViralEvents do
  use Ecto.Migration

  def change do
    create table(:viral_events) do
      add(:event_type, :string, null: false)
      add(:event_data, :map, default: %{})
      add(:user_id, :integer, null: false)
      add(:timestamp, :utc_datetime, null: false)
      add(:k_factor_impact, :float, default: 0.0)
      add(:processed, :boolean, default: false)

      timestamps()
    end

    create(index(:viral_events, [:event_type]))
    create(index(:viral_events, [:user_id]))
    create(index(:viral_events, [:timestamp]))
    create(index(:viral_events, [:processed]))
  end
end
