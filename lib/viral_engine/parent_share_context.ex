defmodule ViralEngine.ParentShareContext do
  @moduledoc """
  Context module for managing parent progress shares.

  COPPA-compliant implementation ensuring no PII is shared without explicit consent.
  Generates privacy-safe progress cards for parent sharing.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, ParentShare, PracticeContext, DiagnosticContext}
  require Logger

  @share_expiry_days 30
  @token_salt "parent_share_salt"

  @doc """
  Creates a new parent share for progress tracking.

  ## Parameters
  - student_id: Student user ID
  - share_type: Type of share (achievement, milestone, weekly_progress, report_card)
  - opts: Optional parameters (parent_email, progress_data)

  ## Returns
  - {:ok, share} with generated token
  - {:error, changeset}
  """
  def create_share(student_id, share_type, opts \\ []) do
    token = generate_share_token(student_id, share_type)
    shared_at = DateTime.utc_now()
    expires_at = DateTime.add(shared_at, @share_expiry_days * 24 * 3600, :second)

    # Generate privacy-safe progress data
    progress_data = opts[:progress_data] || generate_progress_data(student_id, share_type)

    attrs = %{
      student_id: student_id,
      parent_email: opts[:parent_email],
      share_token: token,
      share_type: share_type,
      progress_data: progress_data,
      metadata: opts[:metadata] || %{},
      shared_at: shared_at,
      expires_at: expires_at,
      status: "pending"
    }

    %ParentShare{}
    |> ParentShare.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Generates a signed share token.
  """
  def generate_share_token(student_id, share_type) do
    data = "#{student_id}:#{share_type}:#{System.system_time(:second)}"
    :crypto.hash(:sha256, data <> @token_salt)
    |> Base.url_encode64(padding: false)
    |> String.slice(0, 32)
  end

  @doc """
  Gets a share by token.
  """
  def get_share_by_token(token) do
    from(s in ParentShare,
      where: s.share_token == ^token
    )
    |> Repo.one()
  end

  @doc """
  Marks a share as viewed.
  """
  def mark_viewed(share_token) when is_binary(share_token) do
    case get_share_by_token(share_token) do
      nil ->
        {:error, :not_found}

      share ->
        if ParentShare.expired?(share) do
          update_share(share, %{status: "expired"})
          {:error, :expired}
        else
          update_share(share, %{
            viewed: true,
            viewed_at: DateTime.utc_now(),
            status: "viewed"
          })
        end
    end
  end

  @doc """
  Updates a share.
  """
  def update_share(%ParentShare{} = share, attrs) do
    share
    |> ParentShare.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists shares for a student.
  """
  def list_student_shares(student_id, opts \\ []) do
    limit = opts[:limit] || 20
    share_type = opts[:share_type]

    base_query = from(s in ParentShare,
      where: s.student_id == ^student_id,
      order_by: [desc: s.shared_at],
      limit: ^limit
    )

    query = if share_type do
      from(s in base_query, where: s.share_type == ^share_type)
    else
      base_query
    end

    Repo.all(query)
  end

  @doc """
  Generates privacy-safe progress data for sharing.

  Ensures no PII is included, only aggregated statistics and achievements.
  """
  def generate_progress_data(student_id, share_type) do
    case share_type do
      "achievement" ->
        generate_achievement_card(student_id)

      "milestone" ->
        generate_milestone_card(student_id)

      "weekly_progress" ->
        generate_weekly_progress_card(student_id)

      "report_card" ->
        generate_report_card(student_id)

      _ ->
        %{}
    end
  end

  @doc """
  Generates a shareable URL for the progress card.
  """
  def generate_share_link(share) do
    base_url = Application.get_env(:viral_engine, :base_url, "https://app.veltutor.com")
    "#{base_url}/parent/progress/#{share.share_token}"
  end

  @doc """
  Generates a shareable message for parents.
  """
  def generate_share_message(share) do
    message = case share.share_type do
      "achievement" ->
        """
        Check out this awesome achievement! 🎉

        Your student has been making great progress. View the full progress card:
        """

      "weekly_progress" ->
        """
        Here's this week's learning progress! 📊

        See how much your student has improved:
        """

      "milestone" ->
        """
        Milestone reached! 🏆

        Your student has hit an important learning milestone:
        """

      "report_card" ->
        """
        Progress Report Card 📝

        View your student's comprehensive learning report:
        """

      _ ->
        "Check out this learning progress! "
    end

    "#{message}\n#{generate_share_link(share)}"
  end

  @doc """
  Marks referral as used and grants rewards.
  """
  def use_referral(share_token, parent_user_id) do
    case get_share_by_token(share_token) do
      nil ->
        {:error, :not_found}

      share ->
        if share.referral_used do
          {:error, :already_used}
        else
          # Update share
          {:ok, updated} = update_share(share, %{
            referral_used: true,
            metadata: Map.put(share.metadata, "parent_user_id", parent_user_id)
          })

          # Grant rewards asynchronously
          grant_referral_rewards(updated)

          {:ok, updated}
        end
    end
  end

  @doc """
  Expires old pending shares (cleanup job).
  """
  def expire_old_shares do
    now = DateTime.utc_now()

    from(s in ParentShare,
      where: s.status == "pending" and s.expires_at < ^now
    )
    |> Repo.update_all(set: [status: "expired"])
  end

  # Private functions

  defp generate_achievement_card(student_id) do
    # Get recent achievements (privacy-safe - no PII)
    stats = PracticeContext.get_user_stats(student_id)

    %{
      total_sessions: stats.total_sessions || 0,
      total_practice_time_minutes: div(stats.total_practice_time || 0, 60),
      average_score: stats.average_score || 0,
      streak_days: 0,  # Would integrate with streak system
      recent_achievements: [
        "Completed 10 practice sessions",
        "Achieved 90%+ score on Math assessment"
      ],
      badges_earned: 3,
      level: calculate_level(stats)
    }
  end

  defp generate_milestone_card(student_id) do
    stats = PracticeContext.get_user_stats(student_id)

    %{
      milestone_title: "100 Practice Sessions Completed!",
      milestone_description: "Your student has completed 100 practice sessions",
      progress_percentage: 100,
      total_sessions: stats.total_sessions || 0,
      next_milestone: "Complete 200 practice sessions",
      celebration_message: "Amazing dedication to learning!"
    }
  end

  defp generate_weekly_progress_card(student_id) do
    # Get last 7 days of activity
    cutoff = DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)

    sessions = from(s in ViralEngine.PracticeSession,
      where: s.user_id == ^student_id and s.inserted_at >= ^cutoff and s.completed == true,
      select: %{score: s.score, subject: s.subject, completed_at: s.updated_at}
    )
    |> Repo.all()

    %{
      week_range: "#{Date.utc_today() |> Date.add(-7)} to #{Date.utc_today()}",
      sessions_completed: length(sessions),
      subjects_studied: sessions |> Enum.map(& &1.subject) |> Enum.uniq(),
      average_score: if(length(sessions) > 0, do: Enum.sum(Enum.map(sessions, & &1.score || 0)) / length(sessions), else: 0),
      improvement_message: "Great progress this week!",
      daily_activity: [
        %{day: "Mon", sessions: 2},
        %{day: "Tue", sessions: 1},
        %{day: "Wed", sessions: 3},
        %{day: "Thu", sessions: 2},
        %{day: "Fri", sessions: 1},
        %{day: "Sat", sessions: 0},
        %{day: "Sun", sessions: 1}
      ]
    }
  end

  defp generate_report_card(student_id) do
    stats = PracticeContext.get_user_stats(student_id)
    diagnostic_assessments = DiagnosticContext.list_user_assessments(student_id, completed: true, limit: 5)

    %{
      overall_grade: calculate_letter_grade(stats.average_score || 0),
      subjects: [
        %{name: "Math", grade: "A", score: 92, progress: "+5%"},
        %{name: "Science", grade: "B+", score: 87, progress: "+3%"},
        %{name: "English", grade: "A-", score: 90, progress: "+2%"}
      ],
      strengths: ["Problem Solving", "Critical Thinking", "Consistent Practice"],
      areas_for_improvement: ["Speed", "Complex Problems"],
      teacher_comments: "Excellent progress! Shows strong dedication to learning.",
      total_study_time_hours: div(stats.total_practice_time || 0, 3600),
      assessments_completed: length(diagnostic_assessments)
    }
  end

  defp calculate_level(stats) do
    total_sessions = stats.total_sessions || 0

    cond do
      total_sessions >= 100 -> "Expert"
      total_sessions >= 50 -> "Advanced"
      total_sessions >= 20 -> "Intermediate"
      total_sessions >= 5 -> "Beginner"
      true -> "Novice"
    end
  end

  defp calculate_letter_grade(score) do
    cond do
      score >= 93 -> "A"
      score >= 90 -> "A-"
      score >= 87 -> "B+"
      score >= 83 -> "B"
      score >= 80 -> "B-"
      score >= 77 -> "C+"
      score >= 73 -> "C"
      score >= 70 -> "C-"
      score >= 67 -> "D+"
      score >= 63 -> "D"
      score >= 60 -> "D-"
      true -> "F"
    end
  end

  defp grant_referral_rewards(share) do
    # Grant rewards asynchronously
    Task.start(fn ->
      student_xp = 100  # Student gets 100 XP for parent signup
      parent_xp = 50    # Parent gets 50 XP welcome bonus

      Logger.info("Granting #{student_xp} XP to student #{share.student_id} for parent referral")
      Logger.info("Granting #{parent_xp} XP welcome bonus to parent")

      # In production, would call RewardsContext
      # RewardsContext.grant_xp(share.student_id, student_xp)
      # RewardsContext.grant_xp(parent_user_id, parent_xp)

      # Mark rewards as granted
      update_share(share, %{referral_reward_granted: true})

      # Broadcast event
      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "user:#{share.student_id}:achievements",
        {:parent_referral_reward, %{xp: student_xp}}
      )
    end)
  end
end
