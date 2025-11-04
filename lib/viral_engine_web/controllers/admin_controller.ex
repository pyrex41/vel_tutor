defmodule ViralEngineWeb.AdminController do
  @moduledoc """
  Admin controller for querying audit logs and administrative operations.
  """

  use ViralEngineWeb, :controller

  # Deprecated :namespace option - use plug :put_layout instead if needed
  # Set formats for proper rendering
  plug :accepts, ["html", "json"]
  alias ViralEngine.AuditLogContext
  require Logger

  @doc """
  Query audit logs with filters and pagination.
  GET /api/admin/audit_logs

  Query parameters:
  - user_id: Filter by user ID
  - action: Filter by action
  - event_type: Filter by event type (user_action, ai_interaction, system_event)
  - provider: Filter by AI provider
  - task_id: Filter by task ID
  - date_from: Filter by start date (ISO 8601)
  - date_to: Filter by end date (ISO 8601)
  - limit: Number of results per page (default: 100, max: 1000)
  - offset: Pagination offset (default: 0)
  """
  def audit_logs(conn, params) do
    # TODO: Add authentication and authorization check for admin role
    # For now, this is a basic implementation

    filters = build_filters(params)
    opts = build_pagination_opts(params)

    result = AuditLogContext.query_logs(filters, opts)

    conn
    |> put_status(200)
    |> json(%{
      logs: serialize_logs(result.logs),
      total: result.total,
      limit: result.limit,
      offset: result.offset,
      has_more: result.has_more
    })
  end

  @doc """
  Get audit log statistics.
  GET /api/admin/audit_logs/stats
  """
  def audit_logs_stats(conn, params) do
    filters = build_filters(params)

    # Get basic stats (this could be expanded)
    result = AuditLogContext.query_logs(filters, limit: 10000)

    stats = %{
      total_logs: result.total,
      by_event_type: group_by_event_type(result.logs),
      by_provider: group_by_provider(result.logs),
      date_range: get_date_range(result.logs)
    }

    conn
    |> put_status(200)
    |> json(stats)
  end

  # Private functions

  defp build_filters(params) do
    filters = %{}

    filters = if params["user_id"], do: Map.put(filters, :user_id, String.to_integer(params["user_id"])), else: filters
    filters = if params["action"], do: Map.put(filters, :action, params["action"]), else: filters
    filters = if params["event_type"], do: Map.put(filters, :event_type, params["event_type"]), else: filters
    filters = if params["provider"], do: Map.put(filters, :provider, params["provider"]), else: filters
    filters = if params["task_id"], do: Map.put(filters, :task_id, String.to_integer(params["task_id"])), else: filters

    filters = if params["date_from"] do
      case DateTime.from_iso8601(params["date_from"]) do
        {:ok, datetime, _} -> Map.put(filters, :date_from, datetime)
        _ -> filters
      end
    else
      filters
    end

    filters = if params["date_to"] do
      case DateTime.from_iso8601(params["date_to"]) do
        {:ok, datetime, _} -> Map.put(filters, :date_to, datetime)
        _ -> filters
      end
    else
      filters
    end

    filters
  end

  defp build_pagination_opts(params) do
    limit =
      case params["limit"] do
        nil -> 100
        limit_str -> min(String.to_integer(limit_str), 1000)
      end

    offset =
      case params["offset"] do
        nil -> 0
        offset_str -> String.to_integer(offset_str)
      end

    [limit: limit, offset: offset]
  end

  defp serialize_logs(logs) do
    Enum.map(logs, fn log ->
      %{
        id: log.id,
        user_id: log.user_id,
        action: log.action,
        payload: log.payload,
        ip_address: log.ip_address,
        user_agent: log.user_agent,
        task_id: log.task_id,
        provider: log.provider,
        model: log.model,
        tokens_used: log.tokens_used,
        cost: log.cost,
        latency_ms: log.latency_ms,
        event_type: log.event_type,
        timestamp: log.timestamp,
        inserted_at: log.inserted_at
      }
    end)
  end

  defp group_by_event_type(logs) do
    logs
    |> Enum.group_by(& &1.event_type)
    |> Enum.map(fn {type, logs} -> {type, length(logs)} end)
    |> Enum.into(%{})
  end

  defp group_by_provider(logs) do
    logs
    |> Enum.filter(& &1.provider)
    |> Enum.group_by(& &1.provider)
    |> Enum.map(fn {provider, logs} -> {provider, length(logs)} end)
    |> Enum.into(%{})
  end

  defp get_date_range(logs) do
    if Enum.empty?(logs) do
      %{earliest: nil, latest: nil}
    else
      timestamps = Enum.map(logs, & &1.timestamp)
      %{
        earliest: Enum.min(timestamps, DateTime),
        latest: Enum.max(timestamps, DateTime)
      }
    end
  end
end
