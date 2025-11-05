defmodule ViralEngineWeb.PresenceLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.PresenceTracking

  @impl true
  def mount(%{"subject_id" => subject_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:subject:#{subject_id}")
    end

    {:ok,
     socket
     |> assign(:subject_id, subject_id)
     |> assign(:online_users, [])
     |> load_presence()}
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:lobby")
    end

    {:ok,
     socket
     |> assign(:subject_id, nil)
     |> assign(:online_users, [])
     |> load_presence()}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, load_presence(socket)}
  end

  @impl true
  def handle_event("update_activity", %{"activity" => activity}, socket) do
    user_id = socket.assigns.current_user.id
    subject_id = socket.assigns.subject_id

    # Update presence session
    sessions = PresenceTracking.get_user_sessions(user_id)

    current_session =
      Enum.find(sessions, fn s ->
        (subject_id && s.subject_id == subject_id) || (!subject_id && is_nil(s.subject_id))
      end)

    if current_session do
      PresenceTracking.update_session(current_session.session_id, %{
        current_activity: activity,
        last_seen_at: DateTime.utc_now()
      })
    end

    {:noreply, socket}
  end

  defp load_presence(socket) do
    subject_id = socket.assigns.subject_id
    online_users = PresenceTracking.get_online_users(subject_id)

    assign(socket, :online_users, online_users)
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end
end
