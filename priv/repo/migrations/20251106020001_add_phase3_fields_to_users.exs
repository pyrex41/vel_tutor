defmodule ViralEngine.Repo.Migrations.AddPhase3FieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :age, :integer
      add_if_not_exists :parent_id, :integer
    end

    create_if_not_exists index(:users, [:age])
    create_if_not_exists index(:users, [:parent_id])
  end
end
