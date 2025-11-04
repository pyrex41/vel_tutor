defmodule ViralEngine.Repo.Migrations.CreateResultsRallies do
  use Ecto.Migration

  def change do
    create table(:results_rallies) do
      add :creator_id, :integer, null: false
      add :rally_name, :string, null: false
      add :subject, :string, null: false
      add :grade_level, :integer
      add :rally_token, :string, null: false

      add :start_date, :utc_datetime, null: false
      add :end_date, :utc_datetime
      add :status, :string, null: false, default: "active"

      add :participant_count, :integer, default: 1
      add :invite_count, :integer, default: 0

      add :metadata, :map, default: "{}"

      timestamps()
    end

    # Unique token index
    create unique_index(:results_rallies, [:rally_token])

    # Query indexes
    create index(:results_rallies, [:creator_id])
    create index(:results_rallies, [:subject])
    create index(:results_rallies, [:status])
    create index(:results_rallies, [:status, :end_date])
  end
end
