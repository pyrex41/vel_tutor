defmodule ViralEngineWeb.RallyLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{RallyContext, DiagnosticContext}
  alias ViralEngineWeb.Live.ViralPromptsHook
  require Logger

  # Use the viral prompts hook for experiment tracking
  on_mount ViralEngineWeb.Live.ViralPromptsHook

  @impl true
  def mount(%{"token" => token}, session, socket) do
    user = get_current_user(session)

    case RallyContext.get_rally_by_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(:stage, :error)
         |> assign(:error_message, "Rally not found")
         |> assign(:rally, nil)}

      rally ->
        if user do
          handle_authenticated_rally(socket, rally, user)
        else
          handle_unauthenticated_rally(socket, rally, token)
        end
    end
  end

  defp handle_authenticated_rally(socket, rally, user) do
    if connected?(socket) do
      # Subscribe to rally updates
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "rally:#{rally.id}")

      # Track presence
      ViralEngine.PresenceTracker.track_socket(socket, user, rally_id: rally.id)

      # Subscribe to presence
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:rally:#{rally.id}")
    end

    # Get leaderboard
    leaderboard = RallyContext.get_rally_leaderboard(rally.id, user_id: user.id)

    # Get user's participation status
    user_participant = Enum.find(leaderboard.participants, fn p -> p.user_id == user.id end)

    # Get active users
    active_users = get_active_users(rally.id)

    socket =
      socket
      |> assign(:stage, :leaderboard)
      |> assign(:rally, rally)
      |> assign(:user, user)
      |> assign(:user_participant, user_participant)
      |> assign(:leaderboard, leaderboard)
      |> assign(:active_users, active_users)
      |> assign(:share_link, RallyContext.generate_rally_link(rally))
      |> stream(:participants, leaderboard.participants, id: fn p -> "user-#{p.user_id}" end)

    # Log exposure for results_rally experiment when leaderboard/share UI is shown
    ViralPromptsHook.log_variant_exposure(socket, "results_rally")

    {:ok, socket}
  end

  defp handle_unauthenticated_rally(socket, rally, token) do
    socket =
      socket
      |> assign(:stage, :login_required)
      |> assign(:rally, rally)
      |> assign(:rally_token, token)

    {:ok, socket}
  end

  @impl true
  def handle_event("join_rally", _params, socket) do
    rally = socket.assigns.rally
    user = socket.assigns.user

    # Check if user has a completed diagnostic in this subject
    case find_matching_assessment(user.id, rally.subject) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Complete a #{rally.subject} diagnostic first to join this rally.")
         |> push_navigate(to: "/diagnostic")}

      assessment ->
        case RallyContext.join_rally(rally.rally_token, user.id, assessment.id) do
          {:ok, participant} ->
            # Refresh leaderboard
            leaderboard = RallyContext.get_rally_leaderboard(rally.id, user_id: user.id)

            {:noreply,
             socket
             |> assign(:user_participant, participant)
             |> assign(:leaderboard, leaderboard)
             |> stream(:participants, leaderboard.participants, reset: true)
             |> put_flash(:success, "You've joined the rally! Check your ranking.")}

          {:error, :already_joined} ->
            {:noreply, put_flash(socket, :info, "You're already in this rally.")}

          {:error, :rally_ended} ->
            {:noreply, put_flash(socket, :error, "This rally has ended.")}

          {:error, :subject_mismatch} ->
            {:noreply,
             put_flash(socket, :error, "Your assessment subject doesn't match this rally.")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Could not join rally: #{reason}")}
        end
    end
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    {:noreply, put_flash(socket, :success, "Rally link copied to clipboard!")}
  end

  @impl true
  def handle_event("share_rally", %{"method" => method}, socket) do
    Logger.info("Rally #{socket.assigns.rally.id} shared via #{method}")
    {:noreply, put_flash(socket, :success, "Rally shared!")}
  end

  @impl true
  def handle_event("refresh_leaderboard", _params, socket) do
    rally = socket.assigns.rally
    user = socket.assigns.user

    leaderboard = RallyContext.get_rally_leaderboard(rally.id, user_id: user.id)

    {:noreply,
     socket
     |> assign(:leaderboard, leaderboard)
     |> stream(:participants, leaderboard.participants, reset: true)}
  end

  # PubSub event handlers

  @impl true
  def handle_info({:participant_joined, data}, socket) do
    Logger.info("Participant joined rally: #{inspect(data)}")

    # Refresh leaderboard
    rally = socket.assigns.rally
    user = socket.assigns.user

    leaderboard = RallyContext.get_rally_leaderboard(rally.id, user_id: user.id)

    {:noreply,
     socket
     |> assign(:leaderboard, leaderboard)
     |> stream(:participants, leaderboard.participants, reset: true)
     |> put_flash(:info, "A new challenger has joined!")}
  end

  @impl true
  def handle_info({:ranks_updated, _data}, socket) do
    # Refresh leaderboard silently (no flash)
    rally = socket.assigns.rally
    user = socket.assigns.user

    leaderboard = RallyContext.get_rally_leaderboard(rally.id, user_id: user.id)
    user_participant = Enum.find(leaderboard.participants, fn p -> p.user_id == user.id end)

    {:noreply,
     socket
     |> assign(:leaderboard, leaderboard)
     |> assign(:user_participant, user_participant)
     |> stream(:participants, leaderboard.participants, reset: true)}
  end

  @impl true
  def handle_info({:presence_diff, _diff}, socket) do
    active_users = get_active_users(socket.assigns.rally.id)

    {:noreply, assign(socket, :active_users, active_users)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Helper functions

  defp get_current_user(%{"user_token" => user_token}) do
    ViralEngine.Accounts.get_user_by_session_token(user_token)
  end

  defp get_current_user(_), do: nil

  defp find_matching_assessment(user_id, subject) do
    # Get user's most recent completed diagnostic for this subject
    DiagnosticContext.list_user_assessments(user_id, completed: true, subject: subject)
    |> List.first()
  end

  defp get_active_users(rally_id) do
    topic = "rally:#{rally_id}"

    ViralEngine.Presence.list(topic)
    |> Map.keys()
    |> length()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-4xl mx-auto">
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
              <p class="text-muted-foreground mb-6">This rally may have expired or the link is invalid.</p>
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
              <p class="text-muted-foreground mb-6">Please log in to join this rally</p>
              <div class="space-y-3">
                <a href={"/login?redirect=/rally/#{@rally_token}"} class="block w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors" aria-label="Log in to join rally">
                  Log In
                </a>
                <a href={"/register?redirect=/rally/#{@rally_token}"} class="block w-full border border-primary text-primary hover:bg-muted font-semibold px-6 py-3 rounded-md transition-colors" aria-label="Create account to join rally">
                  Create Account
                </a>
              </div>
            </div>

          <% @stage == :leaderboard -> %>
            <!-- Leaderboard View -->
            <div class="space-y-6">
              <!-- Header -->
              <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
                <div class="flex items-center justify-between mb-4">
                  <div>
                    <h1 class="text-3xl font-bold text-foreground mb-2"><%= @rally.title %></h1>
                    <p class="text-muted-foreground"><%= @rally.description %></p>
                  </div>
                  <div class="text-right">
                    <div class="text-sm text-muted-foreground">Active Now</div>
                    <div class="text-2xl font-bold text-primary"><%= @active_users %></div>
                  </div>
                </div>

                <!-- Rally Info -->
                <div class="grid md:grid-cols-3 gap-4 mb-4">
                  <div class="bg-muted rounded-lg p-4 border">
                    <p class="text-sm text-muted-foreground mb-1">Subject</p>
                    <p class="text-lg font-bold text-foreground capitalize"><%= @rally.subject %></p>
                  </div>
                  <div class="bg-muted rounded-lg p-4 border">
                    <p class="text-sm text-muted-foreground mb-1">Participants</p>
                    <p class="text-lg font-bold text-foreground"><%= length(@leaderboard.participants) %></p>
                  </div>
                  <div class="bg-muted rounded-lg p-4 border">
                    <p class="text-sm text-muted-foreground mb-1">Ends</p>
                    <p class="text-sm font-bold text-foreground">
                      <%= if @rally.ends_at do %>
                        <%= Calendar.strftime(@rally.ends_at, "%b %d, %Y") %>
                      <% else %>
                        Ongoing
                      <% end %>
                    </p>
                  </div>
                </div>

                <!-- Join/Status Button -->
                <%= if @user_participant do %>
                  <div class="flex items-center justify-between">
                    <div class="flex items-center space-x-2">
                      <span class="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-medium">
                        Participating
                      </span>
                      <span class="text-sm text-muted-foreground">
                        Rank: <%= @user_participant.rank %> | Score: <%= @user_participant.score %>
                      </span>
                    </div>
                    <button
                      phx-click="refresh_leaderboard"
                      class="px-4 py-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 rounded-md transition-colors"
                      aria-label="Refresh leaderboard"
                    >
                      Refresh
                    </button>
                  </div>
                <% else %>
                  <button
                    phx-click="join_rally"
                    class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md shadow-sm hover:shadow-md transition-all"
                    aria-label="Join this rally"
                  >
                    Join Rally
                  </button>
                <% end %>
              </div>

              <!-- Leaderboard -->
              <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
                <h2 class="text-xl font-bold text-foreground mb-4 flex items-center">
                  <svg class="w-6 h-6 mr-2 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
                  </svg>
                  Leaderboard
                </h2>

                <div class="space-y-3" role="list">
                  <%= for {participant, index} <- Enum.with_index(@streams.participants, 1) do %>
                    <div class="flex items-center space-x-4 p-4 bg-muted rounded-lg border" role="listitem">
                      <!-- Rank -->
                      <div class="flex-shrink-0">
                        <%= if index <= 3 do %>
                          <div class={"w-8 h-8 rounded-full flex items-center justify-center text-primary-foreground font-bold text-sm #{if index == 1, do: "bg-yellow-500", else: if(index == 2, do: "bg-gray-400", else: "bg-amber-600")}"}>
                            <%= index %>
                          </div>
                        <% else %>
                          <div class="w-8 h-8 rounded-full bg-secondary flex items-center justify-center text-secondary-foreground font-bold text-sm">
                            <%= index %>
                          </div>
                        <% end %>
                      </div>

                      <!-- User Info -->
                      <div class="flex-1 min-w-0">
                        <div class="flex items-center space-x-2">
                          <div class="w-10 h-10 rounded-full bg-primary flex items-center justify-center text-primary-foreground font-bold">
                            <%= String.first(participant.user.name) %>
                          </div>
                          <div>
                            <p class="font-medium text-foreground"><%= participant.user.name %></p>
                            <p class="text-xs text-muted-foreground">Score: <%= participant.score %></p>
                          </div>
                        </div>
                      </div>

                      <!-- Progress Bar -->
                      <div class="flex-1 max-w-xs">
                        <div class="w-full bg-secondary rounded-full h-2 overflow-hidden">
                          <div
                            class="h-2 bg-primary rounded-full transition-all duration-500"
                            style={"width: #{min(participant.score / 100 * 100, 100)}%"}
                          ></div>
                        </div>
                        <p class="text-xs text-muted-foreground mt-1 text-center"><%= round(participant.score) %>%</p>
                      </div>

                      <!-- Status Indicator -->
                      <div class="flex-shrink-0">
                        <%= if participant.user_id == @user.id do %>
                          <span class="px-2 py-1 bg-blue-100 text-blue-800 rounded text-xs font-medium">You</span>
                        <% else %>
                          <div class="w-2 h-2 rounded-full bg-green-500" title="Active"></div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Share Section -->
              <%= if @user_participant do %>
                <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
                  <h3 class="text-lg font-bold text-foreground mb-4">Share This Rally</h3>
                  <div class="flex items-center space-x-2 mb-4">
                    <input
                      type="text"
                      value={@share_link}
                      readonly
                      class="flex-1 px-3 py-2 bg-background border border-input rounded-md text-sm"
                      aria-label="Rally share link"
                    />
                    <button
                      phx-click="copy_link"
                      class="px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md text-sm font-medium transition-colors"
                      aria-label="Copy rally link"
                    >
                      Copy
                    </button>
                  </div>
                  <div class="grid grid-cols-3 gap-3">
                    <button
                      phx-click="share_rally"
                      phx-value-method="whatsapp"
                      class="flex flex-col items-center p-3 bg-muted hover:bg-muted/80 rounded-md border transition-colors"
                      aria-label="Share via WhatsApp"
                    >
                      <svg class="w-5 h-5 text-green-600 mb-1" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0020.885 3.488"/>
                      </svg>
                      <span class="text-xs font-medium text-foreground">WhatsApp</span>
                    </button>
                    <button
                      phx-click="share_rally"
                      phx-value-method="messenger"
                      class="flex flex-col items-center p-3 bg-muted hover:bg-muted/80 rounded-md border transition-colors"
                      aria-label="Share via Messenger"
                    >
                      <svg class="w-5 h-5 text-blue-600 mb-1" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path d="M12 0C5.373 0 0 4.974 0 11.111c0 3.498 1.744 6.614 4.469 8.654V24l4.088-2.242c1.092.3 2.246.464 3.443.464 6.627 0 12-4.975 12-11.111C24 4.974 18.627 0 12 0zm1.191 14.963l-3.055-3.26-5.963 3.26L10.732 8l3.131 3.259L19.752 8l-6.561 6.963z"/>
                      </svg>
                      <span class="text-xs font-medium text-foreground">Messenger</span>
                    </button>
                    <button
                      phx-click="share_rally"
                      phx-value-method="native"
                      class="flex flex-col items-center p-3 bg-muted hover:bg-muted/80 rounded-md border transition-colors"
                      aria-label="Share via other methods"
                    >
                      <svg class="w-5 h-5 text-primary mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                      </svg>
                      <span class="text-xs font-medium text-foreground">More</span>
                    </button>
                  </div>
                </div>
              <% end %>
            </div>

          <% true -> %>
            <!-- Fallback -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 text-center">
              <p class="text-muted-foreground">Loading rally...</p>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
