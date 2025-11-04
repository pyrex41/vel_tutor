import Config

# Configures the database
config :viral_engine, ViralEngine.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Configures the endpoint
config :viral_engine, ViralEngineWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "localhost"],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# MCP Orchestrator configuration
config :viral_engine, :mcp_orchestrator,
  timeout_ms: 150,
  circuit_breaker_enabled: true,
  max_concurrent_requests: 100,
  health_check_interval: 30_000

# Configure MCP agents
config :viral_engine, :mcp_agents, orchestrator: ViralEngine.Agents.Orchestrator

# Configure Telemetry
config :viral_engine, ViralEngineWeb.Telemetry,
  metrics: [
    ViralEngineWeb.Telemetry.Metrics
  ]

# Configure Redis for distributed PubSub (multi-node support)
redis_url = System.get_env("REDIS_URL") || "redis://localhost:6379/0"

if redis_url do
  config :viral_engine, ViralEngine.PubSub,
    adapter: Phoenix.PubSub.Redis,
    url: redis_url,
    node_name: System.get_env("FLY_MACHINE_ID") || :erlang.node()
end

# Configure Oban for distributed task queue
config :viral_engine, Oban,
  repo: ViralEngine.Repo,
  queues: [default: 10, webhooks: 20, batch: 50],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # Run anomaly detection every hour
       # {"0 * * * *", ViralEngine.Jobs.AnomalyDetectionWorker},  # TODO: Implement this worker
       # Check approval timeouts every 5 minutes
       # {"*/5 * * * *", ViralEngine.Jobs.ApprovalTimeoutChecker}  # TODO: Convert GenServer to Oban worker
     ]}
  ]
