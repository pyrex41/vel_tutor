defmodule ViralEngineWeb.RolesController do
  use ViralEngineWeb, :controller

  alias ViralEngine.{RBACContext, OrganizationContext}
  require Logger

  action_fallback(ViralEngineWeb.FallbackController)

  # Import error helpers for changeset error translation
  import ViralEngineWeb.ErrorHelpers

  @doc """
  Assigns a role to a user in an organization.
  PUT /api/users/:user_id/roles
  """
  def assign_role(conn, %{
        "user_id" => user_id_str,
        "role_id" => role_id_str,
        "organization_id" => org_id_str
      }) do
    with {user_id, _} <- Integer.parse(user_id_str),
         {role_id, _} <- Integer.parse(role_id_str),
         {org_id, _} <- Integer.parse(org_id_str) do
      case RBACContext.assign_role(user_id, role_id, org_id) do
        {:ok, user_role} ->
          conn
          |> put_status(:created)
          |> render(:show, user_role: user_role)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render("error.json", changeset: changeset)

        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: reason})
      end
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid ID format"})
    end
  end

  @doc """
  Revokes a role from a user in an organization.
  DELETE /api/users/:user_id/roles/:role_id?organization_id=X
  """
  def revoke_role(conn, %{
        "user_id" => user_id_str,
        "role_id" => role_id_str,
        "organization_id" => org_id_str
      }) do
    with {user_id, _} <- Integer.parse(user_id_str),
         {role_id, _} <- Integer.parse(role_id_str),
         {org_id, _} <- Integer.parse(org_id_str) do
      case RBACContext.revoke_role(user_id, role_id, org_id) do
        :ok ->
          conn
          |> put_status(:no_content)
          |> text("")

        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: reason})
      end
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid ID format"})
    end
  end

  @doc """
  Gets all roles for a user in an organization.
  GET /api/users/:user_id/roles?organization_id=X
  """
  def get_user_roles(conn, %{"user_id" => user_id_str, "organization_id" => org_id_str}) do
    with {user_id, _} <- Integer.parse(user_id_str),
         {org_id, _} <- Integer.parse(org_id_str) do
      roles = RBACContext.get_user_roles(user_id, org_id)
      render(conn, :index, roles: roles)
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid ID format"})
    end
  end

  @doc """
  Checks if a user has a specific permission in an organization.
  GET /api/users/:user_id/permissions/check?permission=X&organization_id=Y
  """
  def check_permission(conn, %{
        "user_id" => user_id_str,
        "permission" => permission,
        "organization_id" => org_id_str
      }) do
    with {user_id, _} <- Integer.parse(user_id_str),
         {org_id, _} <- Integer.parse(org_id_str) do
      has_permission = RBACContext.check_permission(user_id, permission, org_id)

      conn
      |> put_status(:ok)
      |> json(%{has_permission: has_permission})
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid ID format"})
    end
  end

  @doc """
  Lists all available roles.
  GET /api/roles
  """
  def index_roles(conn, _params) do
    roles = RBACContext.list_roles()
    render(conn, :index, roles: roles)
  end

  @doc """
  Lists all available permissions.
  GET /api/permissions
  """
  def index_permissions(conn, _params) do
    permissions = RBACContext.list_permissions()
    render(conn, :index, permissions: permissions)
  end

  # View functions for rendering
  def render("show.json", %{user_role: user_role}) do
    %{
      data: %{
        id: user_role.id,
        user_id: user_role.user_id,
        role_id: user_role.role_id,
        organization_id: user_role.organization_id
      }
    }
  end

  def render("index.json", %{roles: roles}) do
    %{data: Enum.map(roles, &role_json/1)}
  end

  def render("index.json", %{permissions: permissions}) do
    %{data: Enum.map(permissions, &permission_json/1)}
  end

  def render("error.json", %{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp role_json(role) do
    %{id: role.id, name: role.name, description: role.description}
  end

  defp permission_json(permission) do
    %{id: permission.id, name: permission.name, description: permission.description}
  end
end
