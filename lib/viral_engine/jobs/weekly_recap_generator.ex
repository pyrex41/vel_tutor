defmodule ViralEngine.Jobs.WeeklyRecapGenerator do
  @moduledoc """
  Oban worker for generating weekly recaps and triggering Proud Parent loops.

  This job runs weekly (typically Sunday evening or Monday morning) to:
  1. Identify active parents with students who had sessions this week
  2. Generate weekly recap for each parent
  3. Trigger ProudParent loop for each recap
  4. Send notifications to parents about their recap

  Scheduled via Oban cron in application.ex
  """

  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 3,
    priority: 2

  require Logger
  alias ViralEngine.{Repo, Accounts.User, TutoringSession, WeeklyRecap}
  alias ViralEngine.Loops.ProudParent
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    week_start = get_week_start(args)
    week_end = Date.add(week_start, 6)

    Logger.info("Starting WeeklyRecapGenerator for week #{week_start} to #{week_end}")

    with {:ok, active_parents} <- fetch_active_parents(week_start, week_end),
         {:ok, recaps_generated} <- generate_recaps_for_parents(active_parents, week_start),
         {:ok, loops_triggered} <- trigger_proud_parent_loops(recaps_generated) do
      Logger.info(
        "WeeklyRecapGenerator completed: #{length(recaps_generated)} recaps, #{loops_triggered} loops"
      )

      {:ok, %{recaps: length(recaps_generated), loops: loops_triggered}}
    else
      {:error, reason} = error ->
        Logger.error("WeeklyRecapGenerator failed: #{inspect(reason)}")
        error
    end
  end

  # Get week start date from args or default to last Monday
  defp get_week_start(args) do
    case args do
      %{"week_start" => date_string} ->
        Date.from_iso8601!(date_string)

      _ ->
        # Default to last Monday
        today = Date.utc_today()
        days_since_monday = Date.day_of_week(today) - 1
        Date.add(today, -days_since_monday - 7)
    end
  end

  # Fetch parents who have students with sessions in the target week
  defp fetch_active_parents(week_start, week_end) do
    # Find all sessions in the target week
    week_end_inclusive = Date.add(week_end, 1)

    query =
      from s in TutoringSession,
        where: s.started_at >= ^week_start,
        where: s.started_at < ^week_end_inclusive,
        where: not is_nil(s.ended_at),
        select: s.student_id,
        distinct: true

    student_ids = Repo.all(query)

    if Enum.empty?(student_ids) do
      Logger.info("No active sessions found for week #{week_start}")
      {:ok, []}
    else
      # Find parents of these students
      parent_query =
        from u in User,
          where: u.id in subquery(
            from child in User,
              where: child.id in ^student_ids,
              where: not is_nil(child.parent_id),
              select: child.parent_id,
              distinct: true
          ),
          where: u.persona == "parent"

      parents = Repo.all(parent_query)
      Logger.info("Found #{length(parents)} active parents for week #{week_start}")
      {:ok, parents}
    end
  end

  # Generate recap for each parent
  defp generate_recaps_for_parents(parents, week_start) do
    recaps =
      Enum.reduce(parents, [], fn parent, acc ->
        case generate_recap_for_parent(parent, week_start) do
          {:ok, recap} ->
            [recap | acc]

          {:error, reason} ->
            Logger.warning("Failed to generate recap for parent #{parent.id}: #{inspect(reason)}")
            acc
        end
      end)

    {:ok, recaps}
  end

  defp generate_recap_for_parent(parent, week_start) do
    week_end = Date.add(week_start, 6)

    # Check if recap already exists
    existing_recap =
      from(r in WeeklyRecap,
        where: r.parent_id == ^parent.id,
        where: r.week_start == ^week_start
      )
      |> Repo.one()

    if existing_recap do
      Logger.debug("Recap already exists for parent #{parent.id}, week #{week_start}")
      {:ok, existing_recap}
    else
      # Find student(s) for this parent
      students =
        from(u in User,
          where: u.parent_id == ^parent.id,
          where: u.persona == "student"
        )
        |> Repo.all()

      if Enum.empty?(students) do
        {:error, :no_students_found}
      else
        create_new_recap(parent, students, week_start, week_end)
      end
    end
  end

  defp create_new_recap(parent, students, week_start, week_end) do
    student_ids = Enum.map(students, & &1.id)
    week_end_inclusive = Date.add(week_end, 1)

    # Fetch all sessions for these students in the week
    sessions =
      from(s in TutoringSession,
        where: s.student_id in ^student_ids,
        where: s.started_at >= ^week_start,
        where: s.started_at < ^week_end_inclusive,
        where: not is_nil(s.ended_at)
      )
      |> Repo.all()

    if Enum.empty?(sessions) do
      {:error, :no_sessions_in_week}
    else
      recap_data = calculate_recap_data(sessions)

      recap_attrs = %{
        parent_id: parent.id,
        student_id: hd(student_ids),
        week_start: week_start,
        week_end: week_end,
        session_count: recap_data.session_count,
        total_minutes: recap_data.total_minutes,
        skills_practiced: recap_data.skills,
        improvements: recap_data.improvements,
        highlights: generate_highlights(recap_data, students)
      }

      case Repo.insert(WeeklyRecap.changeset(%WeeklyRecap{}, recap_attrs)) do
        {:ok, recap} ->
          Logger.info("Created recap #{recap.id} for parent #{parent.id}")
          {:ok, recap}

        {:error, changeset} ->
          Logger.error("Failed to create recap: #{inspect(changeset.errors)}")
          {:error, :recap_creation_failed}
      end
    end
  end

  defp calculate_recap_data(sessions) do
    session_count = length(sessions)

    total_minutes =
      Enum.reduce(sessions, 0, fn s, acc ->
        acc + (s.duration_minutes || 0)
      end)

    # Extract unique skills/topics
    skills =
      sessions
      |> Enum.flat_map(fn s -> [s.subject, s.topic] end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()

    # Calculate improvements
    ratings = Enum.map(sessions, & &1.rating) |> Enum.filter(&(&1 != nil))

    avg_rating =
      if Enum.empty?(ratings) do
        0.0
      else
        Enum.sum(ratings) / length(ratings)
      end

    # Group sessions by subject for detailed breakdown
    subject_breakdown =
      sessions
      |> Enum.group_by(& &1.subject)
      |> Enum.map(fn {subject, subject_sessions} ->
        {subject, length(subject_sessions)}
      end)
      |> Enum.into(%{})

    improvements = %{
      total_sessions: session_count,
      total_time_minutes: total_minutes,
      average_rating: Float.round(avg_rating, 1),
      skills_count: length(skills),
      subject_breakdown: subject_breakdown
    }

    %{
      session_count: session_count,
      total_minutes: total_minutes,
      skills: skills,
      improvements: improvements
    }
  end

  defp generate_highlights(recap_data, students) do
    student_names = Enum.map(students, & &1.name) |> Enum.join(" and ")
    hours = Float.round(recap_data.total_minutes / 60, 1)

    top_subjects =
      recap_data.improvements.subject_breakdown
      |> Enum.sort_by(fn {_subject, count} -> -count end)
      |> Enum.take(3)
      |> Enum.map(fn {subject, count} -> "#{subject} (#{count} sessions)" end)
      |> Enum.join(", ")

    """
    🌟 Weekly Learning Highlights for #{student_names}

    📊 This Week's Progress:
    • #{recap_data.session_count} tutoring sessions completed
    • #{hours} hours of focused learning
    • #{length(recap_data.skills)} different topics explored
    • #{recap_data.improvements.average_rating}/5.0 average session rating

    🎯 Focus Areas: #{top_subjects}

    #{generate_motivational_message(recap_data)}

    Keep up the fantastic work! 🚀
    """
  end

  defp generate_motivational_message(recap_data) do
    cond do
      recap_data.session_count >= 5 ->
        "🏆 Outstanding commitment! Your child is building excellent study habits."

      recap_data.improvements.average_rating >= 4.5 ->
        "⭐ Excellent engagement! High ratings show great tutor-student connection."

      recap_data.total_minutes >= 180 ->
        "💪 Impressive dedication! Over 3 hours of focused learning this week."

      true ->
        "📈 Great progress! Consistency is key to long-term success."
    end
  end

  # Trigger ProudParent loops for all generated recaps
  defp trigger_proud_parent_loops(recaps) do
    triggered_count =
      Enum.reduce(recaps, 0, fn recap, count ->
        case trigger_loop_for_recap(recap) do
          {:ok, _share_pack} ->
            count + 1

          {:error, reason} ->
            Logger.warning("Failed to trigger loop for recap #{recap.id}: #{inspect(reason)}")
            count
        end
      end)

    {:ok, triggered_count}
  end

  defp trigger_loop_for_recap(recap) do
    case ProudParent.generate(recap.parent_id, recap.week_start) do
      {:ok, share_pack} ->
        # Trigger event to notify Orchestrator
        Phoenix.PubSub.broadcast(
          ViralEngine.PubSub,
          "viral_loops",
          {:proud_parent_ready, recap, share_pack}
        )

        # Send notification to parent
        send_recap_notification(recap, share_pack)

        {:ok, share_pack}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_recap_notification(recap, share_pack) do
    # In production, this would send email/push notification
    Logger.info("""
    Sending recap notification to parent #{recap.parent_id}
    Subject: Your Child's Weekly Learning Progress
    Recap ID: #{recap.id}
    Share pack available with links: #{inspect(Map.keys(share_pack.links))}
    """)

    # Stub: would integrate with email service
    :ok
  end
end
