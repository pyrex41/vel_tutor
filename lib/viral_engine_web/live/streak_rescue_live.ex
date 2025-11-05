defmodule ViralEngineWeb.StreakRescueLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{StreakContext, PracticeContext}
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Track presence in streak rescue room
      {:ok, _} = ViralEngine.PresenceTracker.track_user(socket, user, room: "streak_rescue")

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

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:streak_stats, stats)
      |> assign(:active_users, active_users)
      |> assign(:countdown_seconds, stats.hours_remaining * 3600)
      |> assign(:invite_link, generate_invite_link(user.id))
      |> assign(:show_invite_modal, false)
      # practice or flashcards
      |> assign(:activity_type, "practice")
      |> assign(:urgency_level, calculate_urgency_level(stats.hours_remaining))

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

    case type do
      "practice" ->
        # Create practice session
        {:ok, session} =
          PracticeContext.create_session(%{
            user_id: user.id,
            session_type: "streak_rescue",
            subject: "math",
            total_steps: 5,
            metadata: %{rescue_session: true}
          })

        {:noreply, redirect(socket, to: "/practice/#{session.id}")}

      "flashcards" ->
        # Redirect to flashcards
        {:noreply, redirect(socket, to: "/flashcards")}

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

  defp generate_invite_link(user_id) do
    base_url = Application.get_env(:viral_engine, :base_url, "https://app.veltutor.com")
    "#{base_url}/streak-rescue?inviter=#{user_id}"
  end

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
end
