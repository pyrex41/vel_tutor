defmodule ViralEngineWeb.HealthController do
  @moduledoc """
  Health check endpoint for system monitoring and load balancer integration.
  """

  use ViralEngineWeb, :controller
  alias ViralEngine.Repo
  alias ViralEngine.Integration.{OpenAIAdapter, GroqAdapter, PerplexityAdapter}
  require Logger

  @doc """
  System health check endpoint.
  GET /api/health
  """
  def index(conn, _params) do
    start_time = System.monotonic_time(:millisecond)

    # Run health checks concurrently for speed
    tasks = [
      Task.async(fn -> check_database() end),
      Task.async(fn -> check_providers() end)
    ]

    results = Task.await_many(tasks, 5000)
    [db_result, providers_result] = results

    response_time_ms = System.monotonic_time(:millisecond) - start_time

    # Determine overall health
    all_healthy = db_result.success && providers_result.active_count > 0

    status_code = if all_healthy, do: 200, else: 503

    response = %{
      status: if(all_healthy, do: "healthy", else: "unhealthy"),
      timestamp: DateTime.utc_now(),
      uptime_seconds: get_uptime(),
      version: get_version(),
      response_time_ms: response_time_ms,
      checks: %{
        database: db_result,
        providers: providers_result
      }
    }

    conn
    |> put_status(status_code)
    |> json(response)
  end

  # Private functions

  defp check_database do
    try do
      # Simple query to verify database connectivity
      Repo.query!("SELECT 1", [])

      %{
        success: true,
        message: "Database connection healthy"
      }
    rescue
      error ->
        Logger.error("Database health check failed: #{inspect(error)}")

        %{
          success: false,
          error: "Database unreachable"
        }
    end
  end

  defp check_providers do
    providers = [
      {"openai", &check_openai/0},
      {"groq", &check_groq/0},
      {"perplexity", &check_perplexity/0}
    ]

    # Check each provider concurrently with timeout
    results =
      Task.async_stream(
        providers,
        fn {name, check_fn} ->
          try do
            case check_fn.() do
              :ok -> {name, :healthy}
              {:error, _} -> {name, :unhealthy}
            end
          catch
            _, _ -> {name, :unhealthy}
          end
        end,
        timeout: 2000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    provider_statuses =
      Enum.map(results, fn
        {:ok, {name, status}} -> {name, status}
        {:exit, _} -> {"unknown", :timeout}
      end)
      |> Map.new()

    active_count = Enum.count(provider_statuses, fn {_, status} -> status == :healthy end)

    %{
      active_count: active_count,
      total_count: length(providers),
      providers: provider_statuses,
      message: "#{active_count}/#{length(providers)} providers healthy"
    }
  end

  defp check_openai do
    if System.get_env("OPENAI_API_KEY") do
      case OpenAIAdapter.chat_completion("test") do
        {:ok, _} -> :ok
        {:error, _} -> {:error, :unavailable}
      end
    else
      {:error, :not_configured}
    end
  end

  defp check_groq do
    if System.get_env("GROQ_API_KEY") do
      case GroqAdapter.chat_completion("test") do
        {:ok, _} -> :ok
        {:error, _} -> {:error, :unavailable}
      end
    else
      {:error, :not_configured}
    end
  end

  defp check_perplexity do
    if System.get_env("PERPLEXITY_API_KEY") do
      case PerplexityAdapter.chat_completion("test") do
        {:ok, _} -> :ok
        {:error, _} -> {:error, :unavailable}
      end
    else
      {:error, :not_configured}
    end
  end

  defp get_uptime do
    # Get Erlang VM uptime in milliseconds and convert to seconds
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    div(uptime_ms, 1000)
  end

  defp get_version do
    Application.spec(:viral_engine, :vsn)
    |> to_string()
  rescue
    _ -> "unknown"
  end
end
