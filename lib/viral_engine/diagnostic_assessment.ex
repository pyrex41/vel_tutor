defmodule ViralEngine.DiagnosticAssessment do
  @moduledoc """
  Schema for diagnostic assessments with adaptive difficulty and skill profiling.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "diagnostic_assessments" do
    field(:user_id, :integer)
    field(:subject, :string)
    field(:grade_level, :string)
    field(:current_difficulty, :integer, default: 5)  # 1-10 scale
    field(:time_limit_seconds, :integer)
    field(:time_remaining_seconds, :integer)
    field(:current_question, :integer, default: 1)
    field(:total_questions, :integer)
    field(:completed, :boolean, default: false)
    field(:results, :map)  # Store final results including skill heatmap
    field(:metadata, :map, default: %{})

    has_many(:questions, ViralEngine.DiagnosticQuestion)
    has_many(:responses, ViralEngine.DiagnosticResponse)

    timestamps()
  end

  def changeset(assessment, attrs) do
    assessment
    |> cast(attrs, [
      :user_id,
      :subject,
      :grade_level,
      :current_difficulty,
      :time_limit_seconds,
      :time_remaining_seconds,
      :current_question,
      :total_questions,
      :completed,
      :results,
      :metadata
    ])
    |> validate_required([:user_id, :subject, :grade_level])
    |> validate_inclusion(:subject, ["math", "science", "english", "history", "vocabulary"])
    |> validate_inclusion(:grade_level, ["3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "11th", "12th"])
    |> validate_number(:current_difficulty, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_number(:current_question, greater_than: 0)
  end
end
