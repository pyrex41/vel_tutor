defmodule ViralEngineWeb.ChallengeLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{ChallengeContext, PracticeContext}
  alias ViralEngineWeb.Live.ViralPromptsHook
  require Logger

  # Use the viral prompts hook for experiment tracking
  on_mount ViralEngineWeb.Live.ViralPromptsHook

  @impl true
  def mount(%{"token" => token}, session, socket) do
    user = get_current_user(session)

    case ChallengeContext.get_challenge_by_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(:stage, :error)
         |> assign(:error_message, "Challenge not found")
         |> assign(:challenge, nil)}

      challenge ->
        if user do
          handle_authenticated_challenge(socket, challenge, user)
        else
          handle_unauthenticated_challenge(socket, challenge, token)
        end
    end
  end

  defp handle_authenticated_challenge(socket, challenge, user) do
    cond do
      challenge.challenger_id == user.id ->
        # Viewing own challenge
        socket =
          socket
          |> assign(:stage, :own_challenge)
          |> assign(:challenge, challenge)
          |> assign(:user, user)
          |> assign(:share_link, ChallengeContext.generate_challenge_link(challenge))

        # Log exposure for buddy_challenge experiment when share UI is shown
        ViralPromptsHook.log_variant_exposure(socket, "buddy_challenge")

        {:ok, socket}

      challenge.status == "pending" ->
        # Can accept the challenge
        socket =
          socket
          |> assign(:stage, :accept)
          |> assign(:challenge, challenge)
          |> assign(:user, user)

        {:ok, socket}

      challenge.status == "accepted" && challenge.challenged_user_id == user.id ->
        # User accepted, needs to complete challenge
        socket =
          socket
          |> assign(:stage, :in_progress)
          |> assign(:challenge, challenge)
          |> assign(:user, user)

        {:ok, socket}

      challenge.status == "completed" ->
        # Show results
        socket =
          socket
          |> assign(:stage, :results)
          |> assign(:challenge, challenge)
          |> assign(:user, user)
          |> assign(:is_winner, challenge.winner_id == user.id)

        {:ok, socket}

      true ->
        socket =
          socket
          |> assign(:stage, :expired)
          |> assign(:challenge, challenge)
          |> assign(:user, user)

        {:ok, socket}
    end
  end

  defp handle_unauthenticated_challenge(socket, challenge, token) do
    # Store challenge token in session, redirect to login
    socket =
      socket
      |> assign(:stage, :login_required)
      |> assign(:challenge, challenge)
      |> assign(:challenge_token, token)

    {:ok, socket}
  end

  @impl true
  def handle_event("accept_challenge", _params, socket) do
    challenge = socket.assigns.challenge
    user = socket.assigns.user

    case ChallengeContext.accept_challenge(challenge.challenge_token, user.id) do
      {:ok, updated_challenge} ->
        {:noreply,
         socket
         |> assign(:challenge, updated_challenge)
         |> assign(:stage, :in_progress)
         |> put_flash(:success, "Challenge accepted! Start practicing to beat the score.")}

      {:error, :expired} ->
        {:noreply,
         socket
         |> assign(:stage, :expired)
         |> put_flash(:error, "This challenge has expired.")}

      {:error, :self_challenge} ->
        {:noreply,
         socket
         |> put_flash(:error, "You can't accept your own challenge!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not accept challenge: #{reason}")}
    end
  end

  @impl true
  def handle_event("start_practice", _params, socket) do
    challenge = socket.assigns.challenge

    # Create a new practice session with the same subject
    {:ok, session} =
      PracticeContext.create_session(%{
        user_id: socket.assigns.user.id,
        session_type: "buddy_challenge",
        subject: challenge.subject,
        total_steps: 5,
        metadata: %{challenge_id: challenge.id}
      })

    # Redirect to practice session
    {:noreply, redirect(socket, to: "/practice/#{session.id}")}
  end

  @impl true
  def handle_event("decline_challenge", _params, socket) do
    challenge = socket.assigns.challenge

    ChallengeContext.update_challenge(challenge, %{status: "declined"})

    {:noreply,
     socket
     |> assign(:stage, :declined)
     |> put_flash(:info, "Challenge declined.")}
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    # Link copied via client-side JavaScript
    {:noreply, put_flash(socket, :success, "Challenge link copied to clipboard!")}
  end

  @impl true
  def handle_event("share_challenge", %{"method" => method}, socket) do
    challenge = socket.assigns.challenge

    # Update share method
    ChallengeContext.update_challenge(challenge, %{share_method: method})

    # Log analytics
    Logger.info("Challenge #{challenge.id} shared via #{method}")

    {:noreply, put_flash(socket, :success, "Challenge shared!")}
  end

  defp get_current_user(%{"user_token" => user_token}) do
    ViralEngine.Accounts.get_user_by_session_token(user_token)
  end

  defp get_current_user(_), do: nil

  # View rendering helpers

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-3xl mx-auto">
        <%= cond do %>
          <% @stage == :error -> %>
            <!-- Error State -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 text-center" role="alert">
              <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-muted mb-4">
                <svg class="h-10 w-10 text-destructive" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-foreground mb-2"><%= @error_message %></h2>
              <p class="text-muted-foreground mb-6">This challenge may have expired or the link is invalid.</p>
              <a href="/dashboard" class="inline-block bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors" aria-label="Return to dashboard">
                Back to Dashboard
              </a>
            </div>

          <% @stage == :login_required -> %>
            <!-- Login Required -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 text-center">
              <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-muted mb-4">
                <svg class="h-10 w-10 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-foreground mb-2">Login Required</h2>
              <p class="text-muted-foreground mb-6">Please log in to accept this challenge</p>
              <div class="space-y-3">
                <a href={"/login?redirect=/challenge/#{@challenge_token}"} class="block w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors" aria-label="Log in to accept challenge">
                  Log In
                </a>
                <a href={"/register?redirect=/challenge/#{@challenge_token}"} class="block w-full border border-primary text-primary hover:bg-muted font-semibold px-6 py-3 rounded-md transition-colors" aria-label="Create account to accept challenge">
                  Create Account
                </a>
              </div>
            </div>

          <% @stage == :own_challenge -> %>
            <!-- Own Challenge View -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8">
              <div class="text-center mb-6">
                <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-muted mb-4">
                  <svg class="h-10 w-10 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                </div>
                <h1 class="text-3xl font-bold text-foreground mb-2">Your Challenge</h1>
                <p class="text-muted-foreground">Status: <span class="font-semibold capitalize"><%= @challenge.status %></span></p>
              </div>

              <div class="bg-muted rounded-lg p-6 mb-6 border">
                <h2 class="text-lg font-bold text-foreground mb-2">Challenge Details</h2>
                <div class="space-y-2 text-foreground">
                  <p><strong>Subject:</strong> <%= String.capitalize(@challenge.subject) %></p>
                  <p><strong>Your Score:</strong> <%= @challenge.challenger_score %>%</p>
                  <p><strong>Created:</strong> <%= Calendar.strftime(@challenge.inserted_at, "%B %d, %Y") %></p>
                </div>
              </div>

              <div class="mb-6">
                <label class="block text-sm font-medium text-foreground mb-2">Share this challenge</label>
                <div class="flex space-x-2">
                  <input
                    type="text"
                    value={@share_link}
                    readonly
                    class="flex-1 px-3 py-2 bg-background border border-input rounded-md text-sm"
                    aria-label="Challenge share link"
                  />
                  <button
                    phx-click="copy_link"
                    class="px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold rounded-md transition-colors"
                    aria-label="Copy challenge link"
                  >
                    Copy
                  </button>
                </div>
              </div>

              <div class="grid grid-cols-3 gap-3">
                <button
                  phx-click="share_challenge"
                  phx-value-method="whatsapp"
                  class="flex flex-col items-center p-4 bg-muted hover:bg-muted/80 rounded-md border transition-colors"
                  aria-label="Share via WhatsApp"
                >
                  <svg class="w-6 h-6 text-green-600 mb-1" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0020.885 3.488"/>
                  </svg>
                  <span class="text-sm font-medium text-foreground">WhatsApp</span>
                </button>
                <button
                  phx-click="share_challenge"
                  phx-value-method="messenger"
                  class="flex flex-col items-center p-4 bg-muted hover:bg-muted/80 rounded-md border transition-colors"
                  aria-label="Share via Messenger"
                >
                  <svg class="w-6 h-6 text-blue-600 mb-1" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M12 0C5.373 0 0 4.974 0 11.111c0 3.498 1.744 6.614 4.469 8.654V24l4.088-2.242c1.092.3 2.246.464 3.443.464 6.627 0 12-4.975 12-11.111C24 4.974 18.627 0 12 0zm1.191 14.963l-3.055-3.26-5.963 3.26L10.732 8l3.131 3.259L19.752 8l-6.561 6.963z"/>
                  </svg>
                  <span class="text-sm font-medium text-foreground">Messenger</span>
                </button>
                <button
                  phx-click="share_challenge"
                  phx-value-method="native"
                  class="flex flex-col items-center p-4 bg-muted hover:bg-muted/80 rounded-md border transition-colors"
                  aria-label="Share via other methods"
                >
                  <svg class="w-6 h-6 text-primary mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                  </svg>
                  <span class="text-sm font-medium text-foreground">More</span>
                </button>
              </div>
            </div>

          <% @stage == :accept -> %>
            <!-- Accept Challenge View -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8">
              <div class="text-center mb-6">
                <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-muted mb-4">
                  <svg class="h-10 w-10 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <h1 class="text-3xl font-bold text-foreground mb-2">Challenge Received!</h1>
                <p class="text-muted-foreground">A friend has challenged you to beat their score</p>
              </div>

              <div class="bg-muted rounded-lg p-6 mb-6 border">
                <div class="flex items-center justify-between mb-4">
                  <div class="flex items-center space-x-3">
                    <div class="w-12 h-12 rounded-full bg-primary flex items-center justify-center text-primary-foreground font-bold text-xl">
                      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                      </svg>
                    </div>
                    <div>
                      <p class="font-bold text-foreground">Challenger</p>
                      <p class="text-sm text-muted-foreground">challenged you!</p>
                    </div>
                  </div>
                  <div class="text-right">
                    <div class="text-3xl font-bold text-primary"><%= @challenge.challenger_score %>%</div>
                    <p class="text-sm text-muted-foreground">Score to beat</p>
                  </div>
                </div>

                <div class="space-y-2 text-foreground">
                  <p><strong>Subject:</strong> <%= String.capitalize(@challenge.subject) %></p>
                  <p><strong>Questions:</strong> Approx. 5-10 questions</p>
                  <p><strong>Time:</strong> ~5 minutes</p>
                </div>
              </div>

              <div class="space-y-3">
                <button
                  phx-click="accept_challenge"
                  class="w-full flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-md shadow-sm hover:shadow-md transition-all"
                  aria-label="Accept the challenge"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                  <span>Accept Challenge</span>
                </button>
                <button
                  phx-click="decline_challenge"
                  class="w-full text-muted-foreground hover:text-foreground font-medium py-3 transition-colors"
                  aria-label="Decline the challenge"
                >
                  Maybe later
                </button>
              </div>
            </div>

          <% @stage == :in_progress -> %>
            <!-- In Progress View -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 text-center">
              <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-muted mb-4">
                <svg class="h-10 w-10 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
              </div>
              <h1 class="text-3xl font-bold text-foreground mb-2">Challenge Accepted!</h1>
              <p class="text-muted-foreground mb-6">Ready to beat the score of <%= @challenge.challenger_score %>%?</p>

              <div class="bg-muted rounded-lg p-6 mb-6 border">
                <p class="text-foreground mb-4"><strong>Subject:</strong> <%= String.capitalize(@challenge.subject) %></p>
                <p class="text-sm text-muted-foreground">Complete a practice session to see if you can beat your friend's score!</p>
              </div>

              <button
                phx-click="start_practice"
                class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-md shadow-sm hover:shadow-md transition-all"
                aria-label="Start practice session to complete challenge"
              >
                Start Practice Now
              </button>
            </div>

          <% @stage == :results -> %>
            <!-- Results View -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 text-center">
              <%= if @is_winner do %>
                <div class="mx-auto flex items-center justify-center h-20 w-20 rounded-full bg-muted mb-4">
                  <svg class="h-12 w-12 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <h1 class="text-4xl font-bold text-foreground mb-2">You Won!</h1>
                <p class="text-muted-foreground mb-6">Congratulations! You beat the challenge score!</p>
              <% else %>
                <div class="mx-auto flex items-center justify-center h-20 w-20 rounded-full bg-muted mb-4">
                  <svg class="h-12 w-12 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <h1 class="text-4xl font-bold text-foreground mb-2">Challenge Complete!</h1>
                <p class="text-muted-foreground mb-6">Good effort! Keep practicing to improve.</p>
              <% end %>

              <div class="grid grid-cols-2 gap-4 mb-6">
                <div class="bg-muted rounded-lg p-4 border">
                  <p class="text-sm text-muted-foreground mb-1">Challenger</p>
                  <p class="text-3xl font-bold text-primary"><%= @challenge.challenger_score %>%</p>
                </div>
                <div class="bg-muted rounded-lg p-4 border">
                  <p class="text-sm text-muted-foreground mb-1">Your Score</p>
                  <p class="text-3xl font-bold text-primary"><%= @challenge.challenged_user_score || 0 %>%</p>
                </div>
              </div>

              <div class="space-y-3">
                <a href="/practice" class="block w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors" aria-label="Practice more to improve">
                  Practice More
                </a>
                <a href="/dashboard" class="block w-full text-muted-foreground hover:text-foreground font-medium py-3 transition-colors" aria-label="Return to dashboard">
                  Back to Dashboard
                </a>
              </div>
            </div>

          <% @stage == :expired -> %>
            <!-- Expired Challenge -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 text-center">
              <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-muted mb-4">
                <svg class="h-10 w-10 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-foreground mb-2">Challenge Expired</h2>
              <p class="text-muted-foreground mb-6">This challenge has expired and is no longer available.</p>
              <a href="/dashboard" class="inline-block bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors" aria-label="Return to dashboard">
                Back to Dashboard
              </a>
            </div>

          <% @stage == :declined -> %>
            <!-- Declined Challenge -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 text-center">
              <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-muted mb-4">
                <svg class="h-10 w-10 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-foreground mb-2">Challenge Declined</h2>
              <p class="text-muted-foreground mb-6">You've declined this challenge.</p>
              <a href="/dashboard" class="inline-block bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors" aria-label="Return to dashboard">
                Back to Dashboard
              </a>
            </div>

          <% true -> %>
            <!-- Fallback -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 text-center">
              <p class="text-muted-foreground">Loading challenge...</p>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
