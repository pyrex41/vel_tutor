defmodule ViralEngineWeb.AdminControllerTest do
  use ViralEngineWeb.ConnCase, async: false

  alias ViralEngine.AuditLogContext

  setup do
    # Create test audit logs
    conn_fixture = %Plug.Conn{
      remote_ip: {192, 168, 1, 1},
      req_headers: [{"user-agent", "TestAgent/1.0"}]
    }

    {:ok, _} = AuditLogContext.log_user_action(1, "task_created", %{task_id: 100}, conn_fixture)
    {:ok, _} = AuditLogContext.log_user_action(1, "task_updated", %{task_id: 100}, conn_fixture)
    {:ok, _} = AuditLogContext.log_user_action(2, "task_created", %{task_id: 200}, conn_fixture)
    {:ok, _} = AuditLogContext.log_ai_call(100, "openai", "gpt-5", 1500, Decimal.new("0.015"), 250)
    {:ok, _} = AuditLogContext.log_ai_call(100, "groq", "llama-3.3-70b-versatile", 2000, Decimal.new("0.002"), 80)
    {:ok, _} = AuditLogContext.log_system_event("circuit_breaker_trip", %{provider: "openai"})

    :ok
  end

  describe "GET /api/admin/audit_logs" do
    test "returns all audit logs with default pagination", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs")

      response = json_response(conn, 200)
      assert length(response["logs"]) == 6
      assert response["total"] == 6
      assert response["limit"] == 100
      assert response["offset"] == 0
      assert response["has_more"] == false
    end

    test "filters by user_id", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs?user_id=1")

      response = json_response(conn, 200)
      assert length(response["logs"]) == 2
      assert response["total"] == 2
      assert Enum.all?(response["logs"], fn log -> log["user_id"] == 1 end)
    end

    test "filters by action", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs?action=task_created")

      response = json_response(conn, 200)
      assert length(response["logs"]) == 2
      assert Enum.all?(response["logs"], fn log -> log["action"] == "task_created" end)
    end

    test "filters by event_type", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs?event_type=ai_interaction")

      response = json_response(conn, 200)
      assert length(response["logs"]) == 2
      assert Enum.all?(response["logs"], fn log -> log["event_type"] == "ai_interaction" end)
    end

    test "filters by provider", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs?provider=openai")

      response = json_response(conn, 200)
      assert length(response["logs"]) == 1
      assert hd(response["logs"])["provider"] == "openai"
    end

    test "filters by task_id", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs?task_id=100")

      response = json_response(conn, 200)
      assert length(response["logs"]) >= 2
      assert Enum.all?(response["logs"], fn log -> log["task_id"] == 100 end)
    end

    test "applies pagination with limit and offset", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs?limit=2&offset=0")

      response = json_response(conn, 200)
      assert length(response["logs"]) == 2
      assert response["limit"] == 2
      assert response["offset"] == 0
      assert response["has_more"] == true
    end

    test "filters by date range", %{conn: conn} do
      now = DateTime.utc_now()
      one_hour_ago = DateTime.add(now, -3600, :second) |> DateTime.to_iso8601()
      one_hour_from_now = DateTime.add(now, 3600, :second) |> DateTime.to_iso8601()

      conn = get(conn, "/api/admin/audit_logs?date_from=#{one_hour_ago}&date_to=#{one_hour_from_now}")

      response = json_response(conn, 200)
      assert response["total"] == 6
    end

    test "respects max limit of 1000", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs?limit=5000")

      response = json_response(conn, 200)
      assert response["limit"] == 1000
    end

    test "combines multiple filters", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs?event_type=user_action&user_id=1")

      response = json_response(conn, 200)
      assert length(response["logs"]) == 2
      assert Enum.all?(response["logs"], fn log ->
        log["user_id"] == 1 && log["event_type"] == "user_action"
      end)
    end
  end

  describe "GET /api/admin/audit_logs/stats" do
    test "returns basic statistics", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs/stats")

      response = json_response(conn, 200)
      assert response["total_logs"] == 6
      assert is_map(response["by_event_type"])
      assert is_map(response["by_provider"])
      assert is_map(response["date_range"])
    end

    test "groups logs by event type", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs/stats")

      response = json_response(conn, 200)
      by_event_type = response["by_event_type"]

      assert by_event_type["user_action"] == 3
      assert by_event_type["ai_interaction"] == 2
      assert by_event_type["system_event"] == 1
    end

    test "groups logs by provider", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs/stats")

      response = json_response(conn, 200)
      by_provider = response["by_provider"]

      assert by_provider["openai"] == 1
      assert by_provider["groq"] == 1
    end

    test "provides date range", %{conn: conn} do
      conn = get(conn, "/api/admin/audit_logs/stats")

      response = json_response(conn, 200)
      date_range = response["date_range"]

      assert date_range["earliest"]
      assert date_range["latest"]
    end

    test "filters stats by date range", %{conn: conn} do
      now = DateTime.utc_now()
      one_hour_ago = DateTime.add(now, -3600, :second) |> DateTime.to_iso8601()
      one_hour_from_now = DateTime.add(now, 3600, :second) |> DateTime.to_iso8601()

      conn = get(conn, "/api/admin/audit_logs/stats?date_from=#{one_hour_ago}&date_to=#{one_hour_from_now}")

      response = json_response(conn, 200)
      assert response["total_logs"] == 6
    end
  end
end
