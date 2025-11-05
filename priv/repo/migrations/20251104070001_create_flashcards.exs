defmodule ViralEngine.Repo.Migrations.CreateFlashcards do
  use Ecto.Migration

  def change do
    create table(:flashcards) do
      add(:flashcard_deck_id, references(:flashcard_decks, on_delete: :delete_all), null: false)
      add(:front, :string, null: false)
      add(:back, :text, null: false)
      add(:position, :integer, null: false)
      add(:hint, :text)
      add(:media_url, :string)
      add(:tags, {:array, :string}, default: [])
      add(:metadata, :map, default: %{})

      timestamps()
    end

    create(index(:flashcards, [:flashcard_deck_id]))
    create(unique_index(:flashcards, [:flashcard_deck_id, :position]))
  end
end
