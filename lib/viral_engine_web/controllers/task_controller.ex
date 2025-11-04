defmodule ViralEngineWeb.TaskController do
  use ViralEngineWeb, :controller

  # Deprecated :namespace option - use plug :put_layout instead if needed
  # Set formats for proper rendering
  plug :accepts, ["html", "json"]
  alias ViralEngine.{Task, Repo, AuditLogContext}
  import Ecto.Query
  require Logger

  @rate_limit_table :task_rate_limits
  @max_concurrent_tasks 10

  def create(conn, %{"description" => description, "agent_id" => agent_id, "user_id" => user_id}) do
    # Rate limiting
    if rate_limited?(user_id) do
      conn
      |> put_status(429)
      |> json(%{error: "Rate limit exceeded"})
    else
      # Validate agent_id
      if valid_agent?(agent_id) do
        changeset =
          Task.changeset(%Task{}, %{
            description: description,
            agent_id: agent_id,
            user_id: user_id
          })

        case Repo.insert(changeset) do
          {:ok, task} ->
            # Increment rate limit
            increment_rate_limit(user_id)

            # Log audit event
            AuditLogContext.log_user_action(
              user_id,
              "task_created",
              %{
                task_id: task.id,
                agent_id: agent_id,
                description: String.slice(description, 0..100)
              },
              conn
            )

            # Route to orchestrator (placeholder)
            # ViralEngine.Agents.Orchestrator.route_task(task)

            conn
            |> put_status(201)
            |> json(%{
              task_id: task.id,
              status_url: "/api/tasks/#{task.id}/status"
            })

          {:error, changeset} ->
            conn
            |> put_status(400)
            |> json(%{errors: changeset.errors})
        end
      else
        conn
        |> put_status(400)
        |> json(%{error: "Invalid agent_id"})
      end
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameters"})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Task, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Task not found"})

      task ->
        response = %{
          id: task.id,
          description: task.description,
          agent_id: task.agent_id,
          status: task.status,
          provider: task.provider,
          latency_ms: task.latency_ms,
          tokens_used: task.tokens_used,
          cost: task.cost,
          execution_history: task.execution_history,
          created_at: task.inserted_at,
          updated_at: task.updated_at
        }

        json(conn, response)
    end
  end

  def index(conn, params) do
    page = String.to_integer(params["page"] || "1")
    limit = String.to_integer(params["limit"] || "20")

    offset = (page - 1) * limit

    tasks =
      Repo.all(
        from(t in Task,
          limit: ^limit,
          offset: ^offset,
          order_by: [desc: t.inserted_at]
        )
      )

    total_count = Repo.aggregate(Task, :count, :id)
    total_pages = ceil(total_count / limit)

    response = %{
      tasks:
        Enum.map(tasks, fn task ->
          %{
            id: task.id,
            description: task.description,
            agent_id: task.agent_id,
            status: task.status,
            provider: task.provider,
            latency_ms: task.latency_ms,
            tokens_used: task.tokens_used,
            cost: task.cost,
            created_at: task.inserted_at
          }
        end),
      pagination: %{
        page: page,
        limit: limit,
        total_count: total_count,
        total_pages: total_pages
      }
    }

    json(conn, response)
  end

  @doc """
  Cancel a running or pending task.
  POST /api/tasks/:id/cancel
  """
  def cancel(conn, %{"id" => id, "user_id" => user_id, "reason" => reason}) do
    case Repo.get(Task, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Task not found"})

      task ->
        # Verify task is cancellable
        if task.status in ["pending", "in_progress"] do
          # Send cancellation signal to orchestrator
          GenServer.cast(ViralEngine.Agents.Orchestrator, {:cancel_task, task.id})

          # Update task status
          changeset =
            Task.changeset(task, %{
              status: "cancelled",
              execution_history:
                task.execution_history ++
                  [
                    %{
                      event: "cancelled",
                      timestamp: DateTime.utc_now(),
                      user_id: user_id,
                      reason: reason
                    }
                  ]
            })

          case Repo.update(changeset) do
            {:ok, updated_task} ->
              # Calculate prorated refund (if task was in progress)
              refund_amount = calculate_refund(task)

              # Log audit event
              log_audit_event("task_cancelled", %{
                task_id: task.id,
                user_id: user_id,
                reason: reason,
                refund_amount: refund_amount,
                timestamp: DateTime.utc_now()
              })

              # Publish cancellation event to SSE subscribers
              Phoenix.PubSub.broadcast(
                ViralEngine.PubSub,
                "task:#{task.id}",
                {:task_update, %{status: "cancelled", reason: reason}}
              )

              conn
              |> put_status(200)
              |> json(%{
                task_id: updated_task.id,
                status: "cancelled",
                refund_amount: refund_amount,
                message: "Task cancelled successfully"
              })

            {:error, changeset} ->
              conn
              |> put_status(500)
              |> json(%{error: "Failed to cancel task", details: changeset.errors})
          end
        else
          # Task is not cancellable (already completed, failed, or cancelled)
          conn
          |> put_status(409)
          |> json(%{
            error: "Task cannot be cancelled",
            current_status: task.status
          })
        end
    end
  end

  def cancel(conn, %{"id" => id}) do
    # Default reason if not provided
    cancel(conn, %{"id" => id, "user_id" => "unknown", "reason" => "User requested cancellation"})
  end

  @doc """
  Server-Sent Events endpoint for real-time task progress updates.
  GET /api/tasks/:id/stream
  """
  def stream(conn, %{"id" => id}) do
    case Repo.get(Task, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Task not found"})

      task ->
        # Subscribe to task-specific PubSub channel
        topic = "task:#{task.id}"
        Phoenix.PubSub.subscribe(ViralEngine.PubSub, topic)

        # Set SSE headers
        conn =
          conn
          |> put_resp_content_type("text/event-stream")
          |> put_resp_header("cache-control", "no-cache")
          |> put_resp_header("connection", "keep-alive")
          |> send_chunked(200)

        # Send initial task state
        initial_event =
          format_sse_event("connected", %{
            task_id: task.id,
            status: task.status,
            progress: task.progress || 0,
            provider: task.provider,
            created_at: task.inserted_at
          })

        {:ok, conn} = chunk(conn, initial_event)

        # Start streaming updates
        stream_task_updates(conn, task.id, topic)
    end
  end

  # Private functions

  defp stream_task_updates(conn, task_id, topic) do
    receive do
      {:task_update, update} ->
        event = format_sse_event("progress", update)

        case chunk(conn, event) do
          {:ok, conn} ->
            # Check if task is complete
            if update[:status] in ["completed", "failed", "cancelled"] do
              # Send final event and close
              final_event =
                format_sse_event("complete", %{
                  task_id: task_id,
                  status: update[:status],
                  message: "Task finished"
                })

              chunk(conn, final_event)
              Phoenix.PubSub.unsubscribe(ViralEngine.PubSub, topic)
              conn
            else
              stream_task_updates(conn, task_id, topic)
            end

          {:error, :closed} ->
            Logger.info("SSE connection closed for task #{task_id}")
            Phoenix.PubSub.unsubscribe(ViralEngine.PubSub, topic)
            conn
        end

      {:task_error, error} ->
        event =
          format_sse_event("error", %{
            task_id: task_id,
            error: error
          })

        chunk(conn, event)
        Phoenix.PubSub.unsubscribe(ViralEngine.PubSub, topic)
        conn
    after
      30_000 ->
        # Heartbeat every 30 seconds
        heartbeat = format_sse_event("heartbeat", %{timestamp: DateTime.utc_now()})

        case chunk(conn, heartbeat) do
          {:ok, conn} ->
            stream_task_updates(conn, task_id, topic)

          {:error, :closed} ->
            Logger.info("SSE connection closed during heartbeat for task #{task_id}")
            Phoenix.PubSub.unsubscribe(ViralEngine.PubSub, topic)
            conn
        end
    end
  end

  @doc """
  Stream AI response token-by-token for a task.
  GET /api/tasks/:id/stream-response
  """
  def stream_response(conn, %{"id" => id}) do
    case Repo.get(Task, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Task not found"})

      task ->
        # Setup SSE streaming connection
        conn =
          conn
          |> put_resp_content_type("text/event-stream")
          |> put_resp_header("cache-control", "no-cache")
          |> put_resp_header("connection", "keep-alive")
          |> send_chunked(200)

        # Send initial connected event
        {:ok, conn} =
          chunk(conn, format_sse_event("connected", %{task_id: task.id, status: task.status}))

        # Get provider adapter based on task agent_id
        {adapter_module, prompt} = get_adapter_and_prompt(task)

        # Use Agent for buffer state management
        {:ok, buffer_pid} =
          Agent.start_link(fn ->
            %{
              tokens: [],
              token_count: 0,
              last_send_time: System.monotonic_time(:millisecond)
            }
          end)

        # Stream callback with buffering logic
        callback_fn = fn message ->
          case message do
            {:chunk, text} ->
              # Update buffer atomically
              Agent.update(buffer_pid, fn buffer ->
                updated = %{
                  buffer
                  | tokens: buffer.tokens ++ [text],
                    token_count: buffer.token_count + 1
                }

                # Check if we should send
                if should_send_buffer?(updated) do
                  # Send buffered tokens
                  combined_text = Enum.join(updated.tokens, "")

                  event =
                    format_sse_event("token", %{
                      content: combined_text,
                      tokens: updated.token_count
                    })

                  case chunk(conn, event) do
                    {:ok, _conn} -> :ok
                    {:error, _} -> Logger.warning("Failed to send chunk for task #{task.id}")
                  end

                  # Reset buffer
                  %{
                    tokens: [],
                    token_count: 0,
                    last_send_time: System.monotonic_time(:millisecond)
                  }
                else
                  updated
                end
              end)

            {:done, metadata} ->
              # Flush remaining buffer
              buffer = Agent.get(buffer_pid, & &1)

              if buffer.token_count > 0 do
                combined_text = Enum.join(buffer.tokens, "")

                event =
                  format_sse_event("token", %{content: combined_text, tokens: buffer.token_count})

                chunk(conn, event)
              end

              # Send completion event
              event = format_sse_event("complete", Map.merge(metadata, %{task_id: task.id}))
              chunk(conn, event)

              # Cleanup
              Agent.stop(buffer_pid)

            {:error, reason} ->
              event = format_sse_event("error", %{task_id: task.id, error: inspect(reason)})
              chunk(conn, event)

              # Cleanup
              Agent.stop(buffer_pid)
          end
        end

        # Start streaming from adapter
        case adapter_module.chat_completion_stream(prompt, callback_fn) do
          {:ok, :streaming_complete} ->
            Logger.info("Streaming completed successfully for task #{task.id}")
            conn

          {:error, reason} ->
            Logger.error("Streaming failed for task #{task.id}: #{inspect(reason)}")
            error_event = format_sse_event("error", %{task_id: task.id, error: inspect(reason)})
            chunk(conn, error_event)
            conn
        end
    end
  end

  defp get_adapter_and_prompt(task) do
    # Map agent_id to adapter module
    adapter_module =
      case task.agent_id do
        "gpt_4o" -> ViralEngine.Integration.OpenAIAdapter
        "llama_3_1" -> ViralEngine.Integration.GroqAdapter
        # Default to OpenAI
        _ -> ViralEngine.Integration.OpenAIAdapter
      end

    prompt = task.description || "Hello"
    {adapter_module, prompt}
  end

  defp should_send_buffer?(buffer) do
    # Send every 10 tokens OR every 100ms, whichever comes first
    token_threshold = buffer.token_count >= 10
    time_threshold = System.monotonic_time(:millisecond) - buffer.last_send_time >= 100

    token_threshold or time_threshold
  end

  defp format_sse_event(event_type, data) do
    json_data = Jason.encode!(data)
    "event: #{event_type}\ndata: #{json_data}\n\n"
  end

  defp calculate_refund(task) do
    # Calculate prorated refund based on task progress
    # If task was in progress, refund a percentage based on time/progress
    case task.status do
      "in_progress" ->
        # Refund 50% for cancelled in-progress tasks
        (task.cost || 0.0) * 0.5

      "pending" ->
        # Full refund for pending tasks
        task.cost || 0.0

      _ ->
        0.0
    end
  end

  defp log_audit_event(event_type, metadata) do
    Logger.info("Audit Event: #{event_type}", metadata: metadata)

    # Store audit log in database via AuditLogContext
    AuditLogContext.log_system_event(event_type, metadata)
    :ok
  end

  defp valid_agent?(agent_id) do
    agent_id in ["gpt_4o", "llama_3_1", "sonar_large_online"]
  end

  defp rate_limited?(user_id) do
    table = :ets.whereis(@rate_limit_table)

    if table == :undefined do
      :ets.new(@rate_limit_table, [:set, :public, :named_table])
      false
    else
      case :ets.lookup(@rate_limit_table, user_id) do
        [{^user_id, count}] -> count >= @max_concurrent_tasks
        [] -> false
      end
    end
  end

  defp increment_rate_limit(user_id) do
    table = :ets.whereis(@rate_limit_table)

    if table == :undefined do
      :ets.new(@rate_limit_table, [:set, :public, :named_table])
    end

    case :ets.lookup(@rate_limit_table, user_id) do
      [{^user_id, count}] ->
        :ets.insert(@rate_limit_table, {user_id, count + 1})

      [] ->
        :ets.insert(@rate_limit_table, {user_id, 1})
    end
  end
end
