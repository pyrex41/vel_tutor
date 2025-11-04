defmodule ViralEngine.FineTuningContext do
  @moduledoc """
  Context for managing OpenAI fine-tuning jobs.
  """

  import Ecto.Query
  require Logger
  alias ViralEngine.{Repo, FineTuningJob, OrganizationContext}

  @doc """
  Creates a new fine-tuning job.
  """
  def create_job(attrs) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      attrs_with_tenant = Map.put(attrs, :tenant_id, tenant_id)

      %FineTuningJob{}
      |> FineTuningJob.changeset(attrs_with_tenant)
      |> Repo.insert()
    else
      {:error, :no_tenant_context}
    end
  end

  @doc """
  Gets a fine-tuning job by ID.
  """
  def get_job(id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.get_by(FineTuningJob, id: id, tenant_id: tenant_id)
    else
      nil
    end
  end

  @doc """
  Lists fine-tuning jobs for the current tenant.
  """
  def list_jobs do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.all(
        from(j in FineTuningJob,
          where: j.tenant_id == ^tenant_id,
          order_by: [desc: j.inserted_at]
        )
      )
    else
      []
    end
  end

  @doc """
  Updates a fine-tuning job's status and other fields.
  """
  def update_job(job, attrs) do
    job
    |> FineTuningJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates job status.
  """
  def update_job_status(job_id, status, additional_attrs \\ %{}) do
    case get_job(job_id) do
      nil ->
        {:error, :not_found}

      job ->
        attrs = Map.put(additional_attrs, :status, status)
        update_job(job, attrs)
    end
  end

  @doc """
  Deletes a fine-tuning job.
  """
  def delete_job(id) do
    case get_job(id) do
      nil -> {:error, :not_found}
      job -> Repo.delete(job)
    end
  end

  @doc """
  Gets jobs by status.
  """
  def get_jobs_by_status(status) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.all(from(j in FineTuningJob, where: j.tenant_id == ^tenant_id and j.status == ^status))
    else
      []
    end
  end

  @doc """
  Calculates total cost for all jobs in the current tenant.
  """
  def total_cost do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      result =
        Repo.one(
          from(j in FineTuningJob,
            where: j.tenant_id == ^tenant_id and not is_nil(j.cost),
            select: sum(j.cost)
          )
        )

      result || Decimal.new(0)
    else
      Decimal.new(0)
    end
  end
end
