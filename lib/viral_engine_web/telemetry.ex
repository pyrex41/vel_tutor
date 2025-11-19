defmodule ViralEngineWeb.Telemetry do
  @moduledoc """
  Telemetry integration for Viral Engine.

  Provides metrics and monitoring for MCP agents and viral loops.
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller for system metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # MCP Agent Metrics
      counter("mcp.orchestrator.event_triggered",
        tags: [:event_type]
      ),
      summary("mcp.orchestrator.request.duration",
        unit: {:native, :millisecond}
      ),
      counter("mcp.orchestrator.error",
        tags: [:error_type]
      ),

      # Viral Loop Metrics
      counter("viral.loop.activated",
        tags: [:loop_type]
      ),
      counter("viral.event.processed",
        tags: [:event_type]
      ),

      # Database Metrics
      summary("viral_engine.repo.query.duration",
        unit: {:native, :millisecond}
      )
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__, :measure_orchestrator_health, []}
    ]
  end

  def measure_orchestrator_health do
    try do
      case ViralEngine.Agents.Orchestrator.health() do
        %{active_loops: active_loops, cache_size: cache_size} ->
          :telemetry.execute([:mcp, :orchestrator, :health], %{
            active_loops: active_loops,
            cache_size: cache_size
          })

        _ ->
          :ok
      end
    catch
      :exit, {:noproc, _} ->
        # Orchestrator not started yet, skip measurement
        :ok
    end
  end
end
