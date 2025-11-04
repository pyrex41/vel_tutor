defmodule ViralEngineWeb.BenchmarksLive do
  @moduledoc """
  Phoenix LiveView for AI provider benchmarking dashboard.
  """

  use Phoenix.LiveView
  require Logger
  alias ViralEngine.BenchmarksContext

  @impl true
  def mount(_params, _session, socket) do
    benchmarks = BenchmarksContext.list_benchmarks()
    suites = BenchmarksContext.get_suites()

    socket =
      socket
      |> assign(:benchmarks, benchmarks)
      |> assign(:suites, suites)
      |> assign(:selected_suite, nil)
      |> assign(:running_benchmark, nil)
      |> assign(:benchmark_results, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_suite", %{"suite" => suite_key}, socket) do
    suite = Map.get(socket.assigns.suites, suite_key)

    socket =
      socket
      |> assign(:selected_suite, suite_key)
      |> assign(:form_data, %{
        name: suite.name,
        prompt: suite.prompt,
        providers: suite.providers
      })

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_benchmark", %{"benchmark" => benchmark_params}, socket) do
    # Convert providers from list of strings to actual list
    providers = Map.get(benchmark_params, "providers", [])
    providers = if is_list(providers), do: providers, else: [providers]

    benchmark_attrs = %{
      name: benchmark_params["name"],
      prompt: benchmark_params["prompt"],
      providers: providers,
      suite: socket.assigns[:selected_suite]
    }

    case BenchmarksContext.create_benchmark(benchmark_attrs) do
      {:ok, benchmark} ->
        # Start the benchmark run asynchronously
        Task.start(fn ->
          run_benchmark_async(benchmark.id)
        end)

        # Update the UI
        benchmarks = BenchmarksContext.list_benchmarks()

        socket =
          socket
          |> assign(:benchmarks, benchmarks)
          |> assign(:running_benchmark, benchmark.id)
          |> put_flash(:info, "Benchmark created and started!")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create benchmark: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("run_benchmark", %{"benchmark_id" => benchmark_id}, socket) do
    benchmark = BenchmarksContext.get_benchmark(benchmark_id)

    if benchmark do
      Task.start(fn ->
        run_benchmark_async(benchmark.id)
      end)

      socket =
        socket
        |> assign(:running_benchmark, benchmark.id)
        |> put_flash(:info, "Benchmark started!")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Benchmark not found")}
    end
  end

  @impl true
  def handle_event(
        "rate_result",
        %{"benchmark_id" => benchmark_id, "provider" => provider, "rating" => rating},
        socket
      ) do
    # In a real implementation, you'd store user ratings
    # For now, just log it
    Logger.info("User rated #{provider} in benchmark #{benchmark_id}: #{rating}")

    {:noreply, put_flash(socket, :info, "Rating saved!")}
  end

  @impl true
  def handle_info({:benchmark_completed, benchmark_id, results, stats}, socket) do
    socket =
      if socket.assigns.running_benchmark == benchmark_id do
        socket
        |> assign(:running_benchmark, nil)
        |> assign(:benchmark_results, %{results: results, stats: stats})
        |> put_flash(:info, "Benchmark completed!")
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:benchmark_failed, benchmark_id, error}, socket) do
    socket =
      if socket.assigns.running_benchmark == benchmark_id do
        socket
        |> assign(:running_benchmark, nil)
        |> put_flash(:error, "Benchmark failed: #{error}")
      else
        socket
      end

    {:noreply, socket}
  end

  # Private functions

  defp run_benchmark_async(benchmark_id) do
    benchmark = BenchmarksContext.get_benchmark(benchmark_id)

    if benchmark do
      # Run benchmark (always succeeds in current implementation)
      {:ok, results, stats} = BenchmarksContext.run_benchmark(benchmark)

      # Broadcast completion
      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "benchmarks",
        {:benchmark_completed, benchmark_id, results, stats}
      )
    end
  end

  defp format_latency(ms) do
    cond do
      ms < 1000 -> "#{round(ms)}ms"
      ms < 60000 -> "#{Float.round(ms / 1000, 2)}s"
      true -> "#{Float.round(ms / 60000, 2)}min"
    end
  end

  defp format_cost(cost) do
    "$#{Float.round(cost, 4)}"
  end

  defp get_status(benchmark, running_id) do
    cond do
      benchmark.id == running_id -> "running"
      benchmark.results -> "completed"
      true -> "pending"
    end
  end
end
