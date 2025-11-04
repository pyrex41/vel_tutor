defmodule ViralEngineWeb.Live.Components.PresenceWidgetLive do
  use ViralEngineWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="presence-widget">
      <h3>Online Users</h3>
      <p>Global: <%= @global_count %></p>
      <%= for {subject, count} <- @subject_counts do %>
        <p><%= String.capitalize(subject) %>: <%= count %> online</p>
      <% end %>
    </div>
    """
  end
end
