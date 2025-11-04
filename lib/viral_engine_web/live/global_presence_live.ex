defmodule ViralEngineWeb.GlobalPresenceLive do
  use ViralEngineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:global")
    end

    {:ok, assign(socket, users: ViralEngine.Presence.list_global() |> Map.keys())}
  end

  @impl true
  def handle_info({:presence_diff, _diff}, socket) do
    {:noreply, assign(socket, users: ViralEngine.Presence.list_global() |> Map.keys())}
  end

  def render(assigns) do
    ~H"""
    <div class="global-presence">
      <h3>Global Online Users (<%= length(@users) %>)</h3>
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
