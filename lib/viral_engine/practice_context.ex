defmodule ViralEngine.PracticeContext do
  @moduledoc """
  Context module for managing practice sessions, steps, and answers.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, PracticeSession, PracticeStep, PracticeAnswer}
  require Logger

  @doc """
  Creates a new practice session for a user.
  """
  def create_session(attrs \\ %{}) do
    %PracticeSession{}
    |> PracticeSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a practice session by ID, preloading steps and answers.
  """
  def get_session(id) do
    Repo.get(PracticeSession, id)
    |> Repo.preload([:steps, :answers])
  end

  @doc """
  Gets a practice session by ID for a specific user.
  """
  def get_user_session(session_id, user_id) do
    from(s in PracticeSession,
      where: s.id == ^session_id and s.user_id == ^user_id
    )
    |> Repo.one()
    |> Repo.preload([:steps, :answers])
  end

  @doc """
  Updates a practice session.
  """
  def update_session(%PracticeSession{} = session, attrs) do
    session
    |> PracticeSession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates session progress (current step, timer, paused state).
  """
  def update_progress(session_id, attrs) do
    session = Repo.get(PracticeSession, session_id)

    if session do
      session
      |> PracticeSession.changeset(attrs)
      |> Repo.update()
    else
      {:error, :not_found}
    end
  end

  @doc """
  Marks a session as completed and calculates the score.
  """
  def complete_session(session_id) do
    session = get_session(session_id)

    if session do
      correct_answers =
        from(a in PracticeAnswer,
          where: a.practice_session_id == ^session_id and a.is_correct == true
        )
        |> Repo.aggregate(:count)

      total_steps = length(session.steps)
      score = if total_steps > 0, do: round(correct_answers / total_steps * 100), else: 0

      update_session(session, %{completed: true, score: score})
    else
      {:error, :not_found}
    end
  end

  @doc """
  Creates a practice step for a session.
  """
  def create_step(attrs \\ %{}) do
    %PracticeStep{}
    |> PracticeStep.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates multiple steps for a session.
  """
  def create_steps(session_id, steps_data) when is_list(steps_data) do
    steps =
      Enum.map(steps_data, fn {step_number, step_attrs} ->
        attrs = Map.merge(step_attrs, %{practice_session_id: session_id, step_number: step_number})

        %PracticeStep{}
        |> PracticeStep.changeset(attrs)
        |> Repo.insert!()
      end)

    {:ok, steps}
  end

  @doc """
  Gets all steps for a session, ordered by step number.
  """
  def list_session_steps(session_id) do
    from(s in PracticeStep,
      where: s.practice_session_id == ^session_id,
      order_by: [asc: s.step_number]
    )
    |> Repo.all()
  end

  @doc """
  Gets a specific step by session and step number.
  """
  def get_step(session_id, step_number) do
    from(s in PracticeStep,
      where: s.practice_session_id == ^session_id and s.step_number == ^step_number
    )
    |> Repo.one()
  end

  @doc """
  Updates a practice step.
  """
  def update_step(%PracticeStep{} = step, attrs) do
    step
    |> PracticeStep.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks a step as completed.
  """
  def complete_step(session_id, step_number) do
    step = get_step(session_id, step_number)

    if step do
      update_step(step, %{completed: true})
    else
      {:error, :not_found}
    end
  end

  @doc """
  Records a user's answer to a step.
  """
  def record_answer(attrs \\ %{}) do
    changeset = PracticeAnswer.changeset(%PracticeAnswer{}, attrs)

    case Repo.insert(changeset) do
      {:ok, answer} ->
        Logger.info("Answer recorded for step #{attrs.practice_step_id}")
        {:ok, answer}

      {:error, changeset} ->
        Logger.error("Failed to record answer: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Validates an answer and records it with feedback.
  """
  def validate_and_record_answer(session_id, step_number, user_answer) do
    step = get_step(session_id, step_number)

    if step do
      is_correct = check_answer(step, user_answer)
      feedback = generate_feedback(step, user_answer, is_correct)

      record_answer(%{
        practice_session_id: session_id,
        practice_step_id: step.id,
        user_answer: user_answer,
        is_correct: is_correct,
        feedback: feedback
      })
    else
      {:error, :step_not_found}
    end
  end

  @doc """
  Gets all answers for a session.
  """
  def list_session_answers(session_id) do
    from(a in PracticeAnswer,
      where: a.practice_session_id == ^session_id,
      order_by: [desc: a.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists all active (non-completed) sessions for a user.
  """
  def list_user_active_sessions(user_id) do
    from(s in PracticeSession,
      where: s.user_id == ^user_id and s.completed == false,
      order_by: [desc: s.updated_at],
      preload: [:steps]
    )
    |> Repo.all()
  end

  @doc """
  Lists completed sessions for a user.
  """
  def list_user_completed_sessions(user_id, limit \\ 10) do
    from(s in PracticeSession,
      where: s.user_id == ^user_id and s.completed == true,
      order_by: [desc: s.updated_at],
      limit: ^limit,
      preload: [:steps]
    )
    |> Repo.all()
  end

  @doc """
  Gets session statistics for a user.
  """
  def get_user_stats(user_id) do
    total_sessions =
      from(s in PracticeSession, where: s.user_id == ^user_id)
      |> Repo.aggregate(:count)

    completed_sessions =
      from(s in PracticeSession, where: s.user_id == ^user_id and s.completed == true)
      |> Repo.aggregate(:count)

    average_score =
      from(s in PracticeSession,
        where: s.user_id == ^user_id and s.completed == true and not is_nil(s.score),
        select: avg(s.score)
      )
      |> Repo.one()

    total_time =
      from(s in PracticeSession, where: s.user_id == ^user_id, select: sum(s.timer_seconds))
      |> Repo.one()

    %{
      total_sessions: total_sessions,
      completed_sessions: completed_sessions,
      average_score: average_score || 0,
      total_time_seconds: total_time || 0
    }
  end

  # Private functions

  defp check_answer(%PracticeStep{question_type: "multiple_choice"} = step, user_answer) do
    String.downcase(String.trim(user_answer)) == String.downcase(String.trim(step.correct_answer))
  end

  defp check_answer(%PracticeStep{question_type: "true_false"} = step, user_answer) do
    String.downcase(String.trim(user_answer)) == String.downcase(String.trim(step.correct_answer))
  end

  defp check_answer(%PracticeStep{question_type: "open_ended"} = step, user_answer) do
    # For open-ended, use simple keyword matching or AI validation
    # This is a simplified version - in production, you might use NLP or AI
    correct_keywords = String.split(step.correct_answer, ",") |> Enum.map(&String.trim/1)

    Enum.any?(correct_keywords, fn keyword ->
      String.contains?(String.downcase(user_answer), String.downcase(keyword))
    end)
  end

  defp check_answer(_step, _user_answer), do: false

  defp generate_feedback(%PracticeStep{} = step, _user_answer, true) do
    step.metadata["success_message"] || "Correct! Great job!"
  end

  defp generate_feedback(%PracticeStep{} = step, _user_answer, false) do
    hint = step.metadata["hint"]
    base_message = "Not quite right. "

    if hint do
      base_message <> "Hint: #{hint}"
    else
      base_message <> "Try again!"
    end
  end

  @doc """
  Lists completed sessions by subject for leaderboard.
  """
  def list_completed_sessions_by_subject(subject, days \\ 7) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days, :day)

    from(s in PracticeSession,
      where: s.subject == ^subject and s.completed == true and s.updated_at > ^cutoff_date,
      order_by: [desc: s.score],
      limit: 100
    )
    |> Repo.all()
  end
end
