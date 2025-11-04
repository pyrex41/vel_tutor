defmodule ViralEngineWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel("room:*", ViralEngineWeb.RoomChannel)

  ## Transports
  transport(:websocket, Phoenix.Transports.WebSocket, timeout: 45_000)

  transport(:longpoll, Phoenix.Transports.LongPoll, timeout: 45_000)

  def connect(_params, socket, _connect_info) do
    socket = assign(socket, :user_id, get_user_id(_params))
    {:ok, socket}
  end

  defp get_user_id(params) do
    params["user_id"] || "anonymous"
  end

  def id(socket) do
    "users_socket:#{socket.assigns.user_id}"
  end
end
