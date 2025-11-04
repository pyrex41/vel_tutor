defmodule ViralEngine.RateLimitContext do
  @moduledoc """
  Context for managing rate limits per user or organization.
  """

  import Ecto.Query
  require Logger
  alias ViralEngine.{Repo, RateLimit, OrganizationContext}

  @doc """
  Gets rate limit for a user or organization.
  Returns default limits if none configured.
  """
  def get_rate_limit(user_id \\ nil, organization_id \\ nil) do
    tenant_id = OrganizationContext.current_tenant_id()

    cond do
      user_id && tenant_id ->
        # Check for user-specific limit first
        case Repo.get_by(RateLimit, user_id: user_id, tenant_id: tenant_id) do
          nil ->
            # Fall back to organization limit
            case organization_id &&
                   Repo.get_by(RateLimit, organization_id: organization_id, tenant_id: tenant_id) do
              nil -> get_default_rate_limit()
              org_limit -> org_limit
            end

          user_limit ->
            user_limit
        end

      organization_id && tenant_id ->
        case Repo.get_by(RateLimit, organization_id: organization_id, tenant_id: tenant_id) do
          nil -> get_default_rate_limit()
          limit -> limit
        end

      true ->
        get_default_rate_limit()
    end
  end

  @doc """
  Creates or updates rate limit configuration.
  """
  def upsert_rate_limit(attrs) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      attrs_with_tenant = Map.put(attrs, :tenant_id, tenant_id)

      case get_existing_rate_limit(attrs_with_tenant) do
        nil ->
          create_rate_limit(attrs_with_tenant)

        existing ->
          update_rate_limit(existing, attrs_with_tenant)
      end
    else
      {:error, :no_tenant_context}
    end
  end

  @doc """
  Increments the hourly counter for a user/organization.
  Returns {:ok, rate_limit} if within limits, {:error, :hourly_limit_exceeded} if exceeded.
  """
  def increment_hourly_count(user_id \\ nil, organization_id \\ nil) do
    rate_limit = get_rate_limit(user_id, organization_id)

    if rate_limit.current_hourly_count >= rate_limit.tasks_per_hour do
      {:error, :hourly_limit_exceeded}
    else
      if rate_limit.id do
        # Existing record
        {1, _} =
          Repo.update_all(
            from(r in RateLimit, where: r.id == ^rate_limit.id),
            inc: [current_hourly_count: 1]
          )

        {:ok, %{rate_limit | current_hourly_count: rate_limit.current_hourly_count + 1}}
      else
        # Default limits, create record
        tenant_id = OrganizationContext.current_tenant_id()

        attrs = %{
          tenant_id: tenant_id,
          tasks_per_hour: rate_limit.tasks_per_hour,
          concurrent_tasks: rate_limit.concurrent_tasks,
          current_hourly_count: 1,
          current_concurrent_count: 0
        }

        attrs =
          if user_id,
            do: Map.put(attrs, :user_id, user_id),
            else: Map.put(attrs, :organization_id, organization_id)

        {:ok, new_rate_limit} = Repo.insert(RateLimit.changeset(%RateLimit{}, attrs))

        {:ok, new_rate_limit}
      end
    end
  end

  @doc """
  Increments the concurrent counter for a user/organization.
  Returns {:ok, rate_limit} if within limits, {:error, :concurrent_limit_exceeded} if exceeded.
  """
  def increment_concurrent_count(user_id \\ nil, organization_id \\ nil) do
    rate_limit = get_rate_limit(user_id, organization_id)

    if rate_limit.current_concurrent_count >= rate_limit.concurrent_tasks do
      {:error, :concurrent_limit_exceeded}
    else
      if rate_limit.id do
        # Existing record
        {1, _} =
          Repo.update_all(
            from(r in RateLimit, where: r.id == ^rate_limit.id),
            inc: [current_concurrent_count: 1]
          )

        {:ok, %{rate_limit | current_concurrent_count: rate_limit.current_concurrent_count + 1}}
      else
        # Default limits, create record
        tenant_id = OrganizationContext.current_tenant_id()

        attrs = %{
          tenant_id: tenant_id,
          tasks_per_hour: rate_limit.tasks_per_hour,
          concurrent_tasks: rate_limit.concurrent_tasks,
          current_hourly_count: 0,
          current_concurrent_count: 1
        }

        attrs =
          if user_id,
            do: Map.put(attrs, :user_id, user_id),
            else: Map.put(attrs, :organization_id, organization_id)

        {:ok, new_rate_limit} = Repo.insert(RateLimit.changeset(%RateLimit{}, attrs))

        {:ok, new_rate_limit}
      end
    end
  end

  @doc """
  Decrements the concurrent counter when a task completes.
  """
  def decrement_concurrent_count(user_id \\ nil, organization_id \\ nil) do
    rate_limit = get_rate_limit(user_id, organization_id)

    if rate_limit.id && rate_limit.current_concurrent_count > 0 do
      {1, _} =
        Repo.update_all(
          from(r in RateLimit, where: r.id == ^rate_limit.id),
          inc: [current_concurrent_count: -1]
        )

      {:ok,
       %{rate_limit | current_concurrent_count: max(0, rate_limit.current_concurrent_count - 1)}}
    else
      {:ok, rate_limit}
    end
  end

  @doc """
  Resets hourly counters for all rate limits.
  Called by background job at the start of each hour.
  """
  def reset_hourly_counters do
    {count, _} =
      Repo.update_all(
        from(r in RateLimit),
        set: [current_hourly_count: 0, updated_at: DateTime.utc_now()]
      )

    Logger.info("Reset hourly counters for #{count} rate limits")
    {:ok, count}
  end

  @doc """
  Lists all rate limits for admin dashboard.
  """
  def list_rate_limits do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.all(
        from(r in RateLimit, where: r.tenant_id == ^tenant_id, order_by: [desc: r.updated_at])
      )
    else
      []
    end
  end

  @doc """
  Deletes a rate limit configuration.
  """
  def delete_rate_limit(id) do
    case Repo.get(RateLimit, id) do
      nil -> {:error, :not_found}
      rate_limit -> Repo.delete(rate_limit)
    end
  end

  # Private functions

  defp get_default_rate_limit do
    %RateLimit{
      id: nil,
      user_id: nil,
      organization_id: nil,
      tasks_per_hour: 100,
      concurrent_tasks: 5,
      current_hourly_count: 0,
      current_concurrent_count: 0,
      inserted_at: nil,
      updated_at: nil
    }
  end

  defp get_existing_rate_limit(%{user_id: user_id, tenant_id: tenant_id})
       when not is_nil(user_id) do
    Repo.get_by(RateLimit, user_id: user_id, tenant_id: tenant_id)
  end

  defp get_existing_rate_limit(%{organization_id: org_id, tenant_id: tenant_id})
       when not is_nil(org_id) do
    Repo.get_by(RateLimit, organization_id: org_id, tenant_id: tenant_id)
  end

  defp get_existing_rate_limit(_), do: nil

  defp create_rate_limit(attrs) do
    %RateLimit{}
    |> RateLimit.changeset(attrs)
    |> Repo.insert()
  end

  defp update_rate_limit(existing, attrs) do
    existing
    |> RateLimit.changeset(attrs)
    |> Repo.update()
  end
end
