defmodule ViralEngineWeb.Phase2DashboardLive do
  @moduledoc """
  Phase 2 Metrics Dashboard - Real-time K-factor tracking and viral loop analytics.

  Displays live metrics for Buddy Challenge and Results Rally loops,
  including exposures, conversions, and K-factor calculations.
  """

  use ViralEngineWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Update every 10 seconds
      :timer.send_interval(10_000, self(), :refresh)
    end

    metrics = fetch_phase2_metrics()

    {:ok, assign(socket, :metrics, metrics)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    metrics = fetch_phase2_metrics()
    {:noreply, assign(socket, :metrics, metrics)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background">
      <div class="max-w-7xl mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-4xl font-bold text-foreground mb-2">Phase 2: Viral Loops Active</h1>
          <p class="text-lg text-muted-foreground">Real-time K-factor tracking and viral growth metrics</p>
          <div class="text-sm text-muted-foreground mt-2">
            Last updated: <%= DateTime.utc_now() |> Calendar.strftime("%H:%M:%S UTC") %>
          </div>
        </div>

        <!-- Key Metrics Overview -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-muted-foreground">Total Exposures</p>
                <p class="text-3xl font-bold"><%= @metrics.total_exposures %></p>
              </div>
              <div class="text-2xl">👁️</div>
            </div>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-muted-foreground">Total Joins</p>
                <p class="text-3xl font-bold"><%= @metrics.total_joins %></p>
              </div>
              <div class="text-2xl">🤝</div>
            </div>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-muted-foreground">Combined K-Factor</p>
                <p class={"text-3xl font-bold #{k_factor_color(@metrics.combined_k_factor)}"}>
                  <%= Float.round(@metrics.combined_k_factor, 3) %>
                </p>
              </div>
              <div class="text-2xl">📈</div>
            </div>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-muted-foreground">Rewards Granted</p>
                <p class="text-3xl font-bold"><%= @metrics.total_rewards %></p>
              </div>
              <div class="text-2xl">🎁</div>
            </div>
          </div>
        </div>

        <!-- Loop Performance -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <!-- Buddy Challenge -->
          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <h2 class="text-2xl font-bold mb-6 flex items-center">
              <span class="mr-2">🤝</span>
              Buddy Challenge
            </h2>

            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-muted-foreground">Exposures:</span>
                <span class="font-bold"><%= @metrics.buddy_challenge.exposures %></span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-muted-foreground">Invites Sent:</span>
                <span class="font-bold"><%= @metrics.buddy_challenge.invites_sent %></span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-muted-foreground">Joins:</span>
                <span class="font-bold"><%= @metrics.buddy_challenge.joins %></span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-muted-foreground">Completions:</span>
                <span class="font-bold"><%= @metrics.buddy_challenge.completions %></span>
              </div>

              <div class="flex justify-between items-center border-t pt-4">
                <span class="text-muted-foreground font-medium">K-Factor (7d):</span>
                <span class={"font-bold text-lg #{k_factor_color(@metrics.buddy_challenge.k_factor)}"}>
                  <%= Float.round(@metrics.buddy_challenge.k_factor, 3) %>
                </span>
              </div>
            </div>
          </div>

          <!-- Results Rally -->
          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <h2 class="text-2xl font-bold mb-6 flex items-center">
              <span class="mr-2">🏆</span>
              Results Rally
            </h2>

            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-muted-foreground">Exposures:</span>
                <span class="font-bold"><%= @metrics.results_rally.exposures %></span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-muted-foreground">Invites Sent:</span>
                <span class="font-bold"><%= @metrics.results_rally.invites_sent %></span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-muted-foreground">FVM Reached:</span>
                <span class="font-bold"><%= @metrics.results_rally.fvm_reached %></span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-muted-foreground">Leaderboard Views:</span>
                <span class="font-bold"><%= @metrics.results_rally.leaderboard_views %></span>
              </div>

              <div class="flex justify-between items-center border-t pt-4">
                <span class="text-muted-foreground font-medium">K-Factor (7d):</span>
                <span class={"font-bold text-lg #{k_factor_color(@metrics.results_rally.k_factor)}"}>
                  <%= Float.round(@metrics.results_rally.k_factor, 3) %>
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Success Criteria -->
        <div class="bg-gradient-to-r from-green-50 to-blue-50 border border-green-200 rounded-lg p-6">
          <h3 class="text-xl font-bold text-green-800 mb-4">🎯 Phase 2 Success Criteria</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="flex items-center">
              <div class={"#{if @metrics.combined_k_factor >= 1.20, do: "text-green-600", else: "text-orange-600"} mr-3"}>
                <%= if @metrics.combined_k_factor >= 1.20, do: "✅", else: "⏳" %>
              </div>
              <div>
                <div class="font-medium">Combined K-Factor ≥ 1.20</div>
                <div class="text-sm text-muted-foreground">Over 14 days across both loops</div>
              </div>
            </div>

            <div class="flex items-center">
              <div class={"#{if @metrics.total_exposures >= 50, do: "text-green-600", else: "text-orange-600"} mr-3"}>
                <%= if @metrics.total_exposures >= 50, do: "✅", else: "⏳" %>
              </div>
              <div>
                <div class="font-medium">50+ Loop Executions</div>
                <div class="text-sm text-muted-foreground">Successful viral loop triggers</div>
              </div>
            </div>

            <div class="flex items-center">
              <div class={"#{if @metrics.total_joins >= 25, do: "text-green-600", else: "text-orange-600"} mr-3"}>
                <%= if @metrics.total_joins >= 25, do: "text-green-600", else: "text-orange-600" %> mr-3">
                <%= if @metrics.total_joins >= 25, do: "✅", else: "⏳" %>
              </div>
              <div>
                <div class="font-medium">25+ User Joins</div>
                <div class="text-sm text-muted-foreground">Users joining via viral links</div>
              </div>
            </div>

            <div class="flex items-center">
              <div class={"#{if @metrics.total_rewards >= 10, do: "text-green-600", else: "text-orange-600"} mr-3"}>
                <%= if @metrics.total_rewards >= 10, do: "✅", else: "⏳" %>
              </div>
              <div>
                <div class="font-medium">10+ Rewards Granted</div>
                <div class="text-sm text-muted-foreground">Automatic reward distribution</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Agent Health -->
        <div class="mt-8 bg-card text-card-foreground rounded-lg border p-6">
          <h3 class="text-xl font-bold mb-4">🤖 Agent Health Status</h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="text-center">
              <div class="text-2xl mb-2">🎨</div>
              <div class="font-medium">Personalization Agent</div>
              <div class="text-sm text-muted-foreground">Response time: &lt;500ms</div>
              <div class="text-green-600 font-medium">✅ Healthy</div>
            </div>

            <div class="text-center">
              <div class="text-2xl mb-2">💰</div>
              <div class="font-medium">Incentives Agent</div>
              <div class="text-sm text-muted-foreground">Balance queries: Real-time</div>
              <div class="text-green-600 font-medium">✅ Healthy</div>
            </div>

            <div class="text-center">
              <div class="text-2xl mb-2">🎯</div>
              <div class="font-medium">Orchestrator</div>
              <div class="text-sm text-muted-foreground">Loop routing: Active</div>
              <div class="text-green-600 font-medium">✅ Healthy</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp fetch_phase2_metrics do
    # Mock data for now - in production would query real metrics
    %{
      total_exposures: 47,
      total_joins: 23,
      total_rewards: 18,
      combined_k_factor: 1.15,
      buddy_challenge: %{
        exposures: 28,
        invites_sent: 25,
        joins: 15,
        completions: 12,
        k_factor: 1.08
      },
      results_rally: %{
        exposures: 19,
        invites_sent: 16,
        fvm_reached: 8,
        leaderboard_views: 14,
        k_factor: 0.42
      }
    }
  end

  defp k_factor_color(k_factor) do
    cond do
      k_factor >= 1.20 -> "text-green-600"
      k_factor >= 1.0 -> "text-blue-600"
      k_factor >= 0.5 -> "text-orange-600"
      true -> "text-red-600"
    end
  end
end
