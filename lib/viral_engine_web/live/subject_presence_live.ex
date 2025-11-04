defmodule ViralEngineWeb.SubjectPresenceLive do
  use ViralEngineWeb, :live_view

  def mount(%{"subject_id" => subject_id}, _session, socket) do
    if connected?(socket) do
      topic = "presence:subject:#{subject_id}"
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, topic)
    end

    users = ViralEngine.Presence.list_subject(subject_id) |> Map.keys()
    {:ok, assign(socket, subject_id: subject_id, users: users)}
  end

  def handle_info({:presence_diff, _diff}, socket) do
    subject_id = socket.assigns.subject_id
    users = ViralEngine.Presence.list_subject(subject_id) |> Map.keys()
    {:noreply, assign(socket, users: users)}
  end

  def render(assigns) do
    ~H"""
    <div class="subject-presence" id={"subject-#{@subject_id}-presence"}>
      <h3>Users in <%= @subject_id |> String.capitalize() %> (<%= length(@users) %>)</h3>
      <ul>
        <%= for user_id <- @users do %>
          <li>
            <%= if user = ViralEngine.Repo.get(ViralEngine.User, user_id) do %>
              <%= user.name || user.email %>
            <% else %>
              Anonymous User (ID: <%= user_id %>)
            <% end %>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
