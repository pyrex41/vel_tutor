defmodule ViralEngineWeb.ParentProgressLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.ParentShareContext
  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case ParentShareContext.get_share_by_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(:stage, :error)
         |> assign(:error_message, "Progress card not found")
         |> assign(:share, nil)}

      share ->
        # Mark as viewed
        ParentShareContext.mark_viewed(token)

        socket =
          socket
          |> assign(:stage, :view)
          |> assign(:share, share)
          |> assign(:progress_data, share.progress_data)
          |> assign(:share_link, ParentShareContext.generate_share_link(share))
          |> assign(:show_signup_modal, false)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("show_signup", _params, socket) do
    {:noreply, assign(socket, :show_signup_modal, true)}
  end

  @impl true
  def handle_event("close_signup", _params, socket) do
    {:noreply, assign(socket, :show_signup_modal, false)}
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    {:noreply, put_flash(socket, :success, "Link copied to clipboard!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-4xl mx-auto">
        <%= if @stage == :error do %>
          <!-- Error State -->
          <div class="text-center py-12">
            <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-muted mb-4">
              <svg class="h-12 w-12 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-foreground mb-2">Progress Card Not Found</h3>
            <p class="text-muted-foreground"><%= @error_message %></p>
          </div>
        <% else %>
          <!-- Progress View -->
          <div class="text-center mb-8">
            <h1 class="text-3xl font-bold text-foreground mb-2">Student Progress</h1>
            <p class="text-muted-foreground">Track your child's learning journey</p>
          </div>

          <!-- Progress Overview -->
          <%= if @progress_data do %>
            <div class="grid md:grid-cols-3 gap-6 mb-8">
              <div class="bg-card text-card-foreground rounded-lg border p-6">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-sm font-medium text-muted-foreground">Average Score</span>
                  <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                </div>
                <p class="text-3xl font-bold text-foreground"><%= round(@progress_data["average_score"] || 0) %>%</p>
              </div>

              <div class="bg-card text-card-foreground rounded-lg border p-6">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-sm font-medium text-muted-foreground">Sessions Completed</span>
                  <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <p class="text-3xl font-bold text-foreground"><%= @progress_data["sessions_completed"] || 0 %></p>
              </div>

              <div class="bg-card text-card-foreground rounded-lg border p-6">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-sm font-medium text-muted-foreground">Current Streak</span>
                  <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </div>
                <p class="text-3xl font-bold text-foreground"><%= @progress_data["current_streak"] || 0 %></p>
              </div>
            </div>

            <!-- Subject Performance -->
            <%= if @progress_data["subject_scores"] do %>
              <div class="bg-card text-card-foreground rounded-lg border p-6 mb-8">
                <h2 class="text-xl font-semibold text-foreground mb-4">Subject Performance</h2>
                <div class="space-y-4">
                  <%= for {subject, score} <- @progress_data["subject_scores"] do %>
                    <div>
                      <div class="flex items-center justify-between mb-2">
                        <span class="text-sm font-medium text-foreground capitalize"><%= subject %></span>
                        <span class={"text-sm font-bold #{if(score >= 80, do: "text-green-600", else: if(score >= 60, do: "text-yellow-600", else: "text-red-600"))}"}>
                          <%= round(score) %>%
                        </span>
                      </div>
                      <div class="w-full bg-secondary rounded-full h-3">
                        <div
                          class={"h-3 rounded-full transition-all duration-500 #{if(score >= 80, do: "bg-green-500", else: if(score >= 60, do: "bg-yellow-500", else: "bg-red-500"))}"}
                          style={"width: #{score}%"}
                        ></div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Recent Activities -->
            <%= if @progress_data["recent_activities"] do %>
              <div class="bg-card text-card-foreground rounded-lg border p-6 mb-8">
                <h2 class="text-xl font-semibold text-foreground mb-4">Recent Activities</h2>
                <div class="space-y-3">
                  <%= for activity <- @progress_data["recent_activities"] do %>
                    <div class="flex items-start space-x-3 p-3 bg-muted rounded-lg">
                      <div class="flex-shrink-0 w-8 h-8 bg-primary rounded-full flex items-center justify-center">
                        <span class="text-xs font-medium text-primary-foreground">
                          <%= String.first(activity["type"] || "A") %>
                        </span>
                      </div>
                      <div class="flex-1">
                        <p class="text-sm font-medium text-foreground"><%= activity["description"] %></p>
                        <p class="text-xs text-muted-foreground">
                          <%= Calendar.strftime(activity["timestamp"], "%b %d, %H:%M") %>
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>

          <!-- Share Section -->
          <div class="bg-card text-card-foreground rounded-lg border p-6 mb-8">
            <h2 class="text-xl font-semibold text-foreground mb-4">Share Progress</h2>
            <p class="text-muted-foreground mb-4">Share this progress card with teachers or family members.</p>

            <div class="flex flex-col sm:flex-row gap-3">
              <input
                type="text"
                value={@share_link}
                readonly
                class="flex-1 px-3 py-2 bg-background border border-input rounded-md text-sm"
                aria-label="Share link"
              />
              <button
                phx-click="copy_link"
                class="px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md text-sm font-medium transition-colors"
                aria-label="Copy share link"
              >
                Copy Link
              </button>
            </div>
          </div>

          <!-- Call to Action -->
          <div class="text-center">
            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <h2 class="text-xl font-semibold text-foreground mb-2">Ready to Help Your Child Learn?</h2>
              <p class="text-muted-foreground mb-4">Create a parent account to get detailed insights and track multiple children.</p>
              <button
                phx-click="show_signup"
                class="bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors"
                aria-label="Sign up for parent account"
              >
                Create Parent Account
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Signup Modal -->
    <%= if @show_signup_modal do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_signup" role="dialog" aria-modal="true" aria-labelledby="signup-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
          <h3 id="signup-modal-title" class="text-xl font-bold text-foreground mb-4">Create Parent Account</h3>
          <p class="text-muted-foreground mb-6">Get full access to your child's progress and learning insights.</p>

          <div class="space-y-4">
            <button
              class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
              aria-label="Sign up with email"
            >
              Sign Up with Email
            </button>

            <button
              phx-click="close_signup"
              class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
              aria-label="Close signup modal"
            >
              Maybe Later
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
