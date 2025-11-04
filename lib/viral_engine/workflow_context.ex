defmodule ViralEngine.WorkflowContext do
  require Logger
  alias ViralEngine.{Workflow, Repo, OrganizationContext}
  import Ecto.Query

  @sentiment_keywords %{
    positive: [
      "good",
      "great",
      "excellent",
      "amazing",
      "wonderful",
      "fantastic",
      "love",
      "like",
      "happy",
      "satisfied"
    ],
    negative: [
      "bad",
      "terrible",
      "awful",
      "horrible",
      "hate",
      "dislike",
      "angry",
      "frustrated",
      "disappointed",
      "poor"
    ]
  }

  def get_workflow_state(workflow_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      case Repo.get_by(Workflow, id: workflow_id, tenant_id: tenant_id) do
        nil -> {:error, :not_found}
        workflow -> {:ok, workflow.state}
      end
    else
      {:error, :no_tenant_context}
    end
  end

  def update_workflow_state(workflow_id, _new_state) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.transaction(fn ->
        case Repo.get_by(Workflow, id: workflow_id, tenant_id: tenant_id) do
          nil ->
            Repo.rollback(:not_found)

          workflow ->
            if workflow.status == "awaiting_approval" do
              gate_id = workflow.state["awaiting_gate"]
              gate = Enum.find(workflow.approval_gates, &(&1["id"] == gate_id))

              if gate && gate["timeout_hours"] do
                paused_at_naive = workflow.state["paused_at"] || workflow.updated_at

                paused_at =
                  case paused_at_naive do
                    %DateTime{} -> paused_at_naive
                    %NaiveDateTime{} -> DateTime.from_naive!(paused_at_naive, "Etc/UTC")
                  end

                timeout_hours = gate["timeout_hours"]
                timeout_threshold = DateTime.add(paused_at, timeout_hours * 3600, :second)

                if DateTime.compare(DateTime.utc_now(), timeout_threshold) == :gt do
                  # Auto-reject due to timeout
                  approval_record = %{
                    gate_id: gate_id,
                    decision: "timed_out",
                    user_id: "system",
                    comments: "Auto-rejected due to timeout",
                    timestamp: DateTime.utc_now()
                  }

                  new_history = workflow.approval_history ++ [approval_record]

                  new_state =
                    Map.merge(workflow.state, %{
                      "timed_out" => true,
                      "timed_out_at" => DateTime.utc_now()
                    })

                  changeset =
                    Workflow.changeset(workflow, %{
                      status: "timed_out",
                      state: new_state,
                      approval_history: new_history,
                      version: workflow.version + 1
                    })

                  case Repo.update(changeset) do
                    {:ok, updated_workflow} -> {:timed_out, updated_workflow}
                    {:error, changeset} -> Repo.rollback(changeset)
                  end
                else
                  :not_timed_out
                end
              else
                :no_timeout_configured
              end
            else
              :not_awaiting_approval
            end
        end
      end)
    else
      {:error, :no_tenant_context}
    end
  end

  def list_workflow_versions(workflow_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      from(w in Workflow,
        where: w.id == ^workflow_id and w.tenant_id == ^tenant_id,
        order_by: [desc: w.version]
      )
      |> Repo.all()
    else
      []
    end
  end

  def create_workflow(name, initial_state) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      changeset =
        Workflow.changeset(%Workflow{}, %{
          tenant_id: tenant_id,
          name: name,
          state: initial_state
        })

      Repo.insert(changeset)
    else
      {:error, :no_tenant_context}
    end
  end

  # Condition Evaluators

  def evaluate_condition(
        %{"type" => "sentiment", "text" => text, "threshold" => threshold},
        _context
      ) do
    sentiment_score = analyze_sentiment(text)
    sentiment_score >= threshold
  end

  def evaluate_condition(
        %{"type" => "confidence", "value" => value, "threshold" => threshold},
        _context
      ) do
    value >= threshold
  end

  def evaluate_condition(
        %{"type" => "text_match", "text" => text, "pattern" => pattern},
        _context
      ) do
    String.contains?(text, pattern)
  end

  def evaluate_condition(
        %{"type" => "regex_match", "text" => text, "pattern" => pattern},
        _context
      ) do
    Regex.match?(~r/#{pattern}/, text)
  end

  def evaluate_condition(
        %{"type" => "numeric_range", "value" => value, "min" => min, "max" => max},
        _context
      ) do
    value >= min && value <= max
  end

  def evaluate_condition(%{"type" => "boolean", "value" => value}, _context) do
    value
  end

  def evaluate_condition(_condition, _context), do: false

  # Sentiment Analysis (simple keyword-based)
  defp analyze_sentiment(text) do
    text_lower = String.downcase(text)

    positive_count = Enum.count(@sentiment_keywords.positive, &String.contains?(text_lower, &1))
    negative_count = Enum.count(@sentiment_keywords.negative, &String.contains?(text_lower, &1))

    total_words = String.split(text) |> length()
    score = (positive_count - negative_count) / max(total_words, 1)
    # Normalize to 0-1 range
    max(0.0, min(1.0, (score + 1.0) / 2.0))
  end

  # Routing Logic

  def evaluate_routing_rules(workflow_id, context_data) when is_integer(workflow_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      case Repo.get_by(Workflow, id: workflow_id, tenant_id: tenant_id) do
        nil -> {:error, :not_found}
        workflow -> evaluate_routing_rules(workflow.routing_rules, context_data)
      end
    else
      {:error, :no_tenant_context}
    end
  end

  def evaluate_routing_rules(rules, context_data) when is_list(rules) do
    Enum.find_value(rules, {:default, nil}, fn rule ->
      if evaluate_rule_conditions(rule["conditions"] || [], context_data) do
        {rule["action"] || "continue", rule["next_step"]}
      else
        false
      end
    end)
  end

  def evaluate_routing_rules(_rules, _context_data), do: {:default, nil}

  defp evaluate_rule_conditions(conditions, context_data) do
    Enum.all?(conditions, fn condition ->
      evaluate_condition(condition, context_data)
    end)
  end

  def advance_workflow(workflow_id, context_data) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      Repo.transaction(fn ->
        case Repo.get_by(Workflow, id: workflow_id, tenant_id: tenant_id) do
          nil ->
            Repo.rollback(:not_found)

          workflow ->
            {action, next_step} = evaluate_routing_rules(workflow.routing_rules, context_data)

            new_state =
              Map.merge(workflow.state, %{
                "last_action" => action,
                "next_step" => next_step,
                "context_data" => context_data,
                "timestamp" => DateTime.utc_now()
              })

            changeset =
              Workflow.changeset(workflow, %{
                state: new_state,
                version: workflow.version + 1
              })

            case Repo.update(changeset) do
              {:ok, updated_workflow} -> {action, next_step, updated_workflow}
              {:error, changeset} -> Repo.rollback(changeset)
            end
        end
      end)
    else
      {:error, :no_tenant_context}
    end
  end

  def add_routing_rule(workflow_id, rule) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          new_rules = workflow.routing_rules ++ [rule]

          changeset =
            Workflow.changeset(workflow, %{
              routing_rules: new_rules,
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} -> updated_workflow
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  def add_condition(workflow_id, condition) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          new_conditions = workflow.conditions ++ [condition]

          changeset =
            Workflow.changeset(workflow, %{
              conditions: new_conditions,
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} -> updated_workflow
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  # Approval Gate Functions

  def define_approval_gate(workflow_id, gate_config) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          new_gates = workflow.approval_gates ++ [gate_config]

          changeset =
            Workflow.changeset(workflow, %{
              approval_gates: new_gates,
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} -> updated_workflow
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  def pause_workflow(workflow_id, gate_id, reason \\ nil) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          # Find the gate configuration
          gate = Enum.find(workflow.approval_gates, &(&1["id"] == gate_id))

          if gate do
            # Send notification webhook if configured
            if gate["webhook_url"] do
              send_notification_webhook(gate["webhook_url"], %{
                workflow_id: workflow_id,
                gate_id: gate_id,
                status: "awaiting_approval",
                reason: reason,
                workflow_name: workflow.name,
                paused_at: DateTime.utc_now()
              })
            end

            changeset =
              Workflow.changeset(workflow, %{
                status: "awaiting_approval",
                state: Map.put(workflow.state, "awaiting_gate", gate_id),
                version: workflow.version + 1
              })

            case Repo.update(changeset) do
              {:ok, updated_workflow} -> updated_workflow
              {:error, changeset} -> Repo.rollback(changeset)
            end
          else
            Repo.rollback(:gate_not_found)
          end
      end
    end)
  end

  def approve_workflow(workflow_id, gate_id, decision, user_id, comments \\ nil) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          # Validate decision
          unless decision in ["approved", "rejected"] do
            Repo.rollback(:invalid_decision)
          end

          # Check if workflow is awaiting approval
          unless workflow.status == "awaiting_approval" do
            Repo.rollback(:not_awaiting_approval)
          end

          # Check if the correct gate is being approved
          awaiting_gate = workflow.state["awaiting_gate"]

          unless awaiting_gate == gate_id do
            Repo.rollback(:wrong_gate)
          end

          # Create approval record
          approval_record = %{
            gate_id: gate_id,
            decision: decision,
            user_id: user_id,
            comments: comments,
            timestamp: DateTime.utc_now()
          }

          new_history = workflow.approval_history ++ [approval_record]

          new_status = if decision == "approved", do: "approved", else: "rejected"

          new_state =
            Map.merge(workflow.state, %{
              "last_decision" => decision,
              "approved_by" => user_id,
              "approved_at" => DateTime.utc_now()
            })

          changeset =
            Workflow.changeset(workflow, %{
              status: new_status,
              state: new_state,
              approval_history: new_history,
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} -> {decision, updated_workflow}
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  def check_timeout(workflow_id) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          if workflow.status == "awaiting_approval" do
            gate_id = workflow.state["awaiting_gate"]
            gate = Enum.find(workflow.approval_gates, &(&1["id"] == gate_id))

            if gate && gate["timeout_hours"] do
              paused_at_naive = workflow.state["paused_at"] || workflow.updated_at

              paused_at =
                case paused_at_naive do
                  %DateTime{} -> paused_at_naive
                  %NaiveDateTime{} -> DateTime.from_naive!(paused_at_naive, "Etc/UTC")
                end

              timeout_hours = gate["timeout_hours"]
              timeout_threshold = DateTime.add(paused_at, timeout_hours * 3600, :second)

              if DateTime.compare(DateTime.utc_now(), timeout_threshold) == :gt do
                # Auto-reject due to timeout
                approval_record = %{
                  gate_id: gate_id,
                  decision: "timed_out",
                  user_id: "system",
                  comments: "Auto-rejected due to timeout",
                  timestamp: DateTime.utc_now()
                }

                new_history = workflow.approval_history ++ [approval_record]

                new_state =
                  Map.merge(workflow.state, %{
                    "timed_out" => true,
                    "timed_out_at" => DateTime.utc_now()
                  })

                changeset =
                  Workflow.changeset(workflow, %{
                    status: "timed_out",
                    state: new_state,
                    approval_history: new_history,
                    version: workflow.version + 1
                  })

                case Repo.update(changeset) do
                  {:ok, updated_workflow} -> {:timed_out, updated_workflow}
                  {:error, changeset} -> Repo.rollback(changeset)
                end
              else
                :not_timed_out
              end
            else
              :no_timeout_configured
            end
          else
            :not_awaiting_approval
          end
      end
    end)
  end

  # Parallel Execution Functions

  def define_parallel_group(workflow_id, group_config) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          new_groups = workflow.parallel_groups ++ [group_config]

          changeset =
            Workflow.changeset(workflow, %{
              parallel_groups: new_groups,
              execution_mode: "parallel",
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} -> updated_workflow
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  def execute_parallel_tasks(workflow_id, task_configs) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          # Execute tasks in parallel using Task.async_stream
          max_concurrency = get_max_concurrency(workflow.parallel_groups)

          results =
            Task.async_stream(
              task_configs,
              fn task_config ->
                execute_single_task(task_config)
              end,
              max_concurrency: max_concurrency,
              timeout: :infinity
            )
            |> Enum.map(fn {:ok, result} -> result end)
            |> Enum.into(%{}, fn {task_id, result} -> {task_id, result} end)

          # Update workflow with aggregated results
          new_aggregation = Map.merge(workflow.results_aggregation, results)

          changeset =
            Workflow.changeset(workflow, %{
              results_aggregation: new_aggregation,
              state: Map.put(workflow.state, "parallel_execution_completed", true),
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} -> {results, updated_workflow}
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  def execute_parallel_tasks_with_failure_handling(
        workflow_id,
        task_configs,
        failure_mode \\ :continue
      ) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          max_concurrency = get_max_concurrency(workflow.parallel_groups)

          # Execute tasks with failure handling
          {results, failures} =
            Task.async_stream(
              task_configs,
              fn task_config ->
                case execute_single_task(task_config) do
                  {:ok, result} -> {:ok, {task_config["id"], result}}
                  {:error, reason} -> {:error, {task_config["id"], reason}}
                end
              end,
              max_concurrency: max_concurrency,
              timeout: :infinity
            )
            |> Enum.reduce({%{}, []}, fn
              {:ok, {:ok, {task_id, result}}}, {results_acc, failures_acc} ->
                {Map.put(results_acc, task_id, result), failures_acc}

              {:ok, {:error, {task_id, reason}}}, {results_acc, failures_acc} ->
                {results_acc, [{task_id, reason} | failures_acc]}

              {:error, reason}, {results_acc, failures_acc} ->
                {results_acc, [{:unknown, reason} | failures_acc]}
            end)

          # Handle failures based on mode
          case {failure_mode, failures} do
            {:continue, _} ->
              # Log failures but continue
              Enum.each(failures, fn {task_id, reason} ->
                Logger.warning("Task #{task_id} failed but continuing: #{inspect(reason)}")
              end)

              # Update workflow with results
              new_aggregation = Map.merge(workflow.results_aggregation, results)

              new_state =
                Map.merge(workflow.state, %{
                  "parallel_execution_completed" => true,
                  "task_failures" =>
                    Enum.map(failures, fn {task_id, reason} -> [task_id, reason] end)
                })

              changeset =
                Workflow.changeset(workflow, %{
                  results_aggregation: new_aggregation,
                  state: new_state,
                  version: workflow.version + 1
                })

              case Repo.update(changeset) do
                {:ok, updated_workflow} -> {{:ok, results}, updated_workflow}
                {:error, changeset} -> Repo.rollback(changeset)
              end

            {:abort, [_ | _]} ->
              # Abort on first failure
              Logger.error(
                "Aborting parallel execution due to task failures: #{inspect(failures)}"
              )

              new_state =
                Map.merge(workflow.state, %{
                  "parallel_execution_failed" => true,
                  "task_failures" => failures
                })

              changeset =
                Workflow.changeset(workflow, %{
                  status: "failed",
                  state: new_state,
                  version: workflow.version + 1
                })

              case Repo.update(changeset) do
                {:ok, updated_workflow} -> {{:error, :aborted_due_to_failures}, updated_workflow}
                {:error, changeset} -> Repo.rollback(changeset)
              end

            {:abort, []} ->
              # No failures, proceed normally
              new_aggregation = Map.merge(workflow.results_aggregation, results)
              new_state = Map.put(workflow.state, "parallel_execution_completed", true)

              changeset =
                Workflow.changeset(workflow, %{
                  results_aggregation: new_aggregation,
                  state: new_state,
                  version: workflow.version + 1
                })

              case Repo.update(changeset) do
                {:ok, updated_workflow} -> {{:ok, results}, updated_workflow}
                {:error, changeset} -> Repo.rollback(changeset)
              end
          end
      end
    end)
  end

  # Error Handling and Recovery Functions

  def configure_retry(workflow_id, step_id, retry_config) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          new_retry_config = Map.put(workflow.retry_config, step_id, retry_config)

          changeset =
            Workflow.changeset(workflow, %{
              retry_config: new_retry_config,
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} -> updated_workflow
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  def categorize_error(error_reason, workflow_id) do
    case Repo.get(Workflow, workflow_id) do
      nil ->
        {:error, :not_found}

      workflow ->
        # Default categorization logic
        category =
          cond do
            String.contains?(error_reason, "timeout") -> "retryable"
            String.contains?(error_reason, "network") -> "retryable"
            String.contains?(error_reason, "rate_limit") -> "retryable"
            String.contains?(error_reason, "validation") -> "terminal"
            String.contains?(error_reason, "authentication") -> "terminal"
            true -> workflow.error_categories[error_reason] || "retryable"
          end

        {:ok, category}
    end
  end

  def execute_rollback(workflow_id, step_id) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          rollback_step = workflow.rollback_steps[step_id]

          if rollback_step do
            # Execute rollback logic (simplified - in real implementation would be more complex)
            rollback_result = perform_rollback_action(rollback_step)

            # Update workflow state to reflect rollback
            new_state =
              Map.merge(workflow.state, %{
                "last_rollback" => step_id,
                "rollback_timestamp" => DateTime.utc_now(),
                "rollback_result" => rollback_result
              })

            changeset =
              Workflow.changeset(workflow, %{
                state: new_state,
                version: workflow.version + 1
              })

            case Repo.update(changeset) do
              {:ok, updated_workflow} -> {rollback_result, updated_workflow}
              {:error, changeset} -> Repo.rollback(changeset)
            end
          else
            Repo.rollback(:rollback_step_not_found)
          end
      end
    end)
  end

  def send_error_notification(workflow_id, error_details) do
    case Repo.get(Workflow, workflow_id) do
      nil ->
        {:error, :not_found}

      workflow ->
        # Send notifications to configured webhooks
        results =
          Enum.map(workflow.notification_webhooks, fn webhook ->
            send_notification_webhook(webhook["url"], %{
              workflow_id: workflow_id,
              workflow_name: workflow.name,
              error: error_details,
              timestamp: DateTime.utc_now()
            })
          end)

        {:ok, results}
    end
  end

  def retry_from_step(workflow_id, step_id, context \\ %{}) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          retry_config =
            workflow.retry_config[step_id] ||
              %{"max_attempts" => 3, "backoff_strategy" => "exponential"}

          current_attempts = workflow.state["retry_attempts"] || %{}
          attempt_count = Map.get(current_attempts, step_id, 0) + 1

          if attempt_count > retry_config["max_attempts"] do
            Repo.rollback(:max_retries_exceeded)
          end

          # Calculate backoff delay
          delay_ms = calculate_backoff_delay(retry_config["backoff_strategy"], attempt_count)

          # Update workflow state for retry
          new_state =
            Map.merge(workflow.state, %{
              "retrying_step" => step_id,
              "retry_attempt" => attempt_count,
              "retry_scheduled_at" => DateTime.add(DateTime.utc_now(), delay_ms, :millisecond),
              "retry_context" => context
            })

          new_retry_attempts = Map.put(current_attempts, step_id, attempt_count)

          new_state = Map.put(new_state, "retry_attempts", new_retry_attempts)

          # Log error in history
          error_record = %{
            step_id: step_id,
            attempt: attempt_count,
            timestamp: DateTime.utc_now(),
            context: context
          }

          new_error_history = workflow.error_history ++ [error_record]

          changeset =
            Workflow.changeset(workflow, %{
              state: new_state,
              error_history: new_error_history,
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} -> {delay_ms, updated_workflow}
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  def log_workflow_error(workflow_id, step_id, error_reason, context \\ %{}) do
    Repo.transaction(fn ->
      case Repo.get(Workflow, workflow_id) do
        nil ->
          Repo.rollback(:not_found)

        workflow ->
          error_record = %{
            step_id: step_id,
            error_reason: error_reason,
            timestamp: DateTime.utc_now(),
            context: context
          }

          new_error_history = workflow.error_history ++ [error_record]

          changeset =
            Workflow.changeset(workflow, %{
              error_history: new_error_history,
              version: workflow.version + 1
            })

          case Repo.update(changeset) do
            {:ok, updated_workflow} ->
              # Send notifications asynchronously
              Task.start(fn ->
                send_error_notification(workflow_id, error_record)
              end)

              updated_workflow

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
      end
    end)
  end

  # Private helper functions

  defp get_max_concurrency(parallel_groups) do
    # Default to 5 concurrent tasks, or use the minimum max_concurrency from groups
    default_concurrency = 5

    case parallel_groups do
      [] ->
        default_concurrency

      groups ->
        groups
        |> Enum.map(&(&1["max_concurrency"] || default_concurrency))
        |> Enum.min()
    end
  end

  defp execute_single_task(task_config) do
    # Mock task execution - in real implementation, this would call the MCP orchestrator
    task_id = task_config["id"]
    prompt = task_config["prompt"] || "Execute task #{task_id}"

    # Simulate some processing time
    :timer.sleep(Enum.random(100..500))

    # Simulate occasional failures
    if Enum.random(1..10) == 1 do
      {:error, "Simulated task failure for #{task_id}"}
    else
      {:ok,
       %{task_id: task_id, result: "Completed: #{prompt}", execution_time: Enum.random(100..500)}}
    end
  end

  defp send_notification_webhook(url, payload) do
    # Real webhook delivery with Finch
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "ViralEngine-Webhook/1.0"}
    ]

    body = Jason.encode!(payload)

    Logger.info("Sending webhook to #{url}")

    case Finch.build(:post, url, headers, body)
         |> Finch.request(ViralEngine.Finch, receive_timeout: 10_000) do
      {:ok, %Finch.Response{status: status}} when status in 200..299 ->
        Logger.info("Webhook delivered successfully to #{url} (status: #{status})")
        {:ok, :webhook_sent}

      {:ok, %Finch.Response{status: status, body: error_body}} ->
        Logger.warning("Webhook failed with status #{status}: #{error_body}")
        {:error, {:webhook_failed, status}}

      {:error, reason} ->
        Logger.error("Failed to send webhook to #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp perform_rollback_action(rollback_step) do
    # Simplified rollback implementation
    # In real implementation, this would execute specific rollback logic
    Logger.info("Performing rollback action: #{inspect(rollback_step)}")
    {:ok, "Rollback completed for #{rollback_step["action"]}"}
  end

  defp calculate_backoff_delay(strategy, attempt) do
    case strategy do
      # 1s, 2s, 4s, 8s...
      "exponential" -> trunc(:math.pow(2, attempt - 1) * 1000)
      # 1s, 2s, 3s, 4s...
      "linear" -> attempt * 1000
      # Default 1 second
      _ -> 1000
    end
  end
end
