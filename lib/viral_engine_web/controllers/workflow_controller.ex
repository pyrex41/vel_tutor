defmodule ViralEngineWeb.WorkflowController do
  use ViralEngineWeb, :controller

  # Deprecated :namespace option - use plug :put_layout instead if needed
  # Set formats for proper rendering
  plug :accepts, ["html", "json"]
  alias ViralEngine.WorkflowContext

  def create(conn, params) do
    name = params["name"]
    initial_state = params["initial_state"] || %{}

    case WorkflowContext.create_workflow(name, initial_state) do
      {:ok, workflow} ->
        conn
        |> put_status(:created)
        |> json(%{
          id: workflow.id,
          name: workflow.name,
          state: workflow.state,
          version: workflow.version
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    case WorkflowContext.get_workflow_state(String.to_integer(id)) do
      {:ok, state} ->
        workflow = WorkflowContext.list_workflow_versions(String.to_integer(id)) |> List.first()

        conn
        |> json(%{
          id: workflow.id,
          name: workflow.name,
          state: state,
          version: workflow.version,
          routing_rules: workflow.routing_rules,
          conditions: workflow.conditions
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})
    end
  end

  def advance(conn, %{"id" => id, "context_data" => context_data}) do
    case WorkflowContext.advance_workflow(String.to_integer(id), context_data) do
      {:ok, {action, next_step, workflow}} ->
        conn
        |> json(%{
          action: action,
          next_step: next_step,
          workflow: %{
            id: workflow.id,
            state: workflow.state,
            version: workflow.version
          }
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def add_rule(conn, %{"id" => id, "rule" => rule}) do
    case WorkflowContext.add_routing_rule(String.to_integer(id), rule) do
      {:ok, workflow} ->
        conn
        |> json(%{
          id: workflow.id,
          routing_rules: workflow.routing_rules,
          version: workflow.version
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def add_condition(conn, %{"id" => id, "condition" => condition}) do
    case WorkflowContext.add_condition(String.to_integer(id), condition) do
      {:ok, workflow} ->
        conn
        |> json(%{
          id: workflow.id,
          conditions: workflow.conditions,
          version: workflow.version
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def visualize(conn, %{"id" => id}) do
    case WorkflowContext.get_workflow_state(String.to_integer(id)) do
      {:ok, _state} ->
        workflow = WorkflowContext.list_workflow_versions(String.to_integer(id)) |> List.first()

        visualization = %{
          workflow: %{
            id: workflow.id,
            name: workflow.name,
            current_state: workflow.state,
            version: workflow.version,
            status: workflow.status,
            execution_mode: workflow.execution_mode
          },
          routing_rules: workflow.routing_rules,
          conditions: workflow.conditions,
          approval_gates: workflow.approval_gates,
          approval_history: workflow.approval_history,
          parallel_groups: workflow.parallel_groups,
          results_aggregation: workflow.results_aggregation,
          graph: build_visualization_graph(workflow)
        }

        conn
        |> json(visualization)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})
    end
  end

  def add_gate(conn, %{"id" => id, "gate" => gate}) do
    case WorkflowContext.define_approval_gate(String.to_integer(id), gate) do
      {:ok, workflow} ->
        conn
        |> json(%{
          id: workflow.id,
          approval_gates: workflow.approval_gates,
          version: workflow.version
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def pause(conn, %{"id" => id, "gate_id" => gate_id} = params) do
    reason = params["reason"]

    case WorkflowContext.pause_workflow(String.to_integer(id), gate_id, reason) do
      {:ok, workflow} ->
        conn
        |> json(%{
          id: workflow.id,
          status: workflow.status,
          awaiting_gate: workflow.state["awaiting_gate"],
          version: workflow.version
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, :gate_not_found} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Approval gate not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def approve(conn, %{"id" => id, "gate_id" => gate_id, "decision" => decision} = params) do
    # TODO: Extract user_id from authentication
    user_id = params["user_id"] || "anonymous"
    comments = params["comments"]

    case WorkflowContext.approve_workflow(
           String.to_integer(id),
           gate_id,
           decision,
           user_id,
           comments
         ) do
      {:ok, {decision_result, workflow}} ->
        conn
        |> json(%{
          id: workflow.id,
          status: workflow.status,
          decision: decision_result,
          approved_by: workflow.state["approved_by"],
          approval_history: workflow.approval_history,
          version: workflow.version
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, :invalid_decision} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid decision. Must be 'approved' or 'rejected'"})

      {:error, :not_awaiting_approval} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Workflow is not awaiting approval"})

      {:error, :wrong_gate} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Wrong approval gate"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def check_timeout(conn, %{"id" => id}) do
    case WorkflowContext.check_timeout(String.to_integer(id)) do
      {:ok, :not_awaiting_approval} ->
        conn
        |> json(%{status: "not_awaiting_approval"})

      {:ok, :not_timed_out} ->
        conn
        |> json(%{status: "not_timed_out"})

      {:ok, :no_timeout_configured} ->
        conn
        |> json(%{status: "no_timeout_configured"})

      {:ok, {:timed_out, workflow}} ->
        conn
        |> json(%{
          status: "timed_out",
          workflow: %{
            id: workflow.id,
            status: workflow.status,
            approval_history: workflow.approval_history,
            version: workflow.version
          }
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def add_parallel_group(conn, %{"id" => id, "group" => group}) do
    case WorkflowContext.define_parallel_group(String.to_integer(id), group) do
      {:ok, workflow} ->
        conn
        |> json(%{
          id: workflow.id,
          parallel_groups: workflow.parallel_groups,
          execution_mode: workflow.execution_mode,
          version: workflow.version
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def execute_parallel(conn, %{"id" => id, "tasks" => tasks} = params) do
    failure_mode =
      case params["failure_mode"] do
        "continue" -> :continue
        "fail_fast" -> :fail_fast
        _ -> :continue
      end

    case WorkflowContext.execute_parallel_tasks_with_failure_handling(
           String.to_integer(id),
           tasks,
           failure_mode
         ) do
      {:ok, {{:ok, results}, workflow}} ->
        conn
        |> json(%{
          status: "success",
          results: results,
          workflow: %{
            id: workflow.id,
            results_aggregation: workflow.results_aggregation,
            state: workflow.state,
            version: workflow.version
          }
        })

      {:ok, {{:error, :aborted_due_to_failures}, workflow}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          status: "aborted",
          error: "Execution aborted due to task failures",
          workflow: %{
            id: workflow.id,
            task_failures: workflow.state["task_failures"],
            status: workflow.status,
            version: workflow.version
          }
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def retry_from_step(conn, %{"id" => id, "step_id" => step_id} = params) do
    context = params["context"] || %{}

    case WorkflowContext.retry_from_step(String.to_integer(id), step_id, context) do
      {:ok, {delay_ms, workflow}} ->
        conn
        |> json(%{
          delay_ms: delay_ms,
          workflow: %{
            id: workflow.id,
            state: workflow.state,
            error_history: workflow.error_history,
            version: workflow.version
          }
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, :max_retries_exceeded} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Maximum retry attempts exceeded"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  defp build_visualization_graph(workflow) do
    nodes = [
      %{id: "start", label: "Start", type: "start"},
      %{id: "current", label: "Current State", type: "state", data: workflow.state}
    ]

    edges = []

    # Add routing rules
    {nodes_with_rules, edges_with_rules} =
      Enum.reduce(workflow.routing_rules, {nodes, edges}, fn rule, {nodes_acc, edges_acc} ->
        rule_id = "rule_#{:erlang.phash2(rule)}"
        rule_node = %{id: rule_id, label: rule["action"] || "continue", type: "rule"}

        next_step = rule["next_step"]
        next_node = if next_step, do: %{id: next_step, label: next_step, type: "step"}, else: nil

        nodes_with_next =
          if next_node, do: nodes_acc ++ [rule_node, next_node], else: nodes_acc ++ [rule_node]

        edges_with_next = edges_acc ++ [%{from: "current", to: rule_id, label: "condition met"}]

        edges_final =
          if next_step,
            do: edges_with_next ++ [%{from: rule_id, to: next_step}],
            else: edges_with_next

        {nodes_with_next, edges_final}
      end)

    # Add parallel groups
    {nodes_with_parallel, edges_with_parallel} =
      Enum.reduce(workflow.parallel_groups, {nodes_with_rules, edges_with_rules}, fn group,
                                                                                     {nodes_acc,
                                                                                      edges_acc} ->
        group_id = "parallel_group_#{:erlang.phash2(group)}"
        group_node = %{id: group_id, label: "Parallel Group", type: "parallel_group", data: group}

        # Add fork node
        fork_node = %{id: "#{group_id}_fork", label: "Fork", type: "fork"}
        nodes_with_fork = nodes_acc ++ [group_node, fork_node]

        # Add task nodes
        {nodes_with_tasks, edges_with_tasks} =
          Enum.reduce(
            group["task_ids"] || [],
            {nodes_with_fork, edges_acc ++ [%{from: "current", to: "#{group_id}_fork"}]},
            fn task_id, {nodes_task_acc, edges_task_acc} ->
              task_node = %{id: task_id, label: "Task #{task_id}", type: "parallel_task"}
              join_node = %{id: "#{group_id}_join", label: "Join", type: "join"}

              nodes_updated = nodes_task_acc ++ [task_node, join_node]

              edges_updated =
                edges_task_acc ++
                  [
                    %{from: "#{group_id}_fork", to: task_id, label: "parallel"},
                    %{from: task_id, to: "#{group_id}_join", label: "complete"}
                  ]

              {nodes_updated, edges_updated}
            end
          )

        {nodes_with_tasks, edges_with_tasks}
      end)

    %{
      nodes: nodes_with_parallel,
      edges: edges_with_parallel
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
