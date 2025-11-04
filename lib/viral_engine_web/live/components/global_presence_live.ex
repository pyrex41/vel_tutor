defmodule ViralEngineWeb.Live.Components.GlobalPresenceLive do
  use ViralEngineWeb, :live_component

  @impl true
  def mount(socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:global")
    {:ok, assign(socket, users: ViralEngine.Presence.list_global(), count: 0)}
  end

  def handle_info({:presence_diff, _}, socket) do
    users = ViralEngine.Presence.list_global()
    count = length(users)
    {:noreply, assign(socket, users: users, count: count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="global-presence-widget p-4 bg-gray-100 rounded-lg">
      <h3 class="font-bold text-lg mb-2">Global Online Users</h3>
      <div class="text-sm">
        <span class="font-semibold"><%= @count %> users online</span>
        <ul class="mt-2 space-y-1 max-h-40 overflow-y-auto">
          <%= for {user_id, meta} <- @users do %>
    <li class="flex items-center">
    <span class="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
    <span class="w-6 h-6 bg-green-600 text-white rounded-full flex items-center justify-center text-xs mr-2"><%= String.first(meta.name || "U") %></span>
    <%= meta.name %>
    <%= if meta.role, do: "(#{meta.role})", else: "" %>
    </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end
end
