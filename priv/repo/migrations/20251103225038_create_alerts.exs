defmodule ViralEngine.Repo.Migrations.CreateAlerts do
  use Ecto.Migration

  def change do
    create table(:alerts) do
      add(:metric_type, :string, null: false)
      add(:value, :float, null: false)
      add(:threshold, :float, null: false)
      add(:status, :string, default: "active", null: false)
      add(:details, :map)
      add(:resolved_at, :naive_datetime)
      add(:resolved_by, :integer)

      timestamps()
    end

    create(index(:alerts, [:metric_type]))
    create(index(:alerts, [:status]))
    create(index(:alerts, [:inserted_at]))
  end
end
