defmodule ViralEngine.Agents.OrchestratorTest do
  use ExUnit.Case, async: true

  alias ViralEngine.Agents.Orchestrator

  setup do
    # Start the GenServer for testing
    {:ok, pid} = Orchestrator.start_link()
    {:ok, pid: pid}
  end

  describe "trigger_event/1" do
    test "handles practice_completed event" do
      event = %{type: :practice_completed, user_id: 123, data: %{score: 95}}
      assert {:ok, decision} = Orchestrator.trigger_event(event)
      assert decision.event_type == :practice_completed
      assert decision.rationale == "Phase 1: Event logged, no loops active yet"
    end

    test "handles session_ended event" do
      event = %{type: :session_ended, user_id: 456, data: %{duration: 30}}
      assert {:ok, decision} = Orchestrator.trigger_event(event)
      assert decision.event_type == :session_ended
      assert decision.rationale == "Phase 1: Event logged, no loops active yet"
    end

    test "handles diagnostic_completed event" do
      event = %{type: :diagnostic_completed, user_id: 789, data: %{level: "advanced"}}
      assert {:ok, decision} = Orchestrator.trigger_event(event)
      assert decision.event_type == :diagnostic_completed
      assert decision.rationale == "Phase 1: Event logged, no loops active yet"
    end

    test "rejects invalid event format" do
      assert {:error, :invalid_event_format} = Orchestrator.trigger_event(%{invalid: true})
    end
  end

  describe "health/0" do
    test "returns health status" do
      health = Orchestrator.health()
      assert health.status == "healthy"
      assert is_integer(health.uptime)
      assert is_integer(health.active_loops)
      assert is_integer(health.cache_size)
    end
  end
end
