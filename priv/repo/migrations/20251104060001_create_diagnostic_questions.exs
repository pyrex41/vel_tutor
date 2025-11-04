defmodule ViralEngine.Repo.Migrations.CreateDiagnosticQuestions do
  use Ecto.Migration

  def change do
    create table(:diagnostic_questions) do
      add :diagnostic_assessment_id, references(:diagnostic_assessments, on_delete: :delete_all), null: false
      add :question_number, :integer, null: false
      add :content, :text, null: false
      add :question_type, :string, null: false
      add :correct_answer, :string
      add :options, {:array, :string}, default: []
      add :difficulty, :integer, null: false
      add :skills, {:array, :string}, default: []
      add :time_allocated_seconds, :integer
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:diagnostic_questions, [:diagnostic_assessment_id])
    create index(:diagnostic_questions, [:diagnostic_assessment_id, :question_number])
    create unique_index(:diagnostic_questions, [:diagnostic_assessment_id, :question_number])
    create index(:diagnostic_questions, [:difficulty])
  end
end
