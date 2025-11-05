defmodule ViralEngine.MicroDeck do
  @moduledoc """
  Module for generating 5-question micro-decks from practice sessions.

  Micro-decks are curated sets of 5 questions designed for buddy challenges,
  prioritizing key learning points and maintaining engagement.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, PracticeStep, PracticeAnswer}
  require Logger

  @deck_size 5

  @doc """
  Generates a 5-question micro-deck from a completed practice session.

  Selection strategy prioritizes:
  1. Questions answered incorrectly (learning opportunities)
  2. Questions with longer time spent (challenging questions)
  3. Higher difficulty questions (from metadata)
  4. Diverse question types (variety)

  ## Parameters
  - session_id: ID of completed practice session
  - opts: Options (strategy: :learning_focused | :balanced | :competitive)

  ## Returns
  - {:ok, micro_deck} - Map with questions and metadata
  - {:error, reason}
  """
  def generate(session_id, opts \\ []) do
    strategy = opts[:strategy] || :learning_focused

    with {:ok, steps} <- get_session_steps(session_id),
         {:ok, answers} <- get_session_answers(session_id),
         {:ok, selected_steps} <- select_questions(steps, answers, strategy) do
      micro_deck = build_micro_deck(selected_steps, session_id, strategy)
      {:ok, micro_deck}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets all steps for a session ordered by step number.
  """
  defp get_session_steps(session_id) do
    steps =
      from(s in PracticeStep,
        where: s.practice_session_id == ^session_id,
        order_by: [asc: s.step_number]
      )
      |> Repo.all()

    if length(steps) >= @deck_size do
      {:ok, steps}
    else
      {:error, :insufficient_questions}
    end
  end

  @doc """
  Gets all answers for a session.
  """
  defp get_session_answers(session_id) do
    answers =
      from(a in PracticeAnswer,
        where: a.practice_session_id == ^session_id
      )
      |> Repo.all()
      |> Enum.group_by(& &1.step_number)

    {:ok, answers}
  end

  @doc """
  Selects 5 questions based on the strategy.
  """
  defp select_questions(steps, answers, strategy) do
    scored_steps = score_steps(steps, answers, strategy)

    # Take top 5 by score
    selected =
      scored_steps
      |> Enum.sort_by(fn {_step, score} -> score end, :desc)
      |> Enum.take(@deck_size)
      |> Enum.map(fn {step, _score} -> step end)

    {:ok, selected}
  end

  @doc """
  Scores steps based on selection strategy.
  """
  defp score_steps(steps, answers, strategy) do
    Enum.map(steps, fn step ->
      score = calculate_step_score(step, answers[step.step_number], strategy)
      {step, score}
    end)
  end

  @doc """
  Calculates individual step score for selection.
  """
  defp calculate_step_score(step, step_answers, strategy) do
    base_score = 0.0

    # Factor 1: Correctness (incorrect answers = higher priority)
    correctness_score =
      if step_answers do
        incorrect_count = Enum.count(step_answers, &(!&1.is_correct))
        incorrect_count * 10.0
      else
        # No answer = lower priority
        -5.0
      end

    # Factor 2: Time spent (longer = more challenging)
    time_score = min(step.time_spent_seconds / 10.0, 15.0)

    # Factor 3: Difficulty from metadata
    difficulty_score =
      case step.metadata["difficulty"] do
        "hard" -> 15.0
        "medium" -> 10.0
        "easy" -> 5.0
        _ -> 8.0
      end

    # Factor 4: Question type variety bonus
    type_bonus =
      case step.question_type do
        "multiple_choice" -> 3.0
        "open_ended" -> 5.0
        "true_false" -> 2.0
        _ -> 3.0
      end

    # Factor 5: Randomness for variety (±10%)
    randomness = :rand.uniform() * 10.0 - 5.0

    # Calculate weighted score based on strategy
    case strategy do
      :learning_focused ->
        # Prioritize learning opportunities (incorrect + difficult)
        base_score + correctness_score * 2.0 + difficulty_score * 1.5 + time_score + type_bonus +
          randomness

      :balanced ->
        # Balanced approach
        base_score + correctness_score + difficulty_score + time_score + type_bonus + randomness

      :competitive ->
        # Focus on challenging questions for competition
        base_score + difficulty_score * 2.0 + time_score * 1.5 + correctness_score + type_bonus +
          randomness
    end
  end

  @doc """
  Builds the final micro-deck structure.
  """
  defp build_micro_deck(selected_steps, session_id, strategy) do
    # Shuffle for variety but maintain some challenge progression
    questions =
      selected_steps
      |> Enum.shuffle()
      |> Enum.with_index(1)
      |> Enum.map(fn {step, index} ->
        %{
          question_number: index,
          title: step.title,
          content: step.content,
          question_type: step.question_type,
          correct_answer: step.correct_answer,
          options: step.options,
          metadata: %{
            original_step_number: step.step_number,
            difficulty: step.metadata["difficulty"],
            topic: step.metadata["topic"]
          }
        }
      end)

    %{
      session_id: session_id,
      strategy: strategy,
      questions: questions,
      question_count: length(questions),
      generated_at: DateTime.utc_now(),
      version: "1.0"
    }
  end

  @doc """
  Validates that a micro-deck has the required structure.
  """
  def valid?(micro_deck) do
    is_map(micro_deck) &&
      Map.has_key?(micro_deck, :questions) &&
      is_list(micro_deck.questions) &&
      length(micro_deck.questions) == @deck_size
  end

  @doc """
  Gets a summary of the micro-deck for display.
  """
  def get_summary(micro_deck) do
    question_types = Enum.frequencies_by(micro_deck.questions, & &1.question_type)

    difficulties =
      micro_deck.questions
      |> Enum.map(& &1.metadata["difficulty"])
      |> Enum.filter(& &1)
      |> Enum.frequencies()

    %{
      total_questions: length(micro_deck.questions),
      question_types: question_types,
      difficulties: difficulties,
      strategy: micro_deck.strategy,
      preview: Enum.take(micro_deck.questions, 2) |> Enum.map(& &1.title)
    }
  end
end
