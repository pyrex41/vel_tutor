defmodule ViralEngineWeb.AgentConfigController do
  use ViralEngineWeb, :controller

  # Deprecated :namespace option - use plug :put_layout instead if needed
  # Set formats for proper rendering
  plug :accepts, ["html", "json"]
  alias ViralEngine.{Agent, AgentConfigHistory, Repo}
  alias ViralEngine.Integration.{OpenAIAdapter, GroqAdapter, PerplexityAdapter}
  import Ecto.Query
  require Logger

  def create(conn, %{"name" => name, "config" => config, "user_id" => user_id}) do
    changeset =
      Agent.changeset(%Agent{}, %{
        name: name,
        config: config,
        user_id: user_id
      })

    case Repo.insert(changeset) do
      {:ok, agent} ->
        conn
        |> put_status(201)
        |> json(%{agent_id: agent.id, name: agent.name, config: agent.config})

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        conn
        |> put_status(422)
        |> json(%{errors: errors})
    end
  end

  def update(conn, %{"id" => id, "config" => new_config}) do
    case Repo.get(Agent, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Agent not found"})

      agent ->
        # Save current config to history
        Repo.insert(%AgentConfigHistory{
          agent_id: agent.id,
          config: agent.config,
          changed_at: NaiveDateTime.utc_now()
        })

        changeset = Agent.changeset(agent, %{config: new_config})

        case Repo.update(changeset) do
          {:ok, updated_agent} ->
            json(conn, %{agent_id: updated_agent.id, config: updated_agent.config})

          {:error, changeset} ->
            errors =
              Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
                Enum.reduce(opts, msg, fn {key, value}, acc ->
                  String.replace(acc, "%{#{key}}", to_string(value))
                end)
              end)

            conn
            |> put_status(422)
            |> json(%{errors: errors})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Agent, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Agent not found"})

      agent ->
        # Soft delete
        changeset = Agent.changeset(agent, %{deleted_at: DateTime.utc_now()})

        case Repo.update(changeset) do
          {:ok, _} ->
            # Archive related tasks
            from(t in ViralEngine.Task, where: t.agent_id == ^agent.name)
            |> Repo.update_all(set: [status: "archived"])

            json(conn, %{message: "Agent deleted"})

          {:error, _} ->
            conn
            |> put_status(500)
            |> json(%{error: "Failed to delete agent"})
        end
    end
  end

  @doc """
  Test agent configuration with dry-run capability.
  POST /api/agents/:id/test
  """
  def test(conn, %{"id" => id}) do
    case Repo.get(Agent, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Agent not found"})

      agent ->
        # Rate limiting check
        if rate_limited?(agent.id) do
          conn
          |> put_status(429)
          |> json(%{error: "Rate limit exceeded. Please wait before testing again."})
        else
          # Perform dry-run test
          start_time = System.monotonic_time(:millisecond)

          test_results = %{
            connectivity: test_provider_connectivity(agent),
            sample_prompt: test_sample_prompt(agent),
            response_time_ms: System.monotonic_time(:millisecond) - start_time,
            tested_at: DateTime.utc_now()
          }

          # Generate suggestions based on results
          suggestions = generate_suggestions(test_results)

          # Update agent metadata with test results
          updated_metadata =
            Map.merge(agent.metadata || %{}, %{
              "last_tested_at" => DateTime.utc_now(),
              "last_test_results" => test_results,
              "suggestions" => suggestions
            })

          changeset = Agent.changeset(agent, %{metadata: updated_metadata})
          Repo.update(changeset)

          # Track rate limit
          track_test_rate_limit(agent.id)

          conn
          |> json(%{
            agent_id: agent.id,
            test_results: test_results,
            suggestions: suggestions,
            status: if(test_results.connectivity.success, do: "passed", else: "failed")
          })
        end
    end
  end

  # Private functions

  defp test_provider_connectivity(agent) do
    provider = agent.config["provider"] || "openai"
    test_prompt = "Hello"

    start_time = System.monotonic_time(:millisecond)

    result =
      case provider do
        "openai" ->
          OpenAIAdapter.chat_completion(test_prompt, api_key: agent.config["api_key"])

        "groq" ->
          GroqAdapter.chat_completion(test_prompt, api_key: agent.config["api_key"])

        "perplexity" ->
          PerplexityAdapter.chat_completion(test_prompt, api_key: agent.config["api_key"])

        _ ->
          {:error, :unsupported_provider}
      end

    latency_ms = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, _response} ->
        %{
          success: true,
          provider: provider,
          latency_ms: latency_ms,
          message: "Provider connectivity verified"
        }

      {:error, reason} ->
        %{
          success: false,
          provider: provider,
          error: inspect(reason),
          latency_ms: latency_ms,
          message: "Failed to connect to provider"
        }
    end
  end

  defp test_sample_prompt(agent) do
    provider = agent.config["provider"] || "openai"
    test_prompt = "What is 2+2?"

    start_time = System.monotonic_time(:millisecond)

    result =
      case provider do
        "openai" ->
          OpenAIAdapter.chat_completion(test_prompt,
            api_key: agent.config["api_key"],
            temperature: agent.config["temperature"] || 0.1
          )

        "groq" ->
          GroqAdapter.chat_completion(test_prompt,
            api_key: agent.config["api_key"],
            temperature: agent.config["temperature"] || 0.1
          )

        "perplexity" ->
          PerplexityAdapter.chat_completion(test_prompt,
            api_key: agent.config["api_key"],
            temperature: agent.config["temperature"] || 0.1
          )

        _ ->
          {:error, :unsupported_provider}
      end

    latency_ms = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, response} ->
        %{
          success: true,
          prompt: test_prompt,
          response: String.slice(response.content, 0..100),
          tokens_used: response.tokens_used,
          estimated_cost: response.cost,
          latency_ms: latency_ms
        }

      {:error, reason} ->
        %{
          success: false,
          prompt: test_prompt,
          error: inspect(reason),
          tokens_used: 0,
          estimated_cost: 0.0,
          latency_ms: latency_ms
        }
    end
  end

  defp generate_suggestions(test_results) do
    suggestions = []

    # Connectivity suggestions
    suggestions =
      if not test_results.connectivity.success do
        [
          "Check API key validity for #{test_results.connectivity.provider}",
          "Verify network connectivity to provider API"
          | suggestions
        ]
      else
        suggestions
      end

    # Latency suggestions
    suggestions =
      if test_results.sample_prompt[:latency_ms] && test_results.sample_prompt.latency_ms > 5000 do
        ["Consider using Groq for faster response times (typically <500ms)" | suggestions]
      else
        suggestions
      end

    # Cost optimization
    suggestions =
      if test_results.sample_prompt[:estimated_cost] &&
           test_results.sample_prompt.estimated_cost > 0.01 do
        [
          "Consider Groq for cost savings (70% cheaper than OpenAI for similar quality)"
          | suggestions
        ]
      else
        suggestions
      end

    if Enum.empty?(suggestions) do
      ["Configuration looks optimal!"]
    else
      suggestions
    end
  end

  @rate_limit_table :agent_test_rate_limits
  @rate_limit_window 60_000

  defp rate_limited?(agent_id) do
    table = :ets.whereis(@rate_limit_table)

    if table == :undefined do
      :ets.new(@rate_limit_table, [:set, :public, :named_table])
      false
    else
      case :ets.lookup(@rate_limit_table, agent_id) do
        [{^agent_id, last_test_time}] ->
          System.system_time(:millisecond) - last_test_time < @rate_limit_window

        [] ->
          false
      end
    end
  end

  defp track_test_rate_limit(agent_id) do
    table = :ets.whereis(@rate_limit_table)

    if table == :undefined do
      :ets.new(@rate_limit_table, [:set, :public, :named_table])
    end

    :ets.insert(@rate_limit_table, {agent_id, System.system_time(:millisecond)})
  end
end
