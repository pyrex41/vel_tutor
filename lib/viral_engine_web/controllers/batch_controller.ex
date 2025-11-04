defmodule ViralEngineWeb.BatchController do
  @moduledoc """
  Controller for batch task operations.
  """

  use ViralEngineWeb, :controller

  # Deprecated :namespace option - use plug :put_layout instead if needed
  # Set formats for proper rendering
  plug :accepts, ["html", "json"]
  alias ViralEngine.BatchContext
  require Logger

  @doc """
  Create a new batch of tasks.
  POST /api/batches
  """
  def create(conn, %{"name" => name, "tasks" => tasks, "user_id" => user_id} = params) do
    concurrency_limit = Map.get(params, "concurrency_limit", 20)

    attrs = %{
      user_id: user_id,
      name: name,
      tasks: %{"items" => tasks},
      concurrency_limit: concurrency_limit
    }

    case BatchContext.create_batch(attrs) do
      {:ok, batch} ->
        # Start batch execution in background
        Task.start(fn -> BatchContext.execute_batch(batch.id) end)

        conn
        |> put_status(201)
        |> json(%{
          batch_id: batch.id,
          name: batch.name,
          total_count: batch.total_count,
          status: batch.status,
          status_url: "/api/batches/#{batch.id}"
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
    |> json(%{error: "Missing required parameters: name, tasks, user_id"})
  end

  @doc """
  Get batch status and progress.
  GET /api/batches/:id
  """
  def show(conn, %{"id" => id}) do
    case BatchContext.get_batch(id) do
      {:ok, batch} ->
        response = %{
          id: batch.id,
          name: batch.name,
          status: batch.status,
          total_count: batch.total_count,
          completed_count: batch.completed_count,
          error_count: batch.error_count,
          progress_percent: calculate_progress(batch),
          concurrency_limit: batch.concurrency_limit,
          created_at: batch.inserted_at,
          updated_at: batch.updated_at
        }

        json(conn, response)

      {:error, :batch_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Batch not found"})
    end
  end

  @doc """
  List batches for a user.
  GET /api/batches?user_id=123
  """
  def index(conn, %{"user_id" => user_id} = params) do
    page = String.to_integer(params["page"] || "1")
    limit = String.to_integer(params["limit"] || "20")
    offset = (page - 1) * limit

    result = BatchContext.list_batches(user_id, limit: limit, offset: offset)

    json(conn, result)
  end

  def index(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameter: user_id"})
  end

  @doc """
  Cancel a running batch.
  POST /api/batches/:id/cancel
  """
  def cancel(conn, %{"id" => id, "user_id" => user_id}) do
    case BatchContext.cancel_batch(id, user_id) do
      {:ok, batch} ->
        json(conn, %{
          batch_id: batch.id,
          status: batch.status,
          message: "Batch cancelled successfully"
        })

      {:error, :batch_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Batch not found"})

      {:error, :batch_not_cancellable} ->
        conn
        |> put_status(409)
        |> json(%{error: "Batch cannot be cancelled (already completed or cancelled)"})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{errors: changeset.errors})
    end
  end

  def cancel(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameter: user_id"})
  end

  @doc """
  Export batch results as JSON or CSV.
  GET /api/batches/:id/results?format=json|csv
  """
  def export_results(conn, %{"id" => id} = params) do
    format =
      case Map.get(params, "format", "json") do
        "csv" -> :csv
        _ -> :json
      end

    case BatchContext.export_results(id, format) do
      {:ok, data} ->
        content_type = if format == :csv, do: "text/csv", else: "application/json"
        filename = "batch_#{id}_results.#{format}"

        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_resp(200, data)

      {:error, :batch_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Batch not found"})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: inspect(reason)})
    end
  end

  # Private functions

  defp calculate_progress(batch) do
    if batch.total_count > 0 do
      Float.round(batch.completed_count / batch.total_count * 100, 2)
    else
      0.0
    end
  end
end
