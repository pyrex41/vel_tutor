defmodule ViralEngine.PracticeAnswer do
  @moduledoc """
  Schema for tracking user answers during practice sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "practice_answers" do
    field(:practice_session_id, :id)
    field(:practice_step_id, :id)
    field(:user_answer, :string)
    field(:is_correct, :boolean)
    field(:feedback, :string)
    field(:time_spent_seconds, :integer, default: 0)
    field(:attempt_number, :integer, default: 1)  # Allow multiple attempts
    field(:metadata, :map, default: %{})  # Hints used, confidence level, etc.

    belongs_to(:session, ViralEngine.PracticeSession, define_field: false)
    belongs_to(:step, ViralEngine.PracticeStep, define_field: false)

    timestamps()
  end

  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [
      :practice_session_id,
      :practice_step_id,
      :user_answer,
      :is_correct,
      :feedback,
      :time_spent_seconds,
      :attempt_number,
      :metadata
    ])
    |> validate_required([:practice_session_id, :practice_step_id, :user_answer])
    |> validate_number(:attempt_number, greater_than: 0)
    |> validate_number(:time_spent_seconds, greater_than_or_equal_to: 0)
  end
end
