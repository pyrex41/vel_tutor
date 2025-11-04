defmodule ViralEngine.Integration.PerplexityAdapter do
  @moduledoc """
  Perplexity API integration adapter for web-connected research.
  """

  require Logger

  @behaviour ViralEngine.Integration.AdapterBehaviour

  @max_retries 3
  # 24 hours in ms
  @cache_expiry 86_400_000

  defstruct [
    :api_key,
    :base_url,
    :timeout,
    :temperature,
    :max_tokens,
    :cache
  ]

  @doc """
  Initializes the Perplexity adapter.
  """
  def init(opts \\ []) do
    api_key = System.get_env("PERPLEXITY_API_KEY") || opts[:api_key]

    if is_nil(api_key) or api_key == "" do
      raise "Perplexity API key not configured"
    end

    %__MODULE__{
      api_key: api_key,
      base_url: opts[:base_url] || "https://api.perplexity.ai",
      timeout: opts[:timeout] || 30_000,
      temperature: opts[:temperature] || 0.1,
      max_tokens: opts[:max_tokens] || 4096,
      cache: :ets.new(:perplexity_cache, [:set, :public])
    }
  end

  @doc """
  Performs chat completion with caching.
  """
  def chat_completion(prompt, opts \\ []) do
    adapter = init(opts)

    cache_key = :crypto.hash(:sha256, prompt) |> Base.encode16()

    case get_cache(adapter.cache, cache_key) do
      {:ok, cached} ->
        Logger.info("Using cached Perplexity response")
        {:ok, cached}

      :not_found ->
        do_chat_completion(prompt, adapter, cache_key, @max_retries)
    end
  end

  # Private functions

  defp do_chat_completion(_prompt, _adapter, _cache_key, 0) do
    {:error, :max_retries_exceeded}
  end

  defp do_chat_completion(prompt, adapter, cache_key, retries) do
    case make_api_call(prompt, adapter) do
      {:ok, response} ->
        put_cache(adapter.cache, cache_key, response)
        {:ok, response}

      {:error, reason} ->
        Logger.warning(
          "Perplexity API call failed: #{inspect(reason)}, retries left: #{retries - 1}"
        )

        :timer.sleep(1000 * (@max_retries - retries + 1))
        do_chat_completion(prompt, adapter, cache_key, retries - 1)
    end
  end

  defp make_api_call(prompt, adapter) do
    url = "#{adapter.base_url}/chat/completions"

    headers = [
      {"Authorization", "Bearer #{adapter.api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        model: "sonar-large-online",
        messages: [%{role: "user", content: prompt}],
        temperature: adapter.temperature,
        max_tokens: adapter.max_tokens
      })

    # Real Finch HTTP implementation
    case Finch.build(:post, url, headers, body)
         |> Finch.request(ViralEngine.Finch, receive_timeout: adapter.timeout) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _], "usage" => usage}} ->
            tokens_used = Map.get(usage, "total_tokens", 0)
            cost = calculate_cost(tokens_used, "sonar-large-online")

            {:ok,
             %{
               content: content,
               tokens_used: tokens_used,
               cost: cost,
               provider: "perplexity",
               model: "sonar-large-online",
               raw_response: response_body
             }}

          {:error, decode_error} ->
            Logger.error("Failed to decode Perplexity response: #{inspect(decode_error)}")
            {:error, :decode_error}
        end

      {:ok, %Finch.Response{status: status, body: error_body}} ->
        Logger.error("Perplexity API error (#{status}): #{error_body}")
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        Logger.error("Finch request to Perplexity failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp calculate_cost(tokens, model) do
    # Perplexity pricing (as of 2025)
    # Sonar Large Online: $0.001 input / $0.001 output per 1K tokens (avg $0.001)
    # Includes web search capability
    rate =
      case model do
        "sonar-large-online" -> 0.001
        "sonar-medium-online" -> 0.0006
        _ -> 0.001
      end

    tokens / 1000 * rate
  end

  defp get_cache(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, timestamp}] ->
        if System.system_time(:millisecond) - timestamp < @cache_expiry do
          {:ok, value}
        else
          :ets.delete(table, key)
          :not_found
        end

      [] ->
        :not_found
    end
  end

  defp put_cache(table, key, value) do
    :ets.insert(table, {key, value, System.system_time(:millisecond)})
  end
end
