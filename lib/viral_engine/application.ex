defmodule ViralEngine.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      ViralEngine.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: ViralEngine.PubSub},
      # Start the Telemetry supervisor
      ViralEngineWeb.Telemetry,
      # Start Finch for HTTP requests
      {Finch, name: ViralEngine.Finch},
      # Start the approval timeout checker
      ViralEngine.ApprovalTimeoutChecker,
      # Start the anomaly detection worker
      ViralEngine.AnomalyDetectionWorker,
      # Start the MCP Orchestrator
      ViralEngine.Agents.Orchestrator,
      # Start the rate limit reset scheduler
      ViralEngine.Jobs.ResetHourlyLimits,
      # Start Oban for background job processing
      {Oban, Application.fetch_env!(:viral_engine, Oban)},
      # Start the Endpoint (http/https)
      ViralEngineWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ViralEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ViralEngineWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
