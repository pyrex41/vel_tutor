defmodule ViralEngineWeb.PresenceTest do
  use ViralEngineWeb.ConnCase, async: true

  # Test presence tracking
  test "tracks global presence", %{conn: conn} do
    # Simulate user join, assert count updates
      # Mock Presence and PubSub
    {:ok, _pid} = start_supervised({ViralEngine.Presence, otp_app: :viral_engine})
    
    user = %ViralEngine.User{id: 1, name: \"Test User\"}
    socket = %Phoenix.Socket{assigns: %{user: user}, id: \"test_socket\"}
    
    ViralEngine.PresenceTracker.track_user(socket, user)
    
    presence = ViralEngine.Presence.list(\"global\")
    assert length(Map.keys(presence)) == 1
    assert Map.has_key?(presence, \"1\")
    
    # Test subject tracking
    subject_socket = %{socket | assigns: Map.put(socket.assigns, :subject_id, \"math\")}
    ViralEngine.PresenceTracker.track_user(subject_socket, user)
    
    subject_presence = ViralEngine.Presence.list(\"subject:math\")
    assert length(Map.keys(subject_presence)) == 1
  end
  
  test \"tracks subject-specific presence\", %{conn: conn} do
    # Similar setup for subject only
    user = %ViralEngine.User{id: 2, name: \"Subject User\"}
    socket = %Phoenix.Socket{assigns: %{user: user, subject_id: \"science\"}, id: \"subject_socket\"}
    
    ViralEngine.PresenceTracker.track_user(socket, user)
    
    presence = ViralEngine.Presence.list(\"subject:science\")
    assert length(Map.keys(presence)) == 1
  end
end
