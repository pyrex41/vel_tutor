import Config
config :viral_engine, Oban, testing: :manual

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :viral_engine, ViralEngine.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "viral_engine_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Enable server for E2E tests (Playwright)
config :viral_engine, ViralEngineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "0WRLzjOVA1bsbq9dtjS1O9DAgo4lxP3xvhl/mxYvPQdkA6vV6UIvPt8c3xfhA2PJ",
  server: true

# In test we don't send emails.
config :viral_engine, ViralEngine.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, :console,
  level: :warning,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
