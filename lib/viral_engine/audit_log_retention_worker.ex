defmodule ViralEngine.AuditLogRetentionWorker do
  @moduledoc """
  GenServer that periodically deletes audit logs older than 90 days.
  Runs daily at midnight to enforce the retention policy.
  """

  use GenServer
  require Logger
  alias ViralEngine.AuditLogContext

  # Run retention cleanup daily (24 hours)
  @cleanup_interval :timer.hours(24)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting AuditLogRetentionWorker - 90-day retention policy enabled")
    schedule_cleanup()
    {:ok, %{last_run: nil, deleted_count: 0}}
  end

  @impl true
  def handle_info(:run_retention_cleanup, state) do
    Logger.info("Running scheduled audit log retention cleanup")

    case AuditLogContext.delete_old_logs() do
      {:ok, count} ->
        Logger.info("Deleted #{count} audit logs older than 90 days")
        schedule_cleanup()
        {:noreply, %{state | last_run: DateTime.utc_now(), deleted_count: count}}
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :run_retention_cleanup, @cleanup_interval)
  end

  # Public API for manual cleanup runs
  def run_now do
    GenServer.call(__MODULE__, :run_now)
  end

  @impl true
  def handle_call(:run_now, _from, state) do
    Logger.info("Running manual audit log retention cleanup")

    case AuditLogContext.delete_old_logs() do
      {:ok, count} ->
        Logger.info("Deleted #{count} audit logs older than 90 days")
        {:reply, {:ok, count}, %{state | last_run: DateTime.utc_now(), deleted_count: count}}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state, state}
  end

  # Public API

  # Get worker stats
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
end
