defmodule ViralEngine.FlashcardStudySession do
  @moduledoc """
  Schema for flashcard study sessions with progress tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "flashcard_study_sessions" do
    field(:user_id, :integer)
    field(:flashcard_deck_id, :id)
    field(:current_card_index, :integer, default: 0)
    field(:cards_reviewed, :integer, default: 0)
    field(:cards_mastered, :integer, default: 0)
    field(:session_duration_seconds, :integer, default: 0)
    field(:completed, :boolean, default: false)
    field(:score, :integer)  # Percentage of cards mastered
    field(:metadata, :map, default: %{})

    belongs_to(:deck, ViralEngine.FlashcardDeck, define_field: false)
    has_many(:reviews, ViralEngine.FlashcardReview)

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :flashcard_deck_id,
      :current_card_index,
      :cards_reviewed,
      :cards_mastered,
      :session_duration_seconds,
      :completed,
      :score,
      :metadata
    ])
    |> validate_required([:user_id, :flashcard_deck_id])
    |> validate_number(:current_card_index, greater_than_or_equal_to: 0)
  end
end
