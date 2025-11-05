defmodule ViralEngineWeb.ActivityFeedLive do
  use ViralEngineWeb, :live_view

  alias ViralEngine.Activities
  alias ViralEngine.PubSubHelper

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to global activity feed
      PubSubHelper.subscribe_to_activity()
    end

    # Get recent anonymized activities
    recent_activities =
      Activities.list_recent_activities(limit: 20)
      |> Enum.map(&anonymize_activity/1)

    socket =
      socket
      |> stream(:activities, recent_activities)
      |> assign(:connected, connected?(socket))

    {:ok, socket}
  end

  @impl true
  def handle_info({:activity, event_type, event}, socket) do
    # Only show public activities that haven't been opted out
    if event.visibility == "public" and not opted_out?(event.user_id) do
      anonymized = anonymize_activity(event)
      {:noreply, stream_insert(socket, :activities, anonymized, at: 0)}
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
        <div class="flex items-center space-x-2">
          <div class={"w-2 h-2 rounded-full #{if @connected, do: "bg-green-500", else: "bg-gray-400"}"}></div>
          <span class="text-sm text-muted-foreground">
            <%= if @connected, do: "Live", else: "Connecting..." %>
          </span>
        </div>
      </div>

      <div id="activity-feed" class="space-y-4" role="feed" aria-label="Real-time activity feed">
        <%= for {id, activity} <- @streams.activities do %>
          <article class="activity-card bg-card text-card-foreground border rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow animate-fade-in" aria-labelledby={"activity-#{id}-content"}>
            <div class="flex items-start space-x-3">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                  <%= activity_icon(activity.event_type) %>
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <p id={"activity-#{id}-content"} class="text-sm text-foreground">
                  <%= activity.message %>
                </p>
                <p class="text-xs text-muted-foreground mt-1">
                  <%= Calendar.strftime(activity.timestamp, "%b %d, %H:%M") %>
                </p>
              </div>
            </div>
          </article>
        <% end %>
      </div>

      <%= if Enum.empty?(@streams.activities) do %>
        <div class="text-center py-12">
          <div class="mx-auto flex items-center justify-center h-20 w-20 rounded-full bg-muted mb-4">
            <svg class="h-12 w-12 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
          </div>
          <p class="text-lg text-muted-foreground">No activities yet.</p>
          <p class="text-sm text-muted-foreground mt-2">Activities will appear here as students achieve milestones!</p>
        </div>
      <% end %>
    </div>
    """
  end

  # Anonymize activity data for public feed
  defp anonymize_activity(event) do
    message =
      case event.event_type do
        "streak_completed" ->
          streak = event.data["streak_count"] || event.data["count"] || 1
          "A student completed a #{streak}-day streak! 🔥"

        "high_score" ->
          subject = event.data["subject"] || "practice"
          score = event.data["score"] || event.data["points"] || 0
          "A student achieved a high score of #{score} in #{subject}! 🏆"

        "practice_completed" ->
          "A student completed a practice session! 📚"

        "challenge_completed" ->
          "A student completed a challenge! ⚡"

        "badge_earned" ->
          badge = event.data["badge_name"] || "achievement"
          "A student earned the #{badge} badge! 🏅"

        "flashcard_mastered" ->
          count = event.data["count"] || 1
          "A student mastered #{count} flashcards! 🧠"

        "diagnostic_completed" ->
          "A student completed a diagnostic assessment! 📊"

        "buddy_challenge_created" ->
          "A student created a buddy challenge! 🤝"

        "rally_joined" ->
          "A student joined a results rally! 🎯"

        _ ->
          "A student achieved something amazing! ⭐"
      end

    %{
      id: event.id,
      event_type: event.event_type,
      message: message,
      timestamp: event.inserted_at,
      subject_id: event.subject_id
    }
  end

  # Check if user has opted out of activity sharing
  defp opted_out?(user_id) do
    # Check user's privacy settings
    # For now, return false (everyone participates)
    # In production, this would check user preferences
    false
  end

  # Return appropriate icon for activity type
  defp activity_icon(event_type) do
    case event_type do
      "streak_completed" -> "🔥"
      "high_score" -> "🏆"
      "practice_completed" -> "📚"
      "challenge_completed" -> "⚡"
      "badge_earned" -> "🏅"
      "flashcard_mastered" -> "🧠"
      "diagnostic_completed" -> "📊"
      "buddy_challenge_created" -> "🤝"
      "rally_joined" -> "🎯"
      _ -> "⭐"
    end
  end
end
