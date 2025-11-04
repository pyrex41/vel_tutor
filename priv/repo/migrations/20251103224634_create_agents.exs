defmodule ViralEngine.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    create table(:agents) do
      add(:name, :string, null: false)
      add(:config, :map, null: false)
      add(:metadata, :map)
      add(:user_id, :integer, null: false)
      add(:deleted_at, :naive_datetime)

      timestamps()
    end

    create(index(:agents, [:user_id]))
    create(index(:agents, [:name]))
  end
end
