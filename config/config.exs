# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :viral_engine,
  ecto_repos: [ViralEngine.Repo]

# Configures the endpoint
config :viral_engine, ViralEngineWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "your_secret_key_base",
  render_errors: [
    formats: [html: ViralEngineWeb.ErrorHTML, json: ViralEngineWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ViralEngine.PubSub,
  live_view: [signing_salt: "your_signing_salt"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Anomaly Detection Configuration
config :viral_engine, :anomaly_detection,
  # Alert thresholds (mean + X * standard_deviation)
  alert_threshold_sigma: 3.0,
  # Minimum data points required for anomaly detection
  min_data_points: 10,
  # Check interval in seconds
  # 5 minutes
  check_interval_seconds: 300,
  # Metrics to monitor
  monitored_metrics: [:error_rate, :latency, :cost_per_task, :failures]

# Notification System Configuration
config :viral_engine, :notifications,
  # Email configuration
  email_enabled: true,
  email_from: "alerts@viralengine.com",
  email_recipients: ["admin@viralengine.com"],
  # Webhook configuration
  webhook_enabled: true,
  webhook_url: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
  # In-app notifications
  in_app_enabled: true

# Oban configuration for background job processing
config :viral_engine, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, fine_tuning: 5],
  repo: ViralEngine.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
