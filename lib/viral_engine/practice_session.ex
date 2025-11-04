defmodule ViralEngine.PracticeSession do
  @moduledoc """
  Schema for practice sessions with progress tracking and state persistence.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "practice_sessions" do
    field(:user_id, :integer)
    field(:session_type, :string)  # "diagnostic", "practice_test", "flashcard", etc.
    field(:subject, :string)
    field(:current_step, :integer, default: 1)
    field(:total_steps, :integer)
    field(:timer_seconds, :integer, default: 0)
    field(:paused, :boolean, default: false)
    field(:completed, :boolean, default: false)
    field(:score, :integer)
    field(:metadata, :map, default: %{})  # Extra data like difficulty, topic, etc.

    has_many(:steps, ViralEngine.PracticeStep)
    has_many(:answers, ViralEngine.PracticeAnswer)

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :session_type,
      :subject,
      :current_step,
      :total_steps,
      :timer_seconds,
      :paused,
      :completed,
      :score,
      :metadata
    ])
    |> validate_required([:user_id, :session_type, :subject])
    |> validate_number(:current_step, greater_than: 0)
    |> validate_number(:timer_seconds, greater_than_or_equal_to: 0)
    |> validate_inclusion(:session_type, [
      "diagnostic",
      "practice_test",
      "flashcard",
      "timed_quiz",
      "review"
    ])
  end
end
