defmodule ViralEngineWeb.Live.Components.SubjectPresenceLive do
  use ViralEngineWeb, :live_component

  @impl true
  def mount(assigns) do
    subject_id = assigns.subject_id
    topic = "presence:subject:#{subject_id}"
    if connected?(assigns.socket), do: Phoenix.PubSub.subscribe(ViralEngine.PubSub, topic)
    users = ViralEngine.Presence.list_subject(subject_id)
    count = length(users)
    {:ok, assign(assigns.socket, subject_id: subject_id, users: users, count: count)}
  end

  def handle_info({:presence_diff, _}, socket) do
    users = ViralEngine.Presence.list_subject(socket.assigns.subject_id)
    count = length(users)
    {:noreply, assign(socket, users: users, count: count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="subject-presence-widget p-4 bg-blue-50 rounded-lg">
      <h3 class="font-bold text-lg mb-2">Subject: <%= @subject_id %> Attendees</h3>
      <div class="text-sm">
        <span class="font-semibold"><%= @count %> users in session</span>
        <ul class="mt-2 space-y-1 max-h-40 overflow-y-auto">
          <%= for {user_id, meta} <- @users do %>
    <li class="flex items-center">
    <span class="w-2 h-2 bg-blue-500 rounded-full mr-2"></span>
    <span class="w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-xs mr-2"><%= String.first(meta.name || "U") %></span>
    <%= meta.name %>
    </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end
end
