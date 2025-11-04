defmodule ViralEngine.BatchContext do
  @moduledoc """
  Context module for batch task operations with concurrency control and result aggregation.
  """

  import Ecto.Query
  alias ViralEngine.{Batch, Repo}
  alias ViralEngine.{AuditLogContext, WebhookContext}
  alias ViralEngine.Task, as: VETask
  require Logger

  @doc """
  Creates a new batch with tasks.
  """
  def create_batch(attrs) do
    changeset = Batch.changeset(%Batch{}, attrs)

    case Repo.insert(changeset) do
      {:ok, batch} ->
        Logger.info("Created batch #{batch.id} with #{batch.total_count} tasks")

        # Log audit event
        AuditLogContext.log_system_event("batch_created", %{
          batch_id: batch.id,
          user_id: batch.user_id,
          total_count: batch.total_count
        })

        {:ok, batch}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Executes a batch by processing all tasks with concurrency control.
  """
  def execute_batch(batch_id) do
    case Repo.get(Batch, batch_id) do
      nil ->
        {:error, :batch_not_found}

      batch ->
        if batch.status != "pending" do
          {:error, :batch_already_started}
        else
          # Update status to running
          update_batch_status(batch, "running")

          # Process tasks with concurrency limit
          tasks = Map.get(batch.tasks, "items", [])

          Task.async_stream(
            tasks,
            fn task_def -> process_batch_task(batch, task_def) end,
            max_concurrency: batch.concurrency_limit,
            timeout: 300_000,
            on_timeout: :kill_task
          )
          |> Enum.to_list()

          # Reload batch to get final counts
          batch = Repo.get!(Batch, batch_id)

          # Update final status
          final_status =
            if batch.completed_count == batch.total_count, do: "completed", else: "failed"

          update_batch_status(batch, final_status)

          # Trigger webhook notification
          event_type = if final_status == "completed", do: "batch.completed", else: "batch.failed"

          WebhookContext.trigger_webhook(event_type, %{
            batch_id: batch.id,
            user_id: batch.user_id,
            status: final_status,
            total_count: batch.total_count,
            completed_count: batch.completed_count,
            error_count: batch.error_count,
            timestamp: DateTime.utc_now()
          })

          {:ok, batch}
        end
    end
  end

  @doc """
  Cancels a running batch.
  """
  def cancel_batch(batch_id, user_id) do
    case Repo.get(Batch, batch_id) do
      nil ->
        {:error, :batch_not_found}

      batch ->
        if batch.status in ["pending", "running"] do
          changeset = Batch.changeset(batch, %{status: "cancelled"})

          case Repo.update(changeset) do
            {:ok, updated_batch} ->
              Logger.info("Batch #{batch_id} cancelled by user #{user_id}")

              # Log audit event
              AuditLogContext.log_system_event("batch_cancelled", %{
                batch_id: batch_id,
                user_id: user_id,
                completed_count: batch.completed_count,
                total_count: batch.total_count
              })

              # Trigger webhook notification
              WebhookContext.trigger_webhook("batch.cancelled", %{
                batch_id: batch_id,
                user_id: user_id,
                completed_count: batch.completed_count,
                total_count: batch.total_count,
                timestamp: DateTime.utc_now()
              })

              {:ok, updated_batch}

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :batch_not_cancellable}
        end
    end
  end

  @doc """
  Gets batch status and progress.
  """
  def get_batch(batch_id) do
    case Repo.get(Batch, batch_id) do
      nil -> {:error, :batch_not_found}
      batch -> {:ok, batch}
    end
  end

  @doc """
  Lists batches for a user with pagination.
  """
  def list_batches(user_id, opts \\ []) do
    limit = opts[:limit] || 20
    offset = opts[:offset] || 0

    query =
      from(b in Batch,
        where: b.user_id == ^user_id,
        order_by: [desc: b.inserted_at],
        limit: ^limit,
        offset: ^offset
      )

    batches = Repo.all(query)
    total = count_batches(user_id)

    %{
      batches: batches,
      total: total,
      limit: limit,
      offset: offset,
      has_more: total > offset + limit
    }
  end

  @doc """
  Exports batch results as JSON or CSV.
  """
  def export_results(batch_id, format \\ :json) do
    case Repo.get(Batch, batch_id) do
      nil ->
        {:error, :batch_not_found}

      batch ->
        case format do
          :json ->
            {:ok, Jason.encode!(batch.results)}

          :csv ->
            csv_data = results_to_csv(batch.results)
            {:ok, csv_data}

          _ ->
            {:error, :unsupported_format}
        end
    end
  end

  # Private functions

  defp process_batch_task(batch, task_def) do
    # Create individual task
    task_attrs = %{
      description: task_def["description"],
      agent_id: task_def["agent_id"],
      user_id: batch.user_id,
      batch_id: batch.id
    }

    case create_and_execute_task(task_attrs) do
      {:ok, task_result} ->
        # Increment completed count
        increment_completed_count(batch.id)

        # Store result
        store_task_result(batch.id, task_def["id"] || Ecto.UUID.generate(), task_result)

        {:ok, task_result}

      {:error, reason} ->
        # Increment error count
        increment_error_count(batch.id)

        # Store error
        store_task_error(batch.id, task_def["id"] || Ecto.UUID.generate(), reason)

        {:error, reason}
    end
  end

  defp create_and_execute_task(attrs) do
    # This is a simplified execution - in production, integrate with Orchestrator
    # For now, just create the task record
    changeset = VETask.changeset(%VETask{}, attrs)

    case Repo.insert(changeset) do
      {:ok, task} ->
        {:ok, %{task_id: task.id, status: "completed"}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp increment_completed_count(batch_id) do
    from(b in Batch, where: b.id == ^batch_id)
    |> Repo.update_all(inc: [completed_count: 1])
  end

  defp increment_error_count(batch_id) do
    from(b in Batch, where: b.id == ^batch_id)
    |> Repo.update_all(inc: [error_count: 1])
  end

  defp store_task_result(batch_id, task_id, result) do
    batch = Repo.get!(Batch, batch_id)
    updated_results = Map.put(batch.results, task_id, result)

    changeset = Batch.changeset(batch, %{results: updated_results})
    Repo.update(changeset)
  end

  defp store_task_error(batch_id, task_id, error) do
    batch = Repo.get!(Batch, batch_id)
    updated_results = Map.put(batch.results, task_id, %{error: inspect(error)})

    changeset = Batch.changeset(batch, %{results: updated_results})
    Repo.update(changeset)
  end

  defp update_batch_status(batch, new_status) do
    changeset = Batch.changeset(batch, %{status: new_status})
    Repo.update(changeset)
  end

  defp count_batches(user_id) do
    from(b in Batch, where: b.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  defp results_to_csv(results) do
    headers = "task_id,status,result\n"

    rows =
      Enum.map_join(results, "\n", fn {task_id, result} ->
        status = Map.get(result, :status, "unknown")
        result_str = inspect(result) |> String.replace(",", ";")
        "#{task_id},#{status},\"#{result_str}\""
      end)

    headers <> rows
  end
end
