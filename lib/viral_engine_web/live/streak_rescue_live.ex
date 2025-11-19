defmodule ViralEngineWeb.StreakRescueLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{StreakContext, PracticeContext, AttributionContext}
  alias ViralEngineWeb.Live.ViralPromptsHook
  require Logger

  # Use the viral prompts hook for experiment tracking
  on_mount ViralEngineWeb.Live.ViralPromptsHook

  @impl true
  def mount(params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Track presence in streak rescue room
      ViralEngine.PresenceTracker.track_socket(socket, user, room: "streak_rescue")

      # Subscribe to presence updates
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:streak_rescue")

      # Subscribe to user-specific streak events
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:streak")

      # Start countdown timer (updates every second)
      :timer.send_interval(1000, self(), :tick)
    end

    # Get streak stats
    stats = StreakContext.get_user_stats(user.id)

    # Get active users in rescue room
    active_users = get_active_users()

    # Check if this is a rescue via invitation (attribution tracking)
    inviter_id = params["inviter"]
    attribution_token = params["token"]

    # Track conversion if coming from invite
    if inviter_id && attribution_token do
      track_rescue_conversion(attribution_token, user.id)
    end

    # Generate attributed invite link
    {:ok, attribution_link} = create_rescue_attribution_link(user.id)
    invite_url = build_invite_url(attribution_link.link_token)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:streak_stats, stats)
      |> assign(:active_users, active_users)
      |> assign(:countdown_seconds, stats.hours_remaining * 3600)
      |> assign(:invite_link, invite_url)
      |> assign(:attribution_link, attribution_link)
      |> assign(:show_invite_modal, false)
      # practice or flashcards
      |> assign(:activity_type, "practice")
      |> assign(:urgency_level, calculate_urgency_level(stats.hours_remaining))
      |> assign(:inviter_id, inviter_id)

    # Log exposure for streak_rescue experiment when rescue UI/invite link is shown
    ViralPromptsHook.log_variant_exposure(socket, "streak_rescue")

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    # Update countdown
    new_seconds = max(0, socket.assigns.countdown_seconds - 1)

    # Refresh streak stats every minute
    stats =
      if rem(new_seconds, 60) == 0 do
        StreakContext.get_user_stats(socket.assigns.user_id)
      else
        socket.assigns.streak_stats
      end

    urgency_level = calculate_urgency_level(div(new_seconds, 3600))

    {:noreply,
     socket
     |> assign(:countdown_seconds, new_seconds)
     |> assign(:streak_stats, stats)
     |> assign(:urgency_level, urgency_level)}
  end

  @impl true
  def handle_info({:presence_diff, _diff}, socket) do
    active_users = get_active_users()

    {:noreply, assign(socket, :active_users, active_users)}
  end

  @impl true
  def handle_info({:streak_saved, _data}, socket) do
    # Reload streak stats
    stats = StreakContext.get_user_stats(socket.assigns.user_id)

    {:noreply,
     socket
     |> assign(:streak_stats, stats)
     |> put_flash(:success, "🎉 Streak saved! Keep it going!")}
  end

  @impl true
  def handle_event("start_practice", %{"type" => type}, socket) do
    user = socket.assigns.user
    inviter_id = socket.assigns[:inviter_id]

    case type do
      "practice" ->
        # Create practice session with rescue metadata
        rescue_metadata = %{
          rescue_session: true,
          inviter_id: inviter_id,
          attribution_link_id: socket.assigns.attribution_link.id
        }

        {:ok, session} =
          PracticeContext.create_session(%{
            user_id: user.id,
            session_type: "streak_rescue",
            subject: "math",
            total_steps: 5,
            metadata: rescue_metadata
          })

        {:noreply, redirect(socket, to: "/practice/#{session.id}")}

      "flashcards" ->
        # Redirect to flashcards with rescue metadata
        {:noreply, redirect(socket, to: "/flashcards?rescue=true&inviter=#{inviter_id}")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, !socket.assigns.show_invite_modal)}
  end

  @impl true
  def handle_event("copy_invite_link", _params, socket) do
    {:noreply, put_flash(socket, :success, "Invite link copied! Share with a study buddy.")}
  end

  @impl true
  def handle_event("share_invite", %{"method" => method}, socket) do
    Logger.info("Streak rescue invite shared via #{method}")

    {:noreply, put_flash(socket, :success, "Invite sent!")}
  end

  # Helper functions

  defp get_active_users do
    ViralEngine.Presence.list("streak_rescue")
    |> Map.values()
    |> Enum.map(fn %{metas: metas} -> hd(metas) end)
  end

  defp create_rescue_attribution_link(user_id) do
    expires_at = DateTime.add(DateTime.utc_now(), 7, :day)

    AttributionContext.create_link(%{
      user_id: user_id,
      link_type: "streak_rescue",
      share_method: "copy_link",
      metadata: %{
        "rescue_type" => "co_practice",
        "reward" => "streak_shield"
      },
      expires_at: expires_at
    })
  end

  defp build_invite_url(link_token) do
    base_url = Application.get_env(:viral_engine, :base_url, "https://app.veltutor.com")
    "#{base_url}/streak-rescue?token=#{link_token}"
  end

  defp track_rescue_conversion(attribution_token, converter_user_id) do
    # Track the conversion (friend joined rescue)
    case AttributionContext.track_conversion(attribution_token, converter_user_id, 0) do
      {:ok, _conversion} ->
        Logger.info("Streak rescue conversion tracked for token #{attribution_token}")

      {:error, reason} ->
        Logger.error("Failed to track rescue conversion: #{inspect(reason)}")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-foreground mb-2">Streak Rescue</h1>
          <p class="text-muted-foreground">Don't lose your streak! Complete activities to save it.</p>
        </div>

        <!-- Urgency Alert -->
        <%= if @urgency_level in [:critical, :high] do %>
          <div class={"bg-card text-card-foreground rounded-lg border p-6 mb-6 #{if @urgency_level == :critical, do: "border-red-200 bg-red-50", else: "border-orange-200 bg-orange-50"}"}>
            <div class="flex items-center space-x-3">
              <div class={"flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center #{if @urgency_level == :critical, do: "bg-red-100", else: "bg-orange-100"}"}>
                <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                </svg>
              </div>
              <div class="flex-1">
                <h3 class={"text-lg font-semibold #{if @urgency_level == :critical, do: "text-red-800", else: "text-orange-800"}"}>
                  <%= if @urgency_level == :critical, do: "Critical: Streak Ending Soon!", else: "Warning: Streak at Risk" %>
                </h3>
                <p class={"text-sm #{if @urgency_level == :critical, do: "text-red-700", else: "text-orange-700"}"}>
                  <%= if @urgency_level == :critical, do: "Your streak will be lost in less than 1 hour!", else: "Complete activities quickly to save your streak." %>
                </p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Countdown Timer -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 mb-8 text-center">
          <div class="mb-4">
            <h2 class="text-xl font-semibold text-foreground mb-2">Time Remaining</h2>
            <div class="text-4xl font-mono font-bold text-foreground">
              <%= format_time(@countdown_seconds) %>
            </div>
            <p class="text-sm text-muted-foreground mt-1">until streak expires</p>
          </div>

          <!-- Progress Bar -->
          <div class="w-full bg-secondary rounded-full h-3 mb-4">
            <div
              class={"h-3 rounded-full transition-all duration-1000 #{if @urgency_level == :critical, do: "bg-red-500", else: if(@urgency_level == :high, do: "bg-orange-500", else: if(@urgency_level == :medium, do: "bg-yellow-500", else: "bg-green-500"))}"}
              style={"width: #{calculate_progress_percentage(@countdown_seconds)}%"}
            ></div>
          </div>

          <!-- Streak Info -->
          <div class="grid md:grid-cols-3 gap-4 text-sm">
            <div>
              <div class="font-semibold text-foreground"><%= @streak_stats.current_streak %></div>
              <div class="text-muted-foreground">Current Streak</div>
            </div>
            <div>
              <div class="font-semibold text-foreground"><%= @streak_stats.longest_streak %></div>
              <div class="text-muted-foreground">Best Streak</div>
            </div>
            <div>
              <div class="font-semibold text-foreground"><%= @streak_stats.days_active %></div>
              <div class="text-muted-foreground">Days Active</div>
            </div>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="grid md:grid-cols-2 gap-6 mb-8">
          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <h3 class="text-lg font-semibold text-foreground mb-4">Practice Session</h3>
            <p class="text-muted-foreground text-sm mb-4">Complete a quick practice session to save your streak.</p>
            <button
              phx-click="start_practice"
              phx-value-type="practice"
              class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-3 rounded-md transition-colors"
              aria-label="Start practice session to rescue streak"
            >
              Start Practice
            </button>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <h3 class="text-lg font-semibold text-foreground mb-4">Flashcards</h3>
            <p class="text-muted-foreground text-sm mb-4">Review flashcards to maintain your streak.</p>
            <button
              phx-click="start_practice"
              phx-value-type="flashcards"
              class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-3 rounded-md transition-colors"
              aria-label="Start flashcards to rescue streak"
            >
              Start Flashcards
            </button>
          </div>
        </div>

        <!-- Active Users -->
        <%= if length(@active_users) > 1 do %>
          <div class="bg-card text-card-foreground rounded-lg border p-6 mb-8">
            <h3 class="text-lg font-semibold text-foreground mb-4">Study Buddies Online</h3>
            <div class="flex flex-wrap gap-2">
              <%= for user <- @active_users do %>
                <%= if user.id != @user_id do %>
                  <div class="flex items-center space-x-2 bg-muted rounded-full px-3 py-1">
                    <div class="w-6 h-6 bg-primary rounded-full flex items-center justify-center">
                      <span class="text-xs font-medium text-primary-foreground">
                        <%= String.first(user.name || "U") %>
                      </span>
                    </div>
                    <span class="text-sm text-foreground"><%= user.name %></span>
                  </div>
                <% end %>
              <% end %>
            </div>
            <p class="text-sm text-muted-foreground mt-2">
              <%= length(@active_users) - 1 %> other <%= if length(@active_users) - 1 == 1, do: "student", else: "students" %> rescuing their streaks
            </p>
          </div>
        <% end %>

        <!-- Invite Friends -->
        <div class="text-center">
          <button
            phx-click="toggle_invite_modal"
            class="inline-flex items-center space-x-2 text-primary hover:text-primary/80 font-medium transition-colors"
            aria-label="Invite friends to join streak rescue"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
            </svg>
            <span>Invite Study Buddies</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Invite Modal -->
    <%= if @show_invite_modal do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="toggle_invite_modal" role="dialog" aria-modal="true" aria-labelledby="invite-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
          <h3 id="invite-modal-title" class="text-xl font-bold text-foreground mb-4">Invite Study Buddies</h3>
          <p class="text-muted-foreground mb-6">Share the rescue mission with friends to keep each other motivated!</p>

          <div class="mb-6">
            <input
              type="text"
              value={@invite_link}
              readonly
              class="w-full px-3 py-2 bg-background border border-input rounded-md text-sm"
              aria-label="Invite link"
            />
          </div>

          <div class="space-y-3">
            <button
              phx-click="copy_invite_link"
              class="w-full flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
              aria-label="Copy invite link to clipboard"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              <span>Copy Link</span>
            </button>

            <div class="grid grid-cols-2 gap-3">
              <button
                phx-click="share_invite"
                phx-value-method="email"
                class="flex items-center justify-center space-x-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 font-medium px-4 py-2 rounded-md transition-colors"
                aria-label="Share via email"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
                <span>Email</span>
              </button>

              <button
                phx-click="share_invite"
                phx-value-method="copy"
                class="flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-medium px-4 py-2 rounded-md transition-colors"
                aria-label="Copy link"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
                <span>Copy Link</span>
              </button>
            </div>

            <button
              phx-click="toggle_invite_modal"
              class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
              aria-label="Close invite modal"
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

  defp calculate_urgency_level(hours_remaining) do
    cond do
      # Red, urgent
      hours_remaining <= 1 -> :critical
      # Orange, high urgency
      hours_remaining <= 3 -> :high
      # Yellow, moderate urgency
      hours_remaining <= 6 -> :medium
      # Green, low urgency
      true -> :low
    end
  end

  defp format_time(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, secs]) |> to_string()
  end

  defp calculate_progress_percentage(seconds) do
    # Assuming 24 hours max
    total_seconds = 24 * 3600
    percentage = seconds / total_seconds * 100
    min(100, max(0, percentage))
  end
end
