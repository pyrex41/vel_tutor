defmodule ViralEngineWeb.PresenceSubjectComponent do
  use ViralEngineWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="subject-presence" id={"subject-#{@subject_id}-presence"}>
      <%= @subject_id %> Room: <%= length(@users) %> users online
      <ul><li :for={user_id <- @users}><%= user_id %></li></ul>
    </div>
    """
  end

  def update(%{subject_id: subject_id} = assigns, socket) do
    topic = "subject:#{subject_id}"
    users = Map.keys(PresenceTracker.list_presence(topic))
    {:ok, assign(socket, subject_id: subject_id, users: users)}
  end
end
