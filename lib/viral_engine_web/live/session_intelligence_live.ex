defmodule ViralEngineWeb.SessionIntelligenceLive do
  @moduledoc """
  LiveView dashboard for Session Intelligence analytics and recommendations.

  Displays:
  - Learning pattern insights
  - Performance trends
  - Weak topic identification
  - Personalized study recommendations
  - Peer comparisons
  """

  use ViralEngineWeb, :live_view
  alias ViralEngine.SessionIntelligenceContext

  @impl true
  def mount(_params, %{"user_id" => user_id} = _session, socket) do
    if connected?(socket) do
      # Load analytics data asynchronously
      send(self(), :load_analytics)
    end

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:loading, true)
      |> assign(:patterns, nil)
      |> assign(:trends, nil)
      |> assign(:weak_topics, nil)
      |> assign(:recommendations, nil)
      |> assign(:peer_comparison, nil)
      |> assign(:selected_subject, "math")
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_analytics, socket) do
    user_id = socket.assigns.user_id
    subject = socket.assigns.selected_subject

    # Load all analytics in parallel (async tasks would be better in production)
    with {:ok, patterns} <- SessionIntelligenceContext.analyze_learning_patterns(user_id: user_id),
         {:ok, trends} <- SessionIntelligenceContext.analyze_performance_trends(user_id: user_id, subject: subject),
         {:ok, weak_topics} <- SessionIntelligenceContext.identify_weak_topics(user_id: user_id, subject: subject),
         {:ok, recommendations} <- SessionIntelligenceContext.generate_recommendations(user_id: user_id, subject: subject),
         {:ok, peer_comparison} <- SessionIntelligenceContext.compare_to_peers(user_id: user_id, grade_level: 10) do
      socket =
        socket
        |> assign(:loading, false)
        |> assign(:patterns, patterns)
        |> assign(:trends, trends)
        |> assign(:weak_topics, weak_topics)
        |> assign(:recommendations, recommendations)
        |> assign(:peer_comparison, peer_comparison)

      {:noreply, socket}
    else
      {:error, reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:error, "Failed to load analytics: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_subject", %{"subject" => subject}, socket) do
    socket =
      socket
      |> assign(:selected_subject, subject)
      |> assign(:loading, true)

    send(self(), :load_analytics)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="session-intelligence-dashboard">
      <div class="dashboard-header">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white mb-2">
          Session Intelligence
        </h1>
        <p class="text-gray-600 dark:text-gray-300">
          AI-powered insights and personalized study recommendations
        </p>
      </div>

      <div class="subject-selector my-6">
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-2">
          Select Subject
        </label>
        <select
          name="subject"
          phx-change="change_subject"
          class="w-full max-w-xs px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
        >
          <option value="math" selected={@selected_subject == "math"}>Mathematics</option>
          <option value="english" selected={@selected_subject == "english"}>English</option>
          <option value="science" selected={@selected_subject == "science"}>Science</option>
          <option value="history" selected={@selected_subject == "history"}>History</option>
        </select>
      </div>

      <%= if @loading do %>
        <div class="loading-state flex items-center justify-center py-20">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          <span class="ml-4 text-gray-600">Loading your intelligence report...</span>
        </div>
      <% end %>

      <%= if @error do %>
        <div class="error-state bg-red-50 border border-red-200 rounded-lg p-4 my-4">
          <p class="text-red-800"><%= @error %></p>
        </div>
      <% end %>

      <%= if !@loading and !@error do %>
        <!-- Learning Patterns Section -->
        <div class="analytics-grid grid grid-cols-1 md:grid-cols-2 gap-6 my-8">
          <%= render_learning_patterns(assigns) %>
          <%= render_performance_trends(assigns) %>
        </div>

        <!-- Recommendations Section -->
        <div class="recommendations-section my-8">
          <%= render_recommendations(assigns) %>
        </div>

        <!-- Weak Topics Section -->
        <div class="weak-topics-section my-8">
          <%= render_weak_topics(assigns) %>
        </div>

        <!-- Peer Comparison Section -->
        <div class="peer-comparison-section my-8">
          <%= render_peer_comparison(assigns) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_learning_patterns(assigns) do
    ~H"""
    <div class="card bg-white dark:bg-gray-800 rounded-lg shadow-md p-6">
      <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4 flex items-center">
        <span class="mr-2">🧠</span>
        Learning Patterns
      </h2>

      <%= if @patterns && @patterns.total_sessions > 0 do %>
        <div class="patterns-content space-y-4">
          <!-- Peak Performance Hours -->
          <div class="metric">
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-1">Peak Performance Hours</p>
            <div class="flex items-center space-x-2">
              <%= for hour <- @patterns.peak_hours do %>
                <span class="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm font-medium">
                  <%= format_hour(hour) %>
                </span>
              <% end %>
            </div>
          </div>

          <!-- Optimal Duration -->
          <div class="metric">
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-1">Optimal Session Duration</p>
            <p class="text-2xl font-bold text-gray-900 dark:text-white">
              <%= @patterns.optimal_duration_minutes %> minutes
            </p>
          </div>

          <!-- Consistency Score -->
          <div class="metric">
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-1">Study Consistency</p>
            <div class="flex items-center">
              <div class="w-full bg-gray-200 rounded-full h-2.5 mr-2">
                <div
                  class="bg-green-600 h-2.5 rounded-full"
                  style={"width: #{@patterns.consistency_score * 100}%"}
                >
                </div>
              </div>
              <span class="text-sm font-medium text-gray-900 dark:text-white">
                <%= Float.round(@patterns.consistency_score * 100, 1) %>%
              </span>
            </div>
          </div>

          <!-- Average Score -->
          <div class="metric">
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-1">Average Score</p>
            <p class="text-2xl font-bold text-gray-900 dark:text-white">
              <%= Float.round(@patterns.avg_score, 1) %>%
            </p>
            <p class="text-xs text-gray-500 mt-1">
              Based on <%= @patterns.total_sessions %> sessions
            </p>
          </div>
        </div>
      <% else %>
        <p class="text-gray-500 italic">No session data available yet. Start practicing to see insights!</p>
      <% end %>
    </div>
    """
  end

  defp render_performance_trends(assigns) do
    ~H"""
    <div class="card bg-white dark:bg-gray-800 rounded-lg shadow-md p-6">
      <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4 flex items-center">
        <span class="mr-2">📈</span>
        Performance Trends
      </h2>

      <%= if @trends && @trends.current_score do %>
        <div class="trends-content space-y-4">
          <!-- Trend Direction -->
          <div class="metric">
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-1">Trend Direction</p>
            <div class="flex items-center">
              <%= case @trends.direction do %>
                <% :improving -> %>
                  <span class="bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm font-medium flex items-center">
                    <span class="mr-1">↗</span> Improving
                  </span>
                <% :declining -> %>
                  <span class="bg-red-100 text-red-800 px-3 py-1 rounded-full text-sm font-medium flex items-center">
                    <span class="mr-1">↘</span> Declining
                  </span>
                <% _ -> %>
                  <span class="bg-gray-100 text-gray-800 px-3 py-1 rounded-full text-sm font-medium flex items-center">
                    <span class="mr-1">→</span> Stable
                  </span>
              <% end %>
            </div>
          </div>

          <!-- Current vs Projected -->
          <div class="metric">
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-1">Current Score</p>
            <p class="text-2xl font-bold text-gray-900 dark:text-white">
              <%= @trends.current_score %>%
            </p>
          </div>

          <%= if @trends.projected_score_30d do %>
            <div class="metric">
              <p class="text-sm text-gray-600 dark:text-gray-300 mb-1">Projected (30 days)</p>
              <p class="text-2xl font-bold text-blue-600">
                <%= @trends.projected_score_30d %>%
              </p>
            </div>
          <% end %>

          <!-- Velocity -->
          <div class="metric">
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-1">Improvement Velocity</p>
            <p class="text-lg font-semibold text-gray-900 dark:text-white">
              <%= format_velocity(@trends.velocity) %>
            </p>
          </div>
        </div>
      <% else %>
        <p class="text-gray-500 italic">Complete more practice sessions to see trend analysis.</p>
      <% end %>
    </div>
    """
  end

  defp render_recommendations(assigns) do
    ~H"""
    <div class="card bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg shadow-lg p-6 text-white">
      <h2 class="text-2xl font-bold mb-4 flex items-center">
        <span class="mr-2">💡</span>
        AI Recommendations
      </h2>

      <%= if @recommendations do %>
        <div class="recommendations-grid grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Next Topic -->
          <div class="recommendation-card bg-white bg-opacity-20 rounded-lg p-4">
            <p class="text-sm font-medium mb-1">Next Topic to Study</p>
            <p class="text-xl font-bold"><%= @recommendations.next_topic %></p>
          </div>

          <!-- Optimal Time -->
          <%= if @recommendations.optimal_time do %>
            <div class="recommendation-card bg-white bg-opacity-20 rounded-lg p-4">
              <p class="text-sm font-medium mb-1">Your Best Study Time</p>
              <p class="text-xl font-bold">
                <%= Calendar.strftime(@recommendations.optimal_time, "%I:%M %p") %>
              </p>
            </div>
          <% end %>

          <!-- Recommended Duration -->
          <div class="recommendation-card bg-white bg-opacity-20 rounded-lg p-4">
            <p class="text-sm font-medium mb-1">Recommended Session Length</p>
            <p class="text-xl font-bold"><%= @recommendations.recommended_duration %> minutes</p>
          </div>

          <!-- Difficulty Adjustment -->
          <div class="recommendation-card bg-white bg-opacity-20 rounded-lg p-4">
            <p class="text-sm font-medium mb-1">Difficulty Adjustment</p>
            <p class="text-xl font-bold"><%= format_difficulty(@recommendations.difficulty_adjustment) %></p>
          </div>
        </div>

        <!-- Study Methods -->
        <div class="study-methods mt-4">
          <p class="text-sm font-medium mb-2">Recommended Study Methods</p>
          <div class="flex flex-wrap gap-2">
            <%= for method <- @recommendations.study_methods do %>
              <span class="bg-white bg-opacity-30 px-3 py-1 rounded-full text-sm font-medium">
                <%= format_study_method(method) %>
              </span>
            <% end %>
          </div>
        </div>
      <% else %>
        <p class="text-white text-opacity-80 italic">Loading recommendations...</p>
      <% end %>
    </div>
    """
  end

  defp render_weak_topics(assigns) do
    ~H"""
    <div class="card bg-white dark:bg-gray-800 rounded-lg shadow-md p-6">
      <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4 flex items-center">
        <span class="mr-2">🎯</span>
        Areas Needing Attention
      </h2>

      <%= if @weak_topics && length(@weak_topics) > 0 do %>
        <div class="weak-topics-list space-y-3">
          <%= for topic <- @weak_topics do %>
            <div class="weak-topic-card border border-gray-200 dark:border-gray-700 rounded-lg p-4 hover:shadow-md transition-shadow">
              <div class="flex items-center justify-between mb-2">
                <h3 class="font-semibold text-gray-900 dark:text-white"><%= topic.topic %></h3>
                <span class={"px-2 py-1 rounded text-xs font-medium #{weakness_badge_class(topic.weakness_score)}"}>
                  <%= weakness_label(topic.weakness_score) %>
                </span>
              </div>

              <%= if length(topic.recent_scores) > 0 do %>
                <div class="recent-scores">
                  <p class="text-xs text-gray-600 dark:text-gray-400 mb-1">Recent Scores:</p>
                  <div class="flex space-x-1">
                    <%= for score <- Enum.take(topic.recent_scores, 5) do %>
                      <span class="text-xs bg-gray-100 dark:bg-gray-700 px-2 py-1 rounded">
                        <%= score %>%
                      </span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="text-gray-500 italic">Great job! No weak areas detected. Keep up the excellent work!</p>
      <% end %>
    </div>
    """
  end

  defp render_peer_comparison(assigns) do
    ~H"""
    <div class="card bg-white dark:bg-gray-800 rounded-lg shadow-md p-6">
      <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4 flex items-center">
        <span class="mr-2">👥</span>
        Peer Comparison
      </h2>

      <%= if @peer_comparison && @peer_comparison.overall_percentile do %>
        <div class="peer-comparison-content space-y-4">
          <!-- Percentile Rank -->
          <div class="metric">
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-2">Your Percentile Rank</p>
            <div class="flex items-center">
              <div class="text-4xl font-bold text-blue-600 mr-4">
                <%= @peer_comparison.overall_percentile %>
                <span class="text-2xl">th</span>
              </div>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                You're performing better than <%= @peer_comparison.overall_percentile %>% of your peers!
              </p>
            </div>
          </div>

          <!-- Score Comparison -->
          <div class="score-comparison grid grid-cols-3 gap-4 mt-4">
            <div class="text-center">
              <p class="text-xs text-gray-600 dark:text-gray-400 mb-1">Your Score</p>
              <p class="text-2xl font-bold text-blue-600">
                <%= Float.round(@peer_comparison.user_score, 1) %>
              </p>
            </div>
            <div class="text-center">
              <p class="text-xs text-gray-600 dark:text-gray-400 mb-1">Peer Median</p>
              <p class="text-2xl font-bold text-gray-600">
                <%= Float.round(@peer_comparison.peer_median, 1) %>
              </p>
            </div>
            <div class="text-center">
              <p class="text-xs text-gray-600 dark:text-gray-400 mb-1">Comparison</p>
              <p class={"text-2xl font-bold #{if @peer_comparison.user_score >= @peer_comparison.peer_median, do: "text-green-600", else: "text-orange-600"}"}>
                <%= format_comparison_delta(@peer_comparison.user_score, @peer_comparison.peer_median) %>
              </p>
            </div>
          </div>

          <p class="text-xs text-gray-500 mt-4">
            Based on <%= @peer_comparison.peer_count %> students in your grade level
          </p>
        </div>
      <% else %>
        <p class="text-gray-500 italic">Peer comparison data not available yet.</p>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp format_hour(hour) do
    time = Time.new!(trunc(hour), 0, 0)
    Calendar.strftime(time, "%I:00 %p")
  end

  defp format_velocity(velocity) do
    cond do
      velocity > 1.0 -> "Fast (#{Float.round(velocity, 2)} pts/session)"
      velocity > 0.3 -> "Steady (#{Float.round(velocity, 2)} pts/session)"
      velocity > -0.3 -> "Stable"
      true -> "Needs attention (#{Float.round(velocity, 2)} pts/session)"
    end
  end

  defp format_difficulty(adjustment) do
    case adjustment do
      :increase_slightly -> "Increase Slightly ↑"
      :decrease_slightly -> "Decrease Slightly ↓"
      _ -> "Maintain Current Level →"
    end
  end

  defp format_study_method(method) do
    case method do
      :spaced_repetition -> "Spaced Repetition"
      :practice_problems -> "Practice Problems"
      :daily_practice -> "Daily Practice"
      :challenge_problems -> "Challenge Problems"
      :review_fundamentals -> "Review Fundamentals"
      _ -> to_string(method) |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp weakness_badge_class(score) do
    cond do
      score >= 0.7 -> "bg-red-100 text-red-800"
      score >= 0.5 -> "bg-orange-100 text-orange-800"
      score >= 0.3 -> "bg-yellow-100 text-yellow-800"
      true -> "bg-green-100 text-green-800"
    end
  end

  defp weakness_label(score) do
    cond do
      score >= 0.7 -> "Needs Work"
      score >= 0.5 -> "Moderate"
      score >= 0.3 -> "Minor"
      true -> "Strong"
    end
  end

  defp format_comparison_delta(user_score, peer_median) do
    delta = user_score - peer_median

    if delta >= 0 do
      "+#{Float.round(delta, 1)}"
    else
      "#{Float.round(delta, 1)}"
    end
  end
end
