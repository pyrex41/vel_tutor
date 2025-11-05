defmodule ViralEngineWeb.Plugs.DevAuthPlug do
  @moduledoc """
  Development-only authentication plug that automatically authenticates the dev user.

  This plug is ONLY active in the dev environment and provides automatic
  authentication for development without requiring login flows.

  ## Security

  This plug is disabled in all environments except `:dev` to prevent
  authentication bypass in test or production.

  ## Usage

  Add to router pipeline in dev environment:

      if Mix.env() == :dev do
        plug ViralEngineWeb.Plugs.DevAuthPlug
      end

  """
  import Plug.Conn
  require Logger

  alias ViralEngine.Repo
  alias ViralEngine.Accounts.User

  def init(opts), do: opts

  @doc """
  Automatically authenticate as the dev user in dev environment.

  This assigns both `current_user` and `current_user_id` to the connection,
  making them available in LiveViews and controllers.
  """
  def call(conn, _opts) do
    # Only run in dev environment
    if Mix.env() == :dev do
      case Repo.get_by(User, email: "dev@example.com") do
        nil ->
          Logger.warning("""
          [DevAuthPlug] Dev user not found. Please run:
          mix run priv/repo/seeds_dev.exs
          """)

          conn

        dev_user ->
          conn
          |> assign(:current_user, dev_user)
          |> assign(:current_user_id, dev_user.id)
          |> put_session(:user_token, dev_user.session_token)
      end
    else
      # Safety: ensure this plug does nothing in non-dev environments
      conn
    end
  end
end
