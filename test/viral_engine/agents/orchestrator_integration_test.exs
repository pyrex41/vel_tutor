defmodule ViralEngine.Agents.OrchestratorIntegrationTest do
  use ViralEngine.DataCase, async: false

  alias ViralEngine.Agents.Orchestrator
  alias ViralEngine.{ViralEvent, AgentDecision}

  setup do
    # Start the GenServer for testing
    {:ok, pid} = Orchestrator.start_link()
    {:ok, pid: pid}
  end

  describe "trigger_event/1 database integration" do
    test "logs event to viral_events table" do
      event = %{type: :practice_completed, user_id: 123, data: %{score: 95}}

      assert {:ok, _decision} = Orchestrator.trigger_event(event)

      # Check database
      viral_event = Repo.get_by(ViralEvent, event_type: "practice_completed", user_id: 123)
      assert viral_event
      assert viral_event.event_data == %{score: 95}
      assert viral_event.processed == true
    end

    test "logs decision to agent_decisions table" do
      event = %{type: :session_ended, user_id: 456, data: %{duration: 30}}

      assert {:ok, _decision} = Orchestrator.trigger_event(event)

      # Check database
      agent_decision =
        Repo.get_by(AgentDecision, agent_id: "orchestrator", decision_type: "event_routing")

      assert agent_decision
      assert agent_decision.success == true
      assert agent_decision.decision_data["event_type"] == "session_ended"
    end
  end
end
