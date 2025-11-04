defmodule ViralEngine.Repo.Migrations.CreateDiagnosticResponses do
  use Ecto.Migration

  def change do
    create table(:diagnostic_responses) do
      add :diagnostic_assessment_id, references(:diagnostic_assessments, on_delete: :delete_all), null: false
      add :diagnostic_question_id, references(:diagnostic_questions, on_delete: :delete_all), null: false
      add :user_answer, :text, null: false
      add :is_correct, :boolean
      add :time_spent_seconds, :integer
      add :difficulty_adjustment, :integer
      add :confidence_level, :integer
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:diagnostic_responses, [:diagnostic_assessment_id])
    create index(:diagnostic_responses, [:diagnostic_question_id])
    create index(:diagnostic_responses, [:diagnostic_assessment_id, :diagnostic_question_id])
  end
end
