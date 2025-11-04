defmodule ViralEngine.MetricsContext do
  @moduledoc """
  Context for collecting and managing real-time metrics for AI operations.
  """

  import Ecto.Query
  require Logger
  alias ViralEngine.Repo
  alias ViralEngine.Metrics
  alias ViralEngine.PubSub

  @doc """
  Collects metrics from an AI operation result and stores them in the database.

  ## Parameters
  - operation_result: A map containing the result of an AI operation with keys like:
    - :provider (string) - The AI provider used (e.g., "openai", "groq")
    - :latency_ms (integer) - Operation latency in milliseconds
    - :cost (decimal) - Cost of the operation
    - :tokens_used (integer) - Number of tokens used
    - :timestamp (DateTime) - When the operation occurred (optional, defaults to now)
  """
  def collect_metrics(operation_result) do
    timestamp = operation_result[:timestamp] || DateTime.utc_now()
    # Round timestamp to nearest minute for aggregation
    rounded_timestamp = round_to_minute(timestamp)

    partition_key = DateTime.to_date(rounded_timestamp)

    # Calculate percentiles from the single operation
    # In a real implementation, you'd collect multiple samples and calculate percentiles
    latency_ms = operation_result[:latency_ms] || 0

    attrs = %{
      timestamp: rounded_timestamp,
      task_count: 1,
      # Single sample
      latency_p50: latency_ms / 1.0,
      latency_p95: latency_ms / 1.0,
      latency_p99: latency_ms / 1.0,
      total_cost: operation_result[:cost] || Decimal.new(0),
      total_tokens: operation_result[:tokens_used] || 0,
      provider: operation_result[:provider] || "unknown",
      partition_key: partition_key
    }

    case %Metrics{}
         |> Metrics.changeset(attrs)
         |> Repo.insert() do
      {:ok, metric} ->
        # Broadcast the new metric for real-time updates
        Phoenix.PubSub.broadcast(PubSub, "metrics:updates", {:metric_collected, metric})
        {:ok, metric}

      error ->
        error
    end
  end

  @doc """
  Retrieves metrics for a given time range and provider.

  ## Parameters
  - start_time: Start of the time range
  - end_time: End of the time range
  - provider: Optional provider filter
  """
  def get_metrics(start_time, end_time, provider \\ nil) do
    query =
      from(m in Metrics,
        where: m.timestamp >= ^start_time and m.timestamp <= ^end_time,
        order_by: [desc: m.timestamp]
      )

    query =
      if provider do
        from(m in query, where: m.provider == ^provider)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Aggregates metrics for a given time period.

  ## Parameters
  - start_time: Start of the aggregation period
  - end_time: End of the aggregation period
  - provider: Optional provider filter
  """
  def aggregate_metrics(start_time, end_time, provider \\ nil) do
    query =
      from(m in Metrics,
        where: m.timestamp >= ^start_time and m.timestamp <= ^end_time,
        select: %{
          total_tasks: sum(m.task_count),
          avg_latency_p50: avg(m.latency_p50),
          avg_latency_p95: avg(m.latency_p95),
          avg_latency_p99: avg(m.latency_p99),
          total_cost: sum(m.total_cost),
          total_tokens: sum(m.total_tokens),
          provider: m.provider
        },
        group_by: m.provider
      )

    query =
      if provider do
        from(m in query, where: m.provider == ^provider)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Calculates percentiles from a list of latency values.

  ## Parameters
  - latencies: List of latency values in milliseconds
  """
  def calculate_percentiles(latencies) when is_list(latencies) and length(latencies) > 0 do
    sorted = Enum.sort(latencies)
    count = length(sorted)

    p50_index = round(count * 0.5) - 1
    p95_index = round(count * 0.95) - 1
    p99_index = round(count * 0.99) - 1

    %{
      p50: Enum.at(sorted, max(0, p50_index)),
      p95: Enum.at(sorted, max(0, p95_index)),
      p99: Enum.at(sorted, max(0, p99_index))
    }
  end

  def calculate_percentiles(_), do: %{p50: 0, p95: 0, p99: 0}

  @doc """
  Rounds a DateTime to the nearest minute.
  """
  def round_to_minute(%DateTime{} = dt) do
    %{dt | second: 0, microsecond: {0, 0}}
  end

  @doc """
  Starts a background task to aggregate metrics periodically.
  This would typically be called from an application supervisor.
  """
  def start_aggregation_scheduler do
    # In a real implementation, you'd use a job scheduler like Oban
    # For now, we'll just log that this would run
    Logger.info("Metrics aggregation scheduler would start here")
  end

  @doc """
  Performs hourly aggregation of metrics.
  """
  def aggregate_hourly(hour_start) do
    hour_end = DateTime.add(hour_start, 3600, :second)

    # Get all metrics for the hour
    metrics = get_metrics(hour_start, hour_end)

    if Enum.empty?(metrics) do
      Logger.info("No metrics to aggregate for hour starting #{DateTime.to_string(hour_start)}")
      :ok
    else
      # Group by provider and aggregate
      aggregated =
        Enum.group_by(metrics, & &1.provider)
        |> Enum.map(fn {provider, provider_metrics} ->
          latencies = Enum.map(provider_metrics, & &1.latency_p50)
          percentiles = calculate_percentiles(latencies)

          %{
            timestamp: hour_start,
            task_count: Enum.sum(Enum.map(provider_metrics, & &1.task_count)),
            latency_p50: percentiles.p50,
            latency_p95: percentiles.p95,
            latency_p99: percentiles.p99,
            total_cost:
              Enum.reduce(provider_metrics, Decimal.new(0), fn m, acc ->
                Decimal.add(acc, m.total_cost)
              end),
            total_tokens: Enum.sum(Enum.map(provider_metrics, & &1.total_tokens)),
            provider: provider,
            partition_key: DateTime.to_date(hour_start)
          }
        end)

      # In a real implementation, you'd store these aggregated metrics
      # For now, just log them
      Enum.each(aggregated, fn agg ->
        Logger.info("Hourly aggregation for #{agg.provider}: #{inspect(agg)}")
      end)

      :ok
    end
  end
end
