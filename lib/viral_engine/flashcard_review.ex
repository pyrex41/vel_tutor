defmodule ViralEngine.FlashcardReview do
  @moduledoc """
  Schema for tracking individual flashcard reviews with spaced repetition data.
  Uses SM-2 algorithm for spaced repetition.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "flashcard_reviews" do
    field(:user_id, :integer)
    field(:flashcard_id, :id)
    field(:flashcard_study_session_id, :id)
    field(:rating, :integer)  # 1-5 scale (1=again, 5=easy)
    field(:response_time_seconds, :integer)

    # Spaced repetition fields (SM-2 algorithm)
    field(:ease_factor, :float, default: 2.5)  # Difficulty factor
    field(:interval_days, :integer, default: 0)  # Days until next review
    field(:repetitions, :integer, default: 0)  # Number of successful repetitions
    field(:next_review_date, :date)
    field(:is_mastered, :boolean, default: false)

    field(:metadata, :map, default: %{})

    belongs_to(:flashcard, ViralEngine.Flashcard, define_field: false)
    belongs_to(:session, ViralEngine.FlashcardStudySession, define_field: false)

    timestamps()
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [
      :user_id,
      :flashcard_id,
      :flashcard_study_session_id,
      :rating,
      :response_time_seconds,
      :ease_factor,
      :interval_days,
      :repetitions,
      :next_review_date,
      :is_mastered,
      :metadata
    ])
    |> validate_required([:user_id, :flashcard_id, :rating])
    |> validate_inclusion(:rating, 1..5)
    |> validate_number(:ease_factor, greater_than_or_equal_to: 1.3)
    |> validate_number(:repetitions, greater_than_or_equal_to: 0)
  end
end
