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
  def handle_info({:user_joined, %{user_id: _joined_user_id}}, socket) do
    # Reload study session to get updated participant list
    study_session = Repo.get!(StudySession, socket.assigns.study_session.id)

    {:noreply,
     socket
     |> assign(:study_session, study_session)
     |> put_flash(:info, "Someone joined the study session!")}
  end

  @impl true
  def handle_info({:user_left, %{user_id: _left_user_id}}, socket) do
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

  # Note: Additional UI helper functions have been removed until
  # a render/1 function or .heex template is implemented.
  # Functions included: invite_message/1, format_datetime/1, format_date/1,
  # days_until_exam/1, urgency_color/1, session_type_badge/1,
  # participants_count/1, is_full?/1, time_until_session/1
end
