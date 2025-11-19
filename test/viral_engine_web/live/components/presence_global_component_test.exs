defmodule ViralEngineWeb.PresenceGlobalComponentTest do
  use ViralEngineWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders global presence count", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, ViralEngineWeb.PresenceGlobalComponent, session: %{global_presence: %{"user1" => %{metas: [%{online_at: ~U[2025-11-03 12:00:00Z]}]}}})

    assert has_element?(view, "#global-presence", "Online Users: 1")
  end

  test "updates count on presence diff", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, ViralEngineWeb.PresenceGlobalComponent, session: %{global_presence: %{}})

    send(view, {:presence_diff, {"global", :join, "user1", %{metas: [%{online_at: ~U[2025-11-03 12:00:00Z]}]}}})
    assert has_element?(view, "#global-presence", "Online Users: 1")
  end
end
