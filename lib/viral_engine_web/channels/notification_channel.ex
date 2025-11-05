defmodule ViralEngineWeb.NotificationChannel do
  use ViralEngineWeb, :channel
  alias ViralEngine.Notifications

  @impl true
  def join("notifications:" <> user_id, _payload, socket) do
    if socket.assigns.user_id == String.to_integer(user_id) do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id

    # Send unread notifications
    unread_notifications = Notifications.list_unread_for_user(user_id)
    push(socket, "unread_notifications", %{notifications: unread_notifications})

    {:noreply, socket}
  end

  @impl true
  def handle_in("mark_read", %{"notification_id" => notification_id}, socket) do
    user_id = socket.assigns.user_id

    case Notifications.mark_as_read(notification_id, user_id) do
      {:ok, _notification} ->
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl true
  def handle_in("dismiss", %{"notification_id" => notification_id}, socket) do
    user_id = socket.assigns.user_id

    case Notifications.dismiss(notification_id, user_id) do
      {:ok, _notification} ->
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end
end
