defmodule ViralEngineWeb.PresenceSubjectComponentTest do
  use ViralEngineWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders subject presence users", %{conn: conn} do
    {:ok, view, _html} =
      live_isolated(conn, ViralEngineWeb.PresenceSubjectComponent,
        session: %{
          subject_id: "math",
          subject_presence: %{"user1" => %{metas: [%{online_at: ~U[2025-11-03 12:00:00Z]}]}}
        }
      )

    assert has_element?(view, "#math-presence", "Users in Math: 1")
  end

  test "handles empty subject presence", %{conn: conn} do
    {:ok, view, _html} =
      live_isolated(conn, ViralEngineWeb.PresenceSubjectComponent,
        session: %{subject_id: "science", subject_presence: %{}}
      )

    assert has_element?(view, "#science-presence", "Users in Science: 0")
  end
end
