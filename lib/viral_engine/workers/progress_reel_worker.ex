defmodule ViralEngine.Workers.ProgressReelWorker do
  @moduledoc """
  Oban worker that automatically generates parent progress reels
  when students achieve high ratings or milestones.

  Agentic Action: Detects achievement moments and creates shareable
  visual summaries for proud parent sharing.
  """

  use Oban.Worker,
    queue: :reels,
    max_attempts: 3

  alias ViralEngine.{Repo, ProgressReel, PracticeContext, StreakContext, XPContext, ViralPrompts}
  require Logger

  @high_score_threshold 90  # Trigger reel for 90+ scores
  @milestone_sessions [10, 25, 50, 100]  # Session count milestones
  @streak_milestones [7, 14, 30]  # Streak day milestones

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"trigger_type" => "high_score", "assessment_id" => assessment_id, "student_id" => student_id}}) do
    Logger.info("Generating high score reel for student #{student_id}, assessment #{assessment_id}")

    case generate_high_score_reel(student_id, assessment_id) do
      {:ok, reel} ->
        Logger.info("Successfully generated high score reel: #{reel.reel_token}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to generate high score reel: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: %{"trigger_type" => "milestone", "student_id" => student_id, "milestone_type" => milestone_type}}) do
    Logger.info("Generating milestone reel for student #{student_id}: #{milestone_type}")

    case generate_milestone_reel(student_id, milestone_type) do
      {:ok, reel} ->
        Logger.info("Successfully generated milestone reel: #{reel.reel_token}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to generate milestone reel: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: %{"trigger_type" => "streak", "student_id" => student_id, "streak_days" => streak_days}}) do
    Logger.info("Generating streak reel for student #{student_id}: #{streak_days} days")

    case generate_streak_reel(student_id, streak_days) do
      {:ok, reel} ->
        Logger.info("Successfully generated streak reel: #{reel.reel_token}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to generate streak reel: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Enqueues a high score reel generation job.
  """
  def enqueue_high_score_reel(student_id, assessment_id, score) do
    if score >= @high_score_threshold do
      %{
        trigger_type: "high_score",
        student_id: student_id,
        assessment_id: assessment_id,
        score: score
      }
      |> __MODULE__.new()
      |> Oban.insert()
    else
      {:skip, :below_threshold}
    end
  end

  @doc """
  Checks and enqueues milestone reels for session counts.
  """
  def check_and_enqueue_milestone_reel(student_id) do
    stats = PracticeContext.get_user_stats(student_id)
    session_count = stats.total_sessions || 0

    if session_count in @milestone_sessions do
      %{
        trigger_type: "milestone",
        student_id: student_id,
        milestone_type: "sessions_#{session_count}"
      }
      |> __MODULE__.new()
      |> Oban.insert()
    else
      {:skip, :not_milestone}
    end
  end

  @doc """
  Checks and enqueues streak reels.
  """
  def check_and_enqueue_streak_reel(student_id) do
    case StreakContext.get_user_streak(student_id) do
      {:ok, streak} ->
        streak_days = streak.current_streak || 0

        if streak_days in @streak_milestones do
          %{
            trigger_type: "streak",
            student_id: student_id,
            streak_days: streak_days
          }
          |> __MODULE__.new()
          |> Oban.insert()
        else
          {:skip, :not_milestone}
        end

      _ ->
        {:skip, :no_streak}
    end
  end

  # Private generation functions

  defp generate_high_score_reel(student_id, assessment_id) do
    # Get assessment details
    # In production: assessment = DiagnosticContext.get_assessment(assessment_id)

    # Simulated assessment data
    assessment = %{
      id: assessment_id,
      score: 95,
      subject: "Math",
      grade_level: 8,
      completed_at: DateTime.utc_now()
    }

    # Get student stats for context
    stats = PracticeContext.get_user_stats(student_id)
    {:ok, xp_data} = XPContext.get_user_xp(student_id)

    reel_data = %{
      score: assessment.score,
      subject: assessment.subject,
      grade_level: assessment.grade_level,
      total_sessions: stats.total_sessions || 0,
      average_score: stats.average_score || 0,
      level: xp_data.level,
      percentile: calculate_percentile(assessment.score, assessment.subject)
    }

    reel_attrs = %{
      student_id: student_id,
      reel_type: "high_score",
      reel_token: ProgressReel.generate_token(student_id, "high_score"),
      title: "🌟 #{assessment.score}% on #{assessment.subject}!",
      subtitle: "Top #{calculate_percentile(assessment.score, assessment.subject)}% of students",
      trigger_event: %{
        type: "assessment_completed",
        assessment_id: assessment_id,
        score: assessment.score,
        subject: assessment.subject
      },
      reel_data: reel_data,
      expires_at: DateTime.add(DateTime.utc_now(), 30 * 24 * 60 * 60, :second)  # 30 days
    }

    case Repo.insert(ProgressReel.changeset(%ProgressReel{}, reel_attrs)) do
      {:ok, reel} ->
        # In production, trigger reel generation (image/video)
        # For now, mark as completed immediately
        media_url = generate_reel_media(reel)
        {:ok, completed_reel} = Repo.update(ProgressReel.mark_completed(reel, media_url))

        # Trigger viral prompt to share with parents
        trigger_parent_reel_prompt(student_id, completed_reel)

        {:ok, completed_reel}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp generate_milestone_reel(student_id, milestone_type) do
    stats = PracticeContext.get_user_stats(student_id)
    {:ok, xp_data} = XPContext.get_user_xp(student_id)

    session_count = stats.total_sessions || 0

    reel_data = %{
      sessions_completed: session_count,
      subjects_practiced: ["Math", "Science", "English"],  # Would query actual data
      total_xp: xp_data.total_xp,
      level: xp_data.level,
      badges_earned: 5  # Would query badge count
    }

    reel_attrs = %{
      student_id: student_id,
      reel_type: "milestone",
      reel_token: ProgressReel.generate_token(student_id, "milestone"),
      title: "🎉 #{session_count} Practice Sessions!",
      subtitle: "Dedicated learner milestone achieved",
      trigger_event: %{
        type: "milestone_reached",
        milestone: milestone_type,
        session_count: session_count
      },
      reel_data: reel_data,
      expires_at: DateTime.add(DateTime.utc_now(), 30 * 24 * 60 * 60, :second)
    }

    case Repo.insert(ProgressReel.changeset(%ProgressReel{}, reel_attrs)) do
      {:ok, reel} ->
        media_url = generate_reel_media(reel)
        {:ok, completed_reel} = Repo.update(ProgressReel.mark_completed(reel, media_url))
        trigger_parent_reel_prompt(student_id, completed_reel)
        {:ok, completed_reel}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp generate_streak_reel(student_id, streak_days) do
    stats = PracticeContext.get_user_stats(student_id)

    reel_data = %{
      streak_days: streak_days,
      total_sessions: stats.total_sessions || 0,
      consistency: "#{round((streak_days / 30) * 100)}%"
    }

    reel_attrs = %{
      student_id: student_id,
      reel_type: "streak",
      reel_token: ProgressReel.generate_token(student_id, "streak"),
      title: "🔥 #{streak_days}-Day Streak!",
      subtitle: "Unstoppable dedication",
      trigger_event: %{
        type: "streak_milestone",
        streak_days: streak_days
      },
      reel_data: reel_data,
      expires_at: DateTime.add(DateTime.utc_now(), 30 * 24 * 60 * 60, :second)
    }

    case Repo.insert(ProgressReel.changeset(%ProgressReel{}, reel_attrs)) do
      {:ok, reel} ->
        media_url = generate_reel_media(reel)
        {:ok, completed_reel} = Repo.update(ProgressReel.mark_completed(reel, media_url))
        trigger_parent_reel_prompt(student_id, completed_reel)
        {:ok, completed_reel}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp generate_reel_media(reel) do
    # In production, this would:
    # 1. Generate image with stats and achievements
    # 2. Create animated GIF or short video
    # 3. Upload to S3/CDN
    # 4. Return public URL

    # For now, return placeholder
    "/reels/#{reel.reel_token}.png"
  end

  defp calculate_percentile(_score, _subject) do
    # In production, query actual percentile
    # For now, simulate
    95
  end

  defp trigger_parent_reel_prompt(student_id, reel) do
    event_data = %{
      reel_id: reel.id,
      reel_token: reel.reel_token,
      reel_type: reel.reel_type,
      title: reel.title,
      subtitle: reel.subtitle
    }

    case ViralPrompts.trigger_prompt(:parent_reel_ready, student_id, event_data) do
      {:ok, prompt} ->
        Logger.info("Triggered parent reel prompt for student #{student_id}")
        ViralPrompts.broadcast_event(:parent_reel_ready, student_id, event_data)

      {:throttled, reason} ->
        Logger.debug("Parent reel prompt throttled for student #{student_id}: #{reason}")

      {:no_prompt, reason} ->
        Logger.debug("No parent reel prompt for student #{student_id}: #{reason}")
    end
  end
end
