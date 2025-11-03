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
