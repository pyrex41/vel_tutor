defmodule ViralEngine.Repo.Migrations.CreateFlashcardReviews do
  use Ecto.Migration

  def change do
    create table(:flashcard_reviews) do
      add :user_id, :integer, null: false
      add :flashcard_id, references(:flashcards, on_delete: :delete_all), null: false
      add :flashcard_study_session_id, references(:flashcard_study_sessions, on_delete: :nilify_all)
      add :rating, :integer, null: false
      add :response_time_seconds, :integer

      # Spaced repetition fields (SM-2 algorithm)
      add :ease_factor, :float, default: 2.5
      add :interval_days, :integer, default: 0
      add :repetitions, :integer, default: 0
      add :next_review_date, :date
      add :is_mastered, :boolean, default: false

      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:flashcard_reviews, [:user_id])
    create index(:flashcard_reviews, [:flashcard_id])
    create index(:flashcard_reviews, [:user_id, :flashcard_id])
    create index(:flashcard_reviews, [:next_review_date])
    create index(:flashcard_reviews, [:is_mastered])
  end
end
