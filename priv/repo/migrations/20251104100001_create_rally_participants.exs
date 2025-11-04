defmodule ViralEngine.Repo.Migrations.CreateRallyParticipants do
  use Ecto.Migration

  def change do
    create table(:rally_participants) do
      add :rally_id, :integer, null: false
      add :user_id, :integer, null: false
      add :assessment_id, :integer
      add :score, :integer
      add :rank, :integer
      add :joined_via, :string
      add :is_creator, :boolean, default: false

      timestamps()
    end

    # Unique participation per rally
    create unique_index(:rally_participants, [:rally_id, :user_id])

    # Query indexes
    create index(:rally_participants, [:rally_id])
    create index(:rally_participants, [:user_id])
    create index(:rally_participants, [:rally_id, :score])
    create index(:rally_participants, [:rally_id, :rank])
  end
end
