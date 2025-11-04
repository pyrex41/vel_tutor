defmodule ViralEngine.FlashcardDeck do
  @moduledoc """
  Schema for flashcard decks with AI-generated or user-created content.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "flashcard_decks" do
    field(:user_id, :integer)
    field(:title, :string)
    field(:description, :string)
    field(:subject, :string)
    field(:difficulty, :integer, default: 5)  # 1-10 scale
    field(:is_ai_generated, :boolean, default: false)
    field(:is_public, :boolean, default: false)
    field(:tags, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})

    has_many(:flashcards, ViralEngine.Flashcard)
    has_many(:study_sessions, ViralEngine.FlashcardStudySession)

    timestamps()
  end

  def changeset(deck, attrs) do
    deck
    |> cast(attrs, [
      :user_id,
      :title,
      :description,
      :subject,
      :difficulty,
      :is_ai_generated,
      :is_public,
      :tags,
      :metadata
    ])
    |> validate_required([:user_id, :title, :subject])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_number(:difficulty, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
  end
end
