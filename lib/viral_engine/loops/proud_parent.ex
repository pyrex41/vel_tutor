defmodule ViralEngine.Loops.ProudParent do
  @moduledoc """
  ProudParent viral loop for weekly progress sharing between parents.

  This loop enables parents to share their child's weekly learning progress
  with other parents, creating a viral referral mechanism.

  Flow:
  1. Generate weekly recap for parent
  2. Create shareable progress reel
  3. Parent shares with other parents
  4. Referred parents join and get rewards
  5. Original parent gets rewards for successful referrals
  """

  require Logger
  alias ViralEngine.{Repo, WeeklyRecap, Accounts.User}
  alias ViralEngine.Integration.{AttributionClient, AnalyticsClient}
  import Ecto.Query

  @doc """
  Generate a ProudParent loop instance from a weekly recap.

  Returns a share pack with personalized content and attribution links.
  """
  def generate(parent_id, week_start) do
    with {:ok, parent} <- fetch_parent(parent_id),
         {:ok, recap} <- generate_or_fetch_recap(parent, week_start),
         {:ok, progress_reel} <- create_progress_reel(recap),
         {:ok, share_pack} <- create_share_pack(parent, recap, progress_reel) do
      Logger.info("Generated ProudParent loop for parent #{parent_id}")
      {:ok, share_pack}
    else
      {:error, reason} = error ->
        Logger.error("Failed to generate ProudParent loop: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Handle a new parent joining via ProudParent referral link.
  """
  def handle_join(link_id, new_parent_attrs) do
    with {:ok, link} <- fetch_attribution_link(link_id),
         {:ok, new_parent} <- create_or_find_parent(new_parent_attrs),
         :ok <- track_join_event(link, new_parent),
         {:ok, welcome_pack} <- create_welcome_pack(new_parent, link) do
      Logger.info("Parent #{new_parent.id} joined via ProudParent link #{link_id}")
      {:ok, %{parent: new_parent, welcome_pack: welcome_pack}}
    else
      {:error, reason} = error ->
        Logger.error("Failed to handle ProudParent join: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Complete signup and grant rewards when referred parent completes onboarding.
  """
  def complete_signup(new_parent_id, link_id, completion_data) do
    with {:ok, link} <- fetch_attribution_link(link_id),
         {:ok, new_parent} <- fetch_parent(new_parent_id),
         :ok <- validate_completion(completion_data),
         :ok <- grant_referrer_reward(link.creator_id, new_parent),
         :ok <- grant_referee_reward(new_parent),
         :ok <- track_completion_event(link, new_parent, completion_data) do
      Logger.info("ProudParent signup completed: #{new_parent_id} via #{link_id}")
      {:ok, :signup_completed}
    else
      {:error, reason} = error ->
        Logger.error("Failed to complete ProudParent signup: #{inspect(reason)}")
        error
    end
  end

  # Private Functions

  defp fetch_parent(parent_id) do
    case Repo.get(User, parent_id) do
      nil -> {:error, :parent_not_found}
      parent -> {:ok, parent}
    end
  end

  defp generate_or_fetch_recap(parent, week_start) do
    week_end = Date.add(week_start, 6)

    # Try to fetch existing recap
    query =
      from r in WeeklyRecap,
        where: r.parent_id == ^parent.id,
        where: r.week_start == ^week_start,
        where: r.week_end == ^week_end

    case Repo.one(query) do
      nil ->
        generate_weekly_recap(parent, week_start, week_end)

      existing_recap ->
        {:ok, existing_recap}
    end
  end

  defp generate_weekly_recap(parent, week_start, week_end) do
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
      # Aggregate session data for all students
      student_ids = Enum.map(students, & &1.id)

      sessions =
        from(s in ViralEngine.TutoringSession,
          where: s.student_id in ^student_ids,
          where: s.started_at >= ^week_start,
          where: s.started_at < ^Date.add(week_end, 1),
          where: not is_nil(s.ended_at)
        )
        |> Repo.all()

      recap_data = calculate_recap_metrics(sessions)

      recap_attrs = %{
        parent_id: parent.id,
        student_id: hd(student_ids),
        week_start: week_start,
        week_end: week_end,
        session_count: recap_data.session_count,
        total_minutes: recap_data.total_minutes,
        skills_practiced: recap_data.skills,
        improvements: recap_data.improvements,
        highlights: generate_highlights(recap_data)
      }

      case Repo.insert(WeeklyRecap.changeset(%WeeklyRecap{}, recap_attrs)) do
        {:ok, recap} -> {:ok, recap}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  defp calculate_recap_metrics(sessions) do
    session_count = length(sessions)
    total_minutes = Enum.reduce(sessions, 0, fn s, acc -> acc + (s.duration_minutes || 0) end)

    skills =
      sessions
      |> Enum.flat_map(fn s -> [s.subject, s.topic] end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()

    # Calculate improvements from session ratings
    avg_rating =
      sessions
      |> Enum.map(& &1.rating)
      |> Enum.filter(&(&1 != nil))
      |> case do
        [] -> 0
        ratings -> Enum.sum(ratings) / length(ratings)
      end

    improvements = %{
      total_sessions: session_count,
      total_time: total_minutes,
      average_rating: Float.round(avg_rating, 1),
      skills_count: length(skills)
    }

    %{
      session_count: session_count,
      total_minutes: total_minutes,
      skills: skills,
      improvements: improvements
    }
  end

  defp generate_highlights(recap_data) do
    """
    🎯 #{recap_data.session_count} tutoring sessions completed
    ⏱️  #{recap_data.total_minutes} minutes of focused learning
    📚 #{length(recap_data.skills)} different topics mastered
    ⭐ #{recap_data.improvements.average_rating}/5.0 average session rating

    Your child is making excellent progress! Keep up the great work! 🚀
    """
  end

  defp create_progress_reel(recap) do
    # Generate a shareable "progress reel" (summary visualization)
    reel = %{
      type: "weekly_progress",
      parent_id: recap.parent_id,
      student_id: recap.student_id,
      week: "#{recap.week_start} to #{recap.week_end}",
      metrics: %{
        sessions: recap.session_count,
        minutes: recap.total_minutes,
        skills: length(recap.skills_practiced),
        rating: recap.improvements["average_rating"]
      },
      highlights: recap.highlights,
      visual_url: generate_reel_visual_url(recap),
      created_at: DateTime.utc_now()
    }

    {:ok, reel}
  end

  defp generate_reel_visual_url(recap) do
    # In production, this would generate an actual visual/image
    # For now, return a placeholder URL
    "/api/progress-reels/#{recap.id}/visual"
  end

  defp create_share_pack(parent, recap, progress_reel) do
    # Create attribution links for different sharing channels
    {:ok, email_link} = create_attribution_link(parent, "email", recap)
    {:ok, whatsapp_link} = create_attribution_link(parent, "whatsapp", recap)
    {:ok, sms_link} = create_attribution_link(parent, "sms", recap)

    share_pack = %{
      recap_id: recap.id,
      progress_reel: progress_reel,
      share_message: build_share_message(parent, recap),
      email_template: build_email_template(parent, recap, email_link),
      links: %{
        email: email_link,
        whatsapp: whatsapp_link,
        sms: sms_link
      },
      reward_info: %{
        referrer_reward: "1 month free tutoring",
        referee_reward: "2 free sessions"
      }
    }

    # Update recap to mark it as ready for sharing
    Repo.update(WeeklyRecap.changeset(recap, %{progress_reel_url: progress_reel.visual_url}))

    {:ok, share_pack}
  end

  defp create_attribution_link(parent, channel, recap) do
    link_data = %{
      creator_id: parent.id,
      loop_type: "proud_parent",
      channel: channel,
      source_id: recap.id,
      metadata: %{
        week_start: recap.week_start,
        student_count: 1
      }
    }

    # Use Attribution service to create link
    case AttributionClient.create_link(link_data) do
      {:ok, link} -> {:ok, link}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_share_message(parent, recap) do
    """
    🌟 Amazing progress this week!

    My child just completed #{recap.session_count} tutoring sessions and learned #{length(recap.skills_practiced)} new skills!

    #{String.trim(recap.highlights)}

    Want to see similar results? Try Vel Tutor - you'll get 2 free sessions, and I'll get a month free! Win-win! 🎉

    [Share Link]
    """
  end

  defp build_email_template(parent, recap, link) do
    %{
      subject: "Check out my child's amazing learning progress! 🌟",
      body: """
      Hi there!

      I wanted to share some exciting news - my child has been using Vel Tutor and the results have been incredible!

      This Week's Progress:
      #{recap.highlights}

      I thought you might be interested in trying it out for your child too. If you sign up through my link, you'll get 2 FREE tutoring sessions to start, and I'll get a month free!

      #{link.url}

      It's been such a game-changer for us. Let me know if you have any questions!

      Best,
      #{parent.name}
      """,
      link: link.url,
      cta: "Get 2 Free Sessions"
    }
  end

  defp fetch_attribution_link(link_id) do
    case AttributionClient.get_link(link_id) do
      {:ok, link} -> {:ok, link}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_or_find_parent(attrs) do
    # Check if parent already exists by email
    case Repo.get_by(User, email: attrs.email) do
      nil ->
        # Create new parent
        changeset = User.changeset(%User{}, Map.put(attrs, :persona, "parent"))

        case Repo.insert(changeset) do
          {:ok, parent} -> {:ok, parent}
          {:error, changeset} -> {:error, changeset}
        end

      existing_parent ->
        {:ok, existing_parent}
    end
  end

  defp track_join_event(link, new_parent) do
    AnalyticsClient.track_event(%{
      event_type: "proud_parent_join",
      user_id: new_parent.id,
      link_id: link.id,
      referrer_id: link.creator_id,
      timestamp: DateTime.utc_now()
    })

    :ok
  end

  defp create_welcome_pack(new_parent, link) do
    welcome_pack = %{
      parent: new_parent,
      reward: "2 free tutoring sessions",
      referrer_info: %{
        id: link.creator_id,
        message: "Welcome! You were referred by a happy parent."
      },
      next_steps: [
        "Complete your profile",
        "Add your child's information",
        "Schedule first free session"
      ]
    }

    {:ok, welcome_pack}
  end

  defp validate_completion(completion_data) do
    required_fields = [:profile_completed, :child_added, :first_session_booked]

    if Enum.all?(required_fields, &Map.get(completion_data, &1)) do
      :ok
    else
      {:error, :incomplete_signup}
    end
  end

  defp grant_referrer_reward(referrer_id, referee) do
    # Grant reward to the parent who made the referral
    reward_data = %{
      user_id: referrer_id,
      reward_type: "proud_parent_referral",
      amount: 1,
      unit: "month",
      description: "1 month free tutoring for successful referral",
      metadata: %{
        referee_id: referee.id,
        referee_email: referee.email
      }
    }

    # Use MCP or rewards service to grant reward
    Logger.info("Granting referrer reward to user #{referrer_id}")
    # Stub: In production, call MCP service
    :ok
  end

  defp grant_referee_reward(new_parent) do
    # Grant reward to the new parent who signed up
    reward_data = %{
      user_id: new_parent.id,
      reward_type: "proud_parent_signup",
      amount: 2,
      unit: "sessions",
      description: "2 free tutoring sessions for signing up",
      metadata: %{
        signup_date: DateTime.utc_now()
      }
    }

    Logger.info("Granting referee reward to user #{new_parent.id}")
    # Stub: In production, call MCP service
    :ok
  end

  defp track_completion_event(link, new_parent, completion_data) do
    AnalyticsClient.track_event(%{
      event_type: "proud_parent_signup_complete",
      user_id: new_parent.id,
      link_id: link.id,
      referrer_id: link.creator_id,
      completion_data: completion_data,
      timestamp: DateTime.utc_now()
    })

    :ok
  end
end
