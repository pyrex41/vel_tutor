defmodule ViralEngine.AnomalyDetection do
  @moduledoc """
  Anomaly detection system using statistical methods to monitor key metrics.
  Uses mean + 3σ (standard deviations) algorithm for detecting anomalies.
  """

  require Logger
  alias ViralEngine.{Repo, Alert, MetricsContext, AuditLogContext}

  # Minimum data points required for baseline calculation
  @min_data_points 100

  # Standard deviation multiplier for anomaly detection
  @sigma_multiplier 3.0

  @doc """
  Analyzes metrics for anomalies and creates alerts if detected.
  """
  def analyze_metrics do
    Logger.info("Starting anomaly detection analysis")

    # Get recent metrics data
    metrics_data = fetch_recent_metrics()

    # Analyze each metric type
    analyze_error_rate(metrics_data)
    analyze_latency(metrics_data)
    analyze_cost_per_task(metrics_data)
    analyze_failures(metrics_data)

    Logger.info("Anomaly detection analysis completed")
  end

  @doc """
  Checks if a value is anomalous based on historical data using mean + 3σ method.
  """
  def is_anomalous?(values, current_value) when length(values) >= @min_data_points do
    mean = Enum.sum(values) / length(values)

    variance =
      Enum.reduce(values, 0, fn x, acc -> acc + :math.pow(x - mean, 2) end) / length(values)

    std_dev = :math.sqrt(variance)

    threshold = mean + @sigma_multiplier * std_dev

    current_value > threshold
  end

  def is_anomalous?(_values, _current_value), do: false

  @doc """
  Calculates statistical measures for a dataset.
  """
  def calculate_stats(values) when length(values) >= @min_data_points do
    mean = Enum.sum(values) / length(values)

    variance =
      Enum.reduce(values, 0, fn x, acc -> acc + :math.pow(x - mean, 2) end) / length(values)

    std_dev = :math.sqrt(variance)

    %{
      mean: mean,
      std_dev: std_dev,
      threshold: mean + @sigma_multiplier * std_dev,
      data_points: length(values)
    }
  end

  def calculate_stats(_values), do: nil

  # Private functions

  defp fetch_recent_metrics do
    # Get metrics from the last hour for analysis
    end_time = DateTime.utc_now()
    # 1 hour ago
    start_time = DateTime.add(end_time, -3600, :second)

    MetricsContext.get_metrics(start_time, end_time)
  end

  defp analyze_error_rate(metrics) do
    # Calculate error rate as percentage of failed tasks
    error_rates =
      Enum.map(metrics, fn m ->
        total = m.task_count || 0

        if total > 0 do
          # Assuming we have failure data in metrics
          failures = Map.get(m, :failures, 0)
          failures / total * 100
        else
          0.0
        end
      end)

    current_error_rate = List.last(error_rates) || 0.0

    if is_anomalous?(error_rates, current_error_rate) do
      create_alert("error_rate", current_error_rate, 10.0, %{
        description: "Error rate spike detected",
        historical_rates: error_rates,
        threshold: 10.0
      })
    end
  end

  defp analyze_latency(metrics) do
    latencies = Enum.map(metrics, fn m -> m.latency_p95 || 0 end)
    current_latency = List.last(latencies) || 0

    if latencies != [] and current_latency > 0 do
      baseline_avg = Enum.sum(latencies) / length(latencies)

      # Alert if latency is > 2x baseline average
      if current_latency > baseline_avg * 2 do
        create_alert("latency", current_latency, baseline_avg * 2, %{
          description: "Latency spike detected",
          baseline_avg: baseline_avg,
          historical_latencies: latencies
        })
      end
    end
  end

  defp analyze_cost_per_task(metrics) do
    costs =
      Enum.map(metrics, fn m ->
        tasks = m.task_count || 1
        total_cost = m.total_cost || 0
        Decimal.to_float(total_cost) / tasks
      end)

    current_cost = List.last(costs) || 0.0

    if is_anomalous?(costs, current_cost) do
      stats = calculate_stats(costs)

      if stats do
        create_alert("cost_per_task", current_cost, stats.threshold, %{
          description: "Cost per task anomaly detected",
          stats: stats,
          historical_costs: costs
        })
      end
    end
  end

  defp analyze_failures(metrics) do
    failures = Enum.map(metrics, fn m -> Map.get(m, :failures, 0) end)
    current_failures = List.last(failures) || 0

    if is_anomalous?(failures, current_failures) do
      stats = calculate_stats(failures)

      if stats do
        create_alert("failures", current_failures, stats.threshold, %{
          description: "Failure count anomaly detected",
          stats: stats,
          historical_failures: failures
        })
      end
    end
  end

  defp create_alert(metric_type, value, threshold, details) do
    alert_data = %{
      metric_type: metric_type,
      value: value,
      threshold: threshold,
      details: details,
      status: "active"
    }

    case Repo.insert(Alert.changeset(%Alert{}, alert_data)) do
      {:ok, alert} ->
        Logger.warning(
          "Alert created: #{metric_type} anomaly detected (value: #{value}, threshold: #{threshold})"
        )

        # Log to audit system
        AuditLogContext.log_system_event("anomaly_detected", %{
          alert_id: alert.id,
          metric_type: metric_type,
          value: value,
          threshold: threshold,
          details: details
        })

        # Trigger notifications
        notify_alert(alert)

        {:ok, alert}

      {:error, changeset} ->
        Logger.error("Failed to create alert: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp notify_alert(alert) do
    # Send notifications via different channels
    Task.start(fn ->
      ViralEngine.NotificationSystem.notify_alert(alert)
    end)
  end
end
