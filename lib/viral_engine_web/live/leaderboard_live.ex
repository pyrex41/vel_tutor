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
    leaderboard =
      get_leaderboard(scope, %{
        metric: metric,
        time_period: time_period,
        subject: subject,
        grade_level: grade_level
      })

    # Get user's rank
    {rank_status, user_rank} =
      LeaderboardContext.get_user_rank(user.id, scope, %{
        metric: metric,
        time_period: time_period
      })

    # Get user's percentile
    {:ok, percentile} =
      LeaderboardContext.get_user_percentile(user.id, scope, %{
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
      |> assign(:leaderboard_empty, Enum.empty?(leaderboard))
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

    {rank_status, user_rank} =
      LeaderboardContext.get_user_rank(socket.assigns.user_id, new_scope, opts)

    {:ok, percentile} =
      LeaderboardContext.get_user_percentile(socket.assigns.user_id, new_scope, opts)

    {:noreply,
     socket
     |> assign(:scope, new_scope)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> assign(:leaderboard_empty, Enum.empty?(leaderboard))
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

    {rank_status, user_rank} =
      LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)

    {:ok, percentile} =
      LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:metric, new_metric)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> assign(:leaderboard_empty, Enum.empty?(leaderboard))
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

    {rank_status, user_rank} =
      LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)

    {:ok, percentile} =
      LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:time_period, new_period)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> assign(:leaderboard_empty, Enum.empty?(leaderboard))
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

    {rank_status, user_rank} =
      LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)

    {:ok, percentile} =
      LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:subject, subject)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> assign(:leaderboard_empty, Enum.empty?(leaderboard))
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

    {rank_status, user_rank} =
      LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)

    {:ok, percentile} =
      LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:grade_level, new_grade)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> assign(:leaderboard_empty, Enum.empty?(leaderboard))
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("toggle_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, !socket.assigns.show_invite_modal)}
  end

  @impl true
  def handle_event("copy_invite_link", _params, socket) do
    {:noreply,
     put_flash(socket, :success, "Invite link copied! Share to climb the leaderboard together.")}
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

    {rank_status, user_rank} =
      LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)

    {:ok, percentile} =
      LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> assign(:leaderboard_empty, Enum.empty?(leaderboard))
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
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-8 px-4">
      <div class="max-w-7xl mx-auto">
        <!-- Header Section -->
        <div class="bg-white rounded-xl shadow-lg p-6 mb-6">
          <div class="flex items-center justify-between mb-6">
            <div>
              <h1 class="text-4xl font-bold text-gray-900 mb-2">🏆 Leaderboard</h1>
              <p class="text-gray-600">Compete with others and track your progress</p>
            </div>
            <button
              phx-click="toggle_invite_modal"
              class="bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold px-6 py-3 rounded-lg shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105"
            >
              <div class="flex items-center space-x-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                <span>Invite Friends</span>
              </div>
            </button>
          </div>

          <!-- User Stats Cards -->
          <div class="grid md:grid-cols-3 gap-4 mb-6">
            <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-4 border-2 border-blue-200">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-gray-600 mb-1">Your Rank</p>
                  <p class="text-3xl font-bold text-gray-900">
                    <%= if @rank_status == :ranked, do: "##{@user_rank}", else: "Unranked" %>
                  </p>
                </div>
                <div class="flex items-center justify-center w-12 h-12 rounded-full bg-blue-600">
                  <svg class="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-r from-green-50 to-teal-50 rounded-lg p-4 border-2 border-green-200">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-gray-600 mb-1">Percentile</p>
                  <p class="text-3xl font-bold text-gray-900"><%= Float.round(@percentile, 1) %>%</p>
                </div>
                <div class="flex items-center justify-center w-12 h-12 rounded-full bg-green-600">
                  <svg class="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M12 7a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0V8.414l-4.293 4.293a1 1 0 01-1.414 0L8 10.414l-4.293 4.293a1 1 0 01-1.414-1.414l5-5a1 1 0 011.414 0L11 10.586 14.586 7H12z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg p-4 border-2 border-purple-200">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-gray-600 mb-1">Current Metric</p>
                  <p class="text-2xl font-bold text-gray-900"><%= metric_name(@metric) %></p>
                </div>
                <div class="flex items-center justify-center w-12 h-12 rounded-full bg-purple-600">
                  <svg class="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5zM8 7a1 1 0 011-1h2a1 1 0 011 1v9a1 1 0 01-1 1H9a1 1 0 01-1-1V7zM14 4a1 1 0 011-1h2a1 1 0 011 1v12a1 1 0 01-1 1h-2a1 1 0 01-1-1V4z" />
                  </svg>
                </div>
              </div>
            </div>
          </div>

          <!-- Filters -->
          <div class="grid md:grid-cols-5 gap-3">
            <!-- Scope -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Scope</label>
              <select
                phx-change="change_scope"
                name="scope"
                class="w-full px-3 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="global" selected={@scope == :global}>🌍 Global</option>
                <option value="subject" selected={@scope == :subject}>📚 Subject</option>
                <option value="cohort" selected={@scope == :cohort}>🎓 Cohort</option>
              </select>
            </div>

            <!-- Metric -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Metric</label>
              <select
                phx-change="change_metric"
                name="metric"
                class="w-full px-3 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="total_score" selected={@metric == :total_score}>Score</option>
                <option value="accuracy" selected={@metric == :accuracy}>Accuracy</option>
                <option value="streak" selected={@metric == :streak}>Streak</option>
                <option value="speed" selected={@metric == :speed}>Speed</option>
              </select>
            </div>

            <!-- Time Period -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Period</label>
              <select
                phx-change="change_time_period"
                name="period"
                class="w-full px-3 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="1" selected={@time_period == 1}>Today</option>
                <option value="7" selected={@time_period == 7}>This Week</option>
                <option value="30" selected={@time_period == 30}>This Month</option>
                <option value="365" selected={@time_period == 365}>This Year</option>
              </select>
            </div>

            <!-- Subject (if scope is subject) -->
            <%= if @scope == :subject do %>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Subject</label>
                <select
                  phx-change="change_subject"
                  name="subject"
                  class="w-full px-3 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <option value="math" selected={@subject == "math"}>Math</option>
                  <option value="science" selected={@subject == "science"}>Science</option>
                  <option value="english" selected={@subject == "english"}>English</option>
                  <option value="history" selected={@subject == "history"}>History</option>
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
                  class="w-full px-3 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <%= for grade <- 1..12 do %>
                    <option value={grade} selected={@grade_level == grade}>Grade <%= grade %></option>
                  <% end %>
                </select>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Leaderboard Table -->
        <div class="bg-white rounded-xl shadow-lg overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gradient-to-r from-blue-600 to-indigo-600 text-white">
                <tr>
                  <th class="px-6 py-4 text-left text-sm font-semibold">Rank</th>
                  <th class="px-6 py-4 text-left text-sm font-semibold">User</th>
                  <th class="px-6 py-4 text-left text-sm font-semibold">Score</th>
                  <th class="px-6 py-4 text-left text-sm font-semibold">Accuracy</th>
                  <th class="px-6 py-4 text-left text-sm font-semibold">Streak</th>
                  <th class="px-6 py-4 text-right text-sm font-semibold">Actions</th>
                </tr>
              </thead>
              <tbody id="leaderboard-entries" phx-update="stream" class="divide-y divide-gray-200">
                <tr
                  :for={{dom_id, entry} <- @streams.leaderboard_entries}
                  id={dom_id}
                  class={"hover:bg-blue-50 transition-colors duration-150 #{if entry.user_id == @user_id, do: "bg-blue-100 font-semibold"}"}
                >
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center space-x-2">
                      <%= rank_badge(entry.rank) %>
                      <span class="text-lg font-bold text-gray-900">#<%= entry.rank %></span>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center space-x-3">
                      <div class="flex-shrink-0 w-10 h-10 rounded-full bg-gradient-to-br from-blue-400 to-indigo-500 flex items-center justify-center text-white font-bold">
                        <%= entry.username |> String.slice(0, 1) |> String.upcase() %>
                      </div>
                      <div>
                        <p class="text-sm font-medium text-gray-900">
                          <%= entry.username %>
                          <%= if entry.user_id == @user_id do %>
                            <span class="ml-2 px-2 py-0.5 text-xs bg-blue-600 text-white rounded-full">You</span>
                          <% end %>
                        </p>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="text-lg font-semibold text-gray-900">
                      <%= format_metric_value(entry.score, :total_score) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="text-sm text-gray-700">
                      <%= format_metric_value(entry.accuracy, :accuracy) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center space-x-1">
                      <svg class="w-4 h-4 text-orange-500" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M12.395 2.553a1 1 0 00-1.45-.385c-.345.23-.614.558-.822.88-.214.33-.403.713-.57 1.116-.334.804-.614 1.768-.84 2.734a31.365 31.365 0 00-.613 3.58 2.64 2.64 0 01-.945-1.067c-.328-.68-.398-1.534-.398-2.654A1 1 0 005.05 6.05 6.981 6.981 0 003 11a7 7 0 1011.95-4.95c-.592-.591-.98-.985-1.348-1.467-.363-.476-.724-1.063-1.207-2.03zM12.12 15.12A3 3 0 017 13s.879.5 2.5.5c0-1 .5-4 1.25-4.5.5 1 .786 1.293 1.371 1.879A2.99 2.99 0 0113 13a2.99 2.99 0 01-.879 2.121z" clip-rule="evenodd" />
                      </svg>
                      <span class="text-sm font-semibold text-gray-900"><%= entry.streak %> days</span>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right">
                    <%= if entry.user_id != @user_id do %>
                      <button
                        phx-click="challenge_leader"
                        phx-value-user_id={entry.user_id}
                        class="inline-flex items-center px-3 py-1.5 bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 text-white text-sm font-medium rounded-lg shadow-sm hover:shadow-md transition-all duration-200"
                      >
                        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
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

        <!-- Empty State -->
        <%= if @leaderboard_empty do %>
          <div class="bg-white rounded-xl shadow-lg p-12 text-center">
            <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-gray-100 mb-4">
              <svg class="h-10 w-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No Entries Yet</h3>
            <p class="text-gray-600">Be the first to complete a practice session and claim the top spot!</p>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Invite Modal -->
    <%= if @show_invite_modal do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50" phx-click="toggle_invite_modal">
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8 transform transition-all" phx-click={Phoenix.LiveView.JS.exec("phx-remove", to: ".invite-modal")}>
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-blue-100 mb-4">
              <svg class="h-10 w-10 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <h3 class="text-2xl font-bold text-gray-900 mb-4">Invite Friends</h3>
            <p class="text-gray-600 mb-6">Share your invite link and climb the leaderboard together!</p>

            <div class="bg-gray-50 rounded-lg p-4 mb-4">
              <code class="text-sm text-gray-800 break-all">
                <%= ViralEngineWeb.Endpoint.url() %>/join/<%= @user.id %>
              </code>
            </div>

            <button
              phx-click="copy_invite_link"
              class="w-full bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold px-6 py-3 rounded-lg shadow-md hover:shadow-lg transition-all duration-200 mb-3"
            >
              Copy Invite Link
            </button>
            <button phx-click="toggle_invite_modal" class="text-gray-500 hover:text-gray-700 text-sm font-medium">
              Close
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Helper functions for template

  defp format_metric_value(value, metric) do
    case metric do
      :accuracy -> "#{Float.round(value * 100, 1)}%"
      :total_score -> Integer.to_string(round(value))
      :streak -> "#{value} days"
      :speed -> "#{Float.round(value, 1)}s"
      _ -> to_string(value)
    end
  end

  defp rank_badge(rank) when rank <= 3 do
    colors = %{1 => "🥇", 2 => "🥈", 3 => "🥉"}
    Map.get(colors, rank, "")
  end

  defp rank_badge(_rank), do: ""

  defp metric_name(metric) do
    case metric do
      :total_score -> "Total Score"
      :accuracy -> "Accuracy"
      :streak -> "Streak"
      :speed -> "Speed"
      _ -> "Unknown"
    end
  end
end
