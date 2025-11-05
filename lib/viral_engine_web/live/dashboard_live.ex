defmodule ViralEngineWeb.DashboardLive do
  use ViralEngineWeb, :live_view

  alias ViralEngine.Presence
  alias ViralEngine.Accounts
  alias ViralEngine.PresenceTracker

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      Presence.track_global(user.id, socket)
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:global")
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:subjects")
    end

    {:ok,
     assign(socket,
       user: user,
       global_count: Presence.list_global(),
       subject_counts: %{"math" => 0, "science" => 0}
     )}
  end

  @impl true
  def handle_info({:presence_diff, topic, _diff}, socket) do
    case topic do
      "global" ->
        global_count = Presence.list_global()
        {:noreply, assign(socket, global_count: global_count)}

      "subject:" <> subject ->
        subject_count = Presence.list_subject(subject)
        current_counts = socket.assigns.subject_counts
        updated_counts = Map.put(current_counts, subject, subject_count)
        {:noreply, assign(socket, subject_counts: updated_counts)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_opt_out", _params, socket) do
    user = socket.assigns.user
    new_opt_out = !user.presence_opt_out
    {:ok, updated_user} = Accounts.update_user(user, %{presence_opt_out: new_opt_out})

    if new_opt_out do
      PresenceTracker.untrack_user(user.id, nil, "global_users")
    else
      Presence.track_global(self(), user.id, %{name: user.name || "Anonymous"})
    end

    {:noreply, assign(socket, user: updated_user)}
  end

  @impl true
  def handle_event("join_subject", %{"subject" => subject}, socket) do
    user_id = socket.assigns.user.id

    Presence.track_subject(self(), user_id, subject, %{
      name: socket.assigns.user.name || "Anonymous"
    })

    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "presence:subjects",
      {:presence_diff, "subject:#{subject}", %{}}
    )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-background min-h-screen py-8 px-4" role="main">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-foreground mb-2">Dashboard</h1>
          <p class="text-muted-foreground">Welcome back, <%= @user.name || "Student" %>! Here's what's happening.</p>
        </div>

        <!-- Quick Actions -->
        <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <a href="/diagnostic" class="bg-card text-card-foreground rounded-lg border p-6 hover:shadow-md transition-all hover:scale-[1.02] block" aria-label="Start diagnostic assessment">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 rounded-lg bg-primary flex items-center justify-center">
                <svg class="w-6 h-6 text-primary-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
              </div>
              <div>
                <h3 class="font-semibold text-foreground">Take Assessment</h3>
                <p class="text-sm text-muted-foreground">Check your progress</p>
              </div>
            </div>
          </a>

          <a href="/practice" class="bg-card text-card-foreground rounded-lg border p-6 hover:shadow-md transition-all hover:scale-[1.02] block" aria-label="Start practice session">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 rounded-lg bg-primary flex items-center justify-center">
                <svg class="w-6 h-6 text-primary-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
              <div>
                <h3 class="font-semibold text-foreground">Practice</h3>
                <p class="text-sm text-muted-foreground">Improve your skills</p>
              </div>
            </div>
          </a>

          <a href="/study" class="bg-card text-card-foreground rounded-lg border p-6 hover:shadow-md transition-all hover:scale-[1.02] block" aria-label="Join study session">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 rounded-lg bg-primary flex items-center justify-center">
                <svg class="w-6 h-6 text-primary-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
              <div>
                <h3 class="font-semibold text-foreground">Study Together</h3>
                <p class="text-sm text-muted-foreground">Join a group session</p>
              </div>
            </div>
          </a>

          <a href="/flashcards" class="bg-card text-card-foreground rounded-lg border p-6 hover:shadow-md transition-all hover:scale-[1.02] block" aria-label="Study flashcards">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 rounded-lg bg-primary flex items-center justify-center">
                <svg class="w-6 h-6 text-primary-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 7V3a2 2 0 012-2z" />
                </svg>
              </div>
              <div>
                <h3 class="font-semibold text-foreground">Flashcards</h3>
                <p class="text-sm text-muted-foreground">Review key concepts</p>
              </div>
            </div>
          </a>
        </div>

        <!-- Settings & Privacy -->
        <div class="bg-card text-card-foreground rounded-lg border p-6 mb-8">
          <h2 class="text-xl font-semibold text-foreground mb-4">Privacy Settings</h2>
          <div class="flex items-center justify-between">
            <div>
              <h3 class="font-medium text-foreground">Presence Tracking</h3>
              <p class="text-sm text-muted-foreground">Allow others to see when you're online and studying</p>
            </div>
            <label class="relative inline-flex items-center cursor-pointer">
              <input type="checkbox" phx-click="toggle_opt_out" checked={@user.presence_opt_out} class="sr-only peer">
              <div class="w-11 h-6 bg-muted peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary/25 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
            </label>
          </div>
        </div>

        <!-- Presence Section -->
        <div class="grid lg:grid-cols-2 gap-8">
          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <h2 class="text-xl font-semibold text-foreground mb-4">Global Activity</h2>
            <.live_component module={ViralEngineWeb.GlobalPresenceLive} id="global-presence" />
          </div>

          <div class="space-y-6">
            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <h2 class="text-xl font-semibold text-foreground mb-4">Subject Communities</h2>
              <.live_component module={ViralEngineWeb.SubjectPresenceLive} id="math-presence" subject_id="math" />
              <.live_component module={ViralEngineWeb.SubjectPresenceLive} id="science-presence" subject_id="science" />
            </div>

            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <h2 class="text-xl font-semibold text-foreground mb-4">Quick Join</h2>
              <div class="space-y-3">
                <button phx-click="join_subject" phx-value-subject="math"
                  class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-3 rounded-md transition-colors"
                  aria-label="Join math study community">
                  Join Math Community
                </button>
                <button phx-click="join_subject" phx-value-subject="science"
                  class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-3 rounded-md transition-colors"
                  aria-label="Join science study community">
                  Join Science Community
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
