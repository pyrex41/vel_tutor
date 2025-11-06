defmodule ViralEngine.AIClient do
  @moduledoc """
  Unified AI client with configurable providers and models.

  Handles intelligent routing, automatic fallback, cost tracking, and provider selection
  based on task type, reliability, cost, and performance criteria.

  ## Supported Providers

  - **OpenAI**: GPT-4o, GPT-4o-mini (best for complex reasoning)
  - **Groq**: Llama 3.3 70B, Mixtral 8x7B (best for speed and cost)
  - **Perplexity**: Sonar Large (best for research with web access)

  ## Usage Examples

      # Task-based routing (recommended)
      AIClient.chat("Generate Elixir code for...", task_type: :code_gen)
      # Routes to Groq Llama 3.3 70B (fast, cheap)

      AIClient.chat("Research best practices for...", task_type: :research)
      # Routes to Perplexity Sonar Large (web-connected)

      AIClient.chat("Plan architecture for...", task_type: :planning)
      # Routes to OpenAI GPT-4o (best reasoning)

      # Explicit provider/model override
      AIClient.chat(prompt, provider: :openai, model: "gpt-4o-mini")

      # Streaming responses
      AIClient.stream(prompt, fn
        {:chunk, text} -> IO.write(text)
        {:done, meta} -> IO.puts("\\nDone: " <> inspect(meta))
        {:error, reason} -> IO.puts("Error: " <> reason)
      end, task_type: :code_gen)

      # Intelligent routing based on criteria
      AIClient.chat(prompt, criteria: %{weights: %{cost: 0.8, performance: 0.2}})
      # Selects cheapest fast provider (likely Groq)

  """

  require Logger

  alias ViralEngine.Integration.{OpenAIAdapter, GroqAdapter, PerplexityAdapter}

  @adapters %{
    openai: OpenAIAdapter,
    groq: GroqAdapter,
    perplexity: PerplexityAdapter
  }

  @type provider :: :openai | :groq | :perplexity
  @type task_type :: :code_gen | :planning | :research | :general | :validation
  @type chat_option ::
          {:provider, provider()}
          | {:model, String.t()}
          | {:task_type, task_type()}
          | {:temperature, float()}
          | {:max_tokens, pos_integer()}
          | {:criteria, map()}
          | {:timeout, pos_integer()}

  @doc """
  Execute AI chat request with intelligent routing and automatic fallback.

  ## Options

  - `:provider` - Force specific provider (`:openai`, `:groq`, `:perplexity`)
  - `:model` - Override default model (e.g., `"gpt-4o"`, `"llama-3.3-70b-versatile"`)
  - `:task_type` - Hint for routing (`:code_gen`, `:planning`, `:research`, `:general`, `:validation`)
  - `:temperature` - Control randomness (0.0-1.0, default: 0.7)
  - `:max_tokens` - Maximum response length (default: provider-specific)
  - `:criteria` - Custom routing criteria (e.g., `%{weights: %{cost: 0.8}}`)
  - `:timeout` - Request timeout in milliseconds

  ## Returns

  - `{:ok, %{content: text, tokens_used: int, cost: float, provider: atom, model: string}}`
  - `{:error, reason}` - If all providers fail

  ## Examples

      # Simple task-based routing
      {:ok, response} = AIClient.chat("Explain async/await", task_type: :general)
      IO.puts(response.content)

      # Cost-optimized
      {:ok, response} = AIClient.chat(prompt, criteria: %{weights: %{cost: 1.0}})
      # Will select Groq (9x cheaper than OpenAI)

      # Speed-optimized
      {:ok, response} = AIClient.chat(prompt, criteria: %{weights: %{performance: 1.0}})
      # Will select Groq (88% faster than OpenAI)
  """
  @spec chat(String.t(), [chat_option()]) ::
          {:ok, map()} | {:error, term()}
  def chat(prompt, opts \\ []) do
    # Select provider and model based on options
    {provider, model, adapter_opts} = select_provider_and_model(opts)

    Logger.info(
      "AIClient routing request to #{provider}/#{model}",
      task_type: opts[:task_type],
      prompt_length: String.length(prompt)
    )

    # Execute with automatic fallback
    case execute_with_fallback(prompt, provider, model, adapter_opts) do
      {:ok, response} ->
        # Enrich response with provider/model info
        enriched_response =
          response
          |> Map.put(:provider, provider)
          |> Map.put(:model, model)

        {:ok, enriched_response}

      {:error, reason} = error ->
        Logger.error("AIClient failed for all providers", reason: reason)
        error
    end
  end

  @doc """
  Execute streaming AI request with real-time chunks.

  The callback function receives:
  - `{:chunk, text}` - Incremental text chunks
  - `{:done, metadata}` - Final metadata (tokens, cost, etc.)
  - `{:error, reason}` - Error details

  ## Examples

      AIClient.stream(prompt, fn
        {:chunk, text} -> IO.write(text)
        {:done, meta} -> IO.puts("\\nCost: $" <> to_string(meta.cost))
        {:error, reason} -> IO.puts("Error: " <> reason)
      end, task_type: :code_gen)
  """
  @spec stream(String.t(), function(), [chat_option()]) :: :ok | {:error, term()}
  def stream(prompt, callback_fn, opts \\ []) do
    {provider, model, adapter_opts} = select_provider_and_model(opts)

    # Only OpenAI and Groq support streaming
    if provider in [:openai, :groq] do
      adapter = @adapters[provider]
      final_opts = Keyword.merge(adapter_opts, [model: model] ++ opts)

      adapter.chat_completion_stream(prompt, callback_fn, final_opts)
    else
      {:error, :streaming_not_supported}
    end
  end

  @doc """
  Get list of available providers and their capabilities.

  Returns a map of provider information including models, costs, and features.
  """
  @spec list_providers() :: map()
  def list_providers do
    %{
      openai: %{
        name: "OpenAI",
        models: ["gpt-5", "gpt-4o-mini"],
        default_model: "gpt-5",
        cost_per_1m_tokens: 6.25,
        avg_latency_ms: 2100,
        streaming: true,
        features: [:complex_reasoning, :function_calling, :vision]
      },
      groq: %{
        name: "Groq",
        models: ["llama-3.3-70b-versatile", "mixtral-8x7b-32768"],
        default_model: "llama-3.3-70b-versatile",
        cost_per_1m_tokens: 0.69,
        avg_latency_ms: 300,
        streaming: true,
        features: [:fast_inference, :low_cost, :code_generation]
      },
      perplexity: %{
        name: "Perplexity",
        models: ["sonar-large-online", "sonar-medium-online"],
        default_model: "sonar-large-online",
        cost_per_1m_tokens: 1.0,
        avg_latency_ms: 3200,
        streaming: false,
        features: [:web_search, :real_time_data, :caching]
      }
    }
  end

  # Private Functions

  # Select provider and model based on options
  defp select_provider_and_model(opts) do
    cond do
      # Explicit provider AND model override
      opts[:provider] && opts[:model] ->
        {opts[:provider], opts[:model], opts}

      # Explicit provider only (use default model)
      opts[:provider] ->
        provider = opts[:provider]
        model = get_default_model(provider)
        {provider, model, opts}

      # Task-based routing
      opts[:task_type] ->
        route_by_task(opts[:task_type], opts)

      # Intelligent routing via ProviderRouter
      opts[:criteria] ->
        route_by_criteria(opts[:criteria], opts)

      # Default: Use config default or Groq (cost-effective)
      true ->
        default_provider = get_default_provider()
        default_model = get_default_model(default_provider)
        {default_provider, default_model, opts}
    end
  end

  # Route request based on task type
  defp route_by_task(task_type, opts) do
    routing_config = Application.get_env(:viral_engine, :ai, %{})
    |> Map.get(:routing, %{})

    {provider, model} =
      case task_type do
        :code_gen ->
          Map.get(routing_config, :code_generation, {:groq, "llama-3.3-70b-versatile"})

        :planning ->
          Map.get(routing_config, :planning, {:openai, "gpt-5"})

        :research ->
          Map.get(routing_config, :research, {:perplexity, "sonar-large-online"})

        :validation ->
          Map.get(routing_config, :validation, {:groq, "mixtral-8x7b-32768"})

        :general ->
          Map.get(routing_config, :general, {:groq, "llama-3.3-70b-versatile"})

        _ ->
          # Fallback for unknown task types
          {:openai, "gpt-4o-mini"}
      end

    {provider, model, opts}
  end

  # Route request based on custom criteria
  defp route_by_criteria(criteria, opts) do
    # Use ProviderRouter for intelligent selection
    # Note: ProviderRouter.select_provider requires database providers
    # For now, use simplified in-memory routing

    weights = Map.get(criteria, :weights, %{reliability: 0.4, cost: 0.3, performance: 0.3})

    provider_scores = [
      {
        :openai,
        "gpt-5",
        calculate_score(%{
          reliability: 0.98,
          cost_per_token: 0.00000625,
          latency_ms: 2100
        }, weights)
      },
      {
        :groq,
        "llama-3.3-70b-versatile",
        calculate_score(%{
          reliability: 0.95,
          cost_per_token: 0.00000069,
          latency_ms: 300
        }, weights)
      },
      {
        :perplexity,
        "sonar-large-online",
        calculate_score(%{
          reliability: 0.96,
          cost_per_token: 0.00000100,
          latency_ms: 3200
        }, weights)
      }
    ]

    {provider, model, _score} =
      provider_scores
      |> Enum.max_by(fn {_p, _m, score} -> score end)

    {provider, model, opts}
  end

  # Calculate weighted score for provider selection
  defp calculate_score(metrics, weights) do
    reliability_score = metrics.reliability * Map.get(weights, :reliability, 0.4)

    # Cost score: inverse of cost (lower cost = higher score)
    cost_score = 1 / (metrics.cost_per_token * 1_000_000) * Map.get(weights, :cost, 0.3) * 0.01

    # Performance score: inverse of latency (lower latency = higher score)
    perf_score = 1 / metrics.latency_ms * Map.get(weights, :performance, 0.3) * 1000

    reliability_score + cost_score + perf_score
  end

  # Execute request with automatic fallback on failure
  defp execute_with_fallback(prompt, primary_provider, model, opts) do
    adapter = @adapters[primary_provider]
    final_opts = Keyword.merge(opts, model: model)

    case adapter.chat_completion(prompt, final_opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        Logger.warning(
          "Primary provider #{primary_provider} failed, attempting fallback",
          reason: reason
        )

        fallback_execute(prompt, primary_provider, opts)
    end
  end

  # Execute on fallback provider chain
  defp fallback_execute(prompt, failed_provider, opts) do
    fallback_chain = get_fallback_chain(failed_provider)

    Enum.reduce_while(fallback_chain, {:error, :all_providers_failed}, fn provider, _ ->
      adapter = @adapters[provider]
      model = get_default_model(provider)
      final_opts = Keyword.put(opts, :model, model)

      Logger.info("Attempting fallback to #{provider}/#{model}")

      case adapter.chat_completion(prompt, final_opts) do
        {:ok, response} ->
          Logger.info("Fallback to #{provider} succeeded")
          {:halt, {:ok, response}}

        {:error, reason} ->
          Logger.warning("Fallback to #{provider} failed", reason: reason)
          {:cont, {:error, :all_providers_failed}}
      end
    end)
  end

  # Get fallback provider chain for a given primary provider
  defp get_fallback_chain(primary_provider) do
    fallback_config =
      Application.get_env(:viral_engine, :ai, %{})
      |> Map.get(:fallback, %{})

    Map.get(fallback_config, primary_provider, default_fallback_chain(primary_provider))
  end

  # Default fallback chains if not configured
  defp default_fallback_chain(:openai), do: [:groq, :perplexity]
  defp default_fallback_chain(:groq), do: [:openai, :perplexity]
  defp default_fallback_chain(:perplexity), do: [:openai, :groq]
  defp default_fallback_chain(_), do: [:openai, :groq]

  # Get default model for a provider
  defp get_default_model(provider) do
    providers_config =
      Application.get_env(:viral_engine, :ai, %{})
      |> Map.get(:providers, %{})

    provider_config = Map.get(providers_config, provider, %{})

    Map.get(provider_config, :default_model, fallback_default_model(provider))
  end

  # Fallback default models if not configured
  defp fallback_default_model(:openai), do: "gpt-5"
  defp fallback_default_model(:groq), do: "llama-3.3-70b-versatile"
  defp fallback_default_model(:perplexity), do: "sonar-large-online"
  defp fallback_default_model(_), do: "gpt-5"

  # Get default provider from config
  defp get_default_provider do
    Application.get_env(:viral_engine, :ai, %{})
    |> Map.get(:default_provider, :groq)
  end
end
