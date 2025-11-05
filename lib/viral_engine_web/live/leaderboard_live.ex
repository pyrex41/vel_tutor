defmodule ViralEngineWeb.LeaderboardLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.LeaderboardContext
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to leaderboard updates
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "leaderboard:updates")

      # Refresh leaderboard every 30 seconds
      :timer.send_interval(30_000, self(), :refresh_leaderboard)
    end

    # Default view settings
    scope = :global
    metric = :total_score
    time_period = 7
    subject = "math"
    grade_level = 5

    # Get leaderboard
    leaderboard = get_leaderboard(scope, %{
      metric: metric,
      time_period: time_period,
      subject: subject,
      grade_level: grade_level
    })

    # Get user's rank
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(user.id, scope, %{
      metric: metric,
      time_period: time_period
    })

    # Get user's percentile
    {:ok, percentile} = LeaderboardContext.get_user_percentile(user.id, scope, %{
      metric: metric,
      time_period: time_period
    })

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:scope, scope)
      |> assign(:metric, metric)
      |> assign(:time_period, time_period)
      |> assign(:subject, subject)
      |> assign(:grade_level, grade_level)
      |> assign(:user_rank, user_rank)
      |> assign(:rank_status, rank_status)
      |> assign(:percentile, percentile)
      |> assign(:show_invite_modal, false)
      |> stream(:leaderboard_entries, leaderboard, id: fn entry -> "user-#{entry.user_id}" end)

    {:ok, socket}
  end

  @impl true
  def handle_event("change_scope", %{"scope" => scope}, socket) do
    new_scope = String.to_existing_atom(scope)

    opts = %{
      metric: socket.assigns.metric,
      time_period: socket.assigns.time_period,
      subject: socket.assigns.subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(new_scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, new_scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, new_scope, opts)

    {:noreply,
     socket
     |> assign(:scope, new_scope)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("change_metric", %{"metric" => metric}, socket) do
    new_metric = String.to_existing_atom(metric)

    opts = %{
      metric: new_metric,
      time_period: socket.assigns.time_period,
      subject: socket.assigns.subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:metric, new_metric)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("change_time_period", %{"period" => period}, socket) do
    new_period = String.to_integer(period)

    opts = %{
      metric: socket.assigns.metric,
      time_period: new_period,
      subject: socket.assigns.subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:time_period, new_period)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("change_subject", %{"subject" => subject}, socket) do
    opts = %{
      metric: socket.assigns.metric,
      time_period: socket.assigns.time_period,
      subject: subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:subject, subject)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("change_grade_level", %{"grade" => grade}, socket) do
    new_grade = String.to_integer(grade)

    opts = %{
      metric: socket.assigns.metric,
      time_period: socket.assigns.time_period,
      subject: socket.assigns.subject,
      grade_level: new_grade
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:grade_level, new_grade)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("toggle_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, !socket.assigns.show_invite_modal)}
  end

  @impl true
  def handle_event("copy_invite_link", _params, socket) do
    {:noreply, put_flash(socket, :success, "Invite link copied! Share to climb the leaderboard together.")}
  end

  @impl true
  def handle_event("challenge_leader", %{"user_id" => target_user_id}, socket) do
    Logger.info("User #{socket.assigns.user_id} challenging user #{target_user_id}")

    {:noreply, put_flash(socket, :info, "Challenge sent!")}
  end

  @impl true
  def handle_info(:refresh_leaderboard, socket) do
    opts = %{
      metric: socket.assigns.metric,
      time_period: socket.assigns.time_period,
      subject: socket.assigns.subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_info({:leaderboard_update, _data}, socket) do
    # Refresh leaderboard on PubSub event
    send(self(), :refresh_leaderboard)
    {:noreply, socket}
  end

  # Helper functions

  defp get_leaderboard(scope, opts) do
    case scope do
      :global ->
        LeaderboardContext.get_global_leaderboard(opts)

      :subject ->
        LeaderboardContext.get_subject_leaderboard(opts[:subject] || "math", opts)

      :cohort ->
        LeaderboardContext.get_cohort_leaderboard(opts[:grade_level] || 5, opts)

      _ ->
        LeaderboardContext.get_global_leaderboard(opts)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-4">Leaderboard</h1>

          <!-- Filters -->
          <div class="bg-white border border-gray-200 rounded-lg p-4">
            <div class="grid grid-cols-2 lg:grid-cols-5 gap-4">
              <!-- Scope -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">View</label>
                <select
                  phx-change="change_scope"
                  name="scope"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="global" selected={@scope == :global}>Global</option>
                  <option value="subject" selected={@scope == :subject}>By Subject</option>
                  <option value="cohort" selected={@scope == :cohort}>By Grade</option>
                </select>
              </div>

              <!-- Metric -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Metric</label>
                <select
                  phx-change="change_metric"
                  name="metric"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="total_score" selected={@metric == :total_score}>Score</option>
                  <option value="streak_days" selected={@metric == :streak_days}>Streak</option>
                  <option value="sessions_completed" selected={@metric == :sessions_completed}>Sessions</option>
                  <option value="xp_points" selected={@metric == :xp_points}>XP Points</option>
                </select>
              </div>

              <!-- Time Period -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Period</label>
                <select
                  phx-change="change_time_period"
                  name="period"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="1" selected={@time_period == 1}>Today</option>
                  <option value="7" selected={@time_period == 7}>This Week</option>
                  <option value="30" selected={@time_period == 30}>This Month</option>
                  <option value="365" selected={@time_period == 365}>All Time</option>
                </select>
              </div>

              <!-- Subject (if scope is subject) -->
              <%= if @scope == :subject do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Subject</label>
                  <select
                    phx-change="change_subject"
                    name="subject"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="math" selected={@subject == "math"}>Math</option>
                    <option value="english" selected={@subject == "english"}>English</option>
                    <option value="science" selected={@subject == "science"}>Science</option>
                  </select>
                </div>
              <% end %>

              <!-- Grade Level (if scope is cohort) -->
              <%= if @scope == :cohort do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Grade</label>
                  <select
                    phx-change="change_grade_level"
                    name="grade"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <%= for grade <- 1..12 do %>
                      <option value={grade} selected={@grade_level == grade}>Grade <%= grade %></option>
                    <% end %>
                  </select>
                </div>
              <% end %>

              <!-- Invite Button -->
              <div class="flex items-end">
                <button
                  phx-click="toggle_invite_modal"
                  class="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
                >
                  Invite Friends
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Your Rank Card -->
        <div class="bg-gradient-to-r from-blue-500 to-blue-600 rounded-lg shadow-lg p-6 mb-6 text-white">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-lg font-semibold mb-2">Your Rank</h3>
              <div class="flex items-baseline gap-3">
                <span class="text-4xl font-bold">
                  <%= if @rank_status == :ok, do: "##{@user_rank}", else: "Unranked" %>
                </span>
                <%= if @rank_status == :ok do %>
                  <span class="text-blue-100">Top <%= round(@percentile) %>%</span>
                <% end %>
              </div>
            </div>
            <div class="text-right">
              <div class="text-blue-100 text-sm mb-1">Current <%= metric_name(@metric) %></div>
              <div class="text-2xl font-bold">-</div>
            </div>
          </div>
        </div>

        <!-- Leaderboard Table -->
        <div class="bg-white border border-gray-200 rounded-lg shadow-sm overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th class="px-6 py-4 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Rank</th>
                  <th class="px-6 py-4 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">User</th>
                  <th class="px-6 py-4 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider"><%= metric_name(@metric) %></th>
                  <th class="px-6 py-4 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Change</th>
                  <th class="px-6 py-4 text-right text-xs font-semibold text-gray-600 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody id="leaderboard_entries" phx-update="stream" class="divide-y divide-gray-200">
                <tr :for={{id, entry} <- @streams.leaderboard_entries} id={id} class={[
                  "hover:bg-gray-50 transition-colors",
                  entry.user_id == @user_id && "bg-blue-50"
                ]}>
                  <!-- Rank with Medal -->
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-2">
                      <%= case entry.rank do %>
                        <% 1 -> %>
                          <span class="text-2xl">🥇</span>
                        <% 2 -> %>
                          <span class="text-2xl">🥈</span>
                        <% 3 -> %>
                          <span class="text-2xl">🥉</span>
                        <% _ -> %>
                          <span class="text-lg font-semibold text-gray-700">#<%= entry.rank %></span>
                      <% end %>
                    </div>
                  </td>

                  <!-- User Info -->
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 rounded-full bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center text-white font-semibold">
                        <%= String.first(entry.username || "U") %>
                      </div>
                      <div>
                        <div class="font-medium text-gray-900">
                          <%= entry.username || "User #{entry.user_id}" %>
                          <%= if entry.user_id == @user_id do %>
                            <span class="ml-2 text-xs text-blue-600 font-semibold">(You)</span>
                          <% end %>
                        </div>
                        <%= if entry.streak_days && entry.streak_days > 0 do %>
                          <div class="text-sm text-gray-500">
                            🔥 <%= entry.streak_days %> day streak
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </td>

                  <!-- Score -->
                  <td class="px-6 py-4">
                    <div class="text-lg font-semibold text-gray-900">
                      <%= format_metric_value(entry.score, @metric) %>
                    </div>
                  </td>

                  <!-- Change -->
                  <td class="px-6 py-4">
                    <%= if entry.rank_change && entry.rank_change != 0 do %>
                      <div class={[
                        "flex items-center gap-1 text-sm font-medium",
                        entry.rank_change > 0 && "text-green-600",
                        entry.rank_change < 0 && "text-red-600"
                      ]}>
                        <%= if entry.rank_change > 0 do %>
                          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M5.293 9.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 7.414V15a1 1 0 11-2 0V7.414L6.707 9.707a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
                          </svg>
                          +<%= entry.rank_change %>
                        <% else %>
                          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M14.707 10.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 12.586V5a1 1 0 012 0v7.586l2.293-2.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                          </svg>
                          <%= entry.rank_change %>
                        <% end %>
                      </div>
                    <% else %>
                      <span class="text-sm text-gray-400">-</span>
                    <% end %>
                  </td>

                  <!-- Actions -->
                  <td class="px-6 py-4 text-right">
                    <%= if entry.user_id != @user_id do %>
                      <button
                        phx-click="challenge_leader"
                        phx-value-user_id={entry.user_id}
                        class="inline-flex items-center px-3 py-1.5 text-sm font-medium text-blue-600 hover:text-blue-700 hover:bg-blue-50 rounded-lg transition-colors"
                      >
                        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                        </svg>
                        Challenge
                      </button>
                    <% end %>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Invite Modal -->
      <%= if @show_invite_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h3 class="text-xl font-bold text-gray-900 mb-4">Invite Friends to Compete</h3>
            <p class="text-gray-600 mb-6">Share your invite link and climb the leaderboard together!</p>

            <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
              <code class="text-sm text-gray-700 break-all">
                https://veltutor.com/invite/<%= @user.id %>
              </code>
            </div>

            <div class="flex gap-3">
              <button
                phx-click="copy_invite_link"
                class="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
              >
                Copy Link
              </button>

              <button
                phx-click="toggle_invite_modal"
                class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp format_metric_value(value, metric) do
    case metric do
      :total_score -> "#{value} pts"
      :streak_days -> "#{value} days"
      :sessions_completed -> "#{value} sessions"
      :xp_points -> "#{value} XP"
      _ -> "#{value}"
    end
  end

  defp metric_name(metric) do
    case metric do
      :total_score -> "Score"
      :streak_days -> "Streak"
      :sessions_completed -> "Sessions"
      :xp_points -> "XP"
      _ -> "Value"
    end
  end
end
