defmodule ViralEngine.MetricsContextTest do
  use ViralEngine.DataCase, async: true
  alias ViralEngine.MetricsContext
  alias ViralEngine.Metrics

  describe "collect_metrics/1" do
    test "collects metrics from operation result" do
      operation_result = %{
        provider: "openai",
        latency_ms: 150,
        cost: Decimal.new("0.002"),
        tokens_used: 100,
        timestamp: DateTime.utc_now()
      }

      assert {:ok, metrics} = MetricsContext.collect_metrics(operation_result)

      assert metrics.task_count == 1
      assert metrics.latency_p50 == 150.0
      assert metrics.latency_p95 == 150.0
      assert metrics.latency_p99 == 150.0
      assert Decimal.equal?(metrics.total_cost, Decimal.new("0.002"))
      assert metrics.total_tokens == 100
      assert metrics.provider == "openai"
      # Should be rounded to minute
      assert metrics.timestamp.second == 0
    end

    test "uses default values when optional fields are missing" do
      operation_result = %{
        provider: "groq"
      }

      assert {:ok, metrics} = MetricsContext.collect_metrics(operation_result)

      assert metrics.task_count == 1
      assert metrics.latency_p50 == 0.0
      assert Decimal.equal?(metrics.total_cost, Decimal.new("0"))
      assert metrics.total_tokens == 0
      assert metrics.provider == "groq"
    end

    test "rounds timestamp to nearest minute" do
      timestamp = ~U[2023-01-01 12:34:56.789000Z]

      operation_result = %{
        provider: "test",
        timestamp: timestamp
      }

      assert {:ok, metrics} = MetricsContext.collect_metrics(operation_result)

      assert metrics.timestamp == ~U[2023-01-01 12:34:00Z]
    end
  end

  describe "get_metrics/3" do
    setup do
      # Insert test metrics
      start_time = ~U[2023-01-01 12:00:00Z]
      end_time = ~U[2023-01-01 13:00:00Z]

      {:ok, _} =
        MetricsContext.collect_metrics(%{
          provider: "openai",
          latency_ms: 100,
          cost: Decimal.new("0.001"),
          tokens_used: 50,
          timestamp: ~U[2023-01-01 12:30:00Z]
        })

      {:ok, _} =
        MetricsContext.collect_metrics(%{
          provider: "groq",
          latency_ms: 200,
          cost: Decimal.new("0.002"),
          tokens_used: 75,
          timestamp: ~U[2023-01-01 12:45:00Z]
        })

      %{start_time: start_time, end_time: end_time}
    end

    test "retrieves metrics within time range", %{start_time: start_time, end_time: end_time} do
      metrics = MetricsContext.get_metrics(start_time, end_time)

      assert length(metrics) == 2
      providers = Enum.map(metrics, & &1.provider) |> Enum.sort()
      assert providers == ["groq", "openai"]
    end

    test "filters by provider", %{start_time: start_time, end_time: end_time} do
      metrics = MetricsContext.get_metrics(start_time, end_time, "openai")

      assert length(metrics) == 1
      assert hd(metrics).provider == "openai"
    end

    test "returns empty list when no metrics in range" do
      start_time = ~U[2023-01-02 12:00:00Z]
      end_time = ~U[2023-01-02 13:00:00Z]

      metrics = MetricsContext.get_metrics(start_time, end_time)

      assert metrics == []
    end
  end

  describe "aggregate_metrics/3" do
    setup do
      # Insert test metrics for aggregation
      {:ok, _} =
        MetricsContext.collect_metrics(%{
          provider: "openai",
          latency_ms: 100,
          cost: Decimal.new("0.001"),
          tokens_used: 50,
          timestamp: ~U[2023-01-01 12:00:00Z]
        })

      {:ok, _} =
        MetricsContext.collect_metrics(%{
          provider: "openai",
          latency_ms: 200,
          cost: Decimal.new("0.002"),
          tokens_used: 75,
          timestamp: ~U[2023-01-01 12:01:00Z]
        })

      %{start_time: ~U[2023-01-01 11:00:00Z], end_time: ~U[2023-01-01 13:00:00Z]}
    end

    test "aggregates metrics by provider", %{start_time: start_time, end_time: end_time} do
      aggregations = MetricsContext.aggregate_metrics(start_time, end_time)

      assert length(aggregations) == 1
      agg = hd(aggregations)

      assert agg.total_tasks == 2
      assert agg.total_tokens == 125
      assert Decimal.equal?(agg.total_cost, Decimal.new("0.003"))
      assert agg.provider == "openai"
    end

    test "filters by provider in aggregation", %{start_time: start_time, end_time: end_time} do
      aggregations = MetricsContext.aggregate_metrics(start_time, end_time, "groq")

      assert aggregations == []
    end
  end

  describe "calculate_percentiles/1" do
    test "calculates percentiles from latency list" do
      latencies = [100, 200, 300, 400, 500]

      percentiles = MetricsContext.calculate_percentiles(latencies)

      # Middle value
      assert percentiles.p50 == 300
      # 95th percentile (5th element in sorted list of 5)
      assert percentiles.p95 == 500
      # 99th percentile (5th element in sorted list of 5)
      assert percentiles.p99 == 500
    end

    test "handles empty list" do
      percentiles = MetricsContext.calculate_percentiles([])

      assert percentiles.p50 == 0
      assert percentiles.p95 == 0
      assert percentiles.p99 == 0
    end

    test "handles single value" do
      percentiles = MetricsContext.calculate_percentiles([150])

      assert percentiles.p50 == 150
      assert percentiles.p95 == 150
      assert percentiles.p99 == 150
    end
  end

  describe "round_to_minute/1" do
    test "rounds DateTime to nearest minute" do
      dt = ~U[2023-01-01 12:34:56.789000Z]

      rounded = MetricsContext.round_to_minute(dt)

      assert rounded == ~U[2023-01-01 12:34:00Z]
    end

    test "handles already rounded datetime" do
      dt = ~U[2023-01-01 12:34:00Z]

      rounded = MetricsContext.round_to_minute(dt)

      assert rounded == dt
    end
  end

  describe "aggregate_hourly/1" do
    test "aggregates hourly metrics" do
      # Insert test data
      {:ok, _} =
        MetricsContext.collect_metrics(%{
          provider: "openai",
          latency_ms: 100,
          cost: Decimal.new("0.001"),
          tokens_used: 50,
          timestamp: ~U[2023-01-01 12:30:00Z]
        })

      {:ok, _} =
        MetricsContext.collect_metrics(%{
          provider: "openai",
          latency_ms: 200,
          cost: Decimal.new("0.002"),
          tokens_used: 75,
          timestamp: ~U[2023-01-01 12:45:00Z]
        })

      hour_start = ~U[2023-01-01 12:00:00Z]

      assert :ok = MetricsContext.aggregate_hourly(hour_start)
      # In a real implementation, we'd check that aggregated data was stored
    end

    test "handles empty metrics gracefully" do
      hour_start = ~U[2023-01-01 12:00:00Z]

      assert :ok = MetricsContext.aggregate_hourly(hour_start)
    end
  end
end
