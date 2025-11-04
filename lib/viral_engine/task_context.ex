defmodule ViralEngine.TaskContext do
  @moduledoc """
  Context for managing tasks with multi-tenant support.
  """

  import Ecto.Query
  require Logger
  alias ViralEngine.{Repo, Task, OrganizationContext}

  @doc """
  Creates a new task for the current tenant.
  """
  def create_task(attrs) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      %Task{}
      |> Task.changeset(Map.put(attrs, :tenant_id, tenant_id))
      |> Repo.insert()
    else
      {:error, :no_tenant_context}
    end
  end

  @doc """
  Gets a task by ID, scoped to current tenant.
  """
  def get_task(id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.get_by(Task, id: id, tenant_id: tenant_id)
    else
      nil
    end
  end

  @doc """
  Lists tasks for the current tenant with optional filters.
  """
  def list_tasks(filters \\ %{}) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      query = from(t in Task, where: t.tenant_id == ^tenant_id)

      query
      |> apply_filters(filters)
      |> Repo.all()
    else
      []
    end
  end

  @doc """
  Updates a task, ensuring tenant isolation.
  """
  def update_task(%Task{} = task, attrs) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id && task.tenant_id == tenant_id do
      task
      |> Task.changeset(attrs)
      |> Repo.update()
    else
      {:error, :access_denied}
    end
  end

  @doc """
  Deletes a task (soft delete by setting status to cancelled).
  """
  def delete_task(%Task{} = task) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id && task.tenant_id == tenant_id do
      update_task(task, %{status: "cancelled"})
    else
      {:error, :access_denied}
    end
  end

  @doc """
  Gets tasks by status for the current tenant.
  """
  def get_tasks_by_status(status) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.all(from(t in Task, where: t.tenant_id == ^tenant_id and t.status == ^status))
    else
      []
    end
  end

  @doc """
  Counts tasks for the current tenant.
  """
  def count_tasks do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.aggregate(from(t in Task, where: t.tenant_id == ^tenant_id), :count, :id)
    else
      0
    end
  end

  @doc """
  Validates tenant access to a task.
  """
  def validate_task_access(task_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      case Repo.get_by(Task, id: task_id, tenant_id: tenant_id) do
        nil -> {:error, :task_not_found}
        task -> {:ok, task}
      end
    else
      {:error, :no_tenant_context}
    end
  end

  # Private functions

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, status}, q -> from(t in q, where: t.status == ^status)
      {:user_id, user_id}, q -> from(t in q, where: t.user_id == ^user_id)
      {:agent_id, agent_id}, q -> from(t in q, where: t.agent_id == ^agent_id)
      {:limit, limit}, q -> from(t in q, limit: ^limit)
      {:offset, offset}, q -> from(t in q, offset: ^offset)
      {:order_by, order_by}, q -> from(t in q, order_by: ^order_by)
      _, q -> q
    end)
  end
end
