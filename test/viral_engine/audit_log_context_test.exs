defmodule ViralEngine.AuditLogContextTest do
  use ViralEngine.DataCase, async: false

  alias ViralEngine.{AuditLogContext, AuditLog, Repo}

  describe "log_user_action/4" do
    test "logs user action with conn context" do
      conn = %Plug.Conn{
        remote_ip: {127, 0, 0, 1},
        req_headers: [
          {"user-agent", "Mozilla/5.0"},
          {"x-forwarded-for", "192.168.1.1"}
        ]
      }

      {:ok, log} = AuditLogContext.log_user_action(
        123,
        "task_created",
        %{task_id: 456, description: "Test task"},
        conn
      )

      assert log.user_id == 123
      assert log.action == "task_created"
      assert log.payload == %{task_id: 456, description: "Test task"}
      assert log.ip_address == "192.168.1.1"
      assert log.user_agent == "Mozilla/5.0"
      assert log.event_type == "user_action"
      assert log.timestamp != nil
    end

    test "rejects PII without consent flag" do
      conn = %Plug.Conn{
        remote_ip: {127, 0, 0, 1},
        req_headers: []
      }

      # This should fail validation due to PII without consent
      result = AuditLogContext.log_user_action(
        123,
        "user_updated",
        %{email: "test@example.com", ssn: "123-45-6789"},
        conn
      )

      assert {:error, changeset} = result
      assert changeset.errors[:consent_flag]
    end
  end

  describe "log_ai_call/6" do
    test "logs AI provider interaction with metrics" do
      {:ok, log} = AuditLogContext.log_ai_call(
        789,
        "openai",
        "gpt-5",
        1500,
        Decimal.new("0.015"),
        250
      )

      assert log.task_id == 789
      assert log.provider == "openai"
      assert log.model == "gpt-5"
      assert log.tokens_used == 1500
      assert log.cost == Decimal.new("0.015")
      assert log.latency_ms == 250
      assert log.event_type == "ai_interaction"
      assert log.action == "ai_call"
    end

    test "logs Groq AI call" do
      {:ok, log} = AuditLogContext.log_ai_call(
        890,
        "groq",
        "llama-3.3-70b-versatile",
        2000,
        Decimal.new("0.002"),
        80
      )

      assert log.provider == "groq"
      assert log.model == "llama-3.3-70b-versatile"
      assert log.latency_ms == 80
    end
  end

  describe "log_system_event/2" do
    test "logs system events" do
      {:ok, log} = AuditLogContext.log_system_event(
        "circuit_breaker_trip",
        %{provider: "openai", failures: 5}
      )

      assert log.action == "circuit_breaker_trip"
      assert log.payload == %{provider: "openai", failures: 5}
      assert log.event_type == "system_event"
      assert log.user_id == nil
    end

    test "logs error events" do
      {:ok, log} = AuditLogContext.log_system_event(
        "api_error",
        %{error: "Rate limit exceeded", provider: "perplexity"}
      )

      assert log.action == "api_error"
      assert log.payload.error == "Rate limit exceeded"
    end
  end

  describe "query_logs/2" do
    setup do
      # Create test logs
      conn = %Plug.Conn{remote_ip: {127, 0, 0, 1}, req_headers: []}

      {:ok, _} = AuditLogContext.log_user_action(1, "task_created", %{task_id: 100}, conn)
      {:ok, _} = AuditLogContext.log_user_action(1, "task_updated", %{task_id: 100}, conn)
      {:ok, _} = AuditLogContext.log_user_action(2, "task_created", %{task_id: 200}, conn)
      {:ok, _} = AuditLogContext.log_ai_call(100, "openai", "gpt-5", 1000, Decimal.new("0.01"), 200)
      {:ok, _} = AuditLogContext.log_system_event("test_event", %{data: "test"})

      :ok
    end

    test "returns all logs with default pagination" do
      result = AuditLogContext.query_logs()

      assert length(result.logs) == 5
      assert result.total == 5
      assert result.limit == 100
      assert result.offset == 0
      assert result.has_more == false
    end

    test "filters by user_id" do
      result = AuditLogContext.query_logs(%{user_id: 1})

      assert length(result.logs) == 2
      assert Enum.all?(result.logs, fn log -> log.user_id == 1 end)
    end

    test "filters by action" do
      result = AuditLogContext.query_logs(%{action: "task_created"})

      assert length(result.logs) == 2
      assert Enum.all?(result.logs, fn log -> log.action == "task_created" end)
    end

    test "filters by event_type" do
      result = AuditLogContext.query_logs(%{event_type: "ai_interaction"})

      assert length(result.logs) == 1
      assert hd(result.logs).event_type == "ai_interaction"
    end

    test "filters by provider" do
      result = AuditLogContext.query_logs(%{provider: "openai"})

      assert length(result.logs) == 1
      assert hd(result.logs).provider == "openai"
    end

    test "applies pagination" do
      result = AuditLogContext.query_logs(%{}, limit: 2, offset: 0)

      assert length(result.logs) == 2
      assert result.has_more == true
    end

    test "filters by date range" do
      now = DateTime.utc_now()
      one_hour_ago = DateTime.add(now, -3600, :second)
      one_hour_from_now = DateTime.add(now, 3600, :second)

      result = AuditLogContext.query_logs(%{
        date_from: one_hour_ago,
        date_to: one_hour_from_now
      })

      assert result.total == 5
    end
  end

  describe "delete_old_logs/0" do
    test "deletes logs older than 90 days" do
      # Create an old log by inserting directly with a backdated timestamp
      old_timestamp = DateTime.add(DateTime.utc_now(), -91, :day)

      %AuditLog{
        action: "old_action",
        event_type: "user_action",
        timestamp: old_timestamp
      }
      |> Repo.insert!()

      # Create a recent log
      conn = %Plug.Conn{remote_ip: {127, 0, 0, 1}, req_headers: []}
      {:ok, _} = AuditLogContext.log_user_action(1, "recent_action", %{}, conn)

      # Verify we have 2 logs
      assert Repo.aggregate(AuditLog, :count) == 2

      # Run retention cleanup
      {:ok, count} = AuditLogContext.delete_old_logs()

      # Should have deleted 1 old log
      assert count == 1
      assert Repo.aggregate(AuditLog, :count) == 1

      # Verify the remaining log is the recent one
      remaining = Repo.one(AuditLog)
      assert remaining.action == "recent_action"
    end

    test "does not delete recent logs" do
      conn = %Plug.Conn{remote_ip: {127, 0, 0, 1}, req_headers: []}
      {:ok, _} = AuditLogContext.log_user_action(1, "recent_action", %{}, conn)

      {:ok, count} = AuditLogContext.delete_old_logs()

      assert count == 0
      assert Repo.aggregate(AuditLog, :count) == 1
    end
  end
end
