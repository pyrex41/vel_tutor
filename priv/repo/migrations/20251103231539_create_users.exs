defmodule ViralEngine.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :string, null: false)
      add(:name, :string)
      add(:organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all))

      timestamps()
    end

    create(unique_index(:users, [:email]))
    create(index(:users, [:organization_id]))
  end
end
