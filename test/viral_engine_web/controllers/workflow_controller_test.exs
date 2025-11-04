defmodule ViralEngineWeb.WorkflowControllerTest do
  use ViralEngineWeb.ConnCase, async: true
  alias ViralEngine.WorkflowContext

  describe "POST /api/workflows" do
    test "creates a workflow", %{conn: conn} do
      params = %{
        "name" => "Test Workflow",
        "initial_state" => %{"step" => 1}
      }

      conn = post(conn, "/api/workflows", params)

      assert %{"id" => id, "name" => "Test Workflow", "state" => %{"step" => 1}, "version" => 1} =
               json_response(conn, 201)

      assert is_integer(id)
    end

    test "returns errors for invalid data", %{conn: conn} do
      params = %{"name" => ""}

      conn = post(conn, "/api/workflows", params)

      assert %{"errors" => %{"name" => ["can't be blank"]}} = json_response(conn, 422)
    end
  end

  describe "GET /api/workflows/:id" do
    test "returns workflow details", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      conn = get(conn, "/api/workflows/#{workflow.id}")

      response = json_response(conn, 200)
      assert response["id"] == workflow.id
      assert response["name"] == "Test"
      assert response["state"] == %{"step" => 1}
      assert response["routing_rules"] == []
      assert response["conditions"] == []
    end

    test "returns 404 for non-existent workflow", %{conn: conn} do
      conn = get(conn, "/api/workflows/999")

      assert %{"error" => "Workflow not found"} = json_response(conn, 404)
    end
  end

  describe "PUT /api/workflows/:id/advance" do
    test "advances workflow with context data", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      params = %{"context_data" => %{"input" => "test"}}

      conn = put(conn, "/api/workflows/#{workflow.id}/advance", params)

      response = json_response(conn, 200)
      assert response["action"] == "default"
      assert response["next_step"] == nil
      assert response["workflow"]["version"] == 2
    end

    test "returns 404 for non-existent workflow", %{conn: conn} do
      params = %{"context_data" => %{}}

      conn = put(conn, "/api/workflows/999/advance", params)

      assert %{"error" => "Workflow not found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/workflows/:id/rules" do
    test "adds routing rule to workflow", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      rule = %{
        "conditions" => [%{"type" => "boolean", "value" => true}],
        "action" => "continue",
        "next_step" => "next"
      }

      conn = post(conn, "/api/workflows/#{workflow.id}/rules", %{"rule" => rule})

      response = json_response(conn, 200)
      assert response["id"] == workflow.id
      assert length(response["routing_rules"]) == 1
      assert response["version"] == 2
    end
  end

  describe "POST /api/workflows/:id/conditions" do
    test "adds condition to workflow", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      condition = %{"type" => "boolean", "value" => true}

      conn = post(conn, "/api/workflows/#{workflow.id}/conditions", %{"condition" => condition})

      response = json_response(conn, 200)
      assert response["id"] == workflow.id
      assert length(response["conditions"]) == 1
      assert response["version"] == 2
    end
  end

  describe "GET /api/workflows/:id/visualize" do
    test "returns workflow visualization data", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      conn = get(conn, "/api/workflows/#{workflow.id}/visualize")

      response = json_response(conn, 200)
      assert response["workflow"]["id"] == workflow.id
      assert response["workflow"]["name"] == "Test"
      assert response["workflow"]["status"] == "active"
      assert response["approval_gates"] == []
      assert response["approval_history"] == []
      assert response["graph"]["nodes"] != []
      assert response["graph"]["edges"] == []
    end
  end

  describe "POST /api/workflows/:id/gates" do
    test "adds approval gate to workflow", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate = %{
        "id" => "gate1",
        "description" => "Manager approval",
        "timeout_hours" => 24,
        "webhook_url" => "https://example.com/webhook"
      }

      conn = post(conn, "/api/workflows/#{workflow.id}/gates", %{"gate" => gate})

      response = json_response(conn, 200)
      assert response["id"] == workflow.id
      assert length(response["approval_gates"]) == 1
      assert response["version"] == 2
    end
  end

  describe "PUT /api/workflows/:id/pause" do
    test "pauses workflow at approval gate", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate = %{"id" => "gate1", "description" => "Test gate"}
      WorkflowContext.define_approval_gate(workflow.id, gate)

      params = %{"gate_id" => "gate1", "reason" => "Need approval"}

      conn = put(conn, "/api/workflows/#{workflow.id}/pause", params)

      response = json_response(conn, 200)
      assert response["id"] == workflow.id
      assert response["status"] == "awaiting_approval"
      assert response["awaiting_gate"] == "gate1"
    end

    test "returns error for non-existent gate", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      params = %{"gate_id" => "nonexistent"}

      conn = put(conn, "/api/workflows/#{workflow.id}/pause", params)

      assert %{"error" => "Approval gate not found"} = json_response(conn, 422)
    end
  end

  describe "POST /api/workflows/:id/approve" do
    test "approves workflow successfully", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate = %{"id" => "gate1", "description" => "Test gate"}
      WorkflowContext.define_approval_gate(workflow.id, gate)
      WorkflowContext.pause_workflow(workflow.id, "gate1")

      params = %{
        "gate_id" => "gate1",
        "decision" => "approved",
        "user_id" => "user123",
        "comments" => "Approved"
      }

      conn = post(conn, "/api/workflows/#{workflow.id}/approve", params)

      response = json_response(conn, 200)
      assert response["id"] == workflow.id
      assert response["status"] == "approved"
      assert response["decision"] == "approved"
      assert response["approved_by"] == "user123"
      assert length(response["approval_history"]) == 1
    end

    test "rejects workflow successfully", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate = %{"id" => "gate1", "description" => "Test gate"}
      WorkflowContext.define_approval_gate(workflow.id, gate)
      WorkflowContext.pause_workflow(workflow.id, "gate1")

      params = %{
        "gate_id" => "gate1",
        "decision" => "rejected",
        "user_id" => "user456",
        "comments" => "Rejected"
      }

      conn = post(conn, "/api/workflows/#{workflow.id}/approve", params)

      response = json_response(conn, 200)
      assert response["status"] == "rejected"
      assert response["decision"] == "rejected"
      assert hd(response["approval_history"])["decision"] == "rejected"
    end

    test "returns error for invalid decision", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate = %{"id" => "gate1", "description" => "Test gate"}
      WorkflowContext.define_approval_gate(workflow.id, gate)
      WorkflowContext.pause_workflow(workflow.id, "gate1")

      params = %{"gate_id" => "gate1", "decision" => "invalid"}

      conn = post(conn, "/api/workflows/#{workflow.id}/approve", params)

      assert %{"error" => "Invalid decision. Must be 'approved' or 'rejected'"} =
               json_response(conn, 422)
    end

    test "returns error when not awaiting approval", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      params = %{"gate_id" => "gate1", "decision" => "approved"}

      conn = post(conn, "/api/workflows/#{workflow.id}/approve", params)

      assert %{"error" => "Workflow is not awaiting approval"} = json_response(conn, 422)
    end
  end

  describe "POST /api/workflows/:id/timeout" do
    test "returns not timed out status", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      conn = post(conn, "/api/workflows/#{workflow.id}/timeout", %{})

      response = json_response(conn, 200)
      assert response["status"] == "not_awaiting_approval"
    end

    test "returns timed out status when workflow times out", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      gate = %{"id" => "gate1", "description" => "Test gate", "timeout_hours" => 0}
      WorkflowContext.define_approval_gate(workflow.id, gate)
      WorkflowContext.pause_workflow(workflow.id, "gate1")

      # Small delay to ensure timeout
      :timer.sleep(100)

      conn = post(conn, "/api/workflows/#{workflow.id}/timeout", %{})

      response = json_response(conn, 200)
      assert response["status"] == "timed_out"
      assert response["workflow"]["status"] == "timed_out"
      assert length(response["workflow"]["approval_history"]) == 1
    end
  end

  describe "POST /api/workflows/:id/parallel-groups" do
    test "adds parallel group to workflow", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      group = %{
        "id" => "parallel_group_1",
        "description" => "Parallel processing group",
        "max_concurrency" => 3,
        "task_ids" => ["task1", "task2", "task3"]
      }

      conn = post(conn, "/api/workflows/#{workflow.id}/parallel-groups", %{"group" => group})

      response = json_response(conn, 200)
      assert response["id"] == workflow.id
      assert length(response["parallel_groups"]) == 1
      assert response["execution_mode"] == "parallel"
      assert response["version"] == 2
      assert hd(response["parallel_groups"])["id"] == "parallel_group_1"
    end

    test "returns error for non-existent workflow", %{conn: conn} do
      group = %{"id" => "group1", "description" => "Test group"}

      conn = post(conn, "/api/workflows/999/parallel-groups", %{"group" => group})

      assert %{"error" => "Workflow not found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/workflows/:id/execute-parallel" do
    test "executes parallel tasks successfully", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Define parallel group first
      group = %{"id" => "group1", "max_concurrency" => 2}
      WorkflowContext.define_parallel_group(workflow.id, group)

      tasks = [
        %{"id" => "task1", "prompt" => "Process data 1"},
        %{"id" => "task2", "prompt" => "Process data 2"}
      ]

      conn = post(conn, "/api/workflows/#{workflow.id}/execute-parallel", %{"tasks" => tasks})

      response = json_response(conn, 200)
      assert response["status"] == "success"
      assert is_map(response["results"])
      assert response["workflow"]["id"] == workflow.id
      assert response["workflow"]["state"]["parallel_execution_completed"] == true
    end

    test "handles task failures with continue mode", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Define parallel group
      group = %{"id" => "group1", "max_concurrency" => 2}
      WorkflowContext.define_parallel_group(workflow.id, group)

      # Tasks that might fail
      tasks = [
        %{"id" => "task1", "prompt" => "Process data 1"},
        %{"id" => "task2", "prompt" => "Process data 2"}
      ]

      conn =
        post(conn, "/api/workflows/#{workflow.id}/execute-parallel", %{
          "tasks" => tasks,
          "failure_mode" => "continue"
        })

      response = json_response(conn, 200)
      assert response["status"] == "success"
      assert is_map(response["results"])
    end

    test "returns error for non-existent workflow", %{conn: conn} do
      tasks = [%{"id" => "task1", "prompt" => "Test"}]

      conn = post(conn, "/api/workflows/999/execute-parallel", %{"tasks" => tasks})

      assert %{"error" => "Workflow not found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/workflows/:id/retry-from-step/:step_id" do
    test "schedules retry from specified step", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      conn =
        post(conn, "/api/workflows/#{workflow.id}/retry-from-step/step1", %{
          "context" => %{"attempt" => 1}
        })

      response = json_response(conn, 200)
      assert response["delay_ms"] == 1000
      assert response["workflow"]["id"] == workflow.id
      assert response["workflow"]["state"]["retrying_step"] == "step1"
      assert response["workflow"]["state"]["retry_attempt"] == 1
      assert length(response["workflow"]["error_history"]) == 1
    end

    test "returns error when max retries exceeded", %{conn: conn} do
      {:ok, workflow} = WorkflowContext.create_workflow("Test", %{"step" => 1})

      # Set up workflow with max retries reached
      state = %{"retry_attempts" => %{"step1" => 3}}
      changeset = ViralEngine.Workflow.changeset(workflow, %{state: state})
      {:ok, workflow_at_limit} = ViralEngine.Repo.update(changeset)

      conn = post(conn, "/api/workflows/#{workflow_at_limit.id}/retry-from-step/step1", %{})

      assert %{"error" => "Maximum retry attempts exceeded"} = json_response(conn, 422)
    end

    test "returns error for non-existent workflow", %{conn: conn} do
      conn = post(conn, "/api/workflows/999/retry-from-step/step1", %{})

      assert %{"error" => "Workflow not found"} = json_response(conn, 404)
    end
  end
end
