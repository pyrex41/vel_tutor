defmodule ViralEngineWeb.OrganizationController do
  use ViralEngineWeb, :controller
  alias ViralEngine.{OrganizationContext, Organization}

  action_fallback(ViralEngineWeb.FallbackController)

  @doc """
  Creates a new organization (onboarding endpoint).
  """
  def create(conn, %{"organization" => organization_params}) do
    with {:ok, %Organization{} = organization} <-
           OrganizationContext.create_organization(organization_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.organization_path(conn, :show, organization))
      |> render("show.json", organization: organization)
    end
  end

  @doc """
  Shows an organization.
  """
  def show(conn, %{"id" => id}) do
    organization = OrganizationContext.get_organization(id)

    if organization do
      # Check if user has access to this organization
      case OrganizationContext.validate_tenant_access(organization.tenant_id) do
        :ok ->
          render(conn, "show.json", organization: organization)

        {:error, :access_denied} ->
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Access denied"})
      end
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Organization not found"})
    end
  end

  @doc """
  Updates an organization.
  """
  def update(conn, %{"id" => id, "organization" => organization_params}) do
    organization = OrganizationContext.get_organization(id)

    if organization do
      # Check if user has access to this organization
      case OrganizationContext.validate_tenant_access(organization.tenant_id) do
        :ok ->
          with {:ok, %Organization{} = organization} <-
                 OrganizationContext.update_organization(organization, organization_params) do
            render(conn, "show.json", organization: organization)
          end

        {:error, :access_denied} ->
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Access denied"})
      end
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Organization not found"})
    end
  end

  @doc """
  Deletes an organization (soft delete).
  """
  def delete(conn, %{"id" => id}) do
    organization = OrganizationContext.get_organization(id)

    if organization do
      # Check if user has access to this organization
      case OrganizationContext.validate_tenant_access(organization.tenant_id) do
        :ok ->
          with {:ok, %Organization{} = organization} <-
                 OrganizationContext.delete_organization(organization) do
            render(conn, "show.json", organization: organization)
          end

        {:error, :access_denied} ->
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Access denied"})
      end
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Organization not found"})
    end
  end

  @doc """
  Lists organizations (admin only).
  """
  def index(conn, _params) do
    # This should be restricted to admin users only
    organizations = OrganizationContext.list_organizations()
    render(conn, "index.json", organizations: organizations)
  end
end
