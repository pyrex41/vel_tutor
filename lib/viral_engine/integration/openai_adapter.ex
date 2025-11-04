defmodule ViralEngine.Integration.OpenAIAdapter do
  @moduledoc """
  OpenAI API integration adapter with retry logic, circuit breaker, and token tracking.
  """

  require Logger

  @behaviour ViralEngine.Integration.AdapterBehaviour

  @max_retries 3
  @circuit_breaker_threshold 5
  # 60 seconds
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
  Initializes the OpenAI adapter.
  """
  def init(opts \\ []) do
    api_key = System.get_env("OPENAI_API_KEY") || opts[:api_key]

    if is_nil(api_key) or api_key == "" do
      raise "OpenAI API key not configured"
    end

    %__MODULE__{
      api_key: api_key,
      base_url: opts[:base_url] || "https://api.openai.com/v1",
      timeout: opts[:timeout] || 30_000,
      temperature: opts[:temperature] || 0.1,
      max_tokens: opts[:max_tokens] || 4096,
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
        model: "gpt-4o",
        messages: [%{role: "user", content: prompt}],
        temperature: adapter.temperature,
        max_tokens: adapter.max_tokens,
        stream: true
      })

    # Use Finch stream for SSE
    request = Finch.build(:post, url, headers, body)

    case Finch.stream(request, ViralEngine.Finch, nil, fn
           {:status, _status}, acc ->
             {:cont, acc}

           {:headers, _headers}, acc ->
             {:cont, acc}

           {:data, chunk}, acc ->
             # Parse SSE chunks
             chunk
             |> String.split("\n\n")
             |> Enum.each(fn line ->
               if String.starts_with?(line, "data: ") do
                 data = String.trim_leading(line, "data: ")

                 # OpenAI sends [DONE] when stream finishes
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
                   callback_fn.({:done, %{provider: "openai", model: "gpt-4o"}})
                 end
               end
             end)

             {:cont, acc}
         end) do
      {:ok, _acc} ->
        update_circuit_breaker(adapter, :success)
        {:ok, :streaming_complete}

      {:error, reason} ->
        Logger.error("OpenAI streaming failed: #{inspect(reason)}")
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
        Logger.warning("OpenAI API call failed: #{inspect(reason)}, retries left: #{retries - 1}")
        # exponential backoff
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
        model: "gpt-4o",
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
            cost = calculate_cost(tokens_used, "gpt-4o")

            {:ok, %{content: content, tokens_used: tokens_used, cost: cost, raw_response: response_body}}

          {:error, decode_error} ->
            Logger.error("Failed to decode OpenAI response: #{inspect(decode_error)}")
            {:error, :decode_error}
        end

      {:ok, %Finch.Response{status: status, body: error_body}} ->
        Logger.error("OpenAI API error (#{status}): #{error_body}")
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        Logger.error("Finch request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp calculate_cost(tokens, model) do
    # OpenAI pricing (as of 2025)
    # GPT-4o: $0.0025 input / $0.01 output per 1K tokens (avg $0.00625)
    # GPT-4o-mini: $0.00015 input / $0.0006 output per 1K tokens (avg $0.000375)
    rate =
      case model do
        "gpt-4o" -> 0.00625
        "gpt-4o-mini" -> 0.000375
        _ -> 0.00625
      end

    tokens / 1000 * rate
  end

  defp circuit_breaker_open?(adapter) do
    case adapter.circuit_breaker_state do
      :open ->
        if System.system_time(:millisecond) - (adapter.last_failure_time || 0) >
             @circuit_breaker_timeout do
          # Reset to half-open
          false
        else
          true
        end

      _ ->
        false
    end
  end

  defp update_circuit_breaker(adapter, :success) do
    # Reset on success
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
