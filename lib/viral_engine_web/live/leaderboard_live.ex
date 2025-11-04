defmodule ViralEngineWeb.LeaderboardLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.LeaderboardContext
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to leaderboard updates
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "leaderboard:updates")

      # Refresh leaderboard every 30 seconds
      :timer.send_interval(30_000, self(), :refresh_leaderboard)
    end

    # Default view settings
    scope = :global
    metric = :total_score
    time_period = 7
    subject = "math"
    grade_level = 5

    # Get leaderboard
    leaderboard = get_leaderboard(scope, %{
      metric: metric,
      time_period: time_period,
      subject: subject,
      grade_level: grade_level
    })

    # Get user's rank
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(user.id, scope, %{
      metric: metric,
      time_period: time_period
    })

    # Get user's percentile
    {:ok, percentile} = LeaderboardContext.get_user_percentile(user.id, scope, %{
      metric: metric,
      time_period: time_period
    })

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:scope, scope)
      |> assign(:metric, metric)
      |> assign(:time_period, time_period)
      |> assign(:subject, subject)
      |> assign(:grade_level, grade_level)
      |> assign(:user_rank, user_rank)
      |> assign(:rank_status, rank_status)
      |> assign(:percentile, percentile)
      |> assign(:show_invite_modal, false)
      |> stream(:leaderboard_entries, leaderboard, id: fn entry -> "user-#{entry.user_id}" end)

    {:ok, socket}
  end

  @impl true
  def handle_event("change_scope", %{"scope" => scope}, socket) do
    new_scope = String.to_existing_atom(scope)

    opts = %{
      metric: socket.assigns.metric,
      time_period: socket.assigns.time_period,
      subject: socket.assigns.subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(new_scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, new_scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, new_scope, opts)

    {:noreply,
     socket
     |> assign(:scope, new_scope)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("change_metric", %{"metric" => metric}, socket) do
    new_metric = String.to_existing_atom(metric)

    opts = %{
      metric: new_metric,
      time_period: socket.assigns.time_period,
      subject: socket.assigns.subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:metric, new_metric)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("change_time_period", %{"period" => period}, socket) do
    new_period = String.to_integer(period)

    opts = %{
      metric: socket.assigns.metric,
      time_period: new_period,
      subject: socket.assigns.subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:time_period, new_period)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("change_subject", %{"subject" => subject}, socket) do
    opts = %{
      metric: socket.assigns.metric,
      time_period: socket.assigns.time_period,
      subject: subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:subject, subject)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("change_grade_level", %{"grade" => grade}, socket) do
    new_grade = String.to_integer(grade)

    opts = %{
      metric: socket.assigns.metric,
      time_period: socket.assigns.time_period,
      subject: socket.assigns.subject,
      grade_level: new_grade
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:grade_level, new_grade)
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_event("toggle_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, !socket.assigns.show_invite_modal)}
  end

  @impl true
  def handle_event("copy_invite_link", _params, socket) do
    {:noreply, put_flash(socket, :success, "Invite link copied! Share to climb the leaderboard together.")}
  end

  @impl true
  def handle_event("challenge_leader", %{"user_id" => target_user_id}, socket) do
    Logger.info("User #{socket.assigns.user_id} challenging user #{target_user_id}")

    {:noreply, put_flash(socket, :info, "Challenge sent!")}
  end

  @impl true
  def handle_info(:refresh_leaderboard, socket) do
    opts = %{
      metric: socket.assigns.metric,
      time_period: socket.assigns.time_period,
      subject: socket.assigns.subject,
      grade_level: socket.assigns.grade_level
    }

    leaderboard = get_leaderboard(socket.assigns.scope, opts)
    {rank_status, user_rank} = LeaderboardContext.get_user_rank(socket.assigns.user_id, socket.assigns.scope, opts)
    {:ok, percentile} = LeaderboardContext.get_user_percentile(socket.assigns.user_id, socket.assigns.scope, opts)

    {:noreply,
     socket
     |> assign(:user_rank, user_rank)
     |> assign(:rank_status, rank_status)
     |> assign(:percentile, percentile)
     |> stream(:leaderboard_entries, leaderboard, reset: true)}
  end

  @impl true
  def handle_info({:leaderboard_update, _data}, socket) do
    # Refresh leaderboard on PubSub event
    send(self(), :refresh_leaderboard)
    {:noreply, socket}
  end

  # Helper functions

  defp get_leaderboard(scope, opts) do
    case scope do
      :global ->
        LeaderboardContext.get_global_leaderboard(opts)

      :subject ->
        LeaderboardContext.get_subject_leaderboard(opts[:subject] || "math", opts)

      :cohort ->
        LeaderboardContext.get_cohort_leaderboard(opts[:grade_level] || 5, opts)

      _ ->
        LeaderboardContext.get_global_leaderboard(opts)
    end
  end

  defp format_metric_value(entry, metric) do
    case metric do
      :total_score -> "#{entry.total_score || 0} pts"
      :average_score -> "#{Float.round(entry.avg_score || 0.0, 1)}%"
      :streak -> "#{entry.current_streak || 0} days"
      :sessions -> "#{entry.sessions || 0} sessions"
      _ -> "N/A"
    end
  end

  defp rank_badge(rank) do
    case rank do
      1 -> "🥇"
      2 -> "🥈"
      3 -> "🥉"
      _ -> "##{rank}"
    end
  end

  defp rank_color(rank) do
    case rank do
      1 -> "text-yellow-600 font-bold"
      2 -> "text-gray-400 font-bold"
      3 -> "text-orange-600 font-bold"
      _ -> "text-gray-600"
    end
  end

  defp scope_name(scope) do
    case scope do
      :global -> "Global"
      :subject -> "Subject"
      :cohort -> "Cohort"
      _ -> "Global"
    end
  end

  defp metric_name(metric) do
    case metric do
      :total_score -> "Total Score"
      :average_score -> "Average Score"
      :streak -> "Current Streak"
      :sessions -> "Practice Sessions"
      _ -> "Total Score"
    end
  end

  defp time_period_name(period) do
    case period do
      1 -> "Today"
      7 -> "This Week"
      30 -> "This Month"
      _ -> "#{period} Days"
    end
  end
end
