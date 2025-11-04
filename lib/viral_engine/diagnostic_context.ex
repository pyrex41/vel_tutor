defmodule ViralEngine.DiagnosticContext do
  @moduledoc """
  Context module for managing diagnostic assessments with adaptive difficulty.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, DiagnosticAssessment, DiagnosticQuestion, DiagnosticResponse}
  require Logger

  @default_questions_count 20
  @time_per_question 90  # seconds

  @doc """
  Creates a new diagnostic assessment.
  """
  def create_assessment(attrs \\ %{}) do
    total_questions = attrs[:total_questions] || @default_questions_count
    time_limit = total_questions * @time_per_question

    attrs =
      attrs
      |> Map.put(:total_questions, total_questions)
      |> Map.put(:time_limit_seconds, time_limit)
      |> Map.put(:time_remaining_seconds, time_limit)

    %DiagnosticAssessment{}
    |> DiagnosticAssessment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a diagnostic assessment by ID with preloaded associations.
  """
  def get_assessment(id) do
    Repo.get(DiagnosticAssessment, id)
    |> Repo.preload([:questions, :responses])
  end

  @doc """
  Gets an assessment for a specific user.
  """
  def get_user_assessment(assessment_id, user_id) do
    from(a in DiagnosticAssessment,
      where: a.id == ^assessment_id and a.user_id == ^user_id
    )
    |> Repo.one()
    |> Repo.preload([:questions, :responses])
  end

  @doc """
  Updates an assessment.
  """
  def update_assessment(%DiagnosticAssessment{} = assessment, attrs) do
    assessment
    |> DiagnosticAssessment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Generates adaptive questions based on current difficulty and subject.
  Uses a simple algorithm - in production, this would call an MCP agent.
  """
  def generate_questions(assessment_id, subject, difficulty, count \\ 1) do
    questions_data = generate_question_data(subject, difficulty, count)

    questions =
      Enum.with_index(questions_data, 1)
      |> Enum.map(fn {q_data, idx} ->
        create_question(%{
          diagnostic_assessment_id: assessment_id,
          question_number: idx,
          content: q_data.content,
          question_type: q_data.type,
          correct_answer: q_data.answer,
          options: q_data.options,
          difficulty: difficulty,
          skills: q_data.skills,
          time_allocated_seconds: @time_per_question
        })
      end)

    {:ok, Enum.map(questions, fn {:ok, q} -> q end)}
  end

  @doc """
  Creates a diagnostic question.
  """
  def create_question(attrs) do
    %DiagnosticQuestion{}
    |> DiagnosticQuestion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a specific question by assessment and question number.
  """
  def get_question(assessment_id, question_number) do
    from(q in DiagnosticQuestion,
      where: q.diagnostic_assessment_id == ^assessment_id and q.question_number == ^question_number
    )
    |> Repo.one()
  end

  @doc """
  Records a user response and calculates difficulty adjustment.
  """
  def record_response(attrs) do
    question = Repo.get(DiagnosticQuestion, attrs[:diagnostic_question_id])

    if question do
      is_correct = validate_answer(question, attrs[:user_answer])
      difficulty_adjustment = calculate_difficulty_adjustment(is_correct, attrs[:time_spent_seconds], question.time_allocated_seconds)

      attrs =
        attrs
        |> Map.put(:is_correct, is_correct)
        |> Map.put(:difficulty_adjustment, difficulty_adjustment)

      %DiagnosticResponse{}
      |> DiagnosticResponse.changeset(attrs)
      |> Repo.insert()
    else
      {:error, :question_not_found}
    end
  end

  @doc """
  Updates assessment difficulty based on latest response.
  """
  def adjust_difficulty(assessment_id) do
    assessment = get_assessment(assessment_id)

    if assessment do
      # Get last 3 responses
      recent_responses =
        from(r in DiagnosticResponse,
          where: r.diagnostic_assessment_id == ^assessment_id,
          order_by: [desc: r.inserted_at],
          limit: 3
        )
        |> Repo.all()

      if length(recent_responses) > 0 do
        avg_adjustment = Enum.sum(Enum.map(recent_responses, & &1.difficulty_adjustment)) / length(recent_responses)
        new_difficulty = max(1, min(10, round(assessment.current_difficulty + avg_adjustment)))

        update_assessment(assessment, %{current_difficulty: new_difficulty})
      else
        {:ok, assessment}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Advances to the next question.
  """
  def advance_question(assessment_id) do
    assessment = get_assessment(assessment_id)

    if assessment && assessment.current_question < assessment.total_questions do
      new_question = assessment.current_question + 1

      # Adjust difficulty before generating next question
      adjust_difficulty(assessment_id)

      # Generate next question with adjusted difficulty
      assessment = get_assessment(assessment_id)
      generate_questions(assessment_id, assessment.subject, assessment.current_difficulty, 1)

      update_assessment(assessment, %{current_question: new_question})
    else
      {:error, :assessment_complete}
    end
  end

  @doc """
  Updates time remaining.
  """
  def update_time_remaining(assessment_id, seconds_remaining) do
    assessment = Repo.get(DiagnosticAssessment, assessment_id)

    if assessment do
      update_assessment(assessment, %{time_remaining_seconds: seconds_remaining})
    else
      {:error, :not_found}
    end
  end

  @doc """
  Completes an assessment and generates results.
  """
  def complete_assessment(assessment_id) do
    assessment = get_assessment(assessment_id)

    if assessment do
      results = generate_results(assessment)

      update_assessment(assessment, %{
        completed: true,
        results: results
      })
    else
      {:error, :not_found}
    end
  end

  @doc """
  Generates skill-based results and percentile rankings.
  """
  def generate_results(assessment) do
    responses = assessment.responses

    total_correct = Enum.count(responses, & &1.is_correct)
    total_questions = length(responses)
    accuracy = if total_questions > 0, do: (total_correct / total_questions * 100) |> round(), else: 0

    # Group by skills
    skill_performance = calculate_skill_performance(assessment)

    # Calculate percentile (simplified - in production, compare against other users)
    percentile = calculate_percentile(accuracy, assessment.subject, assessment.grade_level)

    %{
      total_questions: total_questions,
      total_correct: total_correct,
      accuracy: accuracy,
      skill_heatmap: skill_performance,
      percentile: percentile,
      difficulty_range: get_difficulty_range(responses),
      avg_time_per_question: calculate_avg_time(responses),
      completed_at: DateTime.utc_now()
    }
  end

  @doc """
  Lists user's diagnostic assessments.
  """
  def list_user_assessments(user_id, opts \\ []) do
    limit = opts[:limit] || 10

    from(a in DiagnosticAssessment,
      where: a.user_id == ^user_id,
      order_by: [desc: a.inserted_at],
      limit: ^limit,
      preload: [:questions, :responses]
    )
    |> Repo.all()
  end

  # Private functions

  defp validate_answer(%DiagnosticQuestion{question_type: "multiple_choice"} = question, user_answer) do
    String.downcase(String.trim(user_answer)) == String.downcase(String.trim(question.correct_answer))
  end

  defp validate_answer(%DiagnosticQuestion{question_type: "true_false"} = question, user_answer) do
    String.downcase(String.trim(user_answer)) == String.downcase(String.trim(question.correct_answer))
  end

  defp validate_answer(_question, _user_answer), do: false

  defp calculate_difficulty_adjustment(is_correct, time_spent, time_allocated) do
    time_ratio = time_spent / time_allocated

    cond do
      is_correct && time_ratio < 0.5 -> 2  # Very fast and correct - increase difficulty significantly
      is_correct && time_ratio < 0.8 -> 1  # Correct - increase difficulty
      is_correct -> 0  # Correct but slow - maintain difficulty
      !is_correct && time_ratio > 0.8 -> -2  # Incorrect and slow - decrease significantly
      !is_correct -> -1  # Incorrect - decrease difficulty
    end
  end

  defp calculate_skill_performance(assessment) do
    responses = assessment.responses
    questions = assessment.questions

    # Group responses by skills
    skill_data =
      Enum.reduce(questions, %{}, fn question, acc ->
        response = Enum.find(responses, fn r -> r.diagnostic_question_id == question.id end)

        if response do
          Enum.reduce(question.skills, acc, fn skill, skill_acc ->
            current = Map.get(skill_acc, skill, %{correct: 0, total: 0})
            correct_count = if response.is_correct, do: current.correct + 1, else: current.correct

            Map.put(skill_acc, skill, %{
              correct: correct_count,
              total: current.total + 1
            })
          end)
        else
          acc
        end
      end)

    # Convert to percentages
    Map.new(skill_data, fn {skill, data} ->
      {skill, round(data.correct / data.total * 100)}
    end)
  end

  defp calculate_percentile(accuracy, _subject, _grade_level) do
    # Simplified percentile calculation
    # In production, this would query the database for similar assessments
    cond do
      accuracy >= 90 -> 95
      accuracy >= 80 -> 85
      accuracy >= 70 -> 70
      accuracy >= 60 -> 55
      accuracy >= 50 -> 40
      true -> 25
    end
  end

  defp get_difficulty_range(responses) do
    difficulties =
      responses
      |> Enum.map(fn r ->
        question = Repo.get(DiagnosticQuestion, r.diagnostic_question_id)
        question.difficulty
      end)

    %{
      min: Enum.min(difficulties, fn -> 1 end),
      max: Enum.max(difficulties, fn -> 1 end),
      avg: (Enum.sum(difficulties) / length(difficulties)) |> Float.round(1)
    }
  end

  defp calculate_avg_time(responses) do
    total_time = Enum.sum(Enum.map(responses, & &1.time_spent_seconds))
    count = length(responses)

    if count > 0, do: round(total_time / count), else: 0
  end

  # Question generation - simplified version
  # In production, this would call an MCP agent
  defp generate_question_data("math", difficulty, count) do
    Enum.map(1..count, fn _ ->
      %{
        content: "What is #{difficulty * 2} + #{difficulty * 3}?",
        type: "multiple_choice",
        answer: "#{difficulty * 5}",
        options: ["#{difficulty * 4}", "#{difficulty * 5}", "#{difficulty * 6}", "#{difficulty * 7}"],
        skills: ["arithmetic", "addition"]
      }
    end)
  end

  defp generate_question_data("science", _difficulty, count) do
    Enum.map(1..count, fn _ ->
      %{
        content: "Which organ pumps blood through the body?",
        type: "multiple_choice",
        answer: "Heart",
        options: ["Heart", "Lungs", "Liver", "Kidney"],
        skills: ["biology", "anatomy"]
      }
    end)
  end

  defp generate_question_data(_subject, _difficulty, count) do
    Enum.map(1..count, fn _ ->
      %{
        content: "Sample question",
        type: "multiple_choice",
        answer: "A",
        options: ["A", "B", "C", "D"],
        skills: ["general"]
      }
    end)
  end
end
