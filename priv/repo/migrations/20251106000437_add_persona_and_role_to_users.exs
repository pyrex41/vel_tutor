defmodule ViralEngine.Repo.Migrations.AddPersonaAndRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :persona, :string, default: "student"
      add :role, :string, default: "student"
    end

    # Update existing users to have student persona/role
    execute "UPDATE users SET persona = 'student', role = 'student' WHERE persona IS NULL OR role IS NULL"
  end
end