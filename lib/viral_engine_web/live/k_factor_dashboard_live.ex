defmodule ViralEngineWeb.KFactorDashboardLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.ViralMetricsContext
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Require admin role
    unless user.role == "admin" do
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> redirect(to: "/dashboard")}
    else
      socket = if connected?(socket) do
        # Refresh metrics every 60 seconds
        {:ok, timer_ref} = :timer.send_interval(60_000, self(), :refresh_metrics)
        assign(socket, :timer_ref, timer_ref)
      else
        socket
      end

      # Initial load
      socket = load_metrics(socket, 7)  # Default to 7 days

      {:ok, assign(socket, :user, user)}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    # Clean up timer to prevent memory leaks
    if timer_ref = socket.assigns[:timer_ref] do
      :timer.cancel(timer_ref)
    end
    :ok
  end

  @impl true
  def handle_event("change_period", %{"days" => days_str}, socket) do
    days = String.to_integer(days_str)
    {:noreply, load_metrics(socket, days)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    days = socket.assigns.period_days
    {:noreply, load_metrics(socket, days)}
  end

  @impl true
  def handle_info(:refresh_metrics, socket) do
    days = socket.assigns.period_days
    {:noreply, load_metrics(socket, days)}
  end

  defp load_metrics(socket, days) do
    # Compute overall K-factor
    k_factor_data = ViralMetricsContext.compute_k_factor(days: days)

    # K-factor by source
    k_by_source = ViralMetricsContext.compute_k_factor_by_source(days)

    # Top referrers
    top_referrers = ViralMetricsContext.get_top_referrers(days: days, limit: 10)

    # Growth timeline
    timeline = ViralMetricsContext.get_growth_timeline(days)

    # Cycle time
    cycle_time = ViralMetricsContext.compute_cycle_time(days)

    # Viral coefficient
    viral_coeff = ViralMetricsContext.compute_viral_coefficient(days)

    socket
    |> assign(:period_days, days)
    |> assign(:k_factor_data, k_factor_data)
    |> assign(:k_by_source, k_by_source)
    |> assign(:top_referrers, top_referrers)
    |> assign(:timeline, timeline)
    |> assign(:cycle_time, cycle_time)
    |> assign(:viral_coefficient, viral_coeff)
    |> assign(:last_updated, DateTime.utc_now())
  end

  # Helper functions for UI
  defp k_factor_status(k_factor) when k_factor >= 1.2, do: "excellent"
  defp k_factor_status(k_factor) when k_factor >= 1.0, do: "good"
  defp k_factor_status(k_factor) when k_factor >= 0.8, do: "warning"
  defp k_factor_status(_k_factor), do: "poor"

  defp k_factor_description(k_factor) when k_factor >= 1.2 do
    "🚀 Viral! Exponential growth"
  end
  defp k_factor_description(k_factor) when k_factor >= 1.0 do
    "✅ Self-sustaining growth"
  end
  defp k_factor_description(k_factor) when k_factor >= 0.8 do
    "⚠️ Close to viral threshold"
  end
  defp k_factor_description(_k_factor) do
    "📈 Needs optimization"
  end

  defp format_percentage(value) when is_number(value) do
    "#{Float.round(value, 1)}%"
  end
  defp format_percentage(_), do: "0.0%"

  defp format_decimal(value) when is_number(value) do
    Float.round(value, 2)
  end
  defp format_decimal(_), do: 0.0

  defp source_display_name("buddy_challenge"), do: "Buddy Challenge"
  defp source_display_name("results_rally"), do: "Results Rally"
  defp source_display_name("proud_parent"), do: "Proud Parent"
  defp source_display_name("streak_rescue"), do: "Streak Rescue"
  defp source_display_name("study_buddy"), do: "Study Buddy"
  defp source_display_name(source), do: String.capitalize(source)

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end
