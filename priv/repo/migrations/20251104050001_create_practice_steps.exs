defmodule ViralEngine.Repo.Migrations.CreatePracticeSteps do
  use Ecto.Migration

  def change do
    create table(:practice_steps) do
      add(:practice_session_id, references(:practice_sessions, on_delete: :delete_all),
        null: false
      )

      add(:step_number, :integer, null: false)
      add(:title, :string, null: false)
      add(:content, :text, null: false)
      add(:question_type, :string, null: false)
      add(:correct_answer, :string)
      add(:options, {:array, :string}, default: [])
      add(:completed, :boolean, default: false)
      add(:time_spent_seconds, :integer, default: 0)
      add(:metadata, :map, default: %{})

      timestamps()
    end

    create(index(:practice_steps, [:practice_session_id]))
    create(unique_index(:practice_steps, [:practice_session_id, :step_number]))
  end
end
