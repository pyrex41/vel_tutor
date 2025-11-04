defmodule ViralEngine.PresenceIntegrationTest do
  use ViralEngine.DataCase
  import Phoenix.LiveViewTest
  alias ViralEngine.{Presence, Accounts}

  test "presence tracking with opt-out" do
    user = insert(:user, presence_opt_out: false)
    Presence.track_user_presence(user, self())
    assert Presence.list("global") |> length() > 0

    {:ok, updated} = Accounts.update_user(user, %{presence_opt_out: true})
    Presence.handle_opt_out_toggle(user.id, true)
    assert Presence.list("global") |> length() == 0
  end

  # Add more: PubSub broadcast, widget updates
end
