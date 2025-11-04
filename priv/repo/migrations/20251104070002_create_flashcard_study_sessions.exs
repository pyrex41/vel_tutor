defmodule ViralEngine.Repo.Migrations.CreateFlashcardStudySessions do
  use Ecto.Migration

  def change do
    create table(:flashcard_study_sessions) do
      add :user_id, :integer, null: false
      add :flashcard_deck_id, references(:flashcard_decks, on_delete: :delete_all), null: false
      add :current_card_index, :integer, default: 0
      add :cards_reviewed, :integer, default: 0
      add :cards_mastered, :integer, default: 0
      add :session_duration_seconds, :integer, default: 0
      add :completed, :boolean, default: false
      add :score, :integer
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:flashcard_study_sessions, [:user_id])
    create index(:flashcard_study_sessions, [:flashcard_deck_id])
    create index(:flashcard_study_sessions, [:user_id, :completed])
  end
end
