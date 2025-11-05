defmodule ViralEngineWeb.ActivityFeedLiveTest do
  use ViralEngineWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias ViralEngine.{Activities, Accounts}

  describe "ActivityFeedLive" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          email: "test@example.com",
          password: "password123"
        })

      %{user: user}
    end

    test "renders activity feed", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/activity")

      assert html =~ "Activity Feed"
      assert html =~ "Real-time activity feed"
    end

    test "displays recent activities", %{conn: conn, user: user} do
      # Create a test activity
      {:ok, _event} =
        Activities.create_event(%{
          user_id: user.id,
          event_type: "practice_completed",
          data: %{score: 95, subject: "math"},
          visibility: "public"
        })

      {:ok, view, _html} = live(conn, "/activity")

      # Check that the activity appears (anonymized)
      assert has_element?(view, "[role='feed']", "A student completed a practice session! 📚")
    end

    test "filters out private activities", %{conn: conn, user: user} do
      # Create a private activity
      {:ok, _event} =
        Activities.create_event(%{
          user_id: user.id,
          event_type: "practice_completed",
          data: %{score: 95, subject: "math"},
          visibility: "private"
        })

      {:ok, view, _html} = live(conn, "/activity")

      # Private activity should not appear
      refute has_element?(view, "[role='feed']", "A student completed a practice session! 📚")
    end

    test "anonymizes streak completion events", %{conn: conn, user: user} do
      # Create a streak completion event
      {:ok, _event} =
        Activities.create_event(%{
          user_id: user.id,
          event_type: "streak_completed",
          data: %{streak_count: 7, milestone: true},
          visibility: "public"
        })

      {:ok, view, _html} = live(conn, "/activity")

      # Check that the streak appears anonymized
      assert has_element?(view, "[role='feed']", "A student completed a 7-day streak! 🔥")
    end

    test "anonymizes high score events", %{conn: conn, user: user} do
      # Create a high score event
      {:ok, _event} =
        Activities.create_event(%{
          user_id: user.id,
          event_type: "high_score",
          data: %{score: 98, subject: "science"},
          visibility: "public"
        })

      {:ok, view, _html} = live(conn, "/activity")

      # Check that the high score appears anonymized
      assert has_element?(
               view,
               "[role='feed']",
               "A student achieved a high score of 98 in science! 🏆"
             )
    end
  end
end
