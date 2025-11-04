defmodule ViralEngine.WebhookContext do
  @moduledoc """
  Context module for webhook notification system with retry mechanism and HMAC signatures.
  """

  import Ecto.Query
  alias ViralEngine.{Webhook, WebhookDelivery, Repo}
  require Logger

  @max_retries 3

  @doc """
  Creates a new webhook configuration.
  """
  def create_webhook(attrs) do
    changeset = Webhook.changeset(%Webhook{}, attrs)

    case Repo.insert(changeset) do
      {:ok, webhook} ->
        Logger.info("Created webhook #{webhook.id} for user #{webhook.user_id}")
        {:ok, webhook}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists webhooks for a user.
  """
  def list_webhooks(user_id) do
    from(w in Webhook, where: w.user_id == ^user_id and w.is_active == true)
    |> Repo.all()
  end

  @doc """
  Gets a single webhook by ID.
  """
  def get_webhook(id) do
    case Repo.get(Webhook, id) do
      nil -> {:error, :webhook_not_found}
      webhook -> {:ok, webhook}
    end
  end

  @doc """
  Updates a webhook configuration.
  """
  def update_webhook(webhook, attrs) do
    changeset = Webhook.changeset(webhook, attrs)
    Repo.update(changeset)
  end

  @doc """
  Deletes (deactivates) a webhook.
  """
  def delete_webhook(webhook) do
    changeset = Webhook.changeset(webhook, %{is_active: false})
    Repo.update(changeset)
  end

  @doc """
  Triggers webhooks for a specific event type.
  """
  def trigger_webhook(event_type, payload) do
    # Find all active webhooks listening to this event type
    webhooks =
      from(w in Webhook,
        where: w.is_active == true and ^event_type in w.event_types
      )
      |> Repo.all()

    # Queue delivery for each webhook
    Enum.each(webhooks, fn webhook ->
      queue_delivery(webhook, event_type, payload)
    end)

    {:ok, length(webhooks)}
  end

  @doc """
  Tests a webhook by sending a test payload.
  """
  def test_webhook(webhook) do
    test_payload = %{
      event_type: "test.webhook",
      test: true,
      timestamp: DateTime.utc_now(),
      webhook_id: webhook.id
    }

    deliver_webhook_sync(webhook, "test.webhook", test_payload)
  end

  @doc """
  Delivers a webhook synchronously (for testing).
  """
  def deliver_webhook_sync(webhook, event_type, payload) do
    delivery = create_delivery_record(webhook.id, event_type, payload)

    case attempt_delivery(webhook, delivery, payload) do
      {:ok, response} ->
        update_delivery_success(delivery, response)
        {:ok, :delivered}

      {:error, reason} ->
        update_delivery_failure(delivery, reason, 1)
        {:error, reason}
    end
  end

  @doc """
  Gets delivery history for a webhook.
  """
  def get_delivery_history(webhook_id, opts \\ []) do
    limit = opts[:limit] || 50
    offset = opts[:offset] || 0

    query =
      from(d in WebhookDelivery,
        where: d.webhook_id == ^webhook_id,
        order_by: [desc: d.inserted_at],
        limit: ^limit,
        offset: ^offset
      )

    deliveries = Repo.all(query)
    total = count_deliveries(webhook_id)

    %{
      deliveries: deliveries,
      total: total,
      limit: limit,
      offset: offset
    }
  end

  # Private functions

  defp queue_delivery(webhook, event_type, payload) do
    delivery = create_delivery_record(webhook.id, event_type, payload)

    # Start background task for delivery with retries
    Task.start(fn -> deliver_with_retry(webhook, delivery, payload, 0) end)
  end

  defp deliver_with_retry(webhook, delivery, payload, attempt) do
    if attempt >= @max_retries do
      Logger.error("Webhook #{webhook.id} delivery failed after #{@max_retries} attempts")
      update_delivery_failure(delivery, "Max retries exceeded", attempt)
    else
      case attempt_delivery(webhook, delivery, payload) do
        {:ok, response} ->
          update_delivery_success(delivery, response)

        {:error, reason} ->
          Logger.warning(
            "Webhook #{webhook.id} delivery failed (attempt #{attempt + 1}): #{inspect(reason)}"
          )

          # Exponential backoff: 1s, 2s, 4s
          backoff_ms = (:math.pow(2, attempt) * 1000) |> round()
          Process.sleep(backoff_ms)

          deliver_with_retry(webhook, delivery, payload, attempt + 1)
      end
    end
  end

  defp attempt_delivery(webhook, delivery, payload) do
    # Generate HMAC signature
    signature = generate_hmac_signature(webhook.secret, payload)

    headers = [
      {"Content-Type", "application/json"},
      {"X-Webhook-Signature", signature},
      {"X-Webhook-ID", to_string(webhook.id)},
      {"X-Event-Type", delivery.event_type},
      {"User-Agent", "ViralEngine-Webhook/1.0"}
    ]

    body = Jason.encode!(payload)

    # Update delivery record with signature
    delivery_changeset =
      WebhookDelivery.changeset(delivery, %{
        signature: signature,
        attempt_count: delivery.attempt_count + 1,
        last_attempt_at: DateTime.utc_now()
      })

    Repo.update(delivery_changeset)

    # Make HTTP request with timeout
    case Finch.build(:post, webhook.url, headers, body)
         |> Finch.request(ViralEngine.Finch, receive_timeout: 10_000) do
      {:ok, %Finch.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, %{status: status, body: response_body}}

      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:error, {:http_error, status, response_body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp generate_hmac_signature(secret, payload) do
    json_payload = Jason.encode!(payload)

    :crypto.mac(:hmac, :sha256, secret, json_payload)
    |> Base.encode16(case: :lower)
  end

  defp create_delivery_record(webhook_id, event_type, payload) do
    changeset =
      WebhookDelivery.changeset(%WebhookDelivery{}, %{
        webhook_id: webhook_id,
        event_type: event_type,
        payload: payload,
        status: "pending"
      })

    case Repo.insert(changeset) do
      {:ok, delivery} -> delivery
      {:error, _} -> %WebhookDelivery{webhook_id: webhook_id}
    end
  end

  defp update_delivery_success(delivery, response) do
    changeset =
      WebhookDelivery.changeset(delivery, %{
        status: "success",
        response_code: response.status,
        response_body: String.slice(response.body, 0..500)
      })

    Repo.update(changeset)
  end

  defp update_delivery_failure(delivery, reason, attempt_count) do
    changeset =
      WebhookDelivery.changeset(delivery, %{
        status: "failed",
        error_message: inspect(reason),
        attempt_count: attempt_count
      })

    Repo.update(changeset)
  end

  defp count_deliveries(webhook_id) do
    from(d in WebhookDelivery, where: d.webhook_id == ^webhook_id)
    |> Repo.aggregate(:count)
  end
end
