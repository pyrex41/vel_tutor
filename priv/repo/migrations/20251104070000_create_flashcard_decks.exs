defmodule ViralEngine.Repo.Migrations.CreateFlashcardDecks do
  use Ecto.Migration

  def change do
    create table(:flashcard_decks) do
      add :user_id, :integer, null: false
      add :title, :string, null: false
      add :description, :text
      add :subject, :string, null: false
      add :difficulty, :integer, default: 5
      add :is_ai_generated, :boolean, default: false
      add :is_public, :boolean, default: false
      add :tags, {:array, :string}, default: []
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:flashcard_decks, [:user_id])
    create index(:flashcard_decks, [:subject])
    create index(:flashcard_decks, [:is_public])
  end
end
