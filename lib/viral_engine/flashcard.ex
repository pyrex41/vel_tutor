defmodule ViralEngine.Flashcard do
  @moduledoc """
  Schema for individual flashcards with front/back content.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "flashcards" do
    field(:flashcard_deck_id, :id)
    field(:front, :string)
    field(:back, :string)
    field(:position, :integer)  # Order in deck
    field(:hint, :string)
    field(:media_url, :string)  # Optional image/audio
    field(:tags, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})

    belongs_to(:deck, ViralEngine.FlashcardDeck, define_field: false)
    has_many(:reviews, ViralEngine.FlashcardReview)

    timestamps()
  end

  def changeset(flashcard, attrs) do
    flashcard
    |> cast(attrs, [
      :flashcard_deck_id,
      :front,
      :back,
      :position,
      :hint,
      :media_url,
      :tags,
      :metadata
    ])
    |> validate_required([:flashcard_deck_id, :front, :back, :position])
    |> validate_length(:front, min: 1, max: 500)
    |> validate_length(:back, min: 1, max: 1000)
  end
end
