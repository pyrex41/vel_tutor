defmodule ViralEngineWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a channel.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import ViralEngineWeb.ChannelCase

      # The default endpoint for testing
      @endpoint ViralEngineWeb.Endpoint
    end
  end

  setup tags do
    ViralEngine.DataCase.setup_sandbox(tags)
    :ok
  end
end
