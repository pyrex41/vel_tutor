defmodule ViralEngineWeb.ParentProgressLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{ParentShareContext, AttributionContext}
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

        # Create referral attribution link for this share
        referral_link = create_referral_link(share)

        socket =
          socket
          |> assign(:stage, :view)
          |> assign(:share, share)
          |> assign(:progress_data, share.progress_data)
          |> assign(:share_link, ParentShareContext.generate_share_link(share))
          |> assign(:referral_link, referral_link)
          |> assign(:show_signup_modal, false)
          |> assign(:show_referral_copied, false)

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
  def handle_event("copy_referral", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_referral_copied, true)
     |> put_flash(:success, "Referral link copied! Share with friends to get a free class pass.")}
  end

  # Private helpers

  defp create_referral_link(share) do
    target_url = "/signup?source=parent_referral&ref=#{share.share_token}"

    case AttributionContext.create_attribution_link(
      share.student_id,
      "parent_share",
      target_url,
      campaign: "progress_card_#{share.share_type}",
      metadata: %{
        share_id: share.id,
        share_token: share.share_token
      },
      expires_in_days: 30
    ) do
      {:ok, link} ->
        base_url = ViralEngineWeb.Endpoint.url()
        "#{base_url}/invite/#{link.link_token}"

      {:error, reason} ->
        Logger.error("Failed to create referral link: #{inspect(reason)}")
        # Fallback to direct signup link
        base_url = ViralEngineWeb.Endpoint.url()
        "#{base_url}/signup?ref=#{share.share_token}"
    end
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

          <!-- Referral Incentive Card -->
          <div class="bg-gradient-to-br from-amber-50 to-orange-50 border-2 border-amber-200 rounded-lg p-6 mb-8">
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0 w-12 h-12 bg-gradient-to-br from-amber-400 to-orange-500 rounded-full flex items-center justify-center">
                <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v13m0-13V6a2 2 0 112 2h-2zm0 0V5.5A2.5 2.5 0 109.5 8H12zm-7 4h14M5 12a2 2 0 110-4h14a2 2 0 110 4M5 12v7a2 2 0 002 2h10a2 2 0 002-2v-7" />
                </svg>
              </div>
              <div class="flex-1">
                <h3 class="text-xl font-bold text-amber-900 mb-2">🎁 Get a Free Class Pass!</h3>
                <p class="text-amber-800 mb-4">
                  Know another parent who'd love to track their child's learning progress?
                  Share your referral link below and you'll <strong>both get a free class pass</strong> when they sign up!
                </p>

                <div class="bg-white rounded-lg p-4 border border-amber-300 mb-4">
                  <div class="flex flex-col sm:flex-row gap-3">
                    <input
                      type="text"
                      value={@referral_link}
                      readonly
                      class="flex-1 px-3 py-2 bg-gray-50 border border-gray-300 rounded-md text-sm font-mono"
                      aria-label="Referral link"
                      data-clipboard-text={@referral_link}
                    />
                    <button
                      phx-click="copy_referral"
                      data-clipboard-text={@referral_link}
                      class="px-6 py-2 bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-white font-semibold rounded-md shadow-md transition-all duration-200 flex items-center justify-center space-x-2"
                      aria-label="Copy referral link"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                      </svg>
                      <span>Copy Link</span>
                    </button>
                  </div>
                  <%= if @show_referral_copied do %>
                    <p class="text-sm text-green-700 font-medium mt-2 flex items-center">
                      <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                      Link copied! Share with friends.
                    </p>
                  <% end %>
                </div>

                <!-- Share Buttons -->
                <div class="flex flex-wrap gap-2">
                  <a
                    href={"https://wa.me/?text=Check%20out%20this%20awesome%20learning%20platform!%20#{URI.encode(@referral_link)}"}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="flex items-center space-x-2 bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
                  >
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/>
                    </svg>
                    <span>WhatsApp</span>
                  </a>
                  <a
                    href={"mailto:?subject=Check out Vel Tutor&body=I've been using Vel Tutor to track my child's learning progress and it's amazing! Sign up using my link and we'll both get a free class pass: #{@referral_link}"}
                    class="flex items-center space-x-2 bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                    <span>Email</span>
                  </a>
                </div>
              </div>
            </div>
          </div>

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
