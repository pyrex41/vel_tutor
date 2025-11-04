defmodule ViralEngine.OrganizationContext do
  @moduledoc """
  Context for managing organizations and multi-tenant functionality.
  """

  import Ecto.Query
  require Logger
  alias ViralEngine.{Repo, Organization}

  @doc """
  Creates a new organization.
  """
  def create_organization(attrs) do
    Organization.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an organization by ID.
  """
  def get_organization(id) do
    Repo.get(Organization, id)
  end

  @doc """
  Gets an organization by tenant_id.
  """
  def get_organization_by_tenant_id(tenant_id) do
    Repo.get_by(Organization, tenant_id: tenant_id)
  end

  @doc """
  Lists all organizations.
  """
  def list_organizations do
    Repo.all(from(o in Organization, order_by: [desc: o.inserted_at]))
  end

  @doc """
  Updates an organization.
  """
  def update_organization(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an organization (soft delete).
  """
  def delete_organization(%Organization{} = organization) do
    update_organization(organization, %{status: "deleted"})
  end

  @doc """
  Checks if an organization is active.
  """
  def organization_active?(%Organization{} = organization) do
    organization.status == "active"
  end

  def organization_active?(nil), do: false

  @doc """
  Gets the current tenant ID from the process dictionary.
  """
  def current_tenant_id do
    case Process.get(:tenant_id) do
      nil ->
        Logger.warning("No tenant_id found in process dictionary")
        nil

      tenant_id ->
        tenant_id
    end
  end

  @doc """
  Sets the current tenant ID in the process dictionary.
  """
  def set_current_tenant_id(tenant_id) do
    Process.put(:tenant_id, tenant_id)
    Logger.info("Set current tenant_id to #{tenant_id}")
  end

  @doc """
  Clears the current tenant ID from the process dictionary.
  """
  def clear_current_tenant_id do
    Process.delete(:tenant_id)
    Logger.info("Cleared current tenant_id")
  end

  @doc """
  Ensures the current tenant is set and valid.
  """
  def ensure_tenant_context(tenant_id) do
    case get_organization_by_tenant_id(tenant_id) do
      nil ->
        {:error, :organization_not_found}

      organization ->
        if organization_active?(organization) do
          set_current_tenant_id(tenant_id)
          {:ok, organization}
        else
          {:error, :organization_inactive}
        end
    end
  end

  @doc """
  Gets the current organization from the tenant context.
  """
  def current_organization do
    case current_tenant_id() do
      nil -> nil
      tenant_id -> get_organization_by_tenant_id(tenant_id)
    end
  end

  @doc """
  Scopes a query to the current tenant.
  """
  def scope_to_tenant(query, tenant_id \\ nil) do
    tenant_id = tenant_id || current_tenant_id()

    if tenant_id do
      from(q in query, where: q.tenant_id == ^tenant_id)
    else
      query
    end
  end

  @doc """
  Validates tenant access for a resource.
  """
  def validate_tenant_access(resource_tenant_id) do
    current_tenant = current_tenant_id()

    if current_tenant && resource_tenant_id == current_tenant do
      :ok
    else
      {:error, :access_denied}
    end
  end

  @doc """
  Checks if the current tenant has reached user limits.
  """
  def check_user_limits(current_user_count) do
    case current_organization() do
      nil ->
        {:error, :no_organization}

      org ->
        if current_user_count < org.max_users do
          :ok
        else
          {:error, :user_limit_exceeded}
        end
    end
  end

  @doc """
  Checks if the current tenant has reached task limits.
  """
  def check_task_limits(current_task_count) do
    case current_organization() do
      nil ->
        {:error, :no_organization}

      org ->
        if current_task_count < org.max_tasks_per_month do
          :ok
        else
          {:error, :task_limit_exceeded}
        end
    end
  end
end
