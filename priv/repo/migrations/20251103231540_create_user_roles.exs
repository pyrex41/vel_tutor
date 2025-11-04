defmodule ViralEngine.Repo.Migrations.CreateUserRoles do
  use Ecto.Migration

  def change do
    create table(:user_roles) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:role_id, references(:roles, on_delete: :delete_all), null: false)

      add(:organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:assigned_at, :utc_datetime)

      timestamps()
    end

    create(unique_index(:user_roles, [:user_id, :role_id, :organization_id]))
    create(index(:user_roles, [:user_id]))
    create(index(:user_roles, [:role_id]))
    create(index(:user_roles, [:organization_id]))
  end
end
