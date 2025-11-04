defmodule ViralEngine.Workers.StudyBuddyNudgeWorker do
  @moduledoc """
  Oban worker that detects upcoming exams and prompts users
  to invite study buddies for co-practice sessions.

  Agentic Action: Identifies exam stress points and facilitates
  social study group formation.
  """

  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 3

  alias ViralEngine.{Repo, PracticeContext, DiagnosticContext, ViralPrompts, StudySession}
  require Logger

  import Ecto.Query

  @exam_window_days 7  # Nudge if exam in next 7 days
  @weak_subject_threshold 70  # Subject with <70% avg needs attention

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("StudyBuddyNudgeWorker: Checking for users with upcoming exams")

    # Find users with upcoming exams or struggling subjects
    users_needing_nudge = find_users_needing_study_help()

    Logger.info("Found #{length(users_needing_nudge)} users needing study nudges")

    # Generate study buddy nudges for each user
    Enum.each(users_needing_nudge, fn user_data ->
      case generate_study_buddy_nudge(user_data) do
        {:ok, study_session} ->
          Logger.info("Study buddy nudge created for user #{user_data.user_id}: #{study_session.session_token}")

        {:skip, reason} ->
          Logger.debug("Skipped study nudge for user #{user_data.user_id}: #{reason}")

        {:error, reason} ->
          Logger.error("Failed to create study nudge for user #{user_data.user_id}: #{inspect(reason)}")
      end
    end)

    :ok
  end

  @doc """
  Finds users who would benefit from study buddy nudges.

  Criteria:
  - Has upcoming exam/assessment in next 7 days
  - Has weak subject area (< 70% average)
  - Recent practice activity (not completely inactive)
  """
  def find_users_needing_study_help do
    # In production, this would query:
    # 1. Users with scheduled assessments in next 7 days
    # 2. Users with poor performance in specific subjects
    # 3. Users who have been practicing (not inactive)

    # Query structure:
    # from(u in User,
    #   join: a in Assessment, on: a.user_id == u.id,
    #   where: a.scheduled_date >= ^Date.utc_today() and
    #          a.scheduled_date <= ^Date.add(Date.utc_today(), @exam_window_days),
    #   group_by: [u.id, a.subject],
    #   select: %{
    #     user_id: u.id,
    #     subject: a.subject,
    #     exam_date: a.scheduled_date,
    #     average_score: avg(a.score)
    #   },
    #   having: avg(a.score) < @weak_subject_threshold or count(a.id) > 0
    # )
    # |> Repo.all()

    # Simulated: Return empty list
    []
  end

  @doc """
  Generates a study buddy nudge for a user.

  Creates a study session and triggers prompt to invite friends.
  """
  def generate_study_buddy_nudge(user_data) do
    %{user_id: user_id, subject: subject, exam_date: exam_date} = user_data

    # Check if user already has an active study session for this subject
    if has_active_study_session?(user_id, subject) do
      {:skip, :already_has_session}
    else
      # Analyze weak topics for the subject
      weak_topics = identify_weak_topics(user_id, subject)

      # Create study session
      session_attrs = %{
        creator_id: user_id,
        session_name: "#{subject} Exam Prep - #{exam_date}",
        subject: subject,
        session_token: StudySession.generate_token(user_id, subject),
        session_type: "exam_prep",
        scheduled_at: calculate_optimal_study_time(exam_date),
        duration_minutes: 90,  # 90 min exam prep sessions
        topics: weak_topics,
        exam_date: exam_date,
        participant_ids: [user_id],
        metadata: %{
          auto_generated: true,
          nudge_reason: "upcoming_exam",
          weak_topics: weak_topics
        }
      }

      case Repo.insert(StudySession.changeset(%StudySession{}, session_attrs)) do
        {:ok, study_session} ->
          # Trigger viral prompt to invite study buddies
          trigger_study_buddy_prompt(user_id, study_session, weak_topics)

          {:ok, study_session}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Identifies weak topics for a subject based on past performance.
  """
  def identify_weak_topics(user_id, subject) do
    # In production, analyze user's session history
    # and identify topics with low scores

    # Query structure:
    # from(ps in PracticeSession,
    #   where: ps.user_id == ^user_id and
    #          ps.subject == ^subject and
    #          ps.completed == true,
    #   order_by: [asc: ps.score],
    #   limit: 3,
    #   select: fragment("? ->> 'topic'", ps.metadata)
    # )
    # |> Repo.all()

    # Simulated weak topics
    case subject do
      "math" -> ["Quadratic Equations", "Polynomial Factoring", "Logarithms"]
      "science" -> ["Cellular Respiration", "Newton's Laws", "Periodic Table"]
      "english" -> ["Essay Structure", "Grammar Rules", "Literary Analysis"]
      _ -> ["General Review"]
    end
  end

  @doc """
  Calculates optimal study time (2-3 days before exam).
  """
  def calculate_optimal_study_time(exam_date) do
    # Schedule study session 2 days before exam, at 6 PM
    study_date = Date.add(exam_date, -2)

    DateTime.new!(study_date, Time.new!(18, 0, 0), "Etc/UTC")
  end

  @doc """
  Checks if user has an active study session for subject.
  """
  def has_active_study_session?(user_id, subject) do
    # Query for active study sessions
    # In production:
    # from(ss in StudySession,
    #   where: ss.creator_id == ^user_id and
    #          ss.subject == ^subject and
    #          ss.status == "scheduled"
    # )
    # |> Repo.exists?()

    # Simulated: No active sessions
    false
  end

  @doc """
  Triggers viral prompt to invite study buddies.
  """
  defp trigger_study_buddy_prompt(user_id, study_session, weak_topics) do
    event_data = %{
      study_session_id: study_session.id,
      session_token: study_session.session_token,
      subject: study_session.subject,
      exam_date: study_session.exam_date,
      weak_topics: weak_topics,
      scheduled_at: study_session.scheduled_at
    }

    case ViralPrompts.trigger_prompt(:study_buddy_nudge, user_id, event_data) do
      {:ok, prompt} ->
        Logger.info("Triggered study buddy nudge for user #{user_id}")
        ViralPrompts.broadcast_event(:study_buddy_nudge, user_id, event_data)

      {:throttled, reason} ->
        Logger.debug("Study buddy nudge throttled for user #{user_id}: #{reason}")

      {:no_prompt, reason} ->
        Logger.debug("No study buddy nudge for user #{user_id}: #{reason}")
    end
  end

  @doc """
  Recommends study buddies for a user based on:
  - Similar subject/grade level
  - Complementary strengths (friend is strong where user is weak)
  - Recent activity (active users)
  """
  def recommend_study_buddies(user_id, subject, weak_topics, limit \\ 5) do
    # In production, complex query to find compatible study partners:
    # 1. Same grade level and subject
    # 2. Strong in user's weak topics
    # 3. Recently active
    # 4. Existing social connections (if available)

    # Query structure:
    # from(u in User,
    #   join: ps in PracticeSession, on: ps.user_id == u.id,
    #   where: u.id != ^user_id and
    #          ps.subject == ^subject and
    #          ps.completed_at > ^DateTime.add(DateTime.utc_now(), -7, :day) and
    #          fragment("? ->> 'topic' = ANY(?)", ps.metadata, ^weak_topics),
    #   group_by: u.id,
    #   having: avg(ps.score) > 75,
    #   order_by: [desc: count(ps.id)],
    #   limit: ^limit,
    #   select: u
    # )
    # |> Repo.all()

    # Simulated: Return empty list
    []
  end

  @doc """
  Enqueues the worker to run twice daily (morning and evening).
  """
  def schedule_twice_daily do
    # Morning check (8 AM)
    %{}
    |> __MODULE__.new(schedule: "0 8 * * *")
    |> Oban.insert()

    # Evening check (6 PM)
    %{}
    |> __MODULE__.new(schedule: "0 18 * * *")
    |> Oban.insert()
  end
end
