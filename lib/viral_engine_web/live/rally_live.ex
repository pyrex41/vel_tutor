defmodule ViralEngineWeb.RallyLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{RallyContext, DiagnosticContext, ViralEngine.Presence}
  require Logger

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
      {:ok, _} = ViralEngine.PresenceTracker.track_user(socket, user, rally_id: rally.id)

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
            {:noreply, put_flash(socket, :error, "Your assessment subject doesn't match this rally.")}

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
    ViralEngine.Presence.list_rally(rally_id)
    |> Map.keys()
    |> length()
  end

  defp format_score(score) when is_integer(score), do: "#{score}%"
  defp format_score(_), do: "N/A"

  defp score_color(score) do
    cond do
      score >= 90 -> "text-green-600"
      score >= 70 -> "text-blue-600"
      score >= 50 -> "text-yellow-600"
      true -> "text-gray-600"
    end
  end

  defp rank_badge(rank) do
    case rank do
      1 -> "🥇"
      2 -> "🥈"
      3 -> "🥉"
      _ -> "#{rank}"
    end
  end
end
