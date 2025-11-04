defmodule ViralEngine.DiagnosticQuestion do
  @moduledoc """
  Schema for diagnostic assessment questions with difficulty and skill tagging.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "diagnostic_questions" do
    field(:diagnostic_assessment_id, :id)
    field(:question_number, :integer)
    field(:content, :string)
    field(:question_type, :string)  # "multiple_choice", "open_ended", etc.
    field(:correct_answer, :string)
    field(:options, {:array, :string}, default: [])
    field(:difficulty, :integer)  # 1-10 scale
    field(:skills, {:array, :string}, default: [])  # e.g., ["algebra", "equations"]
    field(:time_allocated_seconds, :integer)
    field(:metadata, :map, default: %{})

    belongs_to(:assessment, ViralEngine.DiagnosticAssessment, define_field: false)

    timestamps()
  end

  def changeset(question, attrs) do
    question
    |> cast(attrs, [
      :diagnostic_assessment_id,
      :question_number,
      :content,
      :question_type,
      :correct_answer,
      :options,
      :difficulty,
      :skills,
      :time_allocated_seconds,
      :metadata
    ])
    |> validate_required([:diagnostic_assessment_id, :question_number, :content, :question_type, :difficulty])
    |> validate_number(:difficulty, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_inclusion(:question_type, ["multiple_choice", "open_ended", "true_false", "fill_blank"])
  end
end
