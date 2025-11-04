defmodule ViralEngineWeb.Plugs.TenantContextPlug do
  @moduledoc """
  Plug for setting tenant context from request headers or JWT claims.
  """

  import Plug.Conn
  require Logger
  alias ViralEngine.OrganizationContext

  @doc """
  Initializes the plug with options.
  """
  def init(opts \\ []), do: opts

  @doc """
  Sets the tenant context for the current request.
  """
  def call(conn, _opts) do
    tenant_id = extract_tenant_id(conn)

    case tenant_id do
      nil ->
        Logger.warning("No tenant_id found in request")
        # For development/testing, you might want to set a default tenant
        # OrganizationContext.set_current_tenant_id("default-tenant-id")
        conn

      tenant_id ->
        case OrganizationContext.ensure_tenant_context(tenant_id) do
          {:ok, organization} ->
            Logger.info("Set tenant context for organization: #{organization.name}")

            # Set PostgreSQL session variable for RLS
            Ecto.Adapters.SQL.query!(
              ViralEngine.Repo,
              "SET LOCAL app.current_tenant_id = $1",
              [tenant_id]
            )

            conn
            |> assign(:current_organization, organization)
            |> assign(:tenant_id, tenant_id)

          {:error, :organization_not_found} ->
            Logger.warning("Organization not found for tenant_id: #{tenant_id}")

            conn
            |> put_status(:not_found)
            |> put_resp_content_type("application/json")
            |> send_resp(404, Jason.encode!(%{error: "Organization not found"}))
            |> halt()

          {:error, :organization_inactive} ->
            Logger.warning("Organization inactive for tenant_id: #{tenant_id}")

            conn
            |> put_status(:forbidden)
            |> put_resp_content_type("application/json")
            |> send_resp(403, Jason.encode!(%{error: "Organization is inactive"}))
            |> halt()
        end
    end
  end

  # Private functions

  defp extract_tenant_id(conn) do
    # Try different sources in order of preference

    # 1. From X-Tenant-ID header
    case get_req_header(conn, "x-tenant-id") do
      [tenant_id | _] when tenant_id != "" ->
        tenant_id

      _ ->
        # 2. From JWT claims (if using Guardian or similar)
        extract_from_jwt(conn)
    end
  end

  defp extract_from_jwt(conn) do
    # This assumes you're using Guardian or similar auth library
    # Adjust based on your authentication setup
    case conn.assigns[:current_user] do
      %{organization_id: org_id} when not is_nil(org_id) ->
        # If user has organization_id, get tenant_id from organization
        case OrganizationContext.get_organization(org_id) do
          %{tenant_id: tenant_id} -> tenant_id
          _ -> nil
        end

      _ ->
        # For development/testing, check for a default tenant
        Application.get_env(:viral_engine, :default_tenant_id)
    end
  end
end
