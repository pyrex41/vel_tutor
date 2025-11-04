defmodule ViralEngineWeb.PerformanceDashboardLive do
  @moduledoc """
  Phoenix LiveView dashboard for visualizing provider performance metrics over time.
  """

  use Phoenix.LiveView
  alias ViralEngine.MetricsContext
  alias ViralEngine.PubSub

  # Import Phoenix.LiveView helpers
  import Phoenix.LiveView

  @default_time_range "24h"

  def mount(_params, _session, socket) do
    # Subscribe to real-time metrics updates
    Phoenix.PubSub.subscribe(PubSub, "metrics:updates")

    # Initialize with default time range (last 24 hours)
    end_time = DateTime.utc_now()
    start_time = calculate_start_time(@default_time_range, end_time)

    # Fetch initial metrics
    metrics = fetch_metrics(start_time, end_time)

    socket =
      socket
      |> assign(:time_range, @default_time_range)
      |> assign(:start_time, start_time)
      |> assign(:end_time, end_time)
      |> assign(:metrics, metrics)
      |> assign(:selected_providers, ["openai", "groq", "perplexity"])
      |> assign(:chart_data, prepare_chart_data(metrics))

    {:ok, socket}
  end

  def handle_params(%{"range" => range}, _uri, socket) do
    # Handle URL parameters for time range
    end_time = DateTime.utc_now()
    start_time = calculate_start_time(range, end_time)

    metrics = fetch_metrics(start_time, end_time)

    socket =
      socket
      |> assign(:time_range, range)
      |> assign(:start_time, start_time)
      |> assign(:end_time, end_time)
      |> assign(:metrics, metrics)
      |> assign(:chart_data, prepare_chart_data(metrics))

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("change_time_range", %{"range" => range}, socket) do
    # Update time range and fetch new data
    end_time = DateTime.utc_now()
    start_time = calculate_start_time(range, end_time)

    metrics = fetch_metrics(start_time, end_time)

    socket =
      socket
      |> assign(:time_range, range)
      |> assign(:start_time, start_time)
      |> assign(:end_time, end_time)
      |> assign(:metrics, metrics)
      |> assign(:chart_data, prepare_chart_data(metrics))
      |> push_patch(to: "/dashboard/performance?range=#{range}")

    {:noreply, socket}
  end

  def handle_event("toggle_provider", %{"provider" => provider}, socket) do
    selected_providers = socket.assigns.selected_providers

    new_selected =
      if provider in selected_providers do
        List.delete(selected_providers, provider)
      else
        [provider | selected_providers]
      end

    socket =
      socket
      |> assign(:selected_providers, new_selected)
      |> assign(:chart_data, prepare_chart_data(socket.assigns.metrics, new_selected))

    {:noreply, socket}
  end

  def handle_event("export_csv", _params, socket) do
    # Generate CSV data
    csv_content = generate_csv(socket.assigns.metrics)

    # Create a data URL for download (URL encode the CSV content)
    encoded_csv = URI.encode_www_form(csv_content)
    data_url = "data:text/csv;charset=utf-8,#{encoded_csv}"

    filename =
      "performance-metrics-#{DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()}.csv"

    socket =
      socket
      |> assign(:csv_download_url, data_url)
      |> assign(:csv_filename, filename)

    {:noreply, socket}
  end

  def handle_info({:metric_collected, new_metric}, socket) do
    # Handle real-time metrics updates
    current_metrics = socket.assigns.metrics
    start_time = socket.assigns.start_time
    end_time = socket.assigns.end_time

    # Only update if the new metric is within the current time range
    if DateTime.compare(new_metric.timestamp, start_time) in [:gt, :eq] and
         DateTime.compare(new_metric.timestamp, end_time) in [:lt, :eq] do
      # Add the new metric to the current list
      updated_metrics = [new_metric | current_metrics]

      socket
      |> assign(:metrics, updated_metrics)
      |> assign(
        :chart_data,
        prepare_chart_data(updated_metrics, socket.assigns.selected_providers)
      )
    else
      socket
    end

    {:noreply, socket}
  end

  def handle_info(:update_metrics, socket) do
    # Handle periodic updates (fallback)
    start_time = socket.assigns.start_time
    end_time = DateTime.utc_now()

    metrics = fetch_metrics(start_time, end_time)

    socket =
      socket
      |> assign(:end_time, end_time)
      |> assign(:metrics, metrics)
      |> assign(:chart_data, prepare_chart_data(metrics, socket.assigns.selected_providers))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Provider Performance Dashboard</h1>
        <p class="text-gray-600">Monitor AI provider performance metrics in real-time</p>
      </div>

      <!-- Time Range Selector -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <div class="flex flex-wrap items-center gap-4">
          <label class="font-medium text-gray-700">Time Range:</label>
          <div class="flex gap-2">
            <%= for {range, label} <- [{"1h", "1 Hour"}, {"24h", "24 Hours"}, {"7d", "7 Days"}, {"30d", "30 Days"}] do %>
              <button
                phx-click="change_time_range"
                phx-value-range={range}
                class={"px-4 py-2 rounded-md text-sm font-medium transition-colors " <>
                  if assigns.time_range == range do
                    "bg-blue-600 text-white"
                  else
                    "bg-gray-100 text-gray-700 hover:bg-gray-200"
                  end}
              >
                <%= label %>
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Provider Toggles -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <div class="flex flex-wrap items-center gap-4">
          <label class="font-medium text-gray-700">Providers:</label>
          <div class="flex gap-2">
            <%= for provider <- ["openai", "groq", "perplexity"] do %>
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  phx-click="toggle_provider"
                  phx-value-provider={provider}
                  checked={provider in assigns.selected_providers}
                  class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <span class="text-sm font-medium text-gray-700 capitalize"><%= provider %></span>
              </label>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Charts Section -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <!-- Latency Chart -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Latency (P50)</h3>
          <div id="latency-chart" class="h-64">
            <canvas id="latency-canvas" width="400" height="200"></canvas>
          </div>
        </div>

        <!-- Success Rate Chart -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Success Rate</h3>
          <div id="success-rate-chart" class="h-64">
            <canvas id="success-rate-canvas" width="400" height="200"></canvas>
          </div>
        </div>
      </div>

      <!-- Fallback Frequency Chart -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Fallback Frequency</h3>
        <div id="fallback-chart" class="h-64">
          <canvas id="fallback-canvas" width="400" height="200"></canvas>
        </div>
      </div>

      <!-- Summary Stats -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Summary Statistics</h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600"><%= length(assigns.metrics) %></div>
            <div class="text-sm text-gray-600">Total Requests</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-green-600">
              <%= if length(assigns.metrics) > 0 do %>
                <%= round(Enum.sum(Enum.map(assigns.metrics, & &1.task_count)) / length(assigns.metrics)) %>
              <% else %>
                0
              <% end %>
            </div>
            <div class="text-sm text-gray-600">Avg Tasks/Minute</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-purple-600">
              <%= if length(assigns.metrics) > 0 do %>
                <%= Enum.count(assigns.selected_providers) %>
              <% else %>
                0
              <% end %>
            </div>
            <div class="text-sm text-gray-600">Active Providers</div>
          </div>
        </div>
      </div>

      <!-- CSV Export -->
      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">Export Data</h3>
            <p class="text-sm text-gray-600">Download performance metrics as CSV</p>
          </div>
          <button
            phx-click="export_csv"
            class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md font-medium transition-colors"
          >
            Generate CSV
          </button>
        </div>
        <%= if assigns[:csv_download_url] do %>
          <div class="mt-4 p-4 bg-green-50 border border-green-200 rounded-md">
            <p class="text-sm text-green-800 mb-2">CSV generated successfully!</p>
            <a
              href={@csv_download_url}
              download={@csv_filename}
              class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-green-700 bg-green-100 hover:bg-green-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
            >
              Download CSV
            </a>
          </div>
        <% end %>
      </div>

      <!-- Chart.js Script -->
      <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
      <script>
        // Initialize charts when DOM is loaded
        document.addEventListener('DOMContentLoaded', function() {
          initCharts();
        });

        // Re-initialize charts when LiveView updates
        document.addEventListener('phoenix:page-loading-stop', function() {
          setTimeout(initCharts, 100);
        });

        function initCharts() {
          const latencyData = <%= Jason.encode!(@chart_data.latency) %>;
          const successRateData = <%= Jason.encode!(@chart_data.success_rate) %>;
          const fallbackData = <%= Jason.encode!(@chart_data.fallback_frequency) %>;

          // Latency Chart
          const latencyCtx = document.getElementById('latency-canvas');
          if (latencyCtx) {
            new Chart(latencyCtx, {
              type: 'line',
              data: {
                datasets: latencyData
              },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                  x: {
                    type: 'time',
                    time: {
                      unit: 'hour'
                    }
                  },
                  y: {
                    beginAtZero: true,
                    title: {
                      display: true,
                      text: 'Latency (ms)'
                    }
                  }
                }
              }
            });
          }

          // Success Rate Chart
          const successCtx = document.getElementById('success-rate-canvas');
          if (successCtx) {
            new Chart(successCtx, {
              type: 'bar',
              data: {
                labels: successRateData.map(d => d.provider),
                datasets: [{
                  label: 'Success Rate',
                  data: successRateData.map(d => d.rate),
                  backgroundColor: 'rgba(34, 197, 94, 0.8)',
                  borderColor: 'rgba(34, 197, 94, 1)',
                  borderWidth: 1
                }]
              },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                  y: {
                    beginAtZero: true,
                    max: 1,
                    title: {
                      display: true,
                      text: 'Rate'
                    }
                  }
                }
              }
            });
          }

          // Fallback Frequency Chart
          const fallbackCtx = document.getElementById('fallback-canvas');
          if (fallbackCtx) {
            new Chart(fallbackCtx, {
              type: 'pie',
              data: {
                labels: fallbackData.map(d => d.provider),
                datasets: [{
                  data: fallbackData.map(d => d.frequency),
                  backgroundColor: [
                    'rgba(59, 130, 246, 0.8)',
                    'rgba(16, 185, 129, 0.8)',
                    'rgba(245, 158, 11, 0.8)'
                  ],
                  borderWidth: 1
                }]
              },
              options: {
                responsive: true,
                maintainAspectRatio: false
              }
            });
          }
        }
      </script>
    </div>
    """
  end

  # Helper functions

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  # Private functions

  defp calculate_start_time("1h", end_time), do: DateTime.add(end_time, -3600, :second)
  defp calculate_start_time("24h", end_time), do: DateTime.add(end_time, -86400, :second)
  defp calculate_start_time("7d", end_time), do: DateTime.add(end_time, -604_800, :second)
  defp calculate_start_time("30d", end_time), do: DateTime.add(end_time, -2_592_000, :second)
  defp calculate_start_time(_range, end_time), do: DateTime.add(end_time, -86400, :second)

  defp fetch_metrics(start_time, end_time) do
    MetricsContext.get_metrics(start_time, end_time)
  end

  defp prepare_chart_data(metrics, selected_providers \\ ["openai", "groq", "perplexity"]) do
    # Group metrics by provider and prepare for charting
    metrics_by_provider = Enum.group_by(metrics, & &1.provider)

    # Prepare latency chart data
    latency_data =
      Enum.map(selected_providers, fn provider ->
        provider_metrics = Map.get(metrics_by_provider, provider, [])

        points =
          Enum.map(provider_metrics, fn metric ->
            %{
              x: DateTime.to_unix(metric.timestamp),
              y: metric.latency_p50
            }
          end)

        %{
          label: provider,
          data: points,
          borderColor: provider_color(provider),
          backgroundColor: provider_color(provider, 0.1)
        }
      end)

    # Prepare success rate data (simplified - would need success/failure tracking)
    success_rate_data = calculate_success_rates(metrics_by_provider, selected_providers)

    # Prepare fallback frequency data (simplified)
    fallback_data = calculate_fallback_frequencies(metrics_by_provider, selected_providers)

    %{
      latency: latency_data,
      success_rate: success_rate_data,
      fallback_frequency: fallback_data
    }
  end

  defp calculate_success_rates(_metrics_by_provider, _selected_providers) do
    # Placeholder - would calculate from actual success/failure data
    # For now, return mock data
    [
      %{provider: "openai", rate: 0.95},
      %{provider: "groq", rate: 0.92},
      %{provider: "perplexity", rate: 0.88}
    ]
  end

  defp calculate_fallback_frequencies(_metrics_by_provider, _selected_providers) do
    # Placeholder - would calculate from actual fallback events
    # For now, return mock data
    [
      %{provider: "openai", frequency: 0.02},
      %{provider: "groq", frequency: 0.05},
      %{provider: "perplexity", frequency: 0.08}
    ]
  end

  defp provider_color("openai"), do: "#3B82F6"
  defp provider_color("groq"), do: "#10B981"
  defp provider_color("perplexity"), do: "#F59E0B"
  defp provider_color(_), do: "#6B7280"

  defp provider_color(provider, alpha) do
    color = provider_color(provider)
    # Simple alpha conversion (would use a proper color library in production)
    color <> Integer.to_string(round(alpha * 255), 16)
  end

  defp generate_csv(metrics) do
    # Generate CSV content from metrics
    headers = [
      "timestamp",
      "provider",
      "task_count",
      "latency_p50",
      "latency_p95",
      "latency_p99",
      "total_cost",
      "total_tokens"
    ]

    rows =
      Enum.map(metrics, fn metric ->
        [
          DateTime.to_string(metric.timestamp),
          metric.provider,
          metric.task_count,
          metric.latency_p50,
          metric.latency_p95,
          metric.latency_p99,
          Decimal.to_string(metric.total_cost),
          metric.total_tokens
        ]
      end)

    csv_rows = [headers | rows]

    Enum.map_join(csv_rows, "\n", fn row ->
      Enum.join(row, ",")
    end)
  end
end
