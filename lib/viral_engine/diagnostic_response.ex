defmodule ViralEngine.DiagnosticResponse do
  @moduledoc """
  Schema for tracking user responses to diagnostic questions with adaptive adjustments.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "diagnostic_responses" do
    field(:diagnostic_assessment_id, :id)
    field(:diagnostic_question_id, :id)
    field(:user_answer, :string)
    field(:is_correct, :boolean)
    field(:time_spent_seconds, :integer)
    field(:difficulty_adjustment, :integer)  # +1, 0, -1 for next question
    field(:confidence_level, :integer)  # 1-5 if user self-reports
    field(:metadata, :map, default: %{})

    belongs_to(:assessment, ViralEngine.DiagnosticAssessment, define_field: false)
    belongs_to(:question, ViralEngine.DiagnosticQuestion, define_field: false)

    timestamps()
  end

  def changeset(response, attrs) do
    response
    |> cast(attrs, [
      :diagnostic_assessment_id,
      :diagnostic_question_id,
      :user_answer,
      :is_correct,
      :time_spent_seconds,
      :difficulty_adjustment,
      :confidence_level,
      :metadata
    ])
    |> validate_required([:diagnostic_assessment_id, :diagnostic_question_id, :user_answer])
    |> validate_number(:difficulty_adjustment, greater_than_or_equal_to: -2, less_than_or_equal_to: 2)
    |> validate_number(:confidence_level, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
  end
end
