defmodule ViralEngineWeb.GlobalPresenceLiveTest do
  use ViralEngineWeb.ConnCase
  import Phoenix.LiveViewTest

  test \"displays global presence\", %{conn: conn} do
    {:ok, view, _html} = live(conn, \"/\")
    assert has_element?(view, \"#global-presence\")
  end
end
