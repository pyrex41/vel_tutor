defmodule ViralEngineWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """

  use Phoenix.Component
  use Phoenix.VerifiedRoutes,
    endpoint: ViralEngineWeb.Endpoint,
    router: ViralEngineWeb.Router

  import Phoenix.Controller, only: [get_csrf_token: 0]

  embed_templates "layouts/*"
end
