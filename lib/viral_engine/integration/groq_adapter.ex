defmodule ViralEngine.Integration.GroqAdapter do
  @moduledoc """
  Groq API integration adapter with OpenAI-compatible interface.
  """

  require Logger

  @behaviour ViralEngine.Integration.AdapterBehaviour

  @max_retries 3
  @circuit_breaker_threshold 5
  @circuit_breaker_timeout 60_000

  defstruct [
    :api_key,
    :base_url,
    :timeout,
    :temperature,
    :max_tokens,
    :circuit_breaker_state,
    :failure_count,
    :last_failure_time
  ]

  @doc """
  Initializes the Groq adapter.
  """
  def init(opts \\ []) do
    api_key = System.get_env("GROQ_API_KEY") || opts[:api_key]

    if is_nil(api_key) or api_key == "" do
      raise "Groq API key not configured"
    end

    %__MODULE__{
      api_key: api_key,
      base_url: opts[:base_url] || "https://api.groq.com/openai/v1",
      # Groq is faster
      timeout: opts[:timeout] || 10_000,
      temperature: opts[:temperature] || 0.1,
      max_tokens: opts[:max_tokens] || 8192,
      circuit_breaker_state: :closed,
      failure_count: 0,
      last_failure_time: nil
    }
  end

  @doc """
  Performs chat completion with retry and circuit breaker.
  """
  def chat_completion(prompt, opts \\ []) do
    adapter = init(opts)

    if circuit_breaker_open?(adapter) do
      {:error, :circuit_breaker_open}
    else
      do_chat_completion(prompt, adapter, @max_retries)
    end
  end

  @doc """
  Performs streaming chat completion, sending results to a callback function.
  The callback receives {:chunk, text}, {:done, metadata}, or {:error, reason}.
  """
  def chat_completion_stream(prompt, callback_fn, opts \\ []) do
    adapter = init(opts)

    if circuit_breaker_open?(adapter) do
      {:error, :circuit_breaker_open}
    else
      do_chat_completion_stream(prompt, adapter, callback_fn)
    end
  end

  # Private functions

  defp do_chat_completion_stream(prompt, adapter, callback_fn) do
    url = "#{adapter.base_url}/chat/completions"

    headers = [
      {"Authorization", "Bearer #{adapter.api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        model: "llama-3.3-70b-versatile",
        messages: [%{role: "user", content: prompt}],
        temperature: adapter.temperature,
        max_tokens: adapter.max_tokens,
        stream: true
      })

    # Groq uses OpenAI-compatible streaming
    request = Finch.build(:post, url, headers, body)

    case Finch.stream(request, ViralEngine.Finch, nil, fn
           {:status, _status}, acc ->
             {:cont, acc}

           {:headers, _headers}, acc ->
             {:cont, acc}

           {:data, chunk}, acc ->
             # Parse SSE chunks (same as OpenAI)
             chunk
             |> String.split("\n\n")
             |> Enum.each(fn line ->
               if String.starts_with?(line, "data: ") do
                 data = String.trim_leading(line, "data: ")

                 if data != "[DONE]" do
                   case Jason.decode(data) do
                     {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}} when is_binary(content) ->
                       callback_fn.({:chunk, content})

                     {:ok, _} ->
                       :ok

                     {:error, _} ->
                       :ok
                   end
                 else
                   callback_fn.({:done, %{provider: "groq", model: "llama-3.3-70b-versatile"}})
                 end
               end
             end)

             {:cont, acc}
         end) do
      {:ok, _acc} ->
        update_circuit_breaker(adapter, :success)
        {:ok, :streaming_complete}

      {:error, reason} ->
        Logger.error("Groq streaming failed: #{inspect(reason)}")
        callback_fn.({:error, reason})
        update_circuit_breaker(adapter, :failure)
        {:error, reason}
    end
  end

  defp do_chat_completion(_prompt, adapter, 0) do
    update_circuit_breaker(adapter, :failure)
    {:error, :max_retries_exceeded}
  end

  defp do_chat_completion(prompt, adapter, retries) do
    case make_api_call(prompt, adapter) do
      {:ok, response} ->
        update_circuit_breaker(adapter, :success)
        {:ok, response}

      {:error, reason} ->
        Logger.warning("Groq API call failed: #{inspect(reason)}, retries left: #{retries - 1}")
        :timer.sleep(1000 * (@max_retries - retries + 1))
        update_circuit_breaker(adapter, :failure)
        do_chat_completion(prompt, adapter, retries - 1)
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
        model: "llama-3.3-70b-versatile",
        messages: [%{role: "user", content: prompt}],
        temperature: adapter.temperature,
        max_tokens: adapter.max_tokens
      })

    start_time = System.monotonic_time(:millisecond)

    # Real Finch HTTP implementation
    case Finch.build(:post, url, headers, body)
         |> Finch.request(ViralEngine.Finch, receive_timeout: adapter.timeout) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        latency = System.monotonic_time(:millisecond) - start_time

        case Jason.decode(response_body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _], "usage" => usage}} ->
            tokens_used = Map.get(usage, "total_tokens", 0)
            cost = calculate_cost(tokens_used, "llama-3.3-70b-versatile")

            # Log performance metrics
            Logger.info("Groq API call completed in #{latency}ms, tokens: #{tokens_used}")

            {:ok,
             %{
               content: content,
               tokens_used: tokens_used,
               cost: cost,
               latency_ms: latency,
               provider: "groq",
               model: "llama-3.3-70b-versatile",
               raw_response: response_body
             }}

          {:error, decode_error} ->
            Logger.error("Failed to decode Groq response: #{inspect(decode_error)}")
            {:error, :decode_error}
        end

      {:ok, %Finch.Response{status: 429, body: error_body}} ->
        # Groq-specific rate limit handling
        Logger.warning("Groq rate limit hit: #{error_body}")
        {:error, {:rate_limit, error_body}}

      {:ok, %Finch.Response{status: status, body: error_body}} ->
        Logger.error("Groq API error (#{status}): #{error_body}")
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        Logger.error("Finch request to Groq failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp calculate_cost(tokens, model) do
    # Groq pricing (as of 2025)
    # Llama 3.3 70B: $0.59 input / $0.79 output per 1M tokens (avg $0.00069 per 1K)
    # Llama 3.1 70B: $0.59 input / $0.79 output per 1M tokens (avg $0.00069 per 1K)
    # Mixtral 8x7B: $0.24 input / $0.24 output per 1M tokens (avg $0.00024 per 1K)
    rate =
      case model do
        "llama-3.3-70b-versatile" -> 0.00069
        "llama-3.1-70b-versatile" -> 0.00069
        "mixtral-8x7b-32768" -> 0.00024
        _ -> 0.00069
      end

    tokens / 1000 * rate
  end

  defp circuit_breaker_open?(adapter) do
    case adapter.circuit_breaker_state do
      :open ->
        if System.system_time(:millisecond) - (adapter.last_failure_time || 0) >
             @circuit_breaker_timeout do
          false
        else
          true
        end

      _ ->
        false
    end
  end

  defp update_circuit_breaker(adapter, :success) do
    %{adapter | circuit_breaker_state: :closed, failure_count: 0, last_failure_time: nil}
  end

  defp update_circuit_breaker(adapter, :failure) do
    failure_count = adapter.failure_count + 1
    now = System.system_time(:millisecond)

    if failure_count >= @circuit_breaker_threshold do
      %{
        adapter
        | circuit_breaker_state: :open,
          failure_count: failure_count,
          last_failure_time: now
      }
    else
      %{adapter | failure_count: failure_count, last_failure_time: now}
    end
  end
end
