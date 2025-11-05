defmodule ViralEngine.PracticeContext do
  @moduledoc """
  Context module for managing practice sessions, steps, and answers.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, PracticeSession, PracticeStep, PracticeAnswer, LeaderboardContext}
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

      result = update_session(session, %{completed: true, score: score})

      # Create activity event and update leaderboards
      with {:ok, updated_session} <- result do
        ViralEngine.Activities.create_event(%{
          user_id: updated_session.user_id,
          event_type: "practice_completed",
          data: %{
            score: score,
            correct_answers: correct_answers,
            total_steps: total_steps,
            session_id: session_id
          },
          visibility: "public"
        })

        # Invalidate leaderboard cache and broadcast update
        if updated_session.subject do
          LeaderboardContext.invalidate_cache(updated_session.subject)
          LeaderboardContext.broadcast_update(updated_session.subject)
        end

        # Grant Streak Shield rewards for successful rescue sessions
        if updated_session.session_type == "streak_rescue" && score >= 60 do
          grant_streak_rescue_rewards(updated_session)
        end

        {:ok, updated_session}
      end
    else
      {:error, :not_found}
    end
  end

  # Private helper for granting Streak Shield rewards
  defp grant_streak_rescue_rewards(session) do
    # Grant Streak Shield to the user who completed the rescue
    grant_streak_shield(session.user_id, "rescue_completion")

    # Grant Streak Shield to inviter if this was a co-practice rescue
    if session.metadata["inviter_id"] do
      grant_streak_shield(session.metadata["inviter_id"], "rescue_helper")

      # Track attribution conversion with reward value
      if session.metadata["attribution_link_id"] do
        ViralEngine.AttributionContext.track_conversion(
          session.metadata["attribution_link_id"],
          session.user_id,
          # XP value of helping with rescue
          50
        )
      end
    end

    Logger.info("Streak Shield rewards granted for rescue session #{session.id}")
  end

  defp grant_streak_shield(user_id, reason) do
    # Find or create Streak Shield reward
    streak_shield = Repo.get_by(ViralEngine.Reward, name: "Streak Shield")

    if streak_shield do
      # Check if user already has this reward
      existing =
        Repo.get_by(ViralEngine.UserReward,
          user_id: user_id,
          reward_id: streak_shield.id,
          # Only grant if they don't have an unused one
          uses_remaining: 1
        )

      if !existing do
        # Grant new Streak Shield
        %ViralEngine.UserReward{}
        |> ViralEngine.UserReward.changeset(%{
          user_id: user_id,
          reward_id: streak_shield.id,
          claimed_at: DateTime.utc_now(),
          # Free reward
          xp_spent: 0,
          uses_remaining: 1,
          is_active: true,
          metadata: %{
            "granted_for" => reason,
            "granted_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
        |> Repo.insert()

        # Create activity event
        ViralEngine.Activities.create_event(%{
          user_id: user_id,
          event_type: "reward_earned",
          data: %{
            reward_name: "Streak Shield",
            reason: reason
          },
          visibility: "public"
        })

        Logger.info("Granted Streak Shield to user #{user_id} for #{reason}")
      end
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
        attrs =
          Map.merge(step_attrs, %{practice_session_id: session_id, step_number: step_number})

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

  @doc """
  Calculates the percentile rank for a user's session in a subject.

  ## Parameters
  - session_id: Practice session ID
  - subject: Subject to compare within (optional, defaults to session's subject)
  - time_period: Days to consider for ranking (default 7)

  ## Returns
  - Percentile rank (0-100) where 100 is top performer
  """
  def calculate_percentile_rank(session_id, opts \\ []) do
    session = get_session(session_id)

    if session && session.completed do
      subject = opts[:subject] || session.subject
      time_period = opts[:time_period] || 7

      cutoff_date = DateTime.add(DateTime.utc_now(), -time_period, :day)

      # Get all completed sessions for this subject in the time period
      all_scores =
        from(s in PracticeSession,
          where: s.subject == ^subject and s.completed == true and s.updated_at > ^cutoff_date,
          select: s.score,
          order_by: [asc: s.score]
        )
        |> Repo.all()

      total_count = length(all_scores)

      if total_count > 0 do
        # Count sessions with lower scores
        lower_count = Enum.count(all_scores, fn score -> score < session.score end)

        # Calculate percentile (percentage of users this user beat)
        percentile = (lower_count / total_count * 100) |> Float.round(1)

        {:ok, percentile}
      else
        {:ok, 0.0}
      end
    else
      {:error, :session_not_found}
    end
  end

  @doc """
  Gets user's rank in a subject leaderboard.

  ## Parameters
  - session_id: Practice session ID
  - subject: Subject to rank in (optional, defaults to session's subject)
  - time_period: Days to consider (default 7)

  ## Returns
  - {:ok, %{rank: integer, total: integer, percentile: float}}
  """
  def get_session_rank(session_id, opts \\ []) do
    session = get_session(session_id)

    if session && session.completed do
      subject = opts[:subject] || session.subject
      time_period = opts[:time_period] || 7

      cutoff_date = DateTime.add(DateTime.utc_now(), -time_period, :day)

      # Get all completed sessions ranked by score
      sessions =
        from(s in PracticeSession,
          where: s.subject == ^subject and s.completed == true and s.updated_at > ^cutoff_date,
          select: %{id: s.id, score: s.score},
          order_by: [desc: s.score]
        )
        |> Repo.all()

      total = length(sessions)

      # Find this session's rank
      rank = Enum.find_index(sessions, fn s -> s.id == session.id end)

      if rank do
        # Convert 0-indexed to 1-indexed
        rank = rank + 1
        percentile = ((total - rank) / total * 100) |> Float.round(1)

        {:ok, %{rank: rank, total: total, percentile: percentile, score: session.score}}
      else
        {:ok, %{rank: nil, total: total, percentile: 0.0, score: session.score}}
      end
    else
      {:error, :session_not_found}
    end
  end
end
