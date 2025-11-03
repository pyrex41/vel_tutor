import Config

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

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :viral_engine, ViralEngineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "your_secret_key_base",
  server: false

# In test we don't send emails.
config :viral_engine, ViralEngine.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, :console,
  level: :warn,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
