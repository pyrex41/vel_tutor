defmodule ViralEngineWeb.StudySessionLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{Repo, StudySession, PracticeContext}
  import Ecto.Query
  require Logger

  @impl true
  def mount(%{"token" => token}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Load study session by token
    study_session = from(ss in StudySession,
      where: ss.session_token == ^token
    )
    |> Repo.one()

    if study_session do
      if connected?(socket) do
        # Subscribe to study session updates
        Phoenix.PubSub.subscribe(ViralEngine.PubSub, "study_session:#{study_session.id}")
      end

      # Check if user is already a participant
      is_participant = user.id in study_session.participant_ids
      is_creator = study_session.creator_id == user.id

      socket =
        socket
        |> assign(:user, user)
        |> assign(:user_id, user.id)
        |> assign(:study_session, study_session)
        |> assign(:is_participant, is_participant)
        |> assign(:is_creator, is_creator)
        |> assign(:show_invite_modal, false)
        |> assign(:recommended_buddies, [])

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Study session not found")
       |> redirect(to: "/dashboard")}
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # List user's study sessions
    study_sessions = from(ss in StudySession,
      where: ss.creator_id == ^user.id or ^user.id in ss.participant_ids,
      where: ss.status in ["scheduled", "active"],
      order_by: [asc: ss.scheduled_at]
    )
    |> Repo.all()

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:study_sessions, study_sessions)
      |> assign(:selected_session, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("join_session", _params, socket) do
    study_session = socket.assigns.study_session
    user_id = socket.assigns.user_id

    # Check if already participant
    if user_id in study_session.participant_ids do
      {:noreply,
       socket
       |> put_flash(:info, "You're already in this study session!")}
    else
      # Check if session is full
      if length(study_session.participant_ids) >= study_session.max_participants do
        {:noreply,
         socket
         |> put_flash(:error, "This study session is full")}
      else
        # Add user to participants
        updated_participants = [user_id | study_session.participant_ids]

        {:ok, updated_session} = Repo.update(
          StudySession.changeset(study_session, %{participant_ids: updated_participants})
        )

        # Broadcast join event
        Phoenix.PubSub.broadcast(
          ViralEngine.PubSub,
          "study_session:#{study_session.id}",
          {:user_joined, %{user_id: user_id}}
        )

        {:noreply,
         socket
         |> assign(:study_session, updated_session)
         |> assign(:is_participant, true)
         |> put_flash(:success, "You've joined the study session! 🎉")}
      end
    end
  end

  @impl true
  def handle_event("leave_session", _params, socket) do
    study_session = socket.assigns.study_session
    user_id = socket.assigns.user_id

    # Remove user from participants
    updated_participants = Enum.reject(study_session.participant_ids, & &1 == user_id)

    {:ok, updated_session} = Repo.update(
      StudySession.changeset(study_session, %{participant_ids: updated_participants})
    )

    # Broadcast leave event
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "study_session:#{study_session.id}",
      {:user_left, %{user_id: user_id}}
    )

    {:noreply,
     socket
     |> assign(:study_session, updated_session)
     |> assign(:is_participant, false)
     |> put_flash(:info, "You've left the study session")}
  end

  @impl true
  def handle_event("open_invite_modal", _params, socket) do
    # Get recommended study buddies
    # In production, this would call StudyBuddyNudgeWorker.recommend_study_buddies/4
    recommended_buddies = []

    {:noreply,
     socket
     |> assign(:show_invite_modal, true)
     |> assign(:recommended_buddies, recommended_buddies)}
  end

  @impl true
  def handle_event("close_invite_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_invite_modal, false)}
  end

  @impl true
  def handle_event("copy_invite_link", _params, socket) do
    study_session = socket.assigns.study_session
    invite_url = study_session_url(study_session)

    Logger.info("Study session invite link copied: #{invite_url}")

    {:noreply,
     socket
     |> put_flash(:success, "Invite link copied to clipboard!")}
  end

  @impl true
  def handle_event("start_practice", _params, socket) do
    study_session = socket.assigns.study_session

    # Create practice session for this study group
    {:ok, session} = PracticeContext.create_session(%{
      user_id: socket.assigns.user_id,
      session_type: "group_practice",
      subject: study_session.subject,
      metadata: %{
        study_session_id: study_session.id,
        study_session_token: study_session.session_token,
        topics: study_session.topics
      }
    })

    {:noreply,
     socket
     |> put_flash(:info, "Starting group practice session...")
     |> redirect(to: "/practice/#{session.id}")}
  end

  @impl true
  def handle_info({:user_joined, %{user_id: joined_user_id}}, socket) do
    # Reload study session to get updated participant list
    study_session = Repo.get!(StudySession, socket.assigns.study_session.id)

    {:noreply,
     socket
     |> assign(:study_session, study_session)
     |> put_flash(:info, "Someone joined the study session!")}
  end

  @impl true
  def handle_info({:user_left, %{user_id: left_user_id}}, socket) do
    # Reload study session
    study_session = Repo.get!(StudySession, socket.assigns.study_session.id)

    {:noreply,
     socket
     |> assign(:study_session, study_session)}
  end

  # Helper functions

  defp study_session_url(study_session) do
    "#{ViralEngineWeb.Endpoint.url()}/study/#{study_session.session_token}"
  end

  defp invite_message(study_session) do
    topics = Enum.join(study_session.topics, ", ")
    """
    Join my #{study_session.subject} study session!
    Topics: #{topics}
    When: #{format_datetime(study_session.scheduled_at)}
    #{study_session_url(study_session)}
    """
  end

  defp format_datetime(datetime) when not is_nil(datetime) do
    Calendar.strftime(datetime, "%B %d at %I:%M %p")
  end
  defp format_datetime(_), do: "Not scheduled"

  defp format_date(date) when not is_nil(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end
  defp format_date(_), do: "No date"

  defp days_until_exam(exam_date) when not is_nil(exam_date) do
    days = Date.diff(exam_date, Date.utc_today())

    cond do
      days == 0 -> "Today!"
      days == 1 -> "Tomorrow"
      days > 0 -> "In #{days} days"
      true -> "Past"
    end
  end
  defp days_until_exam(_), do: "No exam scheduled"

  defp urgency_color(exam_date) when not is_nil(exam_date) do
    days = Date.diff(exam_date, Date.utc_today())

    cond do
      days <= 1 -> "text-red-600"
      days <= 3 -> "text-orange-600"
      days <= 7 -> "text-yellow-600"
      true -> "text-green-600"
    end
  end
  defp urgency_color(_), do: "text-gray-600"

  defp session_type_badge(type) do
    case type do
      "exam_prep" -> {"📚", "Exam Prep", "bg-red-100 text-red-800"}
      "group_practice" -> {"👥", "Group Practice", "bg-blue-100 text-blue-800"}
      "peer_tutoring" -> {"🎓", "Peer Tutoring", "bg-green-100 text-green-800"}
      _ -> {"📖", "Study Session", "bg-gray-100 text-gray-800"}
    end
  end

  defp participants_count(study_session) do
    "#{length(study_session.participant_ids)}/#{study_session.max_participants}"
  end

  defp is_full?(study_session) do
    length(study_session.participant_ids) >= study_session.max_participants
  end

  defp time_until_session(scheduled_at) when not is_nil(scheduled_at) do
    seconds = DateTime.diff(scheduled_at, DateTime.utc_now())

    cond do
      seconds < 0 -> "Started"
      seconds < 3600 -> "Starting in #{div(seconds, 60)} minutes"
      seconds < 86400 -> "Starting in #{div(seconds, 3600)} hours"
      true -> "Starting in #{div(seconds, 86400)} days"
    end
  end
  defp time_until_session(_), do: "Not scheduled"
end
