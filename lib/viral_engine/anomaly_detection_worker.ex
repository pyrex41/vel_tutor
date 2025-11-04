defmodule ViralEngine.AnomalyDetectionWorker do
  @moduledoc """
  GenServer that periodically runs anomaly detection on system metrics.
  """

  use GenServer
  require Logger
  alias ViralEngine.AnomalyDetection

  # Run anomaly detection every 5 minutes
  @check_interval :timer.minutes(5)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting AnomalyDetectionWorker")
    schedule_check()
    {:ok, %{}}
  end

  def handle_info(:run_anomaly_detection, state) do
    Logger.info("Running scheduled anomaly detection")
    AnomalyDetection.analyze_metrics()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :run_anomaly_detection, @check_interval)
  end

  # Public API for manual anomaly detection runs
  def run_now do
    GenServer.call(__MODULE__, :run_now)
  end

  def handle_call(:run_now, _from, state) do
    Logger.info("Running manual anomaly detection")
    AnomalyDetection.analyze_metrics()
    {:reply, :ok, state}
  end
end
