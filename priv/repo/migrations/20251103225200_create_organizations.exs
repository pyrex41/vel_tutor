defmodule ViralEngine.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:tenant_id, :uuid, null: false)
      add(:description, :text)
      add(:status, :string, default: "active", null: false)
      add(:settings, :map, default: %{})
      add(:subscription_plan, :string, default: "free", null: false)
      add(:max_users, :integer, default: 10, null: false)
      add(:max_tasks_per_month, :integer, default: 1000, null: false)

      timestamps()
    end

    create(unique_index(:organizations, [:tenant_id]))
    create(index(:organizations, [:status]))
    create(index(:organizations, [:subscription_plan]))
  end
end
