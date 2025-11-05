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

  alias ViralEngine.{Repo, ViralPrompts, StudySession}
  require Logger

  @exam_window_days 7
  @weak_subject_threshold 70
  @recent_activity_days 14

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
          Logger.info(
            "Study buddy nudge created for user #{user_data.user_id}: #{study_session.session_token}"
          )

        {:skip, reason} ->
          Logger.debug("Skipped study nudge for user #{user_data.user_id}: #{reason}")

        {:error, reason} ->
          Logger.error(
            "Failed to create study nudge for user #{user_data.user_id}: #{inspect(reason)}"
          )
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
    import Ecto.Query
    alias ViralEngine.{DiagnosticAssessment, PracticeSession}

    today = Date.utc_today()
    exam_window_end = Date.add(today, @exam_window_days)

    recent_activity_cutoff =
      DateTime.utc_now() |> DateTime.add(-@recent_activity_days * 24 * 3600, :second)

    # Strategy: Find users with upcoming exams OR weak subjects
    # 1. Users with scheduled assessments (via metadata)
    upcoming_exam_users = find_users_with_upcoming_exams(today, exam_window_end)

    # 2. Users with weak performance in subjects they're actively practicing
    weak_subject_users =
      find_users_with_weak_subjects(@weak_subject_threshold, recent_activity_cutoff)

    # 3. Merge and deduplicate
    (upcoming_exam_users ++ weak_subject_users)
    |> Enum.uniq_by(&{&1.user_id, &1.subject})
  end

  defp find_users_with_upcoming_exams(today, exam_window_end) do
    import Ecto.Query
    alias ViralEngine.StudySession

    # Check study sessions with exam_date field
    from(ss in StudySession,
      where:
        ss.session_type == "exam_prep" and
          ss.exam_date >= ^today and
          ss.exam_date <= ^exam_window_end and
          ss.status in ["scheduled", "active"],
      select: %{
        user_id: ss.creator_id,
        subject: ss.subject,
        exam_date: ss.exam_date,
        source: "scheduled_exam"
      }
    )
    |> Repo.all()
  end

  defp find_users_with_weak_subjects(threshold, recent_cutoff) do
    import Ecto.Query
    alias ViralEngine.PracticeSession

    # Find users with low average scores in subjects they're practicing
    from(ps in PracticeSession,
      where:
        ps.completed == true and
          ps.inserted_at >= ^recent_cutoff and
          not is_nil(ps.score),
      group_by: [ps.user_id, ps.subject],
      having: avg(ps.score) < ^threshold and count(ps.id) >= 3,
      select: %{
        user_id: ps.user_id,
        subject: ps.subject,
        exam_date: fragment("DATE(? + INTERVAL '7 days')", ^Date.utc_today()),
        average_score: avg(ps.score),
        source: "weak_performance"
      }
    )
    |> Repo.all()
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
        # 90 min exam prep sessions
        duration_minutes: 90,
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
    import Ecto.Query
    alias ViralEngine.{PracticeSession, DiagnosticAssessment, SessionIntelligenceContext}

    # Strategy: Combine diagnostic weak areas + practice session weak topics

    # 1. Get weak topics from most recent diagnostic assessment
    diagnostic_weak_topics = get_diagnostic_weak_topics(user_id, subject)

    # 2. Get weak topics from recent practice sessions (low scores)
    practice_weak_topics =
      from(ps in PracticeSession,
        where:
          ps.user_id == ^user_id and
            ps.subject == ^subject and
            ps.completed == true and
            not is_nil(ps.score) and
            ps.score < 70,
        order_by: [asc: ps.score, desc: ps.inserted_at],
        limit: 10,
        select: fragment("? ->> 'topic'", ps.metadata)
      )
      |> Repo.all()
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_topic, count} -> -count end)
      |> Enum.take(3)
      |> Enum.map(fn {topic, _count} -> topic end)

    # 3. Use Session Intelligence if available
    intelligence_weak_topics =
      case SessionIntelligenceContext.identify_weak_topics(
             user_id: user_id,
             subject: subject,
             limit: 3
           ) do
        {:ok, topics} -> Enum.map(topics, & &1.topic)
        _ -> []
      end

    # Merge all sources, prioritize diagnostic + intelligence
    (diagnostic_weak_topics ++ intelligence_weak_topics ++ practice_weak_topics)
    |> Enum.uniq()
    |> Enum.take(5)
    |> case do
      # Fallback if no data
      [] -> get_default_topics(subject)
      topics -> topics
    end
  end

  defp get_diagnostic_weak_topics(user_id, subject) do
    import Ecto.Query
    alias ViralEngine.DiagnosticAssessment

    from(da in DiagnosticAssessment,
      where:
        da.user_id == ^user_id and
          da.subject == ^subject and
          da.completed == true,
      order_by: [desc: da.inserted_at],
      limit: 1,
      select: da.results
    )
    |> Repo.one()
    |> case do
      nil ->
        []

      results ->
        # Extract weak topics from results map
        get_in(results, ["weak_topics"]) ||
          get_in(results, ["skill_heatmap"])
          |> extract_weak_from_heatmap() ||
          []
    end
  end

  defp extract_weak_from_heatmap(nil), do: []

  defp extract_weak_from_heatmap(heatmap) when is_map(heatmap) do
    heatmap
    |> Enum.filter(fn {_topic, proficiency} -> proficiency < 0.5 end)
    |> Enum.sort_by(fn {_topic, proficiency} -> proficiency end)
    |> Enum.take(3)
    |> Enum.map(fn {topic, _proficiency} -> topic end)
  end

  defp extract_weak_from_heatmap(_), do: []

  defp get_default_topics(subject) do
    # Fallback for when no user data exists
    case subject do
      "math" -> ["Algebra", "Geometry", "Word Problems"]
      "science" -> ["Scientific Method", "Lab Safety", "Core Concepts"]
      "english" -> ["Reading Comprehension", "Writing", "Grammar"]
      "history" -> ["Key Events", "Important Figures", "Timelines"]
      _ -> ["General Review", "Practice Problems", "Study Skills"]
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
    import Ecto.Query
    alias ViralEngine.StudySession

    from(ss in StudySession,
      where:
        ss.creator_id == ^user_id and
          ss.subject == ^subject and
          ss.status in ["scheduled", "active"] and
          ss.session_type == "exam_prep"
    )
    |> Repo.exists?()
  end

  # Triggers viral prompt to invite study buddies.
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
      {:ok, _prompt} ->
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
    import Ecto.Query
    alias ViralEngine.PracticeSession

    recent_cutoff = DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)

    # Find users who:
    # 1. Are NOT the current user
    # 2. Have practiced same subject recently
    # 3. Have strong scores in user's weak topics
    # 4. Are active (recent sessions)

    if Enum.empty?(weak_topics) do
      # No weak topics? Find generally strong peers in this subject
      find_strong_peers_general(user_id, subject, recent_cutoff, limit)
    else
      # Find peers strong in user's weak areas
      find_complementary_peers(user_id, subject, weak_topics, recent_cutoff, limit)
    end
  end

  defp find_strong_peers_general(user_id, subject, recent_cutoff, limit) do
    import Ecto.Query
    alias ViralEngine.PracticeSession

    from(ps in PracticeSession,
      where:
        ps.user_id != ^user_id and
          ps.subject == ^subject and
          ps.completed == true and
          ps.inserted_at >= ^recent_cutoff and
          not is_nil(ps.score),
      group_by: ps.user_id,
      having: avg(ps.score) > 75 and count(ps.id) >= 3,
      order_by: [desc: avg(ps.score), desc: count(ps.id)],
      limit: ^limit,
      select: %{
        user_id: ps.user_id,
        average_score: avg(ps.score),
        session_count: count(ps.id),
        strength_match: 0.0
      }
    )
    |> Repo.all()
  end

  defp find_complementary_peers(user_id, subject, weak_topics, recent_cutoff, limit) do
    import Ecto.Query
    alias ViralEngine.PracticeSession

    # This query finds users strong in the specified weak topics
    # Using PostgreSQL's @> operator for metadata containment would be ideal,
    # but we'll use a simpler approach that works across databases

    from(ps in PracticeSession,
      where:
        ps.user_id != ^user_id and
          ps.subject == ^subject and
          ps.completed == true and
          ps.inserted_at >= ^recent_cutoff and
          not is_nil(ps.score) and
          ps.score >= 80,
      group_by: ps.user_id,
      having: count(ps.id) >= 3,
      order_by: [desc: avg(ps.score), desc: count(ps.id)],
      # Get more candidates for filtering
      limit: ^limit * 2,
      select: %{
        user_id: ps.user_id,
        average_score: avg(ps.score),
        session_count: count(ps.id)
      }
    )
    |> Repo.all()
    |> Enum.map(fn peer ->
      # Calculate strength match based on topic overlap
      strength_match = calculate_topic_strength_match(peer.user_id, subject, weak_topics)
      Map.put(peer, :strength_match, strength_match)
    end)
    |> Enum.sort_by(&{-&1.strength_match, -&1.average_score})
    |> Enum.take(limit)
  end

  defp calculate_topic_strength_match(peer_user_id, subject, weak_topics) do
    import Ecto.Query
    alias ViralEngine.PracticeSession

    # Count how many sessions this peer has done well in the weak topics
    matching_sessions =
      from(ps in PracticeSession,
        where:
          ps.user_id == ^peer_user_id and
            ps.subject == ^subject and
            ps.completed == true and
            not is_nil(ps.score) and
            ps.score >= 80,
        select: fragment("? ->> 'topic'", ps.metadata)
      )
      |> Repo.all()
      |> Enum.filter(&(&1 in weak_topics))
      |> length()

    # Normalize to 0-1 score
    min(1.0, matching_sessions / max(length(weak_topics), 1))
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
