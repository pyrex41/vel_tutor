defmodule ViralEngine.Integration.OpenAIFineTuning do
  @moduledoc """
  OpenAI API integration for fine-tuning operations.
  Handles file uploads, job creation, status polling, and cost retrieval.
  """

  require Logger

  @base_url "https://api.openai.com/v1"
  # 5 minutes for file uploads
  @upload_timeout 300_000
  # 1 minute for other operations
  @default_timeout 60_000

  @doc """
  Uploads a training file to OpenAI for fine-tuning.
  """
  def upload_file(file_path, api_key, purpose \\ "fine-tune") do
    url = "#{@base_url}/files"

    # Read the file
    case File.read(file_path) do
      {:ok, file_content} ->
        # Create multipart form data
        multipart = [
          {:file, file_content, {"form-data", [name: "file", filename: Path.basename(file_path)]},
           [{"Content-Type", "application/json"}]},
          {:purpose, purpose}
        ]

        headers = [
          {"Authorization", "Bearer #{api_key}"},
          {"OpenAI-Beta", "assistants=v2"}
        ]

        case Finch.build(:post, url, headers, {:multipart, multipart})
             |> Finch.request(ViralEngine.Finch, receive_timeout: @upload_timeout) do
          {:ok, %Finch.Response{status: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"id" => file_id} = response} ->
                {:ok, %{file_id: file_id, response: response}}

              {:error, decode_error} ->
                {:error, {:json_decode, decode_error}}
            end

          {:ok, %Finch.Response{status: status, body: body}} ->
            {:error, {:http_error, status, body}}

          {:error, reason} ->
            {:error, {:request_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:file_read, reason}}
    end
  end

  @doc """
  Creates a fine-tuning job with OpenAI.
  """
  def create_fine_tuning_job(training_file_id, model, api_key, opts \\ []) do
    url = "#{@base_url}/fine_tuning/jobs"

    # Build request body
    body = %{
      training_file: training_file_id,
      model: model
    }

    # Add optional parameters
    body =
      opts
      |> Enum.reduce(body, fn
        {:hyperparameters, hyperparams}, acc -> Map.put(acc, :hyperparameters, hyperparams)
        {:suffix, suffix}, acc -> Map.put(acc, :suffix, suffix)
        {:validation_file, file_id}, acc -> Map.put(acc, :validation_file, file_id)
        _, acc -> acc
      end)

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"OpenAI-Beta", "assistants=v2"}
    ]

    case Finch.build(:post, url, headers, Jason.encode!(body))
         |> Finch.request(ViralEngine.Finch, receive_timeout: @default_timeout) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"id" => job_id} = response} ->
            {:ok, %{job_id: job_id, response: response}}

          {:error, decode_error} ->
            {:error, {:json_decode, decode_error}}
        end

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Retrieves the status of a fine-tuning job.
  """
  def get_fine_tuning_job(job_id, api_key) do
    url = "#{@base_url}/fine_tuning/jobs/#{job_id}"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"OpenAI-Beta", "assistants=v2"}
    ]

    case Finch.build(:get, url, headers)
         |> Finch.request(ViralEngine.Finch, receive_timeout: @default_timeout) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, response} ->
            {:ok, response}

          {:error, decode_error} ->
            {:error, {:json_decode, decode_error}}
        end

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Lists fine-tuning jobs with optional filtering.
  """
  def list_fine_tuning_jobs(api_key, opts \\ []) do
    url = "#{@base_url}/fine_tuning/jobs"

    # Add query parameters
    query_params =
      opts
      |> Enum.reduce([], fn
        {:after, after_id}, acc -> [{"after", after_id} | acc]
        {:limit, limit}, acc -> [{"limit", to_string(limit)} | acc]
        _, acc -> acc
      end)

    url = if query_params != [], do: url <> "?" <> URI.encode_query(query_params), else: url

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"OpenAI-Beta", "assistants=v2"}
    ]

    case Finch.build(:get, url, headers)
         |> Finch.request(ViralEngine.Finch, receive_timeout: @default_timeout) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, response} ->
            {:ok, response}

          {:error, decode_error} ->
            {:error, {:json_decode, decode_error}}
        end

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Cancels a fine-tuning job.
  """
  def cancel_fine_tuning_job(job_id, api_key) do
    url = "#{@base_url}/fine_tuning/jobs/#{job_id}/cancel"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"OpenAI-Beta", "assistants=v2"}
    ]

    case Finch.build(:post, url, headers, "{}")
         |> Finch.request(ViralEngine.Finch, receive_timeout: @default_timeout) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, response} ->
            {:ok, response}

          {:error, decode_error} ->
            {:error, {:json_decode, decode_error}}
        end

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Retrieves events for a fine-tuning job.
  """
  def get_fine_tuning_events(job_id, api_key, opts \\ []) do
    url = "#{@base_url}/fine_tuning/jobs/#{job_id}/events"

    # Add query parameters
    query_params =
      opts
      |> Enum.reduce([], fn
        {:after, after_id}, acc -> [{"after", after_id} | acc]
        {:limit, limit}, acc -> [{"limit", to_string(limit)} | acc]
        _, acc -> acc
      end)

    url = if query_params != [], do: url <> "?" <> URI.encode_query(query_params), else: url

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"OpenAI-Beta", "assistants=v2"}
    ]

    case Finch.build(:get, url, headers)
         |> Finch.request(ViralEngine.Finch, receive_timeout: @default_timeout) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, response} ->
            {:ok, response}

          {:error, decode_error} ->
            {:error, {:json_decode, decode_error}}
        end

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Calculates the estimated cost of a fine-tuning job based on token counts.
  """
  def calculate_cost(model, training_tokens, opts \\ []) do
    # OpenAI fine-tuning pricing (as of 2024)
    # These are approximate and should be verified against current pricing
    pricing = %{
      "gpt-3.5-turbo" => %{
        # $0.008 per 1K tokens
        training_per_1k_tokens: 0.008,
        # $0.003 per 1K tokens for fine-tuned usage
        input_per_1k_tokens: 0.003,
        # $0.006 per 1K tokens for fine-tuned usage
        output_per_1k_tokens: 0.006
      },
      "gpt-4" => %{
        # $0.03 per 1K tokens
        training_per_1k_tokens: 0.03,
        # $0.03 per 1K tokens for fine-tuned usage
        input_per_1k_tokens: 0.03,
        # $0.06 per 1K tokens for fine-tuned usage
        output_per_1k_tokens: 0.06
      },
      "gpt-4-turbo-preview" => %{
        # $0.008 per 1K tokens
        training_per_1k_tokens: 0.008,
        # $0.01 per 1K tokens for fine-tuned usage
        input_per_1k_tokens: 0.01,
        # $0.03 per 1K tokens for fine-tuned usage
        output_per_1k_tokens: 0.03
      }
    }

    case Map.get(pricing, model) do
      nil ->
        {:error, :unsupported_model}

      model_pricing ->
        # Convert training_tokens to Decimal and calculate training cost
        training_tokens_decimal = Decimal.new(training_tokens)
        thousand = Decimal.new(1000)

        training_cost =
          training_tokens_decimal
          |> Decimal.div(thousand)
          |> Decimal.mult(Decimal.from_float(model_pricing.training_per_1k_tokens))

        # Estimate usage costs (rough approximation) - only if explicitly requested
        estimated_input_tokens = Keyword.get(opts, :estimated_input_tokens, 0)
        estimated_output_tokens = Keyword.get(opts, :estimated_output_tokens, 0)

        input_cost =
          estimated_input_tokens
          |> trunc()
          |> Decimal.new()
          |> Decimal.div(thousand)
          |> Decimal.mult(Decimal.from_float(model_pricing.input_per_1k_tokens))

        output_cost =
          estimated_output_tokens
          |> trunc()
          |> Decimal.new()
          |> Decimal.div(thousand)
          |> Decimal.mult(Decimal.from_float(model_pricing.output_per_1k_tokens))

        total_cost = Decimal.add(training_cost, Decimal.add(input_cost, output_cost))

        {:ok,
         %{
           training_cost: training_cost,
           input_cost: input_cost,
           output_cost: output_cost,
           total_cost: total_cost,
           currency: "USD"
         }}
    end
  end

  @doc """
  Extracts token counts and cost information from a completed fine-tuning job response.
  """
  def extract_job_cost_info(job_response) do
    case job_response do
      %{"trained_tokens" => trained_tokens, "model" => model} ->
        case calculate_cost(model, trained_tokens) do
          {:ok, cost_info} ->
            {:ok, cost_info}

          {:error, reason} ->
            {:error, reason}
        end

      _ ->
        {:error, :missing_required_fields}
    end
  end
end
