defmodule ViralEngine.AuditLogContext do
  @moduledoc """
  Context module for comprehensive audit logging of user actions, AI decisions, and system events.
  """

  import Ecto.Query
  alias ViralEngine.{AuditLog, Repo}
  require Logger

  @doc """
  Log a user action with full context.
  """
  def log_user_action(user_id, action, payload, conn) do
    changeset =
      AuditLog.changeset(%AuditLog{}, %{
        user_id: user_id,
        action: action,
        payload: payload,
        ip_address: get_ip_address(conn),
        user_agent: get_user_agent(conn),
        event_type: "user_action",
        timestamp: DateTime.utc_now()
      })

    case Repo.insert(changeset) do
      {:ok, log} ->
        Logger.info("Audit log created: #{action} by user #{user_id}")
        {:ok, log}

      {:error, changeset} ->
        Logger.error("Failed to create audit log: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Log an AI provider call with metrics.
  """
  def log_ai_call(task_id, provider, model, tokens_used, cost, latency_ms) do
    changeset =
      AuditLog.changeset(%AuditLog{}, %{
        action: "ai_call",
        task_id: task_id,
        provider: provider,
        model: model,
        tokens_used: tokens_used,
        cost: cost,
        latency_ms: latency_ms,
        event_type: "ai_interaction",
        timestamp: DateTime.utc_now()
      })

    case Repo.insert(changeset) do
      {:ok, log} ->
        Logger.debug("AI call logged: #{provider}/#{model} - #{tokens_used} tokens, $#{cost}")
        {:ok, log}

      {:error, changeset} ->
        Logger.error("Failed to log AI call: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Log a system event (e.g., circuit breaker trips, failovers, errors).
  """
  def log_system_event(event_type, details) do
    changeset =
      AuditLog.changeset(%AuditLog{}, %{
        action: event_type,
        payload: details,
        event_type: "system_event",
        timestamp: DateTime.utc_now()
      })

    case Repo.insert(changeset) do
      {:ok, log} ->
        Logger.info("System event logged: #{event_type}")
        {:ok, log}

      {:error, changeset} ->
        Logger.error("Failed to log system event: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Query audit logs with filters and pagination.
  """
  def query_logs(filters \\ %{}, opts \\ []) do
    limit = opts[:limit] || 100
    offset = opts[:offset] || 0

    query =
      from(a in AuditLog,
        order_by: [desc: a.timestamp],
        limit: ^limit,
        offset: ^offset
      )

    query = apply_filters(query, filters)

    logs = Repo.all(query)
    total = count_logs(filters)

    %{
      logs: logs,
      total: total,
      limit: limit,
      offset: offset,
      has_more: total > offset + limit
    }
  end

  @doc """
  Delete audit logs older than 90 days (retention policy).
  """
  def delete_old_logs do
    cutoff_date = DateTime.add(DateTime.utc_now(), -90, :day)

    {count, _} =
      from(a in AuditLog, where: a.timestamp < ^cutoff_date)
      |> Repo.delete_all()

    Logger.info("Deleted #{count} audit logs older than 90 days")
    {:ok, count}
  end

  # Private functions

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      case key do
        :user_id ->
          from(a in acc, where: a.user_id == ^value)

        :action ->
          from(a in acc, where: a.action == ^value)

        :event_type ->
          from(a in acc, where: a.event_type == ^value)

        :provider ->
          from(a in acc, where: a.provider == ^value)

        :task_id ->
          from(a in acc, where: a.task_id == ^value)

        :date_from ->
          from(a in acc, where: a.timestamp >= ^value)

        :date_to ->
          from(a in acc, where: a.timestamp <= ^value)

        _ ->
          acc
      end
    end)
  end

  defp count_logs(filters) do
    query = from(a in AuditLog)
    query = apply_filters(query, filters)

    Repo.aggregate(query, :count)
  end

  defp get_ip_address(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> "unknown"
    end
  end
end
