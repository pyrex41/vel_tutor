defmodule ViralEngine.Repo.Migrations.CreatePracticeAnswers do
  use Ecto.Migration

  def change do
    create table(:practice_answers) do
      add :practice_session_id, references(:practice_sessions, on_delete: :delete_all), null: false
      add :practice_step_id, references(:practice_steps, on_delete: :delete_all), null: false
      add :user_answer, :text, null: false
      add :is_correct, :boolean
      add :feedback, :text
      add :time_spent_seconds, :integer, default: 0
      add :attempt_number, :integer, default: 1
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:practice_answers, [:practice_session_id])
    create index(:practice_answers, [:practice_step_id])
    create index(:practice_answers, [:practice_session_id, :practice_step_id])
  end
end
