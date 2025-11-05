defmodule ViralEngineWeb.PresenceChannelTest do
  use ViralEngineWeb.ChannelCase
  alias ViralEngine.Presence

  setup do
    user = insert(:user)

    {:ok, _, socket} =
      ViralEngineWeb.UserSocket
      |> socket("user_id", %{user_id: user.id})
      |> subscribe_and_join(ViralEngineWeb.PresenceChannel, "presence:lobby")

    %{socket: socket, user: user}
  end

  test "tracks user presence after join", %{socket: socket, user: user} do
    presences = Presence.list(socket)
    assert Map.has_key?(presences, to_string(user.id))
  end

  test "updates user status", %{socket: socket, user: user} do
    ref = push(socket, "update_status", %{"status" => "studying"})
    assert_reply(ref, :ok)

    presences = Presence.list(socket)
    user_presence = presences[to_string(user.id)]
    assert user_presence.metas |> List.first() |> Map.get(:status) == "studying"
  end
end
