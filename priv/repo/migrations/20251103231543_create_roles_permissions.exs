defmodule ViralEngine.Repo.Migrations.CreateRolesPermissions do
  use Ecto.Migration

  def change do
    create table(:roles_permissions, primary_key: false) do
      add(:role_id, references(:roles, on_delete: :delete_all), primary_key: true)
      add(:permission_id, references(:permissions, on_delete: :delete_all), primary_key: true)

      timestamps()
    end

    create(index(:roles_permissions, [:role_id]))
    create(index(:roles_permissions, [:permission_id]))
  end
end
