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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"