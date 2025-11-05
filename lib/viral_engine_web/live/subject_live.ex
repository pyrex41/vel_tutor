defmodule ViralEngineWeb.SubjectLive do
  @moduledoc """
  LiveView for subject pages with mini-leaderboards and real-time updates.
  """

  use ViralEngineWeb, :live_view
  alias ViralEngine.LeaderboardContext
  import ViralEngineWeb.Components.MiniLeaderboard

  @impl true
  def mount(%{"subject" => subject}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Subscribe to leaderboard updates for this subject
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "leaderboard:#{subject}")
    end

    # Get initial leaderboard data
    daily_leaderboard = LeaderboardContext.get_mini_leaderboard(subject, :daily)
    weekly_leaderboard = LeaderboardContext.get_mini_leaderboard(subject, :weekly)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:subject, subject)
      |> assign(:period, :daily)
      |> assign(:daily_leaderboard, daily_leaderboard)
      |> assign(:weekly_leaderboard, weekly_leaderboard)
      |> assign(:current_leaderboard, daily_leaderboard)

    {:ok, socket}
  end

  @impl true
  def handle_info({:leaderboard_updated, %{daily: daily, weekly: weekly, subject: subject}}, socket) do
    if socket.assigns.subject == subject do
      current =
        if socket.assigns.period == :daily, do: daily, else: weekly

      {:noreply,
       socket
       |> assign(:daily_leaderboard, daily)
       |> assign(:weekly_leaderboard, weekly)
       |> assign(:current_leaderboard, current)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:cache_invalidated, _subject}, socket) do
    # Cache was invalidated, refresh leaderboard
    send(self(), :refresh_leaderboard)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh_leaderboard, socket) do
    # Refresh leaderboard data (force cache bypass)
    daily = LeaderboardContext.get_mini_leaderboard(socket.assigns.subject, :daily)
    weekly = LeaderboardContext.get_mini_leaderboard(socket.assigns.subject, :weekly)

    current =
      if socket.assigns.period == :daily, do: daily, else: weekly

    {:noreply,
     socket
     |> assign(:daily_leaderboard, daily)
     |> assign(:weekly_leaderboard, weekly)
     |> assign(:current_leaderboard, current)}
  end

  @impl true
  def handle_event("toggle_period", %{"period" => period}, socket) do
    new_period = String.to_existing_atom(period)

    current_leaderboard =
      if new_period == :daily,
        do: socket.assigns.daily_leaderboard,
        else: socket.assigns.weekly_leaderboard

    {:noreply,
     socket
     |> assign(:period, new_period)
     |> assign(:current_leaderboard, current_leaderboard)}
  end

  @impl true
  def handle_event("view_full_leaderboard", %{"subject" => subject}, socket) do
    {:noreply, push_navigate(socket, to: "/leaderboard?subject=#{subject}")}
  end

  @impl true
  def handle_event("start_practice", _params, socket) do
    {:noreply, push_navigate(socket, to: "/practice?subject=#{socket.assigns.subject}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background" role="main">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Page Header -->
        <div class="mb-8">
          <h1 class="text-4xl font-bold text-foreground mb-2">
            <%= String.capitalize(@subject) %> Practice
          </h1>
          <p class="text-lg text-muted-foreground">
            Master <%= @subject %> with interactive practice sessions
          </p>
        </div>

        <div class="grid lg:grid-cols-3 gap-8">
          <!-- Main Content Area -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Practice Session Card -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
              <div class="flex items-start justify-between mb-6">
                <div>
                  <h2 class="text-2xl font-semibold text-foreground mb-2">
                    Ready to Practice?
                  </h2>
                  <p class="text-muted-foreground">
                    Start a new <%= @subject %> session and compete for the top spot!
                  </p>
                </div>
                <svg
                  class="w-16 h-16 text-primary/20"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                  aria-hidden="true"
                >
                  <path d="M10.394 2.08a1 1 0 00-.788 0l-7 3a1 1 0 000 1.84L5.25 8.051a.999.999 0 01.356-.257l4-1.714a1 1 0 11.788 1.838L7.667 9.088l1.94.831a1 1 0 00.787 0l7-3a1 1 0 000-1.838l-7-3zM3.31 9.397L5 10.12v4.102a8.969 8.969 0 00-1.05-.174 1 1 0 01-.89-.89 11.115 11.115 0 01.25-3.762zM9.3 16.573A9.026 9.026 0 007 14.935v-3.957l1.818.78a3 3 0 002.364 0l5.508-2.361a11.026 11.026 0 01.25 3.762 1 1 0 01-.89.89 8.968 8.968 0 00-5.35 2.524 1 1 0 01-1.4 0zM6 18a1 1 0 001-1v-2.065a8.935 8.935 0 00-2-.712V17a1 1 0 001 1z" />
                </svg>
              </div>

              <!-- Start Button -->
              <button
                phx-click="start_practice"
                class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-lg shadow-md hover:shadow-lg transition-all duration-200 flex items-center justify-center space-x-2"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span class="text-lg">Start Practice Session</span>
              </button>
            </div>

            <!-- Subject Info / Tips -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
              <h3 class="text-lg font-semibold text-foreground mb-3">Tips for Success</h3>
              <ul class="space-y-2 text-muted-foreground">
                <li class="flex items-start space-x-2">
                  <svg
                    class="w-5 h-5 text-primary flex-shrink-0 mt-0.5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  <span>Practice daily to maintain your streak</span>
                </li>
                <li class="flex items-start space-x-2">
                  <svg
                    class="w-5 h-5 text-primary flex-shrink-0 mt-0.5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  <span>Challenge friends to boost your learning</span>
                </li>
                <li class="flex items-start space-x-2">
                  <svg
                    class="w-5 h-5 text-primary flex-shrink-0 mt-0.5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  <span>Review incorrect answers to improve faster</span>
                </li>
              </ul>
            </div>
          </div>

          <!-- Sidebar: Mini Leaderboard -->
          <div class="lg:col-span-1">
            <.mini_leaderboard
              subject={@subject}
              period={@period}
              entries={@current_leaderboard}
              current_user_id={@user.id}
              show_period_toggle={true}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
