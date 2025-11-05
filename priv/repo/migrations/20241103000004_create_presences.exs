defmodule ViralEngine.Repo.Migrations.CreatePresences do
  use Ecto.Migration

  def change do
    create table(:presences) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:topic, :string, null: false)
      add(:event_type, :string, null: false)
      add(:meta, :string)

      timestamps()
    end

    create(index(:presences, [:user_id]))
    create(index(:presences, [:topic]))
    create(index(:presences, [:event_type]))
  end
end
