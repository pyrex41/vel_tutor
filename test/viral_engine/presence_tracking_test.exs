defmodule ViralEngine.PresenceTrackingTest do
  use ViralEngine.DataCase

  alias ViralEngine.PresenceTracking
  alias ViralEngine.PresenceTracking.Session
  alias ViralEngine.Accounts.User

  describe "create_session/1" do
    test "creates a presence session with valid data" do
      {:ok, user} = Repo.insert(%User{email: "test@example.com"})

      valid_attrs = %{
        user_id: user.id,
        topic: "global",
        event_type: "join",
        session_id: "test_session_123",
        status: "online",
        current_activity: "studying",
        last_seen_at: DateTime.utc_now(),
        joined_at: DateTime.utc_now()
      }

      assert {:ok, %Session{} = session} = PresenceTracking.create_session(valid_attrs)
      assert session.user_id == user.id
      assert session.session_id == "test_session_123"
      assert session.status == "online"
    end

    test "returns error with invalid data" do
      invalid_attrs = %{session_id: nil}
      assert {:error, %Ecto.Changeset{}} = PresenceTracking.create_session(invalid_attrs)
    end
  end

  describe "get_online_users/1" do
    test "returns users who have been seen recently" do
      {:ok, user} = Repo.insert(%User{email: "test2@example.com"})
      recent_time = DateTime.utc_now()
      # 10 minutes ago
      old_time = DateTime.add(DateTime.utc_now(), -600, :second)

      # Create recent session
      PresenceTracking.create_session(%{
        user_id: user.id,
        topic: "global",
        event_type: "join",
        session_id: "recent_session",
        last_seen_at: recent_time,
        joined_at: recent_time
      })

      # Create old session (should be filtered out)
      PresenceTracking.create_session(%{
        user_id: user.id,
        topic: "global",
        event_type: "join",
        session_id: "old_session",
        last_seen_at: old_time,
        joined_at: old_time
      })

      online_users = PresenceTracking.get_online_users()
      assert length(online_users) == 1
      assert hd(online_users).user_id == user.id
    end

    test "filters by subject_id when provided" do
      {:ok, user} = Repo.insert(%User{email: "test3@example.com"})
      time = DateTime.utc_now()

      # Create session for specific subject (using subject_id 1)
      PresenceTracking.create_session(%{
        user_id: user.id,
        topic: "subject:1",
        event_type: "join",
        subject_id: 1,
        session_id: "subject_session",
        last_seen_at: time,
        joined_at: time
      })

      # Create session for different subject (using subject_id 2)
      PresenceTracking.create_session(%{
        user_id: user.id,
        topic: "subject:2",
        event_type: "join",
        subject_id: 2,
        session_id: "other_subject_session",
        last_seen_at: time,
        joined_at: time
      })

      subject_users = PresenceTracking.get_online_users(1)
      assert length(subject_users) == 1
      assert hd(subject_users).subject_id == 1
    end
  end

  describe "cleanup_stale_sessions/0" do
    test "removes sessions older than 10 minutes" do
      {:ok, user} = Repo.insert(%User{email: "test4@example.com"})
      recent_time = DateTime.utc_now()
      # 11.5 minutes ago
      old_time = DateTime.add(DateTime.utc_now(), -700, :second)

      # Create recent session
      PresenceTracking.create_session(%{
        user_id: user.id,
        topic: "global",
        event_type: "join",
        session_id: "recent_session",
        last_seen_at: recent_time,
        joined_at: recent_time
      })

      # Create old session
      PresenceTracking.create_session(%{
        user_id: user.id,
        topic: "global",
        event_type: "join",
        session_id: "old_session",
        last_seen_at: old_time,
        joined_at: old_time
      })

      # Verify both exist
      sessions_before = PresenceTracking.get_user_sessions(user.id)
      assert length(sessions_before) == 2

      # Clean up
      PresenceTracking.cleanup_stale_sessions()

      # Verify only recent session remains
      sessions_after = PresenceTracking.get_user_sessions(user.id)
      assert length(sessions_after) == 1
      assert hd(sessions_after).session_id == "recent_session"
    end
  end
end
