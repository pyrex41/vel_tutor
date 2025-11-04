defmodule ViralEngineWeb.AgentController do
  @moduledoc """
  JSON-RPC 2.0 controller for MCP agent calls.

  Handles MCP requests to orchestrator and other agents with proper
  JSON-RPC formatting, error handling, and logging.
  """

  use ViralEngineWeb, :controller

  # Deprecated :namespace option - use plug :put_layout instead if needed
  # Set formats for proper rendering
  plug :accepts, ["html", "json"]
  require Logger

  alias ViralEngine.{Repo, AgentDecision, MetricsContext}

  def call_agent(conn, %{"agent" => agent, "method" => method} = params) do
    request_id = params["id"] || generate_request_id()

    case validate_jsonrpc_request(params) do
      {:ok, validated_params} ->
        start_time = System.monotonic_time(:millisecond)

        result = execute_agent_call(agent, method, validated_params["params"] || %{})

        latency = System.monotonic_time(:millisecond) - start_time

        # Collect metrics
        collect_operation_metrics(agent, method, latency, result)

        # Log to agent_decisions table
        log_agent_call(agent, method, validated_params, result, latency)

        case result do
          {:ok, response_data} ->
            jsonrpc_success(conn, request_id, response_data)

          {:error, error} ->
            jsonrpc_error(conn, request_id, error)
        end

      {:error, validation_error} ->
        jsonrpc_error(conn, request_id, validation_error)
    end
  end

  def health(conn, %{"agent" => "orchestrator"}) do
    health_data = ViralEngine.Agents.Orchestrator.health()
    json(conn, health_data)
  end

  def health(conn, _params) do
    conn
    |> put_status(404)
    |> json(%{error: "Agent not found"})
  end

  # Private functions

  defp validate_jsonrpc_request(%{"jsonrpc" => "2.0", "method" => method} = params) do
    # Validate required fields
    with true <- is_binary(method),
         id when not is_nil(id) <- params["id"],
         params_map when is_map(params_map) <- params["params"] || %{} do
      {:ok, params}
    else
      _ -> {:error, %{code: -32600, message: "Invalid Request - missing required fields"}}
    end
  end

  defp validate_jsonrpc_request(_params) do
    {:error, %{code: -32600, message: "Invalid Request"}}
  end

  defp execute_agent_call("orchestrator", "select_loop", params) do
    # Call the orchestrator GenServer
    case ViralEngine.Agents.Orchestrator.trigger_event(params) do
      {:ok, decision} -> {:ok, decision}
      {:error, reason} -> {:error, %{code: -32000, message: "Orchestrator error", data: reason}}
    end
  catch
    :exit, {:timeout, _} ->
      {:error, %{code: -32001, message: "Request timeout"}}
  end

  defp execute_agent_call(agent, method, _params) do
    Logger.warning("Unknown agent/method: #{agent}/#{method}")
    {:error, %{code: -32601, message: "Method not found"}}
  end

  defp log_agent_call(agent, method, params, result, latency) do
    agent_decision = %AgentDecision{
      agent_id: agent,
      decision_type: method,
      decision_data: %{
        params: params,
        result: result,
        latency_ms: latency
      },
      timestamp: DateTime.utc_now(),
      viral_loop_id: nil,
      latency_ms: latency,
      success: match?({:ok, _}, result)
    }

    case Repo.insert(agent_decision) do
      {:ok, _} ->
        Logger.info("Agent call logged: #{agent}/#{method}")

      {:error, changeset} ->
        Logger.error("Failed to log agent call: #{inspect(changeset.errors)}")
    end
  end

  defp collect_operation_metrics(agent, method, latency, result) do
    # Extract provider from agent name (simplified mapping)
    provider =
      case agent do
        "openai" -> "openai"
        "groq" -> "groq"
        "perplexity" -> "perplexity"
        _ -> "unknown"
      end

    # Extract cost and token information from result if available
    {cost, tokens_used} =
      case result do
        {:ok, response_data} ->
          # Try to extract cost and tokens from response metadata
          cost = get_in(response_data, ["metadata", "cost"]) || Decimal.new(0)
          tokens = get_in(response_data, ["metadata", "tokens_used"]) || 0
          {cost, tokens}

        _ ->
          {Decimal.new(0), 0}
      end

    operation_result = %{
      provider: provider,
      latency_ms: latency,
      cost: cost,
      tokens_used: tokens_used,
      timestamp: DateTime.utc_now()
    }

    # Collect metrics asynchronously to avoid blocking the response
    Task.start(fn ->
      case MetricsContext.collect_metrics(operation_result) do
        {:ok, _} ->
          Logger.debug("Metrics collected for #{agent}/#{method}")

        {:error, changeset} ->
          Logger.warning("Failed to collect metrics: #{inspect(changeset.errors)}")
      end
    end)
  end

  defp jsonrpc_success(conn, id, result) do
    response = %{
      jsonrpc: "2.0",
      id: id,
      result: result
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  defp jsonrpc_error(conn, id, error) do
    response = %{
      jsonrpc: "2.0",
      id: id,
      error: error
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
