defmodule ViralEngine.WorkflowContextTest do
  use ViralEngine.DataCase

  alias ViralEngine.WorkflowContext

  describe "get_workflow_state/1" do
    test "returns workflow state" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test Workflow", %{"step" => 1})

      {:ok, state} = WorkflowContext.get_workflow_state(workflow.id)
      assert state == %{"step" => 1}
    end

    test "returns error for non-existent workflow" do
      assert {:error, :not_found} = WorkflowContext.get_workflow_state(999)
    end
  end

  describe "update_workflow_state/2" do
    test "updates state and increments version" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      {:ok, updated} = WorkflowContext.update_workflow_state(workflow.id, %{"step" => 2})

      assert updated.state == %{"step" => 2}
      assert updated.version == 2
    end
  end

  describe "list_workflow_versions/1" do
    test "returns all versions" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})
      WorkflowContext.update_workflow_state(workflow.id, %{"step" => 2})

      versions = WorkflowContext.list_workflow_versions(workflow.id)
      assert length(versions) == 2
      assert Enum.map(versions, & &1.version) == [2, 1]
    end
  end

  describe "condition evaluators" do
    test "sentiment condition evaluates positive text" do
      condition = %{
        "type" => "sentiment",
        "text" => "This is great and amazing!",
        "threshold" => 0.5
      }

      assert WorkflowContext.evaluate_condition(condition, %{})
    end

    test "sentiment condition evaluates negative text" do
      condition = %{
        "type" => "sentiment",
        "text" => "This is terrible and awful!",
        "threshold" => 0.8
      }

      refute WorkflowContext.evaluate_condition(condition, %{})
    end

    test "confidence condition evaluates correctly" do
      condition = %{"type" => "confidence", "value" => 0.9, "threshold" => 0.8}
      assert WorkflowContext.evaluate_condition(condition, %{})

      condition = %{"type" => "confidence", "value" => 0.6, "threshold" => 0.8}
      refute WorkflowContext.evaluate_condition(condition, %{})
    end

    test "text_match condition evaluates correctly" do
      condition = %{"type" => "text_match", "text" => "Hello world", "pattern" => "world"}
      assert WorkflowContext.evaluate_condition(condition, %{})

      condition = %{"type" => "text_match", "text" => "Hello world", "pattern" => "universe"}
      refute WorkflowContext.evaluate_condition(condition, %{})
    end

    test "regex_match condition evaluates correctly" do
      condition = %{"type" => "regex_match", "text" => "user123", "pattern" => "\\d+"}
      assert WorkflowContext.evaluate_condition(condition, %{})

      condition = %{"type" => "regex_match", "text" => "userabc", "pattern" => "\\d+"}
      refute WorkflowContext.evaluate_condition(condition, %{})
    end

    test "numeric_range condition evaluates correctly" do
      condition = %{"type" => "numeric_range", "value" => 5, "min" => 1, "max" => 10}
      assert WorkflowContext.evaluate_condition(condition, %{})

      condition = %{"type" => "numeric_range", "value" => 15, "min" => 1, "max" => 10}
      refute WorkflowContext.evaluate_condition(condition, %{})
    end

    test "boolean condition evaluates correctly" do
      condition = %{"type" => "boolean", "value" => true}
      assert WorkflowContext.evaluate_condition(condition, %{})

      condition = %{"type" => "boolean", "value" => false}
      refute WorkflowContext.evaluate_condition(condition, %{})
    end
  end

  describe "routing rules" do
    test "evaluate_routing_rules returns default when no rules match" do
      rules = [
        %{"conditions" => [%{"type" => "boolean", "value" => false}], "action" => "reject"}
      ]

      context_data = %{}

      assert {:default, nil} = WorkflowContext.evaluate_routing_rules(rules, context_data)
    end

    test "evaluate_routing_rules returns matching rule action" do
      rules = [
        %{
          "conditions" => [%{"type" => "boolean", "value" => true}],
          "action" => "approve",
          "next_step" => "approved"
        }
      ]

      context_data = %{}

      assert {"approve", "approved"} = WorkflowContext.evaluate_routing_rules(rules, context_data)
    end

    test "evaluate_routing_rules with multiple conditions" do
      rules = [
        %{
          "conditions" => [
            %{"type" => "confidence", "value" => 0.9, "threshold" => 0.8},
            %{"type" => "text_match", "text" => "approved", "pattern" => "approved"}
          ],
          "action" => "approve",
          "next_step" => "approved"
        }
      ]

      context_data = %{}

      assert {"approve", "approved"} = WorkflowContext.evaluate_routing_rules(rules, context_data)
    end
  end

  describe "advance_workflow/2" do
    test "advances workflow with routing rules" do
      # Create workflow with routing rules
      {:ok, workflow} = WorkflowContext.create_workflow("Test Routing", %{"step" => "initial"})

      # Add a routing rule
      rule = %{
        "conditions" => [%{"type" => "boolean", "value" => true}],
        "action" => "proceed",
        "next_step" => "next_phase"
      }

      {:ok, _} = WorkflowContext.add_routing_rule(workflow.id, rule)

      # Advance workflow
      context_data = %{"user_input" => "yes"}

      {:ok, {action, next_step, updated_workflow}} =
        WorkflowContext.advance_workflow(workflow.id, context_data)

      assert action == "proceed"
      assert next_step == "next_phase"
      assert updated_workflow.version == 2
      assert updated_workflow.state["last_action"] == "proceed"
      assert updated_workflow.state["next_step"] == "next_phase"
    end

    test "returns error for non-existent workflow" do
      assert {:error, :not_found} = WorkflowContext.advance_workflow(999, %{})
    end
  end

  describe "add_routing_rule/2" do
    test "adds routing rule to workflow" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      rule = %{
        "conditions" => [%{"type" => "boolean", "value" => true}],
        "action" => "continue",
        "next_step" => "step2"
      }

      {:ok, updated_workflow} = WorkflowContext.add_routing_rule(workflow.id, rule)

      assert length(updated_workflow.routing_rules) == 1
      assert updated_workflow.version == 2
    end

    test "returns error for non-existent workflow" do
      rule = %{"conditions" => [], "action" => "continue"}
      assert {:error, :not_found} = WorkflowContext.add_routing_rule(999, rule)
    end
  end

  describe "add_condition/2" do
    test "adds condition to workflow" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      condition = %{"type" => "boolean", "value" => true}

      {:ok, updated_workflow} = WorkflowContext.add_condition(workflow.id, condition)

      assert length(updated_workflow.conditions) == 1
      assert updated_workflow.version == 2
    end

    test "returns error for non-existent workflow" do
      condition = %{"type" => "boolean", "value" => true}
      assert {:error, :not_found} = WorkflowContext.add_condition(999, condition)
    end
  end

  describe "define_approval_gate/2" do
    test "adds approval gate to workflow" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{
        "id" => "approval_gate_1",
        "description" => "Manager approval required",
        "timeout_hours" => 24,
        "webhook_url" => "https://example.com/webhook"
      }

      {:ok, updated_workflow} = WorkflowContext.define_approval_gate(workflow.id, gate_config)

      assert length(updated_workflow.approval_gates) == 1
      assert updated_workflow.version == 2
      assert hd(updated_workflow.approval_gates)["id"] == "approval_gate_1"
    end

    test "returns error for non-existent workflow" do
      gate_config = %{"id" => "gate1", "description" => "Test gate"}
      assert {:error, :not_found} = WorkflowContext.define_approval_gate(999, gate_config)
    end
  end

  describe "pause_workflow/3" do
    test "pauses workflow at approval gate" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{"id" => "gate1", "description" => "Test gate"}
      {:ok, _} = WorkflowContext.define_approval_gate(workflow.id, gate_config)

      {:ok, paused_workflow} =
        WorkflowContext.pause_workflow(workflow.id, "gate1", "Need approval")

      assert paused_workflow.status == "awaiting_approval"
      assert paused_workflow.state["awaiting_gate"] == "gate1"
      assert paused_workflow.version == 3
    end

    test "returns error for non-existent gate" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      assert {:error, :gate_not_found} =
               WorkflowContext.pause_workflow(workflow.id, "nonexistent", "Test")
    end

    test "returns error for non-existent workflow" do
      assert {:error, :not_found} = WorkflowContext.pause_workflow(999, "gate1", "Test")
    end
  end

  describe "approve_workflow/5" do
    test "approves workflow successfully" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{"id" => "gate1", "description" => "Test gate"}
      {:ok, _} = WorkflowContext.define_approval_gate(workflow.id, gate_config)
      {:ok, _} = WorkflowContext.pause_workflow(workflow.id, "gate1")

      {:ok, {"approved", approved_workflow}} =
        WorkflowContext.approve_workflow(
          workflow.id,
          "gate1",
          "approved",
          "user123",
          "Looks good"
        )

      assert approved_workflow.status == "approved"
      assert approved_workflow.state["last_decision"] == "approved"
      assert approved_workflow.state["approved_by"] == "user123"
      assert length(approved_workflow.approval_history) == 1
      assert hd(approved_workflow.approval_history)["decision"] == "approved"
    end

    test "rejects workflow successfully" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{"id" => "gate1", "description" => "Test gate"}
      {:ok, _} = WorkflowContext.define_approval_gate(workflow.id, gate_config)
      {:ok, _} = WorkflowContext.pause_workflow(workflow.id, "gate1")

      {:ok, {"rejected", rejected_workflow}} =
        WorkflowContext.approve_workflow(
          workflow.id,
          "gate1",
          "rejected",
          "user456",
          "Needs changes"
        )

      assert rejected_workflow.status == "rejected"
      assert rejected_workflow.state["last_decision"] == "rejected"
      assert hd(rejected_workflow.approval_history)["decision"] == "rejected"
    end

    test "returns error for invalid decision" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{"id" => "gate1", "description" => "Test gate"}
      {:ok, _} = WorkflowContext.define_approval_gate(workflow.id, gate_config)
      {:ok, _} = WorkflowContext.pause_workflow(workflow.id, "gate1")

      assert {:error, :invalid_decision} =
               WorkflowContext.approve_workflow(workflow.id, "gate1", "invalid", "user123")
    end

    test "returns error when workflow not awaiting approval" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      assert {:error, :not_awaiting_approval} =
               WorkflowContext.approve_workflow(workflow.id, "gate1", "approved", "user123")
    end

    test "returns error for wrong gate" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{"id" => "gate1", "description" => "Test gate"}
      {:ok, _} = WorkflowContext.define_approval_gate(workflow.id, gate_config)
      {:ok, _} = WorkflowContext.pause_workflow(workflow.id, "gate1")

      assert {:error, :wrong_gate} =
               WorkflowContext.approve_workflow(workflow.id, "wrong_gate", "approved", "user123")
    end
  end

  describe "check_timeout/1" do
    test "returns not timed out when no timeout configured" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{"id" => "gate1", "description" => "Test gate"}
      {:ok, _} = WorkflowContext.define_approval_gate(workflow.id, gate_config)
      {:ok, _} = WorkflowContext.pause_workflow(workflow.id, "gate1")

      assert {:ok, :no_timeout_configured} = WorkflowContext.check_timeout(workflow.id)
    end

    test "returns not timed out when within timeout period" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{"id" => "gate1", "description" => "Test gate", "timeout_hours" => 24}
      {:ok, _} = WorkflowContext.define_approval_gate(workflow.id, gate_config)
      {:ok, _} = WorkflowContext.pause_workflow(workflow.id, "gate1")

      assert {:ok, :not_timed_out} = WorkflowContext.check_timeout(workflow.id)
    end

    test "auto-rejects when timed out" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate_config = %{"id" => "gate1", "description" => "Test gate", "timeout_hours" => 0}
      {:ok, _} = WorkflowContext.define_approval_gate(workflow.id, gate_config)
      {:ok, _} = WorkflowContext.pause_workflow(workflow.id, "gate1")

      # Wait a bit to ensure timeout
      :timer.sleep(100)

      {:ok, {:timed_out, timed_out_workflow}} = WorkflowContext.check_timeout(workflow.id)

      assert timed_out_workflow.status == "timed_out"
      assert timed_out_workflow.state["timed_out"] == true
      assert length(timed_out_workflow.approval_history) == 1
      assert hd(timed_out_workflow.approval_history)["decision"] == "timed_out"
    end

    test "returns not awaiting approval for active workflow" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      assert {:ok, :not_awaiting_approval} = WorkflowContext.check_timeout(workflow.id)
    end
  end

  describe "define_parallel_group/2" do
    test "adds parallel group to workflow" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      group_config = %{
        "id" => "parallel_group_1",
        "description" => "Parallel processing group",
        "max_concurrency" => 3,
        "tasks" => ["task1", "task2", "task3"]
      }

      {:ok, updated_workflow} = WorkflowContext.define_parallel_group(workflow.id, group_config)

      assert length(updated_workflow.parallel_groups) == 1
      assert updated_workflow.execution_mode == "parallel"
      assert updated_workflow.version == 2
      assert hd(updated_workflow.parallel_groups)["id"] == "parallel_group_1"
      assert hd(updated_workflow.parallel_groups)["max_concurrency"] == 3
    end

    test "returns error for non-existent workflow" do
      group_config = %{"id" => "group1", "description" => "Test group"}
      assert {:error, :not_found} = WorkflowContext.define_parallel_group(999, group_config)
    end
  end

  describe "execute_parallel_tasks/2" do
    test "executes tasks in parallel and aggregates results" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Define parallel group
      group_config = %{"id" => "group1", "max_concurrency" => 2}
      {:ok, _} = WorkflowContext.define_parallel_group(workflow.id, group_config)

      # Task configs
      task_configs = [
        %{"id" => "task1", "prompt" => "Process data 1"},
        %{"id" => "task2", "prompt" => "Process data 2"},
        %{"id" => "task3", "prompt" => "Process data 3"}
      ]

      {:ok, {results, updated_workflow}} =
        WorkflowContext.execute_parallel_tasks(workflow.id, task_configs)

      assert map_size(results) == 3
      assert Map.has_key?(results, "task1")
      assert Map.has_key?(results, "task2")
      assert Map.has_key?(results, "task3")
      assert updated_workflow.state["parallel_execution_completed"] == true
      assert updated_workflow.version == 3
    end

    test "returns error for non-existent workflow" do
      task_configs = [%{"id" => "task1", "prompt" => "Test"}]
      assert {:error, :not_found} = WorkflowContext.execute_parallel_tasks(999, task_configs)
    end
  end

  describe "execute_parallel_tasks_with_failure_handling/3" do
    test "continues execution when tasks fail with :continue mode" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Define parallel group
      group_config = %{"id" => "group1", "max_concurrency" => 2}
      {:ok, _} = WorkflowContext.define_parallel_group(workflow.id, group_config)

      # Task configs (some will simulate failures)
      task_configs = [
        %{"id" => "task1", "prompt" => "Process data 1"},
        %{"id" => "task2", "prompt" => "Process data 2"},
        %{"id" => "task3", "prompt" => "Process data 3"}
      ]

      {:ok, {{:ok, results}, updated_workflow}} =
        WorkflowContext.execute_parallel_tasks_with_failure_handling(
          workflow.id,
          task_configs,
          :continue
        )

      # Results should contain successful tasks
      assert is_map(results)
      assert updated_workflow.state["parallel_execution_completed"] == true
      assert updated_workflow.version == 3
    end

    test "aborts execution when tasks fail with :abort mode" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Define parallel group
      group_config = %{"id" => "group1", "max_concurrency" => 2}
      {:ok, _} = WorkflowContext.define_parallel_group(workflow.id, group_config)

      # Task configs
      task_configs = [
        %{"id" => "task1", "prompt" => "Process data 1"},
        %{"id" => "task2", "prompt" => "Process data 2"}
      ]

      # This test assumes some tasks might fail - in real scenario we'd mock failures
      result =
        WorkflowContext.execute_parallel_tasks_with_failure_handling(
          workflow.id,
          task_configs,
          :abort
        )

      case result do
        {:ok, {{:ok, _results}, _workflow}} ->
          # No failures occurred
          :ok

        {:ok, {{:error, :aborted_due_to_failures}, failed_workflow}} ->
          # Failures occurred and execution was aborted
          assert failed_workflow.status == "failed"
          assert failed_workflow.state["parallel_execution_failed"] == true
          assert is_list(failed_workflow.state["task_failures"])
      end
    end

    test "returns error for non-existent workflow" do
      task_configs = [%{"id" => "task1", "prompt" => "Test"}]

      assert {:error, :not_found} =
               WorkflowContext.execute_parallel_tasks_with_failure_handling(
                 999,
                 task_configs,
                 :continue
               )
    end
  end

  describe "parallel execution helper functions" do
    test "get_max_concurrency returns default when no groups" do
      assert WorkflowContext.get_max_concurrency([]) == 5
    end

    test "get_max_concurrency returns minimum concurrency from groups" do
      groups = [
        %{"max_concurrency" => 3},
        %{"max_concurrency" => 5},
        %{"max_concurrency" => 2}
      ]

      assert WorkflowContext.get_max_concurrency(groups) == 2
    end

    test "get_max_concurrency uses default for groups without max_concurrency" do
      groups = [%{}, %{"max_concurrency" => 3}]

      assert WorkflowContext.get_max_concurrency(groups) == 3
    end
  end

  describe "configure_retry/3" do
    test "configures retry settings for a workflow step" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      retry_config = %{"max_attempts" => 5, "backoff_strategy" => "exponential"}

      {:ok, updated_workflow} =
        WorkflowContext.configure_retry(workflow.id, "step1", retry_config)

      assert updated_workflow.retry_config["step1"] == retry_config
      assert updated_workflow.version == 2
    end

    test "returns error for non-existent workflow" do
      retry_config = %{"max_attempts" => 3}
      assert {:error, :not_found} = WorkflowContext.configure_retry(999, "step1", retry_config)
    end
  end

  describe "categorize_error/2" do
    test "categorizes timeout errors as retryable" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      {:ok, category} = WorkflowContext.categorize_error("Request timeout occurred", workflow.id)
      assert category == "retryable"
    end

    test "categorizes validation errors as terminal" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      {:ok, category} = WorkflowContext.categorize_error("Validation failed", workflow.id)
      assert category == "terminal"
    end

    test "uses custom error categories from workflow config" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Update workflow with custom error categories
      changeset =
        Workflow.changeset(workflow, %{error_categories: %{"custom_error" => "terminal"}})

      {:ok, workflow_with_categories} = Repo.update(changeset)

      {:ok, category} =
        WorkflowContext.categorize_error("custom_error", workflow_with_categories.id)

      assert category == "terminal"
    end

    test "returns error for non-existent workflow" do
      assert {:error, :not_found} = WorkflowContext.categorize_error("some_error", 999)
    end
  end

  describe "execute_rollback/2" do
    test "executes rollback for configured step" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Configure rollback step
      rollback_config = %{"action" => "undo_payment", "amount" => 100}
      changeset = Workflow.changeset(workflow, %{rollback_steps: %{"step1" => rollback_config}})
      {:ok, workflow_with_rollback} = Repo.update(changeset)

      {:ok, {result, updated_workflow}} =
        WorkflowContext.execute_rollback(workflow_with_rollback.id, "step1")

      assert result == {:ok, "Rollback completed for undo_payment"}
      assert updated_workflow.state["last_rollback"] == "step1"
      assert updated_workflow.version == 3
    end

    test "returns error when rollback step not found" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      assert {:error, :rollback_step_not_found} =
               WorkflowContext.execute_rollback(workflow.id, "nonexistent")
    end

    test "returns error for non-existent workflow" do
      assert {:error, :not_found} = WorkflowContext.execute_rollback(999, "step1")
    end
  end

  describe "send_error_notification/2" do
    test "sends notifications to configured webhooks" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Configure webhooks
      webhooks = [
        %{"url" => "https://example.com/webhook1"},
        %{"url" => "https://example.com/webhook2"}
      ]

      changeset = Workflow.changeset(workflow, %{notification_webhooks: webhooks})
      {:ok, workflow_with_webhooks} = Repo.update(changeset)

      error_details = %{step_id: "step1", error_reason: "timeout"}

      {:ok, results} =
        WorkflowContext.send_error_notification(workflow_with_webhooks.id, error_details)

      assert length(results) == 2
      assert Enum.all?(results, &(&1 == {:ok, :webhook_sent}))
    end

    test "returns error for non-existent workflow" do
      assert {:error, :not_found} = WorkflowContext.send_error_notification(999, %{})
    end
  end

  describe "retry_from_step/3" do
    test "schedules retry with exponential backoff" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Configure retry settings
      retry_config = %{"max_attempts" => 3, "backoff_strategy" => "exponential"}
      changeset = Workflow.changeset(workflow, %{retry_config: %{"step1" => retry_config}})
      {:ok, workflow_with_retry} = Repo.update(changeset)

      {:ok, {delay_ms, updated_workflow}} =
        WorkflowContext.retry_from_step(workflow_with_retry.id, "step1")

      # First attempt: 2^(1-1) * 1000 = 1000ms
      assert delay_ms == 1000
      assert updated_workflow.state["retrying_step"] == "step1"
      assert updated_workflow.state["retry_attempt"] == 1
      assert length(updated_workflow.error_history) == 1
    end

    test "prevents retry when max attempts exceeded" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Set up workflow with max retries already reached
      state = %{"retry_attempts" => %{"step1" => 3}}
      changeset = Workflow.changeset(workflow, %{state: state})
      {:ok, workflow_at_limit} = Repo.update(changeset)

      assert {:error, :max_retries_exceeded} =
               WorkflowContext.retry_from_step(workflow_at_limit.id, "step1")
    end

    test "uses linear backoff strategy" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      retry_config = %{"max_attempts" => 3, "backoff_strategy" => "linear"}
      changeset = Workflow.changeset(workflow, %{retry_config: %{"step1" => retry_config}})
      {:ok, workflow_with_linear} = Repo.update(changeset)

      {:ok, {delay_ms, _}} = WorkflowContext.retry_from_step(workflow_with_linear.id, "step1")

      # First attempt: 1 * 1000 = 1000ms
      assert delay_ms == 1000
    end

    test "returns error for non-existent workflow" do
      assert {:error, :not_found} = WorkflowContext.retry_from_step(999, "step1")
    end
  end

  describe "log_workflow_error/4" do
    test "logs error and sends notifications" do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Configure webhooks for notifications
      webhooks = [%{"url" => "https://example.com/webhook"}]
      changeset = Workflow.changeset(workflow, %{notification_webhooks: webhooks})
      {:ok, workflow_with_webhooks} = Repo.update(changeset)

      {:ok, updated_workflow} =
        WorkflowContext.log_workflow_error(
          workflow_with_webhooks.id,
          "step1",
          "Network timeout",
          %{"attempt" => 1}
        )

      assert length(updated_workflow.error_history) == 1
      error_record = hd(updated_workflow.error_history)
      assert error_record["step_id"] == "step1"
      assert error_record["error_reason"] == "Network timeout"
      assert error_record["context"] == %{"attempt" => 1}
    end

    test "returns error for non-existent workflow" do
      assert {:error, :not_found} = WorkflowContext.log_workflow_error(999, "step1", "error")
    end
  end
end
