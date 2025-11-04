defmodule ViralEngine.Agents.Orchestrator do
  @moduledoc """
  MCP Orchestrator Agent - Routes events to viral loops and coordinates agent decisions.

  This GenServer implements the core orchestration logic for the viral growth engine,
  handling event routing, decision logging, and health monitoring.
  """

  use GenServer
  require Logger

  alias ViralEngine.{Repo, AgentDecision, ViralEvent, Agents.ProviderRouter}

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

  @doc """
  Selects an AI provider based on criteria.

  ## Parameters
  - criteria: Map with selection criteria (e.g., %{reliability: :high, cost_sensitive: true})

  ## Returns
  - Selected provider atom (:gpt_4o or :llama_3_1)
  """
  def select_provider(criteria \\ %{}) do
    GenServer.call(__MODULE__, {:select_provider, criteria})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
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
      },
      providers: [:gpt_4o, :llama_3_1],
      provider_index: 0
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

  @impl true
  def handle_call({:select_provider, criteria}, _from, state) do
    provider = select_provider_logic(criteria, state)
    new_index = rem(state.provider_index + 1, length(state.providers))
    new_state = %{state | provider_index: new_index}

    Logger.info("Selected provider: #{provider} for criteria: #{inspect(criteria)}")
    {:reply, provider, new_state}
  end

  @impl true
  def handle_cast({:cancel_task, task_id}, state) do
    Logger.info("Cancellation requested for task #{task_id}")

    # TODO: Implement actual task cancellation logic
    # This would involve:
    # 1. Finding the running task process
    # 2. Sending it a graceful shutdown signal
    # 3. Cleaning up any pending work
    # 4. Notifying the task tracking system

    # For now, just log the cancellation
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "task:#{task_id}",
      {:task_update, %{status: "cancelling", message: "Cancellation in progress"}}
    )

    {:noreply, state}
  end

  # Private functions

  defp select_provider_logic(criteria, _state) do
    # Use ProviderRouter for intelligent selection based on criteria
    case ProviderRouter.select_provider(criteria) do
      %ViralEngine.Provider{name: name} -> String.to_atom(String.replace(name, "-", "_"))
      other -> other
    end
  end

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
      _ -> Logger.warning("Unknown event type: #{event_type}")
    end

    {:ok, decision}
  end

  defp process_event(_invalid_event, _state) do
    {:error, :invalid_event_format}
  end

  # Event handlers (stubbed for Phase 1)

  defp handle_practice_completed(event, state) do
    Logger.info("Practice completed event: #{inspect(event)}")

    # Select provider for AI decision making
    criteria = %{priority: :performance, weights: %{reliability: 0.5, performance: 0.5}}
    provider = select_provider_logic(criteria, state)

    # TODO: Route to Buddy Challenge loop with selected provider
    Logger.info("Routing practice completed to Buddy Challenge with provider: #{provider}")

    # Example: Trigger AI analysis
    decision = %{
      type: :ai_analysis,
      provider: provider,
      event_data: event,
      rationale: "Selected #{provider} for high-performance practice analysis"
    }

    # Log the AI routing decision
    log_ai_decision(decision)
  end

  defp handle_session_ended(event, _state) do
    Logger.info("Session ended event: #{inspect(event)}")
    # TODO: Route to Results Rally loop
  end

  defp handle_diagnostic_completed(event, _state) do
    Logger.info("Diagnostic completed event: #{inspect(event)}")
    # TODO: Route to Proud Parent loop
  end

  defp log_decision(_event, decision) do
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

  defp log_ai_decision(decision) do
    agent_decision = %AgentDecision{
      agent_id: "orchestrator",
      decision_type: "ai_routing",
      decision_data: decision,
      timestamp: DateTime.utc_now(),
      viral_loop_id: decision[:loop_id],
      # TODO: measure actual AI call latency
      latency_ms: 0,
      success: true
    }

    case Repo.insert(agent_decision) do
      {:ok, _} ->
        Logger.info("AI decision logged: #{decision.type}")

      {:error, changeset} ->
        Logger.error("Failed to log AI decision: #{inspect(changeset.errors)}")
    end
  end
end
