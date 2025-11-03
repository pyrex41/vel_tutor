defmodule ViralEngineWeb.Router do
  use ViralEngineWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/mcp", ViralEngineWeb do
    pipe_through(:api)

    # MCP agent endpoints
    post("/:agent/:method", AgentController, :call_agent)
  end

  # Enable LiveDashboard in development
  if Mix.env() == :dev do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through([:fetch_session, :protect_from_forgery])
      live_dashboard("/dashboard", metrics: ViralEngineWeb.Telemetry)
    end
  end
end
