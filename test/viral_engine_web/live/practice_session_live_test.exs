defmodule ViralEngineWeb.PracticeSessionLiveTest do
  use ViralEngineWeb.ConnCase

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest, only: [get: 2]

  # Enable when ready
  @tag :skip
  test "disconnected mount", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, ViralEngineWeb.PracticeSessionLive)
    assert html =~ "Practice Session"
  end

  @tag :skip
  test "next_step advances", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, ViralEngineWeb.PracticeSessionLive)
    view |> element("button", "Next") |> render_click()
    assert render(view) =~ "Exercise 1"
  end
end
