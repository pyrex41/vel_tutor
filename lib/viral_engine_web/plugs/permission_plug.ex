defmodule ViralEngineWeb.Plugs.PermissionPlug do
  @moduledoc """
  Plug for checking user permissions based on RBAC system.
  """

  import Plug.Conn
  alias ViralEngine.RBACContext

  @doc """
  Initializes the plug with required permission.
  """
  def init(permission), do: permission

  @doc """
  Checks if the current user has the required permission.
  Assumes user_id and organization_id are set in conn assigns.
  """
  def call(conn, permission) do
    user_id = conn.assigns[:current_user_id]
    organization_id = conn.assigns[:current_organization_id]

    if user_id && organization_id do
      if RBACContext.check_permission(user_id, permission, organization_id) do
        conn
      else
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{error: "Insufficient permissions"})
        |> halt()
      end
    else
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.json(%{error: "Authentication required"})
      |> halt()
    end
  end
end
