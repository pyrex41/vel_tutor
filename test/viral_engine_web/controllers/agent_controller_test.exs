defmodule ViralEngineWeb.AgentControllerTest do
  use ViralEngineWeb.ConnCase, async: false

  alias ViralEngine.{ViralEvent, AgentDecision}

  describe "POST /mcp/orchestrator/select_loop" do
    test "accepts valid JSON-RPC request and logs to database", %{conn: conn} do
      params = %{
        "jsonrpc" => "2.0",
        "method" => "select_loop",
        "params" => %{
          "type" => "practice_completed",
          "user_id" => 123,
          "data" => %{"score" => 95}
        },
        "id" => "test-123"
      }

      conn = post(conn, "/mcp/orchestrator/select_loop", params)

      assert %{"jsonrpc" => "2.0", "id" => "test-123", "result" => result} =
               json_response(conn, 200)

      assert result["event_type"] == "practice_completed"
      assert result["rationale"] == "Phase 1: Event logged, no loops active yet"

      # Check viral_events table
      viral_event = Repo.get_by(ViralEvent, event_type: "practice_completed", user_id: 123)
      assert viral_event
      assert viral_event.event_data == %{"score" => 95}

      # Check agent_decisions table
      agent_decision =
        Repo.get_by(AgentDecision, agent_id: "orchestrator", decision_type: "select_loop")

      assert agent_decision
      assert agent_decision.success == true
    end

    test "returns error for invalid JSON-RPC", %{conn: conn} do
      params = %{"invalid" => "request"}

      conn = post(conn, "/mcp/orchestrator/select_loop", params)

      assert %{"jsonrpc" => "2.0", "error" => %{"code" => -32600}} = json_response(conn, 200)
    end

    test "handles unknown agent/method", %{conn: conn} do
      params = %{
        "jsonrpc" => "2.0",
        "method" => "unknown_method",
        "id" => "test-456"
      }

      conn = post(conn, "/mcp/unknown_agent/unknown_method", params)

      assert %{"jsonrpc" => "2.0", "error" => %{"code" => -32601}} = json_response(conn, 200)
    end
  end
end
