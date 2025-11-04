defmodule ViralEngineWeb.WebhooksController do
  @moduledoc """
  Controller for managing webhook configurations.
  """

  use ViralEngineWeb, :controller
  alias ViralEngine.WebhookContext
  require Logger

  @doc """
  Create a new webhook.
  POST /api/webhooks
  """
  def create(conn, %{"url" => url, "event_types" => event_types, "user_id" => user_id} = params) do
    attrs = %{
      user_id: user_id,
      url: url,
      event_types: event_types,
      description: Map.get(params, "description")
    }

    case WebhookContext.create_webhook(attrs) do
      {:ok, webhook} ->
        conn
        |> put_status(201)
        |> json(%{
          webhook_id: webhook.id,
          url: webhook.url,
          event_types: webhook.event_types,
          is_active: webhook.is_active,
          secret: webhook.secret,
          created_at: webhook.inserted_at
        })

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

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameters: url, event_types, user_id"})
  end

  @doc """
  List webhooks for a user.
  GET /api/webhooks?user_id=123
  """
  def index(conn, %{"user_id" => user_id}) do
    webhooks = WebhookContext.list_webhooks(user_id)

    response = Enum.map(webhooks, fn webhook ->
      %{
        id: webhook.id,
        url: webhook.url,
        event_types: webhook.event_types,
        is_active: webhook.is_active,
        description: webhook.description,
        created_at: webhook.inserted_at
      }
    end)

    json(conn, %{webhooks: response})
  end

  def index(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameter: user_id"})
  end

  @doc """
  Get a single webhook.
  GET /api/webhooks/:id
  """
  def show(conn, %{"id" => id}) do
    case WebhookContext.get_webhook(id) do
      {:ok, webhook} ->
        json(conn, %{
          id: webhook.id,
          url: webhook.url,
          event_types: webhook.event_types,
          is_active: webhook.is_active,
          description: webhook.description,
          secret: webhook.secret,
          created_at: webhook.inserted_at
        })

      {:error, :webhook_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Webhook not found"})
    end
  end

  @doc """
  Update a webhook.
  PUT /api/webhooks/:id
  """
  def update(conn, %{"id" => id} = params) do
    case WebhookContext.get_webhook(id) do
      {:ok, webhook} ->
        attrs = Map.take(params, ["url", "event_types", "is_active", "description"])

        case WebhookContext.update_webhook(webhook, attrs) do
          {:ok, updated_webhook} ->
            json(conn, %{
              webhook_id: updated_webhook.id,
              url: updated_webhook.url,
              event_types: updated_webhook.event_types,
              is_active: updated_webhook.is_active
            })

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

      {:error, :webhook_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Webhook not found"})
    end
  end

  @doc """
  Delete (deactivate) a webhook.
  DELETE /api/webhooks/:id
  """
  def delete(conn, %{"id" => id}) do
    case WebhookContext.get_webhook(id) do
      {:ok, webhook} ->
        case WebhookContext.delete_webhook(webhook) do
          {:ok, _} ->
            json(conn, %{message: "Webhook deleted successfully"})

          {:error, _} ->
            conn
            |> put_status(500)
            |> json(%{error: "Failed to delete webhook"})
        end

      {:error, :webhook_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Webhook not found"})
    end
  end

  @doc """
  Test a webhook by sending a test payload.
  POST /api/webhooks/:id/test
  """
  def test(conn, %{"id" => id}) do
    case WebhookContext.get_webhook(id) do
      {:ok, webhook} ->
        case WebhookContext.test_webhook(webhook) do
          {:ok, :delivered} ->
            json(conn, %{
              message: "Test webhook delivered successfully",
              webhook_id: webhook.id
            })

          {:error, reason} ->
            conn
            |> put_status(422)
            |> json(%{
              error: "Test webhook delivery failed",
              reason: inspect(reason)
            })
        end

      {:error, :webhook_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Webhook not found"})
    end
  end

  @doc """
  Get delivery history for a webhook.
  GET /api/webhooks/:id/deliveries
  """
  def deliveries(conn, %{"id" => id} = params) do
    page = String.to_integer(params["page"] || "1")
    limit = String.to_integer(params["limit"] || "50")
    offset = (page - 1) * limit

    result = WebhookContext.get_delivery_history(id, limit: limit, offset: offset)

    json(conn, result)
  end
end
