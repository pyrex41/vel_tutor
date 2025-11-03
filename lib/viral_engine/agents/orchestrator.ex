defmodule ViralEngine.Agents.Orchestrator do
  @moduledoc """
  MCP Orchestrator Agent - Routes events to viral loops and coordinates agent decisions.

  This GenServer implements the core orchestration logic for the viral growth engine,
  handling event routing, decision logging, and health monitoring.
  """

  use GenServer
  require Logger

  alias ViralEngine.{Repo, AgentDecision, ViralEvent}

  # Client API

  @doc """
  Starts the Orchestrator GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an event for processing by the orchestrator.

  ## Parameters
  - event: Map containing event details (:type, :user_id, :data, :timestamp)

  ## Returns
  - {:ok, decision} - Successful processing with decision rationale
  - {:error, reason} - Processing failed
  """
  def trigger_event(event) do
    # 150ms SLA
    GenServer.call(__MODULE__, {:trigger_event, event}, 150)
  end

  @doc """
  Returns health status and metrics.
  """
  def health do
    GenServer.call(__MODULE__, :health)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Load configuration
    config = Application.get_env(:viral_engine, :mcp_orchestrator, [])

    state = %{
      uptime: System.system_time(:second),
      active_loops: 0,
      cache_size: 0,
      last_error: nil,
      config: config,
      viral_loops: %{
        buddy_challenge: ViralEngine.Agents.BuddyChallenge,
        results_rally: ViralEngine.Agents.ResultsRally,
        proud_parent: ViralEngine.Agents.ProudParent,
        tutor_spotlight: ViralEngine.Agents.TutorSpotlight
      }
    }

    Logger.info("MCP Orchestrator started")
    {:ok, state}
  end

  @impl true
  def handle_call({:trigger_event, event}, _from, state) do
    case process_event(event, state) do
      {:ok, decision} ->
        # Log decision to database
        log_decision(event, decision)
        {:reply, {:ok, decision}, state}

      {:error, reason} ->
        Logger.error("Event processing failed: #{inspect(reason)}")
        {:reply, {:error, reason}, %{state | last_error: reason}}
    end
  end

  @impl true
  def handle_call(:health, _from, state) do
    health_data = %{
      status: "healthy",
      uptime: System.system_time(:second) - state.uptime,
      active_loops: state.active_loops,
      cache_size: state.cache_size,
      last_error: state.last_error,
      timestamp: DateTime.utc_now()
    }

    {:reply, health_data, state}
  end

  # Private functions

  defp process_event(%{type: event_type} = event, state) do
    timestamp = DateTime.utc_now()

    # Log event to database
    viral_event = %ViralEvent{
      event_type: Atom.to_string(event_type),
      event_data: event[:data] || %{},
      user_id: event[:user_id],
      timestamp: timestamp,
      # Phase 1: no impact yet
      k_factor_impact: 0.0,
      processed: true
    }

    case Repo.insert(viral_event) do
      {:ok, _} -> Logger.info("Event logged to database: #{event_type}")
      {:error, changeset} -> Logger.error("Failed to log event: #{inspect(changeset.errors)}")
    end

    # Phase 1: Log events but no active loops yet
    decision = %{
      event_type: event_type,
      rationale: "Phase 1: Event logged, no loops active yet",
      timestamp: timestamp,
      user_id: event[:user_id],
      data: event[:data] || %{}
    }

    # Route to appropriate handler (stubbed for Phase 1)
    case event_type do
      :practice_completed -> handle_practice_completed(event, state)
      :session_ended -> handle_session_ended(event, state)
      :diagnostic_completed -> handle_diagnostic_completed(event, state)
      _ -> Logger.warn("Unknown event type: #{event_type}")
    end

    {:ok, decision}
  end

  defp process_event(_invalid_event, _state) do
    {:error, :invalid_event_format}
  end

  # Event handlers (stubbed for Phase 1)

  defp handle_practice_completed(event, _state) do
    Logger.info("Practice completed event: #{inspect(event)}")
    # TODO: Route to Buddy Challenge loop
  end

  defp handle_session_ended(event, _state) do
    Logger.info("Session ended event: #{inspect(event)}")
    # TODO: Route to Results Rally loop
  end

  defp handle_diagnostic_completed(event, _state) do
    Logger.info("Diagnostic completed event: #{inspect(event)}")
    # TODO: Route to Proud Parent loop
  end

  defp log_decision(event, decision) do
    agent_decision = %AgentDecision{
      agent_id: "orchestrator",
      decision_type: "event_routing",
      decision_data: decision,
      timestamp: decision.timestamp,
      # Phase 1: no loops
      viral_loop_id: nil,
      # TODO: measure actual latency
      latency_ms: 0,
      success: true
    }

    case Repo.insert(agent_decision) do
      {:ok, _} -> Logger.info("Decision logged to database")
      {:error, changeset} -> Logger.error("Failed to log decision: #{inspect(changeset.errors)}")
    end
  end
end
