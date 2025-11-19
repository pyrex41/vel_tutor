defmodule ViralEngine.PresenceTrackerTest do
  use ViralEngine.DataCase
  import ViralEngine.Fixtures
  alias ViralEngine.{PresenceTracker, Presence, Repo}
  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  @tag :skip
  test "tracks global and subject presence" do
    user = %ViralEngine.Accounts.User{id: "user1", role: "user"} |> Repo.insert!()
    socket = %Phoenix.Socket{private: %{phoenix_socket_connected?: true}}

    {:ok, _} = Presence.start_link()

    # expect(Phoenix.PubSub, :broadcast, fn _pubsub, topic, msg ->
    #   case msg do
    #     {:presence_diff, _} -> topic == "presence:global"
    #     _ -> false
    #   end
    # end)

    updated_socket = PresenceTracker.track_user(socket, user, subject_id: "math")

    assert updated_socket
    assert map_size(Presence.list("global")) == 1
    assert map_size(Presence.list("subject:math")) == 1
  end

  @tag :skip
  test "updates user presence status in DB" do
    user = create_user()

    socket = %Phoenix.Socket{private: %{phoenix_socket_connected?: true}}

    PresenceTracker.track_user(socket, user, subject_id: "math")

    updated_user = Repo.get(ViralEngine.Accounts.User, user.id)
    assert updated_user.presence_status == "online"
    assert updated_user.last_seen_at
  end
end
