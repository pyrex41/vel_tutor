defmodule ViralEngine.BenchmarksContext do
  @moduledoc """
  Context for managing AI provider benchmarks.
  """

  import Ecto.Query
  require Logger
  alias ViralEngine.{Repo, Benchmark}
  alias ViralEngine.Agents.Orchestrator, as: MCPOrchestrator

  @predefined_suites %{
    "code_generation" => %{
      name: "Code Generation",
      prompt:
        "Write a Python function that calculates the fibonacci sequence up to n terms using memoization.",
      providers: ["openai", "groq"]
    },
    "text_analysis" => %{
      name: "Text Analysis",
      prompt:
        "Analyze the sentiment of this text: 'I love this product, it's amazing and works perfectly!'",
      providers: ["openai", "groq", "perplexity"]
    },
    "creative_writing" => %{
      name: "Creative Writing",
      prompt: "Write a short story about a robot who discovers emotions.",
      providers: ["openai", "groq"]
    }
  }

  @doc """
  Creates a new benchmark.
  """
  def create_benchmark(attrs) do
    %Benchmark{}
    |> Benchmark.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a benchmark by ID.
  """
  def get_benchmark(id) do
    Repo.get(Benchmark, id)
  end

  @doc """
  Lists all benchmarks.
  """
  def list_benchmarks do
    Repo.all(from(b in Benchmark, order_by: [desc: b.inserted_at]))
  end

  @doc """
  Gets predefined benchmark suites.
  """
  def get_suites do
    @predefined_suites
  end

  @doc """
  Runs a benchmark against multiple providers.
  """
  def run_benchmark(benchmark) do
    Logger.info("Starting benchmark run for: #{benchmark.name}")

    # Run the prompt against each provider in parallel
    results =
      Task.async_stream(
        benchmark.providers,
        fn provider ->
          run_provider_test(benchmark.prompt, provider)
        end,
        # Limit concurrency to avoid overwhelming providers
        max_concurrency: 3,
        # 30 second timeout per provider
        timeout: 30000
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, reason} -> {:error, "Task failed: #{inspect(reason)}"}
      end)

    # Process results
    processed_results = process_results(results)

    # Calculate statistics
    stats = calculate_statistics(processed_results)

    # Update benchmark with results
    update_benchmark_results(benchmark, processed_results, stats)

    {:ok, processed_results, stats}
  end

  @doc """
  Updates benchmark with new results and adds to history.
  """
  def update_benchmark_results(benchmark, results, stats) do
    current_history = benchmark.history || []

    new_history_entry = %{
      run_at: DateTime.utc_now(),
      results: results,
      stats: stats
    }

    changeset =
      Benchmark.changeset(benchmark, %{
        results: results,
        stats: stats,
        history: [new_history_entry | current_history]
      })

    Repo.update(changeset)
  end

  # Private functions

  defp run_provider_test(prompt, provider) do
    start_time = System.monotonic_time(:millisecond)

    case MCPOrchestrator.execute_task(%{
           description: prompt,
           agent_id: provider,
           benchmark_mode: true
         }) do
      {:ok, task_result} ->
        end_time = System.monotonic_time(:millisecond)
        latency = end_time - start_time

        %{
          provider: provider,
          success: true,
          latency_ms: latency,
          cost: task_result[:cost] || 0,
          tokens_used: task_result[:tokens_used] || 0,
          response: task_result[:response],
          error: nil
        }

      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        latency = end_time - start_time

        %{
          provider: provider,
          success: false,
          latency_ms: latency,
          cost: 0,
          tokens_used: 0,
          response: nil,
          error: inspect(reason)
        }
    end
  end

  defp process_results(results) do
    Enum.map(results, fn result ->
      case result do
        {:error, reason} ->
          %{provider: "unknown", success: false, error: reason}

        result when is_map(result) ->
          result
      end
    end)
  end

  defp calculate_statistics(results) do
    successful_results = Enum.filter(results, & &1.success)

    if length(successful_results) < 2 do
      %{error: "Need at least 2 successful results for statistical analysis"}
    else
      latencies = Enum.map(successful_results, & &1.latency_ms)
      costs = Enum.map(successful_results, & &1.cost)

      %{
        sample_size: length(successful_results),
        latency_stats: calculate_basic_stats(latencies),
        cost_stats: calculate_basic_stats(costs),
        significance_tests: perform_significance_tests(successful_results)
      }
    end
  end

  defp calculate_basic_stats(values) do
    n = length(values)
    mean = Enum.sum(values) / n
    variance = Enum.reduce(values, 0, fn x, acc -> acc + (x - mean) * (x - mean) end) / n
    std_dev = :math.sqrt(variance)

    %{
      mean: mean,
      std_dev: std_dev,
      min: Enum.min(values),
      max: Enum.max(values),
      median: calculate_median(values)
    }
  end

  defp calculate_median(values) do
    sorted = Enum.sort(values)
    n = length(sorted)

    if rem(n, 2) == 0 do
      mid1 = Enum.at(sorted, div(n, 2) - 1)
      mid2 = Enum.at(sorted, div(n, 2))
      (mid1 + mid2) / 2
    else
      Enum.at(sorted, div(n, 2))
    end
  end

  defp perform_significance_tests(results) do
    # Simple comparison between providers
    # In a real implementation, you'd use proper statistical tests
    providers = Enum.map(results, & &1.provider)
    latencies = Enum.map(results, & &1.latency_ms)

    comparisons =
      for i <- 0..(length(providers) - 2),
          j <- (i + 1)..(length(providers) - 1) do
        provider1 = Enum.at(providers, i)
        provider2 = Enum.at(providers, j)
        latency1 = Enum.at(latencies, i)
        latency2 = Enum.at(latencies, j)

        %{
          comparison: "#{provider1} vs #{provider2}",
          latency_diff: latency2 - latency1,
          faster_provider: if(latency1 < latency2, do: provider1, else: provider2)
        }
      end

    %{comparisons: comparisons}
  end
end
