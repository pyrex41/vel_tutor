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
      if connected?(socket) do
        # Refresh metrics every 60 seconds
        :timer.send_interval(60_000, self(), :refresh_metrics)
      end

      # Initial load
      socket = load_metrics(socket, 7)  # Default to 7 days

      {:ok, assign(socket, :user, user)}
    end
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

  # Note: UI helper functions have been removed until a render/1 function or .heex template is implemented.
  # Functions included: k_factor_status/1, k_factor_description/1, format_percentage/1,
  # format_decimal/1, source_display_name/1, timeline_chart_data/1, format_date/1, time_ago/1
end
