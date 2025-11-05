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
  def handle_event("toggle-like", %{"activity_id" => activity_id}, socket) do
    user_id = socket.assigns.current_user.id
    {:ok, _result} = ActivityContext.toggle_like(activity_id, user_id)

    # Refresh activities to show like state
    activities = ActivityContext.list_activities_for_user(user_id)
    {:noreply, stream(socket, :activities, activities)}
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
  def render(assigns) do
    ~H"""
    <div class="bg-background min-h-screen p-4 max-w-4xl mx-auto" role="main">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold text-foreground">Activity Feed</h1>
        <div class="flex space-x-2" role="group" aria-label="Filter activities">
          <button phx-click="filter-type" phx-value-type="all"
            class={"px-4 py-2 rounded-md text-sm font-medium transition-colors " <>
              if(@type_filter == "all", do: "bg-primary text-primary-foreground", else: "bg-muted text-muted-foreground hover:bg-muted/80")}
            aria-pressed={@type_filter == "all"}>
            All
          </button>
          <button phx-click="filter-type" phx-value-type="achievement"
            class={"px-4 py-2 rounded-md text-sm font-medium transition-colors " <>
              if(@type_filter == "achievement", do: "bg-primary text-primary-foreground", else: "bg-muted text-muted-foreground hover:bg-muted/80")}
            aria-pressed={@type_filter == "achievement"}>
            Achievements
          </button>
          <button phx-click="filter-type" phx-value-type="like"
            class={"px-4 py-2 rounded-md text-sm font-medium transition-colors " <>
              if(@type_filter == "like", do: "bg-primary text-primary-foreground", else: "bg-muted text-muted-foreground hover:bg-muted/80")}
            aria-pressed={@type_filter == "like"}>
            Interactions
          </button>
        </div>
      </div>

      <div id="feed" class="space-y-4" role="feed" aria-label="Activity feed">
        <%= for {id, activity} <- @streams.activities do %>
          <article class="activity-card bg-card text-card-foreground border rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow" aria-labelledby={"activity-#{id}-content"}>
            <div class="flex items-start space-x-3">
              <div class="flex-shrink-0">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-secondary text-secondary-foreground">
                  <%= String.capitalize(activity.type) %>
                </span>
              </div>
              <div class="flex-1 min-w-0">
                <p id={"activity-#{id}-content"} class="text-sm text-foreground"><%= activity.content %></p>
                <p class="text-xs text-muted-foreground mt-1">
                  By <%= activity.user.name %> • <%= Calendar.strftime(activity.inserted_at, "%b %d, %Y %H:%M") %>
                </p>
                <%= if activity.type != "like" do %>
                  <button
                    phx-click="toggle-like"
                    phx-value-activity_id={activity.id}
                    class="mt-2 px-3 py-1 text-xs font-medium rounded-md bg-muted text-muted-foreground hover:bg-muted/80 transition-colors"
                    aria-label={if has_user_liked?(assigns, activity.id), do: "Unlike this activity", else: "Like this activity"}>
                    <%= if has_user_liked?(assigns, activity.id), do: "Unlike", else: "Like" %>
                  </button>
                <% end %>
              </div>
            </div>
          </article>
        <% end %>
      </div>

      <%= if @has_more do %>
        <div class="text-center mt-8">
          <button phx-click="load-more"
            class="px-6 py-3 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md transition-colors font-medium shadow-sm hover:shadow-md"
            aria-label="Load more activities">
            Load More Activities
          </button>
        </div>
      <% end %>

      <%= if Enum.empty?(@streams.activities) do %>
        <div class="text-center py-12">
          <div class="mx-auto flex items-center justify-center h-20 w-20 rounded-full bg-muted mb-4">
            <svg class="h-12 w-12 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
          </div>
          <p class="text-lg text-muted-foreground">No activities yet.</p>
          <p class="text-sm text-muted-foreground mt-2">Start interacting to see updates here!</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp has_user_liked?(_assigns, _activity_id) do
    # Simple check - in production you'd query the DB
    false
  end
end
