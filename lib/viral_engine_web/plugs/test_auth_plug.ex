defmodule ViralEngineWeb.Plugs.TestAuthPlug do
  @moduledoc """
  Test-only authentication plug that automatically authenticates the test user.

  This plug is ONLY active in the test environment and provides automatic
  authentication for E2E tests without requiring login flows.

  ## Security

  This plug is disabled in all environments except `:test` to prevent
  authentication bypass in development or production.

  ## Usage

  Add to router pipeline in test environment:

      if Mix.env() == :test do
        plug ViralEngineWeb.Plugs.TestAuthPlug
      end

  """
  import Plug.Conn
  require Logger

  alias ViralEngine.Repo
  alias ViralEngine.Accounts.User

  def init(opts), do: opts

  @doc """
  Automatically authenticate as the test user in test environment.

  This assigns both `current_user` and `current_user_id` to the connection,
  making them available in LiveViews and controllers.
  """
  def call(conn, _opts) do
    # Only run in test environment
    if Mix.env() == :test do
      case Repo.get_by(User, email: "test@example.com") do
        nil ->
          Logger.warning("""
          [TestAuthPlug] Test user not found. Please run:
          MIX_ENV=test mix run priv/repo/seeds_test.exs
          """)

          conn

        test_user ->
          conn
          |> assign(:current_user, test_user)
          |> assign(:current_user_id, test_user.id)
          |> put_session(:user_token, test_user.session_token)
      end
    else
      # Safety: ensure this plug does nothing in non-test environments
      conn
    end
  end
end
