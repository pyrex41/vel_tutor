defmodule ViralEngineWeb.UserController do
  use ViralEngineWeb, :controller

  alias ViralEngine.{RateLimitContext, RBACContext, OrganizationContext}

  action_fallback(ViralEngineWeb.FallbackController)

  @doc """
  Updates rate limits for a user.
  Requires admin permission or user managing their own limits.
  """
  def update_rate_limits(conn, %{"id" => user_id, "rate_limits" => rate_limit_params}) do
    current_user_id = conn.assigns[:current_user_id]
    current_org_id = conn.assigns[:current_organization_id]

    # Check permissions: user can manage their own limits, or org admin can manage any user's limits
    can_manage =
      current_user_id == user_id ||
        RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if can_manage do
      attrs = %{
        user_id: user_id,
        tasks_per_hour: rate_limit_params["tasks_per_hour"],
        concurrent_tasks: rate_limit_params["concurrent_tasks"]
      }

      case RateLimitContext.upsert_rate_limit(attrs) do
        {:ok, rate_limit} ->
          conn
          |> put_status(:ok)
          |> json(%{
            data: %{
              id: rate_limit.id,
              user_id: rate_limit.user_id,
              tasks_per_hour: rate_limit.tasks_per_hour,
              concurrent_tasks: rate_limit.concurrent_tasks,
              current_hourly_count: rate_limit.current_hourly_count,
              current_concurrent_count: rate_limit.current_concurrent_count
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_changeset_errors(changeset)})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions to manage rate limits"})
    end
  end

  @doc """
  Gets rate limit information for a user.
  """
  def show_rate_limits(conn, %{"id" => user_id}) do
    current_user_id = conn.assigns[:current_user_id]
    current_org_id = conn.assigns[:current_organization_id]

    # Check permissions: user can view their own limits, or org admin can view any user's limits
    can_view =
      current_user_id == user_id ||
        RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if can_view do
      rate_limit = RateLimitContext.get_rate_limit(user_id, current_org_id)

      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          user_id: user_id,
          tasks_per_hour: rate_limit.tasks_per_hour,
          concurrent_tasks: rate_limit.concurrent_tasks,
          current_hourly_count: rate_limit.current_hourly_count,
          current_concurrent_count: rate_limit.current_concurrent_count,
          is_default: is_nil(rate_limit.id)
        }
      })
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions to view rate limits"})
    end
  end

  @doc """
  Deletes custom rate limits for a user (reverts to defaults).
  """
  def delete_rate_limits(conn, %{"id" => user_id}) do
    current_user_id = conn.assigns[:current_user_id]
    current_org_id = conn.assigns[:current_organization_id]

    # Check permissions: user can manage their own limits, or org admin can manage any user's limits
    can_manage =
      current_user_id == user_id ||
        RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if can_manage do
      # Find and delete the rate limit record
      case RateLimitContext.get_rate_limit(user_id, current_org_id) do
        %{id: nil} ->
          # Already using defaults
          conn
          |> put_status(:ok)
          |> json(%{message: "Already using default rate limits"})

        %{id: rate_limit_id} ->
          case RateLimitContext.delete_rate_limit(rate_limit_id) do
            {:ok, _} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Rate limits reset to defaults"})

            {:error, :not_found} ->
              conn
              |> put_status(:not_found)
              |> json(%{error: "Rate limit configuration not found"})
          end
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions to manage rate limits"})
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
