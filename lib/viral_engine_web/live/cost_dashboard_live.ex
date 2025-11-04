defmodule ViralEngineWeb.CostDashboardLive do
  @moduledoc """
  Phoenix LiveView dashboard for cost tracking and budget management.
  """

  use Phoenix.LiveView
  alias ViralEngine.MetricsContext

  @default_time_range "30d"
  # Default monthly budget in USD
  @default_budget_limit 100.0

  def mount(_params, _session, socket) do
    # Initialize with default time range and budget settings
    end_time = DateTime.utc_now()
    start_time = calculate_start_time(@default_time_range, end_time)

    # Fetch cost metrics
    cost_data = fetch_cost_data(start_time, end_time)

    socket =
      socket
      |> assign(:time_range, @default_time_range)
      |> assign(:start_time, start_time)
      |> assign(:end_time, end_time)
      |> assign(:cost_data, cost_data)
      |> assign(:budget_limit, @default_budget_limit)
      |> assign(:alerts, calculate_budget_alerts(cost_data, @default_budget_limit))
      |> assign(:projections, calculate_cost_projections(cost_data))
      |> assign(:chart_data, prepare_cost_chart_data(cost_data))

    {:ok, socket}
  end

  def handle_params(%{"range" => range}, _uri, socket) do
    end_time = DateTime.utc_now()
    start_time = calculate_start_time(range, end_time)

    cost_data = fetch_cost_data(start_time, end_time)

    socket =
      socket
      |> assign(:time_range, range)
      |> assign(:start_time, start_time)
      |> assign(:end_time, end_time)
      |> assign(:cost_data, cost_data)
      |> assign(:alerts, calculate_budget_alerts(cost_data, socket.assigns.budget_limit))
      |> assign(:projections, calculate_cost_projections(cost_data))
      |> assign(:chart_data, prepare_cost_chart_data(cost_data))
      |> push_patch(to: "/dashboard/costs?range=#{range}")

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("change_time_range", %{"range" => range}, socket) do
    end_time = DateTime.utc_now()
    start_time = calculate_start_time(range, end_time)

    cost_data = fetch_cost_data(start_time, end_time)

    socket =
      socket
      |> assign(:time_range, range)
      |> assign(:start_time, start_time)
      |> assign(:end_time, end_time)
      |> assign(:cost_data, cost_data)
      |> assign(:alerts, calculate_budget_alerts(cost_data, socket.assigns.budget_limit))
      |> assign(:projections, calculate_cost_projections(cost_data))
      |> assign(:chart_data, prepare_cost_chart_data(cost_data))
      |> push_patch(to: "/dashboard/costs?range=#{range}")

    {:noreply, socket}
  end

  def handle_event("update_budget_limit", %{"limit" => limit}, socket) do
    budget_limit = String.to_float(limit)

    socket =
      socket
      |> assign(:budget_limit, budget_limit)
      |> assign(:alerts, calculate_budget_alerts(socket.assigns.cost_data, budget_limit))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Cost Tracking & Budget Dashboard</h1>
        <p class="text-gray-600">Monitor AI costs, track budget usage, and manage spending</p>
      </div>

      <!-- Budget Alerts -->
      <%= if @alerts != [] do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">Budget Alert</h3>
              <div class="mt-2 text-sm text-red-700">
                <ul role="list" class="list-disc pl-5 space-y-1">
                  <%= for alert <- @alerts do %>
                    <li><%= alert %></li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Controls -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Time Range Selector -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Time Range</label>
            <div class="flex gap-2">
              <%= for {range, label} <- [{"7d", "7 Days"}, {"30d", "30 Days"}, {"90d", "90 Days"}] do %>
                <button
                  phx-click="change_time_range"
                  phx-value-range={range}
                  class={"px-3 py-2 rounded-md text-sm font-medium transition-colors " <>
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

          <!-- Budget Limit -->
          <div>
            <label for="budget-limit" class="block text-sm font-medium text-gray-700 mb-2">
              Monthly Budget Limit (USD)
            </label>
            <input
              id="budget-limit"
              type="number"
              step="0.01"
              value={@budget_limit}
              phx-blur="update_budget_limit"
              phx-value-limit={@budget_limit}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>
        </div>
      </div>

      <!-- Cost Summary Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                <span class="text-white text-sm font-semibold">$</span>
              </div>
            </div>
            <div class="ml-4">
              <dt class="text-sm font-medium text-gray-500 truncate">Total Cost</dt>
              <dd class="text-lg font-semibold text-gray-900">$<%= format_currency(@cost_data.total_cost) %></dd>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                <span class="text-white text-sm font-semibold">📈</span>
              </div>
            </div>
            <div class="ml-4">
              <dt class="text-sm font-medium text-gray-500 truncate">Avg Daily Cost</dt>
              <dd class="text-lg font-semibold text-gray-900">$<%= format_currency(@cost_data.avg_daily_cost) %></dd>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
                <span class="text-white text-sm font-semibold">⚡</span>
              </div>
            </div>
            <div class="ml-4">
              <dt class="text-sm font-medium text-gray-500 truncate">Cost per Token</dt>
              <dd class="text-lg font-semibold text-gray-900">$<%= format_currency(@cost_data.cost_per_token) %></dd>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                <span class="text-white text-sm font-semibold">📊</span>
              </div>
            </div>
            <div class="ml-4">
              <dt class="text-sm font-medium text-gray-500 truncate">Budget Used</dt>
              <dd class="text-lg font-semibold text-gray-900"><%= format_percentage(@cost_data.budget_used_percent) %>%</dd>
            </div>
          </div>
        </div>
      </div>

      <!-- Charts -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <!-- Cost Trends Chart -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Cost Trends</h3>
          <div id="cost-trends-chart" class="h-64">
            <canvas id="cost-trends-canvas" width="400" height="200"></canvas>
          </div>
        </div>

        <!-- Budget Burn Rate Chart -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Budget Burn Rate</h3>
          <div id="budget-burn-chart" class="h-64">
            <canvas id="budget-burn-canvas" width="400" height="200"></canvas>
          </div>
        </div>
      </div>

      <!-- Cost Breakdown by Provider -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Cost Breakdown by Provider</h3>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Provider</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Total Cost</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Percentage</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Requests</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Avg Cost/Request</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for provider_data <- @cost_data.by_provider do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 capitalize">
                    <%= provider_data.provider %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    $<%= format_currency(provider_data.total_cost) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= format_percentage(provider_data.percentage) %>%
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= provider_data.request_count %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    $<%= format_currency(provider_data.avg_cost_per_request) %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Cost Projections -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Cost Projections</h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600">$<%= format_currency(@projections.month_end) %></div>
            <div class="text-sm text-gray-600">Projected Month End</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-green-600">$<%= format_currency(@projections.next_month) %></div>
            <div class="text-sm text-gray-600">Next Month Estimate</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-orange-600"><%= @projections.days_to_budget %> days</div>
            <div class="text-sm text-gray-600">Days to Budget Limit</div>
          </div>
        </div>
      </div>

      <!-- Per-Agent Breakdown -->
      <div class="bg-white rounded-lg shadow p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Per-Agent Cost Breakdown</h3>
        <div class="space-y-4">
          <%= for agent_data <- @cost_data.by_agent do %>
            <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
              <div class="flex items-center">
                <div class="ml-4">
                  <div class="text-sm font-medium text-gray-900"><%= agent_data.agent_name || "Unknown Agent" %></div>
                  <div class="text-sm text-gray-500"><%= agent_data.request_count %> requests</div>
                </div>
              </div>
              <div class="text-right">
                <div class="text-sm font-medium text-gray-900">$<%= format_currency(agent_data.total_cost) %></div>
                <div class="text-sm text-gray-500"><%= format_percentage(agent_data.percentage) %>% of total</div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Chart.js Script -->
      <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns"></script>
      <script>
        document.addEventListener('DOMContentLoaded', function() {
          initCharts();
        });

        document.addEventListener('phoenix:page-loading-stop', function() {
          setTimeout(initCharts, 100);
        });

        function initCharts() {
          const costTrendsData = <%= Jason.encode!(@chart_data.cost_trends) %>;
          const budgetBurnData = <%= Jason.encode!(@chart_data.budget_burn) %>;

          // Cost Trends Chart
          const costTrendsCtx = document.getElementById('cost-trends-canvas');
          if (costTrendsCtx) {
            new Chart(costTrendsCtx, {
              type: 'line',
              data: {
                datasets: costTrendsData
              },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                  x: {
                    type: 'time',
                    time: {
                      unit: 'day'
                    }
                  },
                  y: {
                    beginAtZero: true,
                    title: {
                      display: true,
                      text: 'Cost (USD)'
                    }
                  }
                }
              }
            });
          }

          // Budget Burn Rate Chart
          const budgetBurnCtx = document.getElementById('budget-burn-canvas');
          if (budgetBurnCtx) {
            new Chart(budgetBurnCtx, {
              type: 'doughnut',
              data: {
                labels: ['Used', 'Remaining'],
                datasets: [{
                  data: budgetBurnData,
                  backgroundColor: [
                    'rgba(239, 68, 68, 0.8)',
                    'rgba(34, 197, 94, 0.8)'
                  ],
                  borderWidth: 1
                }]
              },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                  legend: {
                    position: 'bottom'
                  }
                }
              }
            });
          }
        }
      </script>
    </div>
    """
  end

  # Helper functions

  defp calculate_start_time("7d", end_time), do: DateTime.add(end_time, -604_800, :second)
  defp calculate_start_time("30d", end_time), do: DateTime.add(end_time, -2_592_000, :second)
  defp calculate_start_time("90d", end_time), do: DateTime.add(end_time, -7_776_000, :second)
  defp calculate_start_time(_range, end_time), do: DateTime.add(end_time, -2_592_000, :second)

  defp fetch_cost_data(start_time, end_time) do
    # Fetch metrics and calculate cost data
    metrics = MetricsContext.get_metrics(start_time, end_time)

    # Calculate costs based on provider pricing
    cost_data = calculate_costs_from_metrics(metrics)

    # Group by provider
    by_provider = group_costs_by_provider(cost_data)

    # Group by agent (assuming agent info is in metrics or can be derived)
    by_agent = group_costs_by_agent(cost_data)

    # Calculate totals
    total_cost = Enum.sum(Enum.map(cost_data, & &1.cost))
    total_tokens = Enum.sum(Enum.map(cost_data, & &1.tokens))
    cost_per_token = if total_tokens > 0, do: total_cost / total_tokens, else: 0

    # Calculate average daily cost
    days_diff = DateTime.diff(end_time, start_time, :day)
    avg_daily_cost = if days_diff > 0, do: total_cost / days_diff, else: total_cost

    # Calculate budget usage percentage
    budget_used_percent = total_cost / @default_budget_limit * 100

    %{
      total_cost: total_cost,
      avg_daily_cost: avg_daily_cost,
      cost_per_token: cost_per_token,
      budget_used_percent: budget_used_percent,
      by_provider: by_provider,
      by_agent: by_agent,
      daily_costs: calculate_daily_costs(cost_data, start_time, end_time)
    }
  end

  defp calculate_costs_from_metrics(metrics) do
    # This is a simplified cost calculation
    # In reality, you'd use actual pricing from each provider
    Enum.map(metrics, fn metric ->
      cost = Decimal.to_float(metric.total_cost)
      tokens = metric.total_tokens

      %{
        provider: metric.provider,
        # Mock agent assignment
        agent: "agent_#{:rand.uniform(5)}",
        cost: cost,
        tokens: tokens,
        timestamp: metric.timestamp
      }
    end)
  end

  defp group_costs_by_provider(cost_data) do
    grouped = Enum.group_by(cost_data, & &1.provider)

    total_cost = Enum.sum(Enum.map(cost_data, & &1.cost))

    Enum.map(grouped, fn {provider, entries} ->
      provider_cost = Enum.sum(Enum.map(entries, & &1.cost))
      request_count = length(entries)
      avg_cost_per_request = if request_count > 0, do: provider_cost / request_count, else: 0
      percentage = if total_cost > 0, do: provider_cost / total_cost * 100, else: 0

      %{
        provider: provider,
        total_cost: provider_cost,
        percentage: percentage,
        request_count: request_count,
        avg_cost_per_request: avg_cost_per_request
      }
    end)
    |> Enum.sort_by(& &1.total_cost, :desc)
  end

  defp group_costs_by_agent(cost_data) do
    grouped = Enum.group_by(cost_data, & &1.agent)

    total_cost = Enum.sum(Enum.map(cost_data, & &1.cost))

    Enum.map(grouped, fn {agent, entries} ->
      agent_cost = Enum.sum(Enum.map(entries, & &1.cost))
      request_count = length(entries)
      percentage = if total_cost > 0, do: agent_cost / total_cost * 100, else: 0

      %{
        agent_name: agent,
        total_cost: agent_cost,
        percentage: percentage,
        request_count: request_count
      }
    end)
    |> Enum.sort_by(& &1.total_cost, :desc)
  end

  defp calculate_daily_costs(cost_data, start_time, end_time) do
    # Group costs by day
    grouped =
      Enum.group_by(cost_data, fn entry ->
        DateTime.to_date(entry.timestamp)
      end)

    start_date = DateTime.to_date(start_time)
    end_date = DateTime.to_date(end_time)

    # Generate date range and calculate daily costs
    Date.range(start_date, end_date)
    |> Enum.map(fn date ->
      daily_entries = Map.get(grouped, date, [])
      daily_cost = Enum.sum(Enum.map(daily_entries, & &1.cost))

      %{date: date, cost: daily_cost}
    end)
  end

  defp calculate_budget_alerts(cost_data, _budget_limit) do
    used_percent = cost_data.budget_used_percent

    cond do
      used_percent >= 100 ->
        ["Budget limit exceeded! Current usage: #{format_percentage(used_percent)}%"]

      used_percent >= 80 ->
        ["Budget usage at #{format_percentage(used_percent)}% - approaching limit"]

      true ->
        []
    end
  end

  defp calculate_cost_projections(cost_data) do
    avg_daily_cost = cost_data.avg_daily_cost
    total_cost = cost_data.total_cost
    budget_limit = @default_budget_limit

    # Calculate days in current period
    days_elapsed = length(cost_data.daily_costs)
    _days_elapsed = if days_elapsed == 0, do: 1, else: days_elapsed

    # Project month-end cost (assuming 30 days)
    month_end_projection = avg_daily_cost * 30

    # Project next month
    next_month_projection = avg_daily_cost * 30

    # Calculate days to budget limit
    remaining_budget = budget_limit - total_cost

    days_to_budget =
      if avg_daily_cost > 0, do: round(remaining_budget / avg_daily_cost), else: 999

    %{
      month_end: month_end_projection,
      next_month: next_month_projection,
      days_to_budget: max(0, days_to_budget)
    }
  end

  defp prepare_cost_chart_data(cost_data) do
    # Cost trends data
    cost_trends = [
      %{
        label: "Daily Cost",
        data:
          Enum.map(cost_data.daily_costs, fn daily ->
            %{
              x: Date.to_string(daily.date),
              y: daily.cost
            }
          end),
        borderColor: "#3B82F6",
        backgroundColor: "#3B82F640",
        fill: false
      }
    ]

    # Budget burn data
    used = cost_data.total_cost
    remaining = max(0, @default_budget_limit - used)

    budget_burn = [used, remaining]

    %{
      cost_trends: cost_trends,
      budget_burn: budget_burn
    }
  end

  defp format_currency(amount) when is_float(amount) do
    :erlang.float_to_binary(amount, decimals: 2)
  end

  defp format_currency(amount) when is_integer(amount) do
    Integer.to_string(amount) <> ".00"
  end

  defp format_percentage(percent) when is_float(percent) do
    :erlang.float_to_binary(percent, decimals: 1)
  end

  defp format_percentage(percent) when is_integer(percent) do
    Integer.to_string(percent)
  end
end
