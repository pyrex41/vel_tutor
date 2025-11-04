defmodule ViralEngineWeb.TaskControllerTest do
  use ViralEngineWeb.ConnCase, async: false

  alias ViralEngine.Task

  describe "POST /api/tasks" do
    test "creates task with valid params", %{conn: conn} do
      params = %{
        "description" => "Test task",
        "agent_id" => "gpt_4o",
        "user_id" => 1
      }

      conn = post(conn, "/api/tasks", params)

      assert %{"task_id" => task_id, "status_url" => status_url} = json_response(conn, 201)
      assert is_integer(task_id)
      assert status_url == "/api/tasks/#{task_id}/status"

      # Check database
      task = Repo.get(Task, task_id)
      assert task.description == "Test task"
      assert task.agent_id == "gpt_4o"
      assert task.status == "pending"
    end

    test "validates required params", %{conn: conn} do
      conn = post(conn, "/api/tasks", %{})

      assert %{"error" => "Missing required parameters"} = json_response(conn, 400)
    end

    test "validates agent_id", %{conn: conn} do
      params = %{
        "description" => "Test",
        "agent_id" => "invalid",
        "user_id" => 1
      }

      conn = post(conn, "/api/tasks", params)

      assert %{"error" => "Invalid agent_id"} = json_response(conn, 400)
    end
  end

  describe "GET /api/tasks/:id" do
    test "returns task details", %{conn: conn} do
      # Create a task first
      {:ok, task} =
        Repo.insert(%Task{
          description: "Test task",
          agent_id: "gpt_4o",
          user_id: 1,
          provider: "openai",
          latency_ms: 150,
          tokens_used: 100,
          cost: 0.03
        })

      conn = get(conn, "/api/tasks/#{task.id}")

      response = json_response(conn, 200)
      assert response["id"] == task.id
      assert response["description"] == "Test task"
      assert response["provider"] == "openai"
      assert response["latency_ms"] == 150
    end

    test "returns 404 for non-existent task", %{conn: conn} do
      conn = get(conn, "/api/tasks/999")

      assert %{"error" => "Task not found"} = json_response(conn, 404)
    end
  end

  describe "GET /api/tasks" do
    test "returns paginated tasks", %{conn: conn} do
      # Create some tasks
      Repo.insert(%Task{description: "Task 1", agent_id: "gpt_4o", user_id: 1})
      Repo.insert(%Task{description: "Task 2", agent_id: "llama_3_1", user_id: 1})

      conn = get(conn, "/api/tasks")

      response = json_response(conn, 200)
      assert length(response["tasks"]) == 2
      assert response["pagination"]["total_count"] == 2
      assert response["pagination"]["page"] == 1
    end
  end
end
