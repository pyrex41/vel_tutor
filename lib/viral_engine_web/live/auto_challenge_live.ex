defmodule ViralEngineWeb.AutoChallengeLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{ChallengeContext, PracticeContext}
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to auto-challenge events
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:challenges")
    end

    # Get user's active auto-challenges
    auto_challenges = get_user_auto_challenges(user.id)

    # Get user's recent stats for motivation
    stats = PracticeContext.get_user_stats(user.id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:auto_challenges, auto_challenges)
      |> assign(:stats, stats)
      |> assign(:selected_challenge, nil)
      |> assign(:show_share_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("accept_challenge", %{"challenge_id" => challenge_id_str}, socket) do
    challenge_id = String.to_integer(challenge_id_str)

    # Redirect to practice session for this challenge
    challenge = Enum.find(socket.assigns.auto_challenges, &(&1.id == challenge_id))

    if challenge do
      # Create practice session for this challenge
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: socket.assigns.user_id,
          session_type: "practice_test",
          subject: challenge.subject,
          grade_level: challenge.grade_level,
          metadata: %{
            challenge_id: challenge.id,
            target_score: challenge.target_score
          }
        })

      {:noreply,
       socket
       |> put_flash(:info, "Challenge accepted! Beat your score of #{challenge.target_score}!")
       |> redirect(to: "/practice/#{session.id}")}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Challenge not found")}
    end
  end

  @impl true
  def handle_event("share_challenge", %{"challenge_id" => challenge_id_str}, socket) do
    challenge_id = String.to_integer(challenge_id_str)
    challenge = Enum.find(socket.assigns.auto_challenges, &(&1.id == challenge_id))

    if challenge do
      {:noreply,
       socket
       |> assign(:selected_challenge, challenge)
       |> assign(:show_share_modal, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> assign(:selected_challenge, nil)}
  end

  @impl true
  def handle_event("copy_challenge_link", %{"token" => token}, socket) do
    # Would copy to clipboard in frontend
    challenge_url = "#{ViralEngineWeb.Endpoint.url()}/challenge/#{token}"

    Logger.info("Challenge link copied: #{challenge_url}")

    {:noreply,
     socket
     |> put_flash(:success, "Challenge link copied to clipboard!")}
  end

  @impl true
  def handle_event("dismiss_challenge", %{"challenge_id" => challenge_id_str}, socket) do
    challenge_id = String.to_integer(challenge_id_str)

    # Mark challenge as dismissed (update status to cancelled)
    challenge = ChallengeContext.get_challenge(challenge_id)

    case ChallengeContext.update_challenge(challenge, %{status: "cancelled"}) do
      {:ok, _challenge} ->
        # Remove from list
        updated_challenges = Enum.reject(socket.assigns.auto_challenges, &(&1.id == challenge_id))

        {:noreply,
         socket
         |> assign(:auto_challenges, updated_challenges)
         |> put_flash(:info, "Challenge dismissed")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to dismiss challenge")}
    end
  end

  @impl true
  def handle_info({:challenge_created, %{challenge: challenge}}, socket) do
    # Add new auto-challenge to list if it's auto-generated
    if challenge.metadata["auto_generated"] do
      updated_challenges = [challenge | socket.assigns.auto_challenges]

      {:noreply,
       socket
       |> assign(:auto_challenges, updated_challenges)
       |> put_flash(:info, "🎯 New challenge available! Can you beat your best score?")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-foreground mb-2">Auto Challenges</h1>
          <p class="text-muted-foreground">Beat your personal best scores and keep improving!</p>
        </div>

        <!-- Stats Cards -->
        <%= if @stats && map_size(@stats) > 0 do %>
          <div class="grid md:grid-cols-3 gap-4 mb-8">
            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-medium text-muted-foreground">Sessions Completed</span>
                <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <p class="text-3xl font-bold text-foreground"><%= @stats["total_sessions"] || 0 %></p>
            </div>

            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-medium text-muted-foreground">Average Score</span>
                <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
              <p class="text-3xl font-bold text-foreground"><%= round((@stats["average_score"] || 0) * 100) %>%</p>
            </div>

            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-medium text-muted-foreground">Streak</span>
                <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
              </div>
              <p class="text-3xl font-bold text-foreground"><%= @stats["current_streak"] || 0 %></p>
            </div>
          </div>
        <% end %>

        <!-- Challenges List -->
        <%= if length(@auto_challenges) > 0 do %>
          <div class="space-y-4 mb-8">
            <%= for challenge <- @auto_challenges do %>
              <div class="bg-card text-card-foreground rounded-lg border p-6 shadow-sm">
                <div class="flex items-start justify-between mb-4">
                  <div class="flex-1">
                    <h3 class="text-lg font-semibold text-foreground mb-1">
                      Beat Your Score: <%= String.capitalize(challenge.subject) %> Grade <%= challenge.grade_level %>
                    </h3>
                    <p class="text-muted-foreground text-sm mb-2">
                      Target Score: <span class="font-medium text-foreground"><%= challenge.target_score %>%</span>
                    </p>
                    <p class="text-sm text-muted-foreground">
                      Can you improve on your previous performance?
                    </p>
                  </div>
                  <div class="flex-shrink-0 ml-4">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-secondary text-secondary-foreground">
                      Auto Challenge
                    </span>
                  </div>
                </div>

                <div class="flex flex-col sm:flex-row gap-3">
                  <button
                    phx-click="accept_challenge"
                    phx-value-challenge_id={challenge.id}
                    class="flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
                    aria-label="Accept challenge to beat your score"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    <span>Accept Challenge</span>
                  </button>

                  <button
                    phx-click="share_challenge"
                    phx-value-challenge_id={challenge.id}
                    class="flex items-center justify-center space-x-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 font-medium px-4 py-2 rounded-md transition-colors"
                    aria-label="Share this challenge"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                    </svg>
                    <span>Share</span>
                  </button>

                  <button
                    phx-click="dismiss_challenge"
                    phx-value-challenge_id={challenge.id}
                    class="flex items-center justify-center space-x-2 text-muted-foreground hover:text-destructive font-medium px-4 py-2 rounded-md transition-colors"
                    aria-label="Dismiss this challenge"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                    <span>Dismiss</span>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- Empty State -->
          <div class="text-center py-12">
            <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-muted mb-4">
              <svg class="h-12 w-12 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-foreground mb-2">No Auto Challenges Available</h3>
            <p class="text-muted-foreground mb-6">Complete some practice sessions to unlock personalized challenges!</p>
            <a
              href="/practice"
              class="inline-flex items-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
              <span>Start Practicing</span>
            </a>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Share Modal -->
    <%= if @show_share_modal && @selected_challenge do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_share_modal" role="dialog" aria-modal="true" aria-labelledby="share-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
          <h3 id="share-modal-title" class="text-xl font-bold text-foreground mb-4">Share Challenge</h3>
          <p class="text-muted-foreground mb-6">Challenge a friend to beat your score!</p>

          <div class="mb-6">
            <input
              type="text"
              value={"#{ViralEngineWeb.Endpoint.url()}/challenge/#{@selected_challenge.id}"}
              readonly
              class="w-full px-3 py-2 bg-background border border-input rounded-md text-sm"
              aria-label="Challenge share URL"
            />
          </div>

          <div class="space-y-3">
            <button
              phx-click="copy_challenge_link"
              phx-value-token={@selected_challenge.id}
              class="w-full flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
              aria-label="Copy challenge link to clipboard"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              <span>Copy Link</span>
            </button>

            <button
              phx-click="close_share_modal"
              class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
              aria-label="Close share modal"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Helper functions

  defp get_user_auto_challenges(_user_id) do
    # Get all pending self-challenges that are auto-generated
    # In production:
    # from(c in Challenge,
    #   where: c.challenger_id == ^user_id and
    #          c.target_user_id == ^user_id and
    #          c.status == "pending" and
    #          fragment("?->>'auto_generated' = 'true'", c.metadata),
    #   order_by: [desc: c.inserted_at]
    # )
    # |> Repo.all()

    # Simulated: Return empty list
    []
  end
end
