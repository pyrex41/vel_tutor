defmodule ViralEngine.Repo.Migrations.CreateWorkflows do
  use Ecto.Migration

  def change do
    create table(:workflows) do
      add(:name, :string, null: false)
      add(:state, :map, default: %{})
      add(:version, :integer, default: 1)
      add(:routing_rules, {:array, :map}, default: [])
      add(:conditions, {:array, :map}, default: [])

      timestamps()
    end

    create(index(:workflows, [:name]))
  end
end
