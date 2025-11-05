defmodule ViralEngineWeb.PresenceChannel do
  use ViralEngineWeb, :channel
  alias ViralEngine.Presence

  @impl true
  def join("presence:lobby", _payload, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id
    user = ViralEngine.Accounts.get_user!(user_id)

    {:ok, _} =
      Presence.track(socket, user_id, %{
        user_id: user_id,
        username: user.username,
        online_at: inspect(System.system_time(:second)),
        avatar_url: user.avatar_url,
        current_subject: nil,
        status: "online"
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("update_status", %{"status" => status}, socket) do
    user_id = socket.assigns.user_id

    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :status, status)
    end)

    {:reply, :ok, socket}
  end
end
