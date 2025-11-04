defmodule ViralEngine.Repo.Migrations.CreatePresences do
  use Ecto.Migration

  def change do
    create table(:presences) do
      add :topic, :string
      add :joined_at, :utc_datetime
      add :left_at, :utc_datetime
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:presences, [:user_id])
  end
end
