defmodule ViralEngineWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel("presence:lobby", ViralEngineWeb.PresenceChannel)
  channel("presence:subject:*", ViralEngineWeb.SubjectChannel)
  channel("activity:*", ViralEngineWeb.ActivityChannel)
  channel("notifications:*", ViralEngineWeb.NotificationChannel)

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case ViralEngine.Accounts.verify_socket_token(token) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
