defmodule ViralEngine.PresenceTest do
  use ViralEngine.DataCase
  use Phoenix.ChannelTest, async: true

  alias ViralEngine.Presence

  @endpoint ViralEngineWeb.Endpoint

  setup do
    {:ok, _} = Presence.start_link([])
    :ok
  end

  test "list_global returns 0 initially" do
    assert Presence.list_global() == 0
  end

  test "list_subject returns 0 initially" do
    assert Presence.list_subject("math") == 0
  end

  test "track global presence" do
    {:ok, _, socket} = socket(ViralEngineWeb.UserSocket, "user_id", %{})

    # Mock user
    user = %ViralEngine.User{id: "user1"}

    Presence.track_user_presence(user, socket)

    assert Presence.list_global() == 1
  end

  test "track subject presence" do
    {:ok, _, socket} = socket(ViralEngineWeb.UserSocket, "user_id", %{})

    # Mock user
    user = %ViralEngine.User{id: "user1"}

    Presence.track_user_presence(user, socket)

    assert Presence.list_subject("general") == 1
  end
end
