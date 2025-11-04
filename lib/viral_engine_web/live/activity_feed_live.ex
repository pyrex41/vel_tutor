defmodule ViralEngineWeb.ActivityFeedLive do
  use ViralEngineWeb, :live_view

  alias ViralEngine.Activity.Context, as: ActivityContext

  @impl true
  def mount(params, _session, socket) do
    user_id = socket.assigns.current_user.id
    type_filter = params["type"] || "all"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "activities:#{user_id}")
    end

    activities =
      ActivityContext.list_activities_for_user(user_id,
        type: if(type_filter == "all", do: nil, else: type_filter)
      )

    socket =
      socket
      |> stream(:activities, activities)
      |> assign(:user_id, user_id)
      |> assign(:type_filter, type_filter)
      |> assign(:has_more, true)
      |> assign(:next_cursor, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("load-more", _params, socket) do
    user_id = socket.assigns.user_id
    type_filter = socket.assigns.type_filter
    cursor = socket.assigns.next_cursor

    {new_activities, next_cursor} =
      ActivityContext.list_activities_paginated(user_id,
        limit: 10,
        cursor: cursor,
        type: if(type_filter == "all", do: nil, else: type_filter)
      )

    socket =
      socket
      |> stream(:activities, new_activities, at: -1)
      |> assign(:next_cursor, next_cursor)
      |> assign(:has_more, length(new_activities) == 10)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-type", %{"type" => type}, socket) do
    activities = ActivityContext.list_activities_for_user(socket.assigns.user_id, type: type)

    socket =
      socket
      |> stream(:activities, activities)
      |> assign(:type_filter, type)
      |> assign(:has_more, true)
      |> assign(:next_cursor, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:activity, user_id, activity}, socket) do
    if user_id == socket.assigns.user_id do
      {:noreply, stream_insert(socket, :activities, activity, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle-like", %{"activity_id" => activity_id}, socket) do
    user_id = socket.assigns.current_user.id
    {:ok, result} = ActivityContext.toggle_like(activity_id, user_id)

    # Refresh activities to show like state
    activities = ActivityContext.list_activities_for_user(user_id)
    {:noreply, stream(socket, :activities, activities)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="feed-container p-4 max-w-4xl mx-auto">
      <div class="flex justify-between items-center mb-6">
        <h2 class="text-2xl font-bold">Activity Feed</h2>
        <div class="flex space-x-2">
          <button phx-click="filter-type" phx-value-type="all" 
            class={"px-4 py-2 rounded-md text-sm font-medium " <> 
              if(@type_filter == "all", do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700")}>
            All
          </button>
          <button phx-click="filter-type" phx-value-type="achievement" 
            class={"px-4 py-2 rounded-md text-sm font-medium " <> 
              if(@type_filter == "achievement", do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700")}>
            Achievements
          </button>
          <button phx-click="filter-type" phx-value-type="like" 
            class={"px-4 py-2 rounded-md text-sm font-medium " <> 
              if(@type_filter == "like", do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700")}>
            Interactions
          </button>
        </div>
      </div>

      <div id="feed" class="space-y-4">
        <%= for {id, activity} <- @streams.activities do %>
          <div class="activity-card bg-white border rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow">
            <div class="flex items-start space-x-3">
              <div class="flex-shrink-0">
                <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{
                  case activity.type do
                    "like" -> "bg-green-100 text-green-800"
                    "achievement" -> "bg-purple-100 text-purple-800"
                    "follow" -> "bg-indigo-100 text-indigo-800"
                    _ -> "bg-blue-100 text-blue-800"
                  end
                }"}>
                  <%= String.capitalize(activity.type) %>
                </span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm text-gray-900"><%= activity.content %></p>
                <p class="text-xs text-gray-500 mt-1">
                  By <%= activity.user.name %> • <%= Calendar.strftime(activity.inserted_at, "%b %d, %Y %H:%M") %>
                </p>
                <%= if activity.type != "like" do %>
                  <button 
                    phx-click="toggle-like" 
                    phx-value-activity_id={activity.id}
                    class="mt-2 px-3 py-1 text-xs font-medium rounded-md bg-gray-100 text-gray-800 hover:bg-gray-200 transition-colors">
                    <%= if has_user_liked?(assigns, activity.id), do: "Unlike", else: "Like" %>
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%= if @has_more do %>
        <div class="text-center mt-8">
          <button phx-click="load-more" 
            class="px-6 py-3 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors font-medium">
            Load More Activities
          </button>
        </div>
      <% end %>

      <%= if Enum.empty?(@streams.activities) do %>
        <div class="text-center py-12 text-gray-500">
          <div class="text-6xl mb-4">📭</div>
          <p class="text-lg">No activities yet.</p>
          <p class="text-sm mt-2">Start interacting to see updates here!</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp has_user_liked?(assigns, activity_id) do
    # Simple check - in production you'd query the DB
    false
end
end
