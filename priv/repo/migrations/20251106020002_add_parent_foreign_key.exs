defmodule ViralEngine.Repo.Migrations.AddParentForeignKey do
  use Ecto.Migration

  def up do
    # Add foreign key constraint for parent_id
    execute "ALTER TABLE users ADD CONSTRAINT users_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES users(id)"
  end

  def down do
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS users_parent_id_fkey"
  end
end
