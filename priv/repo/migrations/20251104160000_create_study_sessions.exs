defmodule ViralEngine.Repo.Migrations.CreateStudySessions do
  use Ecto.Migration

  def change do
    create table(:study_sessions) do
      add :creator_id, :integer, null: false
      add :session_name, :string, null: false
      add :subject, :string, null: false
      add :grade_level, :integer

      add :session_token, :string, null: false
      add :scheduled_at, :utc_datetime
      add :duration_minutes, :integer, default: 60

      add :status, :string, default: "scheduled", null: false
      add :participant_ids, {:array, :integer}, default: []
      add :max_participants, :integer, default: 6

      add :session_type, :string, default: "group_practice", null: false
      add :topics, {:array, :string}, default: []
      add :exam_date, :date

      add :metadata, :map, default: "{}"

      timestamps()
    end

    # Unique session token
    create unique_index(:study_sessions, [:session_token])

    # Query indexes
    create index(:study_sessions, [:creator_id])
    create index(:study_sessions, [:status])
    create index(:study_sessions, [:scheduled_at])
    create index(:study_sessions, [:subject])
    create index(:study_sessions, [:exam_date])

    # GIN index for participant_ids array queries
    create index(:study_sessions, [:participant_ids], using: :gin)
  end
end
