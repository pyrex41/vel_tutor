defmodule ViralEngine.Loops.TutorSpotlight do
  @moduledoc """
  TutorSpotlight viral loop for tutors sharing referral packs after 5-star sessions.

  This loop enables tutors to share their profile and success stories after
  highly-rated sessions, creating a viral referral mechanism.

  Flow:
  1. Trigger after 5-star session
  2. Generate tutor card with profile and feedback
  3. Tutor shares with prospective students
  4. Referred students book session
  5. Tutor gets rewards for successful bookings
  """

  require Logger
  alias ViralEngine.{Repo, TutoringSession, Accounts.User}
  alias ViralEngine.Integration.{AttributionClient, AnalyticsClient}
  import Ecto.Query

  @doc """
  Generate a TutorSpotlight loop instance after a 5-star session.

  Returns a share pack with tutor card and referral links.
  """
  def generate(session_id, tutor_id) do
    with {:ok, session} <- fetch_session(session_id),
         {:ok, tutor} <- fetch_tutor(tutor_id),
         :ok <- validate_session_rating(session),
         {:ok, tutor_card} <- create_tutor_card(tutor, session),
         {:ok, share_pack} <- create_share_pack(tutor, tutor_card, session) do
      Logger.info("Generated TutorSpotlight loop for tutor #{tutor_id}, session #{session_id}")
      {:ok, share_pack}
    else
      {:error, reason} = error ->
        Logger.error("Failed to generate TutorSpotlight loop: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Handle a new student joining via TutorSpotlight referral link.
  """
  def handle_join(link_id, student_attrs) do
    with {:ok, link} <- fetch_attribution_link(link_id),
         {:ok, tutor} <- fetch_tutor(link.creator_id),
         {:ok, student} <- create_or_find_student(student_attrs),
         :ok <- track_join_event(link, student, tutor),
         {:ok, booking_info} <- create_booking_info(student, tutor, link) do
      Logger.info("Student #{student.id} joined via TutorSpotlight link #{link_id}")
      {:ok, %{student: student, tutor: tutor, booking_info: booking_info}}
    else
      {:error, reason} = error ->
        Logger.error("Failed to handle TutorSpotlight join: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Complete booking and grant rewards when referred student books and completes session.
  """
  def complete_booking(student_id, tutor_id, booking_data) do
    with {:ok, student} <- fetch_student(student_id),
         {:ok, tutor} <- fetch_tutor(tutor_id),
         {:ok, link} <- find_referral_link(student_id, tutor_id),
         :ok <- validate_booking(booking_data),
         :ok <- grant_tutor_reward(tutor, student),
         :ok <- grant_student_reward(student),
         :ok <- track_completion_event(link, student, tutor, booking_data) do
      Logger.info("TutorSpotlight booking completed: student #{student_id}, tutor #{tutor_id}")
      {:ok, :booking_completed}
    else
      {:error, reason} = error ->
        Logger.error("Failed to complete TutorSpotlight booking: #{inspect(reason)}")
        error
    end
  end

  # Private Functions

  defp fetch_session(session_id) do
    case Repo.get(TutoringSession, session_id) do
      nil -> {:error, :session_not_found}
      session -> {:ok, session}
    end
  end

  defp fetch_tutor(tutor_id) do
    case Repo.get(User, tutor_id) do
      nil -> {:error, :tutor_not_found}
      tutor -> {:ok, tutor}
    end
  end

  defp fetch_student(student_id) do
    case Repo.get(User, student_id) do
      nil -> {:error, :student_not_found}
      student -> {:ok, student}
    end
  end

  defp validate_session_rating(session) do
    if session.rating && session.rating >= 5 do
      :ok
    else
      {:error, :insufficient_rating}
    end
  end

  defp create_tutor_card(tutor, session) do
    # Fetch tutor's recent ratings and feedback
    {:ok, tutor_stats} = fetch_tutor_stats(tutor.id)
    {:ok, recent_feedback} = fetch_recent_feedback(tutor.id, 5)

    tutor_card = %{
      tutor_id: tutor.id,
      name: tutor.name,
      email: redact_email(tutor.email),
      subjects: tutor_stats.subjects,
      stats: %{
        total_sessions: tutor_stats.total_sessions,
        average_rating: Float.round(tutor_stats.avg_rating, 1),
        five_star_sessions: tutor_stats.five_star_count,
        completion_rate: Float.round(tutor_stats.completion_rate, 1)
      },
      recent_feedback: recent_feedback,
      featured_session: %{
        subject: session.subject,
        topic: session.topic,
        duration: session.duration_minutes,
        rating: session.rating,
        feedback: session.feedback || "Excellent session!"
      },
      created_at: DateTime.utc_now()
    }

    {:ok, tutor_card}
  end

  defp fetch_tutor_stats(tutor_id) do
    sessions =
      from(s in TutoringSession,
        where: s.tutor_id == ^tutor_id,
        where: not is_nil(s.ended_at)
      )
      |> Repo.all()

    total_sessions = length(sessions)

    avg_rating =
      sessions
      |> Enum.map(& &1.rating)
      |> Enum.filter(&(&1 != nil))
      |> case do
        [] -> 0.0
        ratings -> Enum.sum(ratings) / length(ratings)
      end

    five_star_count = Enum.count(sessions, fn s -> s.rating == 5 end)

    subjects =
      sessions
      |> Enum.map(& &1.subject)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()

    completion_rate =
      if total_sessions > 0 do
        completed = Enum.count(sessions, fn s -> s.ended_at != nil end)
        completed / total_sessions * 100
      else
        0.0
      end

    stats = %{
      total_sessions: total_sessions,
      avg_rating: avg_rating,
      five_star_count: five_star_count,
      subjects: subjects,
      completion_rate: completion_rate
    }

    {:ok, stats}
  end

  defp fetch_recent_feedback(tutor_id, limit) do
    feedback =
      from(s in TutoringSession,
        where: s.tutor_id == ^tutor_id,
        where: not is_nil(s.feedback),
        where: s.rating >= 4,
        order_by: [desc: s.ended_at],
        limit: ^limit,
        select: %{
          feedback: s.feedback,
          rating: s.rating,
          subject: s.subject,
          date: s.ended_at
        }
      )
      |> Repo.all()

    {:ok, feedback}
  end

  defp redact_email(email) do
    # Redact email for privacy (show first letter and domain)
    case String.split(email, "@") do
      [username, domain] ->
        first = String.first(username)
        "#{first}***@#{domain}"

      _ ->
        "***"
    end
  end

  defp create_share_pack(tutor, tutor_card, session) do
    # Create attribution links for different sharing channels
    {:ok, whatsapp_link} = create_attribution_link(tutor, "whatsapp", session)
    {:ok, sms_link} = create_attribution_link(tutor, "sms", session)
    {:ok, email_link} = create_attribution_link(tutor, "email", session)
    {:ok, social_link} = create_attribution_link(tutor, "social", session)

    share_pack = %{
      tutor_card: tutor_card,
      share_message: build_share_message(tutor, tutor_card, session),
      whatsapp_message: build_whatsapp_message(tutor_card, whatsapp_link),
      sms_message: build_sms_message(tutor_card, sms_link),
      email_template: build_email_template(tutor_card, email_link),
      links: %{
        whatsapp: whatsapp_link,
        sms: sms_link,
        email: email_link,
        social: social_link
      },
      reward_info: %{
        tutor_reward: "$50 per completed referral",
        student_reward: "First session 50% off"
      }
    }

    {:ok, share_pack}
  end

  defp create_attribution_link(tutor, channel, session) do
    link_data = %{
      creator_id: tutor.id,
      loop_type: "tutor_spotlight",
      channel: channel,
      source_id: session.id,
      metadata: %{
        session_rating: session.rating,
        subject: session.subject
      }
    }

    case AttributionClient.create_link(link_data) do
      {:ok, link} -> {:ok, link}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_share_message(tutor, tutor_card, session) do
    """
    🌟 Just wrapped up an amazing #{session.subject} session!

    #{tutor_card.stats.average_rating}⭐ average rating | #{tutor_card.stats.total_sessions}+ successful sessions

    Recent Student Feedback:
    "#{get_top_feedback(tutor_card)}"

    Looking for a tutor? Let's work together! First session is 50% off through my referral link.

    [Share Link]

    #Tutoring ##{session.subject} #Learning
    """
  end

  defp get_top_feedback(tutor_card) do
    case tutor_card.recent_feedback do
      [] -> "Great tutor!"
      [first | _] -> first.feedback
    end
  end

  defp build_whatsapp_message(tutor_card, link) do
    """
    Hey! 👋

    I'm #{tutor_card.name}, a tutor specializing in #{Enum.join(tutor_card.subjects, ", ")}.

    My students love working with me:
    • #{tutor_card.stats.average_rating}⭐ average rating
    • #{tutor_card.stats.total_sessions}+ successful sessions
    • #{tutor_card.stats.five_star_sessions} 5-star reviews

    Want to see if we're a good fit? Get 50% off your first session:
    #{link.url}

    Let me know if you have questions! 📚
    """
  end

  defp build_sms_message(tutor_card, link) do
    """
    Hi! I'm #{tutor_card.name}, #{tutor_card.stats.average_rating}⭐ tutor with #{tutor_card.stats.total_sessions}+ sessions.
    Specializing in #{Enum.join(Enum.take(tutor_card.subjects, 2), ", ")}.
    Get 50% off first session: #{link.url}
    """
  end

  defp build_email_template(tutor_card, link) do
    %{
      subject: "Meet Your Perfect Tutor - #{tutor_card.name} (#{tutor_card.stats.average_rating}⭐)",
      body: """
      Hi there!

      I'm #{tutor_card.name}, and I'd love to help you achieve your learning goals!

      About Me:
      • Subjects: #{Enum.join(tutor_card.subjects, ", ")}
      • Average Rating: #{tutor_card.stats.average_rating}⭐ (#{tutor_card.stats.five_star_sessions} 5-star reviews)
      • Successful Sessions: #{tutor_card.stats.total_sessions}+

      What Students Are Saying:
      #{format_feedback_for_email(tutor_card.recent_feedback)}

      Ready to get started? Get 50% off your first session with me:
      #{link.url}

      Looking forward to working together!

      Best,
      #{tutor_card.name}
      """,
      link: link.url,
      cta: "Book First Session (50% Off)"
    }
  end

  defp format_feedback_for_email(feedback) do
    feedback
    |> Enum.take(3)
    |> Enum.map(fn f ->
      "\"#{f.feedback}\" - #{f.rating}⭐ (#{f.subject})"
    end)
    |> Enum.join("\n")
  end

  defp fetch_attribution_link(link_id) do
    case AttributionClient.get_link(link_id) do
      {:ok, link} -> {:ok, link}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_or_find_student(attrs) do
    case Repo.get_by(User, email: attrs.email) do
      nil ->
        changeset = User.changeset(%User{}, Map.put(attrs, :persona, "student"))

        case Repo.insert(changeset) do
          {:ok, student} -> {:ok, student}
          {:error, changeset} -> {:error, changeset}
        end

      existing_student ->
        {:ok, existing_student}
    end
  end

  defp track_join_event(link, student, tutor) do
    AnalyticsClient.track_event(%{
      event_type: "tutor_spotlight_join",
      user_id: student.id,
      tutor_id: tutor.id,
      link_id: link.id,
      timestamp: DateTime.utc_now()
    })

    :ok
  end

  defp create_booking_info(student, tutor, link) do
    booking_info = %{
      tutor: %{
        id: tutor.id,
        name: tutor.name
      },
      discount: "50% off first session",
      referral_link_id: link.id,
      next_steps: [
        "Choose a time slot",
        "Select subject and topic",
        "Confirm booking with 50% discount"
      ]
    }

    {:ok, booking_info}
  end

  defp find_referral_link(student_id, tutor_id) do
    # Query attribution service for the link used by this student for this tutor
    case AttributionClient.find_link_by_user_and_creator(student_id, tutor_id) do
      {:ok, link} -> {:ok, link}
      {:error, _} -> {:error, :link_not_found}
    end
  end

  defp validate_booking(booking_data) do
    required_fields = [:session_completed, :payment_processed, :feedback_given]

    if Enum.all?(required_fields, &Map.get(booking_data, &1)) do
      :ok
    else
      {:error, :incomplete_booking}
    end
  end

  defp grant_tutor_reward(tutor, student) do
    reward_data = %{
      user_id: tutor.id,
      reward_type: "tutor_spotlight_referral",
      amount: 50,
      unit: "usd",
      description: "$50 reward for successful student referral",
      metadata: %{
        student_id: student.id,
        student_email: student.email
      }
    }

    Logger.info("Granting tutor reward to user #{tutor.id}")
    # Stub: In production, call MCP/rewards service
    :ok
  end

  defp grant_student_reward(student) do
    reward_data = %{
      user_id: student.id,
      reward_type: "tutor_spotlight_signup",
      amount: 50,
      unit: "percent",
      description: "50% off first tutoring session",
      metadata: %{
        signup_date: DateTime.utc_now()
      }
    }

    Logger.info("Granting student reward to user #{student.id}")
    # Stub: In production, call MCP/rewards service
    :ok
  end

  defp track_completion_event(link, student, tutor, booking_data) do
    AnalyticsClient.track_event(%{
      event_type: "tutor_spotlight_booking_complete",
      user_id: student.id,
      tutor_id: tutor.id,
      link_id: link.id,
      booking_data: booking_data,
      timestamp: DateTime.utc_now()
    })

    :ok
  end
end
