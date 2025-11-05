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
  def collect_metrics(%{provider_id: provider_id} = operation_result) do
    timestamp = operation_result[:timestamp] || DateTime.utc_now()
    rounded_timestamp = round_to_minute(timestamp)
    partition_key = DateTime.to_date(rounded_timestamp)
    latency_ms = operation_result[:latency_ms] || 0
    success = operation_result[:success] !== false

    attrs = %{
      timestamp: rounded_timestamp,
      task_count: 1,
      latency_p50: latency_ms / 1.0,
      latency_p95: latency_ms / 1.0,
      latency_p99: latency_ms / 1.0,
      total_cost: operation_result[:cost] || Decimal.new(0),
      total_tokens: operation_result[:tokens_used] || 0,
      provider_id: provider_id,
      success_rate: if(success, do: 1.0, else: 0.0),
      partition_key: partition_key
    }

    case %Metrics{}
         |> Metrics.changeset(attrs)
         |> Repo.insert() do
      {:ok, metric} ->
        # Update provider performance metrics
        update_provider_performance(provider_id, latency_ms, success, operation_result[:cost])
        Phoenix.PubSub.broadcast(PubSub, "metrics:updates", {:metric_collected, metric})
        {:ok, metric}

      error ->
        error
    end
  end

  def collect_metrics(operation_result) do
    # Legacy support for provider name
    provider_name = operation_result[:provider] || "unknown"
    provider = Repo.get_by(ViralEngine.Provider, name: provider_name)

    if provider do
      collect_metrics(Map.put(operation_result, :provider_id, provider.id))
    else
      # Fallback to legacy behavior
      timestamp = operation_result[:timestamp] || DateTime.utc_now()
      rounded_timestamp = round_to_minute(timestamp)
      partition_key = DateTime.to_date(rounded_timestamp)
      latency_ms = operation_result[:latency_ms] || 0

      attrs = %{
        timestamp: rounded_timestamp,
        task_count: 1,
        latency_p50: latency_ms / 1.0,
        latency_p95: latency_ms / 1.0,
        latency_p99: latency_ms / 1.0,
        total_cost: operation_result[:cost] || Decimal.new(0),
        total_tokens: operation_result[:tokens_used] || 0,
        provider: provider_name,
        partition_key: partition_key
      }

      case %Metrics{}
           |> Metrics.changeset(attrs)
           |> Repo.insert() do
        {:ok, metric} ->
          Phoenix.PubSub.broadcast(PubSub, "metrics:updates", {:metric_collected, metric})
          {:ok, metric}

        error ->
          error
      end
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
  def aggregate_metrics(start_time, end_time, provider_id \\ nil) do
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
          success_rate: avg(m.success_rate),
          provider_id: m.provider_id
        },
        group_by: m.provider_id
      )

    query =
      if provider_id do
        from(m in query, where: m.provider_id == ^provider_id)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets aggregated performance metrics for a specific provider over the last N minutes.
  """
  def get_provider_performance(provider_id, minutes \\ 60) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -minutes * 60, :second)

    aggregates = aggregate_metrics(start_time, end_time, provider_id)

    case List.first(aggregates) do
      nil ->
        %{
          avg_latency_ms: 1000,
          reliability_score: 0.9,
          avg_cost_per_token: Decimal.new("0.001"),
          request_count: 0
        }

      agg ->
        %{
          avg_latency_ms: trunc(agg.avg_latency_p50 || 1000),
          reliability_score: agg.success_rate || 0.9,
          avg_cost_per_token:
            if(agg.total_tokens > 0,
              do: Decimal.div(agg.total_cost, agg.total_tokens),
              else: Decimal.new("0.001")
            ),
          request_count: agg.total_tasks || 0
        }
    end
  end

  @doc """
  Updates provider performance metrics based on recent operations.
  """
  def update_provider_performance(provider_id, latency_ms, success, cost) do
    provider = Repo.get!(ViralEngine.Provider, provider_id)

    # Calculate moving averages (simple implementation)
    # Last hour
    recent_perf = get_provider_performance(provider_id, 60)

    new_latency =
      if recent_perf.request_count > 0 do
        (recent_perf.avg_latency_ms * recent_perf.request_count + latency_ms) /
          (recent_perf.request_count + 1)
      else
        latency_ms
      end

    new_reliability =
      if recent_perf.request_count > 0 do
        (recent_perf.reliability_score * recent_perf.request_count +
           if(success, do: 1.0, else: 0.0)) / (recent_perf.request_count + 1)
      else
        if(success, do: 1.0, else: 0.0)
      end

    new_cost =
      if recent_perf.request_count > 0 and recent_perf.request_count > 0 do
        Decimal.add(
          Decimal.mult(recent_perf.avg_cost_per_token, recent_perf.request_count),
          Decimal.div(cost || Decimal.new(0), recent_perf.request_count + 1)
        )
      else
        cost || Decimal.new("0.001")
      end

    changeset =
      provider
      |> ViralEngine.Provider.changeset(%{
        avg_latency_ms: trunc(new_latency),
        reliability_score: new_reliability,
        cost_per_token: new_cost
      })

    case Repo.update(changeset) do
      {:ok, updated_provider} ->
        Logger.info(
          "Updated provider #{provider_id} performance: latency=#{trunc(new_latency)}ms, reliability=#{:io_lib.format(~c"~.3f", [new_reliability])}"
        )

        {:ok, updated_provider}

      {:error, changeset} ->
        Logger.error("Failed to update provider performance: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
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
  Records provider selection for analytics and optimization.
  """
  def record_provider_selection(provider_id, criteria) do
    # Log the selection for analytics
    Logger.info("Provider selected: #{provider_id}, criteria: #{inspect(criteria)}")

    # In a real implementation, you might store this in a separate table
    # for provider selection analytics
    :ok
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
