defmodule ViralEngineWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel("room:*", ViralEngineWeb.RoomChannel)

  ## Transports are configured in config/config.exs via Phoenix.Endpoint

  def connect(params, socket, _connect_info) do
    user_id = get_user_id(params)
    socket = assign(socket, :user_id, user_id)
    {:ok, socket}
  end

  defp get_user_id(params) do
    params["user_id"] || "anonymous"
  end

  def id(socket) do
    "users_socket:#{socket.assigns.user_id}"
  end
end
