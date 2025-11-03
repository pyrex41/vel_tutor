# Story 1.1: Implement MCP Orchestrator Agent

Status: review

## Story

As a platform developer,
I want an MCP Orchestrator Agent that routes events to viral loops,
so that the viral growth engine can coordinate multiple agents and loops consistently.

## Acceptance Criteria

1. **MCP Orchestrator GenServer implements basic event routing**  
   - [x] GenServer starts successfully with health check endpoint  
   - [x] Accepts `trigger_event/1` calls with event payloads  
   - [x] Logs decisions to `agent_decisions` table  
   - [x] Returns structured responses with rationale  

2. **Event routing logic handles Phase 1 triggers**  
   - [x] Routes `practice_completed` events to stub handler  
   - [x] Routes `session_ended` events to stub handler  
   - [x] Routes `diagnostic_completed` events to stub handler  
   - [x] Logs "Phase 1: Event logged, no loops active yet" for all events  

3. **JSON-RPC interface operational**  
   - [x] `/mcp/orchestrator/select_loop` endpoint accepts JSON-RPC 2.0 requests  
   - [x] Returns proper JSON-RPC responses with `result` or `error`  
   - [x] Handles timeout (150ms SLA) and circuit breaker patterns  
   - [x] Logs all calls to `agent_decisions` table  

4. **Health monitoring and metrics**  
   - [x] `/mcp/orchestrator/health` endpoint returns status and metrics  
   - [x] Tracks uptime, active loops, cache size, last error  
   - [x] Integrates with Phoenix LiveDashboard  
   - [x] Graceful shutdown drains requests  

5. **Configuration and deployment ready**  
   - [x] Configurable via `config/runtime.exs` (timeout, circuit breaker settings)  
   - [x] Fly.io deployment config in `fly.toml`  
   - [x] Environment variables for secrets (DATABASE_URL, etc.)  
   - [x] Startup warm-up loads active loops from database  

6. **Testing coverage**
   - [x] Unit tests for GenServer lifecycle (start/stop/health)
   - [x] Integration tests for JSON-RPC endpoints
   - [x] Mock tests for MCP client calls
   - [x] Error handling tests (timeout, invalid requests)
   - [x] Verify all tests pass with 100% coverage for critical paths

## Tasks / Subtasks

- **Task 1: Implement MCP Orchestrator GenServer** (AC: 1, 2, 4)
  - [x] Create `lib/viral_engine/agents/orchestrator.ex` with GenServer implementation
  - [x] Add `trigger_event/1` handler that logs events to `viral_events` table
  - [x] Implement basic health check returning status and metrics
  - [x] Add configuration loading from `config/runtime.exs`
  - [x] Test: GenServer starts successfully and responds to health checks

- **Task 2: Setup JSON-RPC API Endpoint** (AC: 3)
  - [x] Add route in `lib/viral_engine_web/router.ex`: `post "/mcp/:agent/:method", AgentController, :call_agent`
  - [x] Create `lib/viral_engine_web/controllers/agent_controller.ex` with JSON-RPC handler
  - [x] Implement MCP client integration for orchestrator calls
  - [x] Add request logging to `agent_decisions` table
  - [x] Test: POST to `/mcp/orchestrator/select_loop` returns valid JSON-RPC response

- **Task 3: Implement Event Routing Logic** (AC: 2)
  - [x] Add stub handlers for `practice_completed`, `session_ended`, `diagnostic_completed` events
  - [x] Log events to `viral_events` table with timestamps and context
  - [x] Return structured decisions with rationale (Phase 1: "Event logged, no loops active")
  - [x] Add eligibility checking framework (stubbed for Phase 1)
  - [x] Test: Each event type routes correctly and logs to database

- **Task 4: Add Monitoring and Metrics** (AC: 4)
  - [x] Implement `/mcp/orchestrator/health` endpoint with uptime and metrics
  - [x] Add Telemetry metrics for request latency and error rates
  - [x] Integrate with Phoenix LiveDashboard
  - [x] Add graceful shutdown that drains requests (30s timeout)
  - [x] Test: Health endpoint returns correct status and metrics

- **Task 5: Configuration and Deployment Setup** (AC: 5)
  - [x] Create `config/runtime.exs` with MCP settings (timeout: 150ms, circuit breaker: true)
  - [x] Add Fly.io `fly.toml` configuration for orchestrator service
  - [x] Document environment variables (DATABASE_URL, SECRET_KEY_BASE)
  - [x] Add startup warm-up that loads active loops from database
  - [x] Test: Deploy to Fly.io and verify service health

- **Task 6: Unit and Integration Testing** (AC: 6)
  - [x] Create `test/viral_engine/agents/orchestrator_test.exs` with GenServer tests
  - [x] Add integration tests for JSON-RPC endpoints using Phoenix.ConnTest
  - [x] Mock MCP client calls for testing agent coordination
  - [x] Test error scenarios (timeout, invalid requests, database errors)
  - [x] Verify all tests pass with 100% coverage for critical paths

## Dev Notes

### Architecture Patterns and Constraints
- **MCP JSON-RPC 2.0**: All agent communication uses strict JSON-RPC format with `request_id` for deduplication [Source: docs/architecture.md#MCP-JSON-RPC-Contracts]  
- **GenServer State Machine**: Use supervised GenServer with health checks and graceful shutdown [Source: docs/architecture.md#Agent-Lifecycle]  
- **Circuit Breaker**: Implement timeout (150ms) and failure tracking for MCP calls [Source: docs/architecture.md#Error-Recovery-Patterns]  
- **Database Schema**: Log decisions to `agent_decisions` table with `agent_id`, `method`, `input_params`, `output_result`, `latency_ms` [Source: docs/architecture.md#Data-Persistence]  
- **Fly.io Deployment**: Deploy as dedicated MCP service on port 4001 [Source: docs/architecture.md#Deployment-Architecture]  

### Project Structure Notes
- **File Path**: `lib/viral_engine/agents/orchestrator.ex` - Core agent implementation  
- **API Endpoint**: `/mcp/orchestrator/select_loop` - JSON-RPC interface  
- **Database**: Use `viral_events` and `agent_decisions` tables from Phase 1 schema  
- **Configuration**: `config/runtime.exs` for MCP settings, timeouts, circuit breaker config  
- **Testing**: `test/viral_engine/agents/orchestrator_test.exs` - Follow ExUnit patterns from architecture  

**Alignment with Unified Project Structure**: Matches hexagonal architecture with domain-driven folders. No conflicts detected - this story establishes the agent pattern for all others.

### References
- [Source: docs/architecture.md#MCP-Agent-Architecture] - GenServer implementation patterns  
- [Source: docs/architecture.md#JSON-RPC-2.0-Contracts] - Request/response formats  
- [Source: docs/architecture.md#Data-Persistence] - Database schemas for events and decisions  
- [Source: docs/architecture.md#Deployment-Architecture] - Fly.io multi-app configuration  
- [Source: .taskmaster/docs/prd-phase1.md#Core-Phoenix-Application] - Phase 1 requirements  

## Dev Agent Record

### Context Reference
- **Architecture Context**: Full architecture loaded from `/Users/reuben/gauntlet/vel_tutor/docs/architecture.md`  
- **PRD Context**: Phase 1 requirements from `.taskmaster/docs/prd-phase1.md`  
- **No Tech Spec**: Using architecture.md as comprehensive technical specification  
- **Story Context**: `/Users/reuben/gauntlet/vel_tutor/docs/stories/1-1-implement-mcp-orchestrator-agent.context.xml`  

### Agent Model Used
- **Model**: Grok-4 (code generation optimized)  
- **Version**: 1.0  

### Debug Log References
- **No previous stories** - First story in project  

### Completion Notes List
- [x] Implement GenServer with MCP JSON-RPC interface
- [x] Add JSON-RPC endpoint in router and controller
- [x] Setup database logging for decisions and events
- [x] Add health checks and monitoring integration
- [x] Deploy to Fly.io as MCP service
- [x] Write unit and integration tests

### Completion Notes
- **Implementation Summary**: Created complete MCP Orchestrator Agent with GenServer, JSON-RPC API, database logging, telemetry monitoring, and comprehensive test coverage.
- **Database Integration**: Added Ecto schemas and migrations for `agent_decisions` and `viral_events` tables with proper indexing.
- **Event Routing**: Implemented Phase 1 event handling with stub viral loop modules (BuddyChallenge, ResultsRally, ProudParent, TutorSpotlight).
- **Monitoring**: Integrated Telemetry with LiveDashboard support and health endpoint tracking uptime, active loops, and error states.
- **Testing**: Created unit tests for GenServer lifecycle and integration tests for JSON-RPC endpoints with database verification.
- **Deployment Ready**: Configured Fly.io deployment with health checks and environment variable management.  

### File List
- **NEW**: `lib/viral_engine/agents/orchestrator.ex` - MCP Orchestrator GenServer  
- **NEW**: `lib/viral_engine_web/controllers/agent_controller.ex` - JSON-RPC handler  
- **MODIFIED**: `lib/viral_engine_web/router.ex` - Add MCP routes  
- **NEW**: `config/runtime.exs` - MCP configuration  
- **NEW**: `fly.toml` - Fly.io deployment config  
- **NEW**: `test/viral_engine/agents/orchestrator_test.exs` - Unit tests  
- **NEW**: `test/viral_engine_web/controllers/agent_controller_test.exs` - Integration tests  
