defmodule ViralEngineWeb.SubjectChannel do
  use ViralEngineWeb, :channel
  alias ViralEngine.Presence

  @impl true
  def join("presence:subject:" <> subject_id, _payload, socket) do
    send(self(), {:after_join, subject_id})
    {:ok, assign(socket, :subject_id, subject_id)}
  end

  @impl true
  def handle_info({:after_join, subject_id}, socket) do
    user_id = socket.assigns.user_id
    user = ViralEngine.Accounts.get_user!(user_id)

    {:ok, _} =
      Presence.track(socket, user_id, %{
        user_id: user_id,
        username: user.username,
        subject_id: subject_id,
        online_at: inspect(System.system_time(:second)),
        current_activity: "browsing"
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("update_activity", %{"activity" => activity}, socket) do
    user_id = socket.assigns.user_id

    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :current_activity, activity)
    end)

    {:reply, :ok, socket}
  end
end
