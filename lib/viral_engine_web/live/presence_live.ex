defmodule ViralEngineWeb.PresenceLive do
  use ViralEngineWeb, :live_view

  @subjects ~w(math science english history)

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:global")

      for subject <- @subjects do
        Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:subject:#{subject}")
      end
    end

    socket =
      socket
      |> assign(:global_count, 0)
      |> assign(:subject_counts, %{})

    {:ok, socket}
  end

  def handle_info({:presence_diff, {topic, _diff}}, socket) do
    count = ViralEngine.Presence.list(topic)

    key =
      if String.contains?(topic, "subject:"),
        do: String.replace(topic, "subject:", ""),
        else: :global_count

    socket =
      if key == :global_count do
        assign(socket, :global_count, map_size(count))
      else
        update(socket, :subject_counts, &Map.put(&1, key, map_size(count)))
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="presence-dashboard">
      <div class="global">Online Users: <%= @global_count %></div>
      <div class="subjects">
        <%= for {subject, count} <- @subject_counts do %>
          <span><%= String.capitalize(subject) %>: <%= count %> online</span>
        <% end %>
      </div>
    </div>
    """
  end
end
