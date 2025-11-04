defmodule ViralEngine.PracticeStep do
  @moduledoc """
  Schema for individual steps/questions within a practice session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "practice_steps" do
    field(:practice_session_id, :id)
    field(:step_number, :integer)
    field(:title, :string)
    field(:content, :string)
    field(:question_type, :string)  # "multiple_choice", "open_ended", "true_false", etc.
    field(:correct_answer, :string)
    field(:options, {:array, :string}, default: [])  # For multiple choice
    field(:completed, :boolean, default: false)
    field(:time_spent_seconds, :integer, default: 0)
    field(:metadata, :map, default: %{})  # Hints, explanations, difficulty, etc.

    belongs_to(:session, ViralEngine.PracticeSession, define_field: false)

    timestamps()
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [
      :practice_session_id,
      :step_number,
      :title,
      :content,
      :question_type,
      :correct_answer,
      :options,
      :completed,
      :time_spent_seconds,
      :metadata
    ])
    |> validate_required([:practice_session_id, :step_number, :title, :content, :question_type])
    |> validate_number(:step_number, greater_than: 0)
    |> validate_inclusion(:question_type, [
      "multiple_choice",
      "open_ended",
      "true_false",
      "fill_blank",
      "matching"
    ])
  end
end
