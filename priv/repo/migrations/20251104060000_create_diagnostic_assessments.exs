defmodule ViralEngine.Repo.Migrations.CreateDiagnosticAssessments do
  use Ecto.Migration

  def change do
    create table(:diagnostic_assessments) do
      add :user_id, :integer, null: false
      add :subject, :string, null: false
      add :grade_level, :string, null: false
      add :current_difficulty, :integer, default: 5
      add :time_limit_seconds, :integer
      add :time_remaining_seconds, :integer
      add :current_question, :integer, default: 1
      add :total_questions, :integer
      add :completed, :boolean, default: false
      add :results, :map
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:diagnostic_assessments, [:user_id])
    create index(:diagnostic_assessments, [:user_id, :completed])
    create index(:diagnostic_assessments, [:subject, :grade_level])
  end
end
