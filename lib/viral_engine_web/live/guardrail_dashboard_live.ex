defmodule ViralEngineWeb.GuardrailDashboardLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.GuardrailMetricsContext
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
        # Refresh metrics every 30 seconds
        :timer.send_interval(30_000, self(), :refresh_metrics)
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
  def handle_event("dismiss_alert", %{"index" => index_str}, socket) do
    # In production, you'd persist dismissed alerts
    index = String.to_integer(index_str)
    alerts = socket.assigns.alerts_data.alerts
    updated_alerts = List.delete_at(alerts, index)

    socket = assign(socket, :alerts_data, %{
      socket.assigns.alerts_data | alerts: updated_alerts, total_alerts: length(updated_alerts)
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh_metrics, socket) do
    days = socket.assigns.period_days
    {:noreply, load_metrics(socket, days)}
  end

  defp load_metrics(socket, days) do
    # Compute health score and all components
    health_data = GuardrailMetricsContext.compute_health_score(days: days)

    # Get active alerts
    alerts_data = GuardrailMetricsContext.get_active_alerts(days: days)

    # Extract components for easier template access
    fraud_data = health_data.components.fraud
    bot_data = health_data.components.bots
    opt_out_data = health_data.components.opt_outs
    coppa_data = health_data.components.coppa
    anomaly_data = health_data.components.anomalies

    socket
    |> assign(:period_days, days)
    |> assign(:health_score, health_data.health_score)
    |> assign(:health_status, health_data.health_status)
    |> assign(:deductions, health_data.deductions)
    |> assign(:fraud_data, fraud_data)
    |> assign(:bot_data, bot_data)
    |> assign(:opt_out_data, opt_out_data)
    |> assign(:coppa_data, coppa_data)
    |> assign(:anomaly_data, anomaly_data)
    |> assign(:alerts_data, alerts_data)
    |> assign(:last_updated, DateTime.utc_now())
  end

  # Render template

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Guardrail Metrics Dashboard</h1>
        <p class="mt-2 text-sm text-gray-600">
          Monitor fraud, compliance, and viral feature health
        </p>
      </div>

      <!-- Controls -->
      <div class="mb-6 flex items-center justify-between">
        <form phx-change="change_period" class="flex items-center space-x-4">
          <label class="text-sm font-medium text-gray-700">Time Period:</label>
          <select name="days" class="rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500">
            <option value="7" selected={@period_days == 7}>Last 7 days</option>
            <option value="14" selected={@period_days == 14}>Last 14 days</option>
            <option value="30" selected={@period_days == 30}>Last 30 days</option>
          </select>
        </form>

        <div class="flex items-center space-x-4">
          <span class="text-xs text-gray-500">
            Last updated: <%= time_ago(@last_updated) %>
          </span>
          <button
            phx-click="refresh"
            class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 text-sm"
          >
            Refresh
          </button>
        </div>
      </div>

      <!-- Health Score Card -->
      <div class="mb-6">
        <div class={"rounded-lg shadow-lg p-6 #{health_score_bg(@health_status)}"}>
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold text-gray-900">Overall Health Score</h2>
              <p class="text-sm text-gray-600">System health across all viral features</p>
            </div>
            <div class="text-right">
              <div class={"text-4xl font-bold #{health_score_color(@health_status)}"}>
                <%= @health_score %>
              </div>
              <div class={"text-sm font-medium #{health_score_color(@health_status)}"}>
                <%= health_status_text(@health_status) %>
              </div>
            </div>
          </div>

          <!-- Deductions Breakdown -->
          <div class="mt-4 grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="text-center">
              <div class="text-xs text-gray-600">Fraud</div>
              <div class="text-sm font-semibold text-red-600">-<%= @deductions.fraud %></div>
            </div>
            <div class="text-center">
              <div class="text-xs text-gray-600">Bots</div>
              <div class="text-sm font-semibold text-red-600">-<%= @deductions.bot_behavior %></div>
            </div>
            <div class="text-center">
              <div class="text-xs text-gray-600">Opt-outs</div>
              <div class="text-sm font-semibold text-yellow-600">-<%= @deductions.opt_out_rate %></div>
            </div>
            <div class="text-center">
              <div class="text-xs text-gray-600">COPPA</div>
              <div class="text-sm font-semibold text-red-700">-<%= @deductions.coppa_violations %></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Active Alerts -->
      <%= if @alerts_data.total_alerts > 0 do %>
        <div class="mb-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-3">
            Active Alerts (<%= @alerts_data.total_alerts %>)
          </h2>
          <div class="space-y-2">
            <%= for {alert, index} <- Enum.with_index(@alerts_data.alerts) do %>
              <div class={"flex items-center justify-between p-4 rounded-lg #{alert_bg(alert.severity)}"}>
                <div class="flex items-center space-x-3">
                  <span class="text-2xl"><%= alert_icon(alert.severity) %></span>
                  <div>
                    <div class={"text-sm font-medium #{alert_text_color(alert.severity)}"}>
                      <%= alert_type_label(alert.type) %>
                    </div>
                    <div class="text-sm text-gray-700"><%= alert.message %></div>
                  </div>
                </div>
                <button
                  phx-click="dismiss_alert"
                  phx-value-index={index}
                  class="text-gray-400 hover:text-gray-600"
                >
                  ✕
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg">
          <div class="flex items-center space-x-2">
            <span class="text-2xl">✅</span>
            <span class="text-sm font-medium text-green-800">No active alerts - All systems healthy</span>
          </div>
        </div>
      <% end %>

      <!-- Metrics Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Fraud Detection -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Fraud Detection</h3>

          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-sm text-gray-600">Suspicious IPs</span>
              <span class={"text-sm font-semibold #{status_color(@fraud_data.total_flagged_ips)}"}>
                <%= @fraud_data.total_flagged_ips %>
              </span>
            </div>

            <div class="text-xs text-gray-500">
              Threshold: <%= @fraud_data.threshold_used %> clicks/IP/day
            </div>

            <%= if length(@fraud_data.suspicious_ips) > 0 do %>
              <div class="mt-4">
                <div class="text-xs font-medium text-gray-700 mb-2">Top Suspicious IPs:</div>
                <div class="space-y-1">
                  <%= for ip_stat <- Enum.take(@fraud_data.suspicious_ips, 5) do %>
                    <div class="flex justify-between text-xs">
                      <span class="font-mono text-gray-600"><%= ip_stat.ip_address %></span>
                      <span class="text-red-600"><%= ip_stat.click_count %> clicks</span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Bot Detection -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Bot Detection</h3>

          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-sm text-gray-600">Bot-like Devices</span>
              <span class={"text-sm font-semibold #{status_color(@bot_data.total_flagged_devices)}"}>
                <%= @bot_data.total_flagged_devices %>
              </span>
            </div>

            <div class="text-xs text-gray-500">
              Detection: <%= @bot_data.detection_params.min_clicks %>+ clicks in <%= @bot_data.detection_params.time_window_seconds %>s
            </div>

            <%= if length(@bot_data.bot_like_devices) > 0 do %>
              <div class="mt-4">
                <div class="text-xs font-medium text-gray-700 mb-2">Flagged Devices:</div>
                <div class="space-y-1">
                  <%= for device <- Enum.take(@bot_data.bot_like_devices, 3) do %>
                    <div class="flex justify-between text-xs">
                      <span class="font-mono text-gray-600"><%= String.slice(device.device_fingerprint || "", 0..15) %>...</span>
                      <span class="text-red-600"><%= device.total_clicks %> clicks</span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Opt-out Rates -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Opt-out Rates</h3>

          <div class="space-y-4">
            <div>
              <div class="flex justify-between items-center mb-1">
                <span class="text-sm text-gray-600">Parent Shares</span>
                <span class={"text-sm font-semibold #{opt_out_color(@opt_out_data.parent_shares.opt_out_rate)}"}>
                  <%= @opt_out_data.parent_shares.opt_out_rate %>%
                </span>
              </div>
              <div class="text-xs text-gray-500">
                <%= @opt_out_data.parent_shares.never_viewed %> / <%= @opt_out_data.parent_shares.total %> never viewed
              </div>
            </div>

            <div>
              <div class="flex justify-between items-center mb-1">
                <span class="text-sm text-gray-600">Attribution Links</span>
                <span class={"text-sm font-semibold #{opt_out_color(@opt_out_data.attribution_links.opt_out_rate)}"}>
                  <%= @opt_out_data.attribution_links.opt_out_rate %>%
                </span>
              </div>
              <div class="text-xs text-gray-500">
                <%= @opt_out_data.attribution_links.zero_clicks %> / <%= @opt_out_data.attribution_links.total %> zero clicks
              </div>
            </div>

            <div>
              <div class="flex justify-between items-center mb-1">
                <span class="text-sm text-gray-600">Study Sessions</span>
                <span class="text-sm font-semibold text-gray-900">
                  <%= @opt_out_data.study_sessions.avg_participants %> avg
                </span>
              </div>
              <div class="text-xs text-gray-500">
                <%= @opt_out_data.study_sessions.total %> total sessions
              </div>
            </div>
          </div>
        </div>

        <!-- COPPA Compliance -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">COPPA Compliance</h3>

          <div class="space-y-4">
            <div>
              <div class="flex justify-between items-center mb-1">
                <span class="text-sm text-gray-600">Parent Shares</span>
                <span class={"text-sm font-semibold #{compliance_color(@coppa_data.parent_shares.compliance_rate)}"}>
                  <%= @coppa_data.parent_shares.compliance_rate %>%
                </span>
              </div>
              <div class="text-xs text-gray-500">
                <%= @coppa_data.parent_shares.violations_found %> violations in <%= @coppa_data.parent_shares.total_checked %> checked
              </div>
            </div>

            <div>
              <div class="flex justify-between items-center mb-1">
                <span class="text-sm text-gray-600">Progress Reels</span>
                <span class={"text-sm font-semibold #{compliance_color(@coppa_data.progress_reels.compliance_rate)}"}>
                  <%= @coppa_data.progress_reels.compliance_rate %>%
                </span>
              </div>
              <div class="text-xs text-gray-500">
                <%= @coppa_data.progress_reels.violations_found %> violations in <%= @coppa_data.progress_reels.total_checked %> checked
              </div>
            </div>

            <div class="pt-3 border-t border-gray-200">
              <div class="flex justify-between items-center">
                <span class="text-sm font-medium text-gray-900">Overall Compliance</span>
                <span class={"text-lg font-bold #{compliance_color(@coppa_data.overall_compliance_rate)}"}>
                  <%= @coppa_data.overall_compliance_rate %>%
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Conversion Anomalies -->
        <div class="bg-white rounded-lg shadow p-6 md:col-span-2">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Conversion Anomalies</h3>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <div class="text-sm font-medium text-gray-700 mb-3">High Volume Referrers</div>
              <%= if length(@anomaly_data.suspicious_referrers) > 0 do %>
                <div class="space-y-2">
                  <%= for referrer <- Enum.take(@anomaly_data.suspicious_referrers, 5) do %>
                    <div class="flex justify-between items-center text-xs">
                      <span class="text-gray-600">User <%= referrer.referrer_id %> on <%= referrer.date %></span>
                      <span class="text-red-600 font-semibold"><%= referrer.conversion_count %> conversions</span>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-sm text-gray-500">No suspicious volume detected</div>
              <% end %>
            </div>

            <div>
              <div class="text-sm font-medium text-gray-700 mb-3">Unusually High Conversion Rates</div>
              <%= if length(@anomaly_data.high_conversion_rate_referrers) > 0 do %>
                <div class="space-y-2">
                  <%= for referrer <- Enum.take(@anomaly_data.high_conversion_rate_referrers, 5) do %>
                    <div class="flex justify-between items-center text-xs">
                      <span class="text-gray-600">User <%= referrer.referrer_id %></span>
                      <span class="text-orange-600 font-semibold"><%= referrer.conversion_rate %>% conv rate</span>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-sm text-gray-500">All conversion rates within normal range</div>
              <% end %>
            </div>
          </div>

          <div class="mt-4 pt-4 border-t border-gray-200">
            <div class="flex justify-between items-center">
              <span class="text-sm text-gray-600">Total Flagged Anomalies</span>
              <span class={"text-sm font-semibold #{status_color(@anomaly_data.total_flagged)}"}>
                <%= @anomaly_data.total_flagged %>
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp health_score_bg(status) do
    case status do
      :excellent -> "bg-green-50 border border-green-200"
      :good -> "bg-blue-50 border border-blue-200"
      :fair -> "bg-yellow-50 border border-yellow-200"
      :warning -> "bg-orange-50 border border-orange-200"
      :critical -> "bg-red-50 border border-red-200"
    end
  end

  defp health_score_color(status) do
    case status do
      :excellent -> "text-green-700"
      :good -> "text-blue-700"
      :fair -> "text-yellow-700"
      :warning -> "text-orange-700"
      :critical -> "text-red-700"
    end
  end

  defp health_status_text(status) do
    case status do
      :excellent -> "Excellent"
      :good -> "Good"
      :fair -> "Fair"
      :warning -> "Warning"
      :critical -> "Critical"
    end
  end

  defp alert_bg(severity) do
    case severity do
      :critical -> "bg-red-100 border border-red-300"
      :high -> "bg-orange-100 border border-orange-300"
      :medium -> "bg-yellow-100 border border-yellow-300"
      :low -> "bg-blue-100 border border-blue-300"
    end
  end

  defp alert_text_color(severity) do
    case severity do
      :critical -> "text-red-800"
      :high -> "text-orange-800"
      :medium -> "text-yellow-800"
      :low -> "text-blue-800"
    end
  end

  defp alert_icon(severity) do
    case severity do
      :critical -> "🚨"
      :high -> "⚠️"
      :medium -> "⚡"
      :low -> "ℹ️"
    end
  end

  defp alert_type_label(type) do
    case type do
      :coppa_violation -> "COPPA Violation"
      :fraud_detection -> "Fraud Detection"
      :bot_detection -> "Bot Detection"
      :high_opt_out -> "High Opt-out Rate"
      :conversion_anomaly -> "Conversion Anomaly"
      _ -> String.capitalize(to_string(type))
    end
  end

  defp status_color(count) do
    cond do
      count == 0 -> "text-green-600"
      count < 3 -> "text-yellow-600"
      count < 5 -> "text-orange-600"
      true -> "text-red-600"
    end
  end

  defp opt_out_color(rate) do
    cond do
      rate < 10 -> "text-green-600"
      rate < 20 -> "text-yellow-600"
      rate < 30 -> "text-orange-600"
      true -> "text-red-600"
    end
  end

  defp compliance_color(rate) do
    cond do
      rate >= 99 -> "text-green-600"
      rate >= 95 -> "text-blue-600"
      rate >= 90 -> "text-yellow-600"
      true -> "text-red-600"
    end
  end

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
