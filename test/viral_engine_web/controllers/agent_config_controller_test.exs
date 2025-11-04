defmodule ViralEngineWeb.AgentConfigControllerTest do
  use ViralEngineWeb.ConnCase, async: false

  alias ViralEngine.{Agent, Repo}

  describe "POST /api/agents" do
    test "creates agent with valid config", %{conn: conn} do
      params = %{
        "name" => "Test Agent",
        "config" => %{
          "provider" => "openai",
          "model" => "gpt-4o",
          "temperature" => 0.7,
          "max_tokens" => 1000,
          "system_prompt" => "You are a helpful assistant"
        },
        "user_id" => 1
      }

      conn = post(conn, "/api/agents", params)

      response = json_response(conn, 201)
      assert response["agent_id"]
      assert response["name"] == "Test Agent"
    end

    test "validates config", %{conn: conn} do
      params = %{
        "name" => "Test",
        "config" => %{"provider" => "invalid"},
        "user_id" => 1
      }

      conn = post(conn, "/api/agents", params)

      assert json_response(conn, 422)
    end
  end

  describe "POST /api/agents/:id/test" do
    setup do
      # Create a test agent
      agent =
        %Agent{
          name: "Test Agent",
          config: %{
            "provider" => "openai",
            "api_key" => "test_key",
            "temperature" => 0.7
          },
          user_id: 1
        }
        |> Repo.insert!()

      %{agent: agent}
    end

    test "returns test structure for valid agent", %{conn: conn, agent: agent} do
      conn = post(conn, "/api/agents/#{agent.id}/test")

      response = json_response(conn, 200)
      assert response["agent_id"] == agent.id
      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "test_results")
      assert Map.has_key?(response["test_results"], "connectivity")
      assert Map.has_key?(response["test_results"], "sample_prompt")
      assert Map.has_key?(response["test_results"], "response_time_ms")
      assert Map.has_key?(response, "suggestions")
      assert is_list(response["suggestions"])
    end

    test "handles agent not found", %{conn: conn} do
      conn = post(conn, "/api/agents/999/test")

      assert json_response(conn, 404)
    end

    test "rate limits repeated tests", %{conn: conn, agent: agent} do
      # First test
      conn = post(conn, "/api/agents/#{agent.id}/test")
      assert json_response(conn, 200)

      # Second test within rate limit window should be blocked
      conn = post(conn, "/api/agents/#{agent.id}/test")
      assert json_response(conn, 429)
    end
  end
end
