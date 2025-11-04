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

  # Helper functions

  defp k_factor_status(k_factor) do
    cond do
      k_factor >= 1.0 -> {"🚀", "Viral!", "text-green-600"}
      k_factor >= 0.5 -> {"📈", "Growing", "text-blue-600"}
      k_factor >= 0.2 -> {"📊", "Moderate", "text-yellow-600"}
      true -> {"📉", "Low", "text-red-600"}
    end
  end

  defp k_factor_description(k_factor) do
    cond do
      k_factor >= 1.0 ->
        "Exponential growth! Each user brings #{Float.round(k_factor, 2)} new users on average."

      k_factor >= 0.5 ->
        "Solid growth. Keep optimizing conversion rates to reach viral threshold."

      k_factor >= 0.2 ->
        "Moderate viral growth. Focus on increasing invites per user and conversion rates."

      true ->
        "Sub-viral. Need to improve both invite frequency and conversion rates."
    end
  end

  defp format_percentage(value) when is_float(value), do: "#{value}%"
  defp format_percentage(value) when is_integer(value), do: "#{value}%"
  defp format_percentage(_), do: "0%"

  defp format_decimal(value) when is_float(value), do: Float.to_string(value)
  defp format_decimal(value) when is_integer(value), do: Integer.to_string(value)
  defp format_decimal(_), do: "0"

  defp source_display_name(source) do
    case source do
      "buddy_challenge" -> "Buddy Challenges"
      "results_rally" -> "Results Rallies"
      "parent_share" -> "Parent Shares"
      "prep_pack" -> "Prep Packs"
      "study_session" -> "Study Sessions"
      _ -> String.capitalize(source)
    end
  end

  defp timeline_chart_data(timeline) do
    # Prepare data for chart rendering
    Enum.map(timeline, fn day ->
      %{
        date: format_date(day.date),
        links: day.links_created || 0,
        clicks: day.clicks || 0,
        conversions: day.conversions || 0
      }
    end)
  end

  defp format_date(date) when is_binary(date) do
    Date.from_iso8601!(date)
    |> Calendar.strftime("%m/%d")
  end
  defp format_date(%Date{} = date) do
    Calendar.strftime(date, "%m/%d")
  end
  defp format_date(_), do: "Unknown"

  defp time_ago(datetime) when not is_nil(datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      seconds < 60 -> "Just now"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86400 -> "#{div(seconds, 3600)} hours ago"
      true -> "#{div(seconds, 86400)} days ago"
    end
  end
  defp time_ago(_), do: "Unknown"
end
