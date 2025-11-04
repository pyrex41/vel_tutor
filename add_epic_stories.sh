#!/bin/bash

# Script to add all 48 epic stories to Task Master
# Each story references docs/epics.md for full context

echo "Adding Epic 1 stories..."

# Story 1.1
task-master add-task --prompt="Story 1.1: Implement MCP Orchestrator Agent ✅ IN REVIEW

Reference: docs/epics.md lines 40-54
Context: lib/vel_tutor/mcp_orchestrator.ex

As a platform developer, I want a core MCP orchestrator that can route tasks to appropriate AI providers, so that the system can intelligently balance performance, cost, and reliability.

Acceptance Criteria:
1. MCPOrchestrator context module created
2. Provider routing logic (GPT-4o/Llama 3.1)
3. Task status tracking (pending → in_progress → completed/failed)
4. Basic error handling with provider fallback
5. Unit tests for routing and state transitions

Tags: epic epic-1 foundation in-review"

# Story 1.2
task-master add-task --prompt="Story 1.2: Implement OpenAI Integration Adapter

Reference: docs/epics.md lines 57-73
Context: lib/vel_tutor/integration/openai_adapter.ex
Prerequisites: Story 1.1

As a platform developer, I want a robust OpenAI API integration with retry logic and error handling.

Acceptance Criteria:
1. OpenAIAdapter module with AdapterBehaviour
2. Chat completion API with streaming support
3. Retry logic with exponential backoff (3 attempts)
4. Circuit breaker pattern (5 failures/60s)
5. Token usage and cost tracking
6. Integration tests with Mox
7. API key validation on init

Tags: epic epic-1 integration openai"

# Story 1.3
task-master add-task --prompt="Story 1.3: Implement Groq Integration Adapter

Reference: docs/epics.md lines 76-92
Context: lib/vel_tutor/integration/groq_adapter.ex
Prerequisites: Story 1.2

As a platform developer, I want a high-performance Groq API integration for ultra-fast code generation.

Acceptance Criteria:
1. GroqAdapter module created
2. OpenAI-compatible client with Groq base URL
3. Llama 3.1 70B and Mixtral 8x7B support
4. Same retry and circuit breaker as OpenAI
5. Performance metrics tracking (P50/P95)
6. Integration tests for Groq error codes
7. Automatic fallback to OpenAI

Tags: epic epic-1 integration groq"

# Story 1.4
task-master add-task --prompt="Story 1.4: Implement Perplexity Integration Adapter

Reference: docs/epics.md lines 95-110
Context: lib/vel_tutor/integration/perplexity_adapter.ex
Prerequisites: Story 1.2

As a platform developer, I want a Perplexity Sonar integration for web-connected research tasks.

Acceptance Criteria:
1. PerplexityAdapter module created
2. Sonar Large model with web search
3. Custom HTTP client for Perplexity API format
4. Result caching for 24h (87% hit rate target)
5. Integration tests with mocks
6. Cost tracking and budget warnings

Tags: epic epic-1 integration perplexity"

# Story 1.5
task-master add-task --prompt="Story 1.5: Add Task Creation and Submission API Endpoint

Reference: docs/epics.md lines 113-129
Context: lib/vel_tutor_web/controllers/task_controller.ex
Prerequisites: Story 1.1

As a user, I want to submit AI tasks via REST API with clear task descriptions.

Acceptance Criteria:
1. POST /api/tasks endpoint implemented
2. Request validation (description, agent_id, authorization)
3. Task creation in PostgreSQL with pending status
4. JSON response with task ID and status URL
5. Rate limiting (10 concurrent tasks per user)
6. Controller tests with auth
7. API documentation updated

Tags: epic epic-1 api rest"

# Story 1.6
task-master add-task --prompt="Story 1.6: Add Task Status Tracking API Endpoints

Reference: docs/epics.md lines 132-148
Context: lib/vel_tutor_web/controllers/task_controller.ex
Prerequisites: Story 1.5

As a user, I want to check task status and retrieve results via API.

Acceptance Criteria:
1. GET /api/tasks/:id endpoint
2. GET /api/tasks endpoint with pagination (20/page)
3. Task metadata includes provider, latency, tokens, cost
4. Execution history in JSONB field
5. Error messages sanitized
6. Controller tests for all statuses
7. P95 response time <200ms

Tags: epic epic-1 api rest"

# Story 1.7
task-master add-task --prompt="Story 1.7: Implement Real-Time Task Progress via Server-Sent Events

Reference: docs/epics.md lines 151-167
Context: lib/vel_tutor_web/controllers/task_controller.ex
Prerequisites: Story 1.6

As a user, I want real-time progress updates for long-running tasks.

Acceptance Criteria:
1. GET /api/tasks/:id/stream SSE endpoint
2. Phoenix PubSub broadcasts task status changes
3. SSE connection <1s, streams until completion
4. Supports 50 concurrent SSE per user
5. Graceful closure on completion/failure
6. Integration tests for SSE lifecycle
7. Automatic reconnection guidance

Tags: epic epic-1 realtime sse"

# Story 1.8
task-master add-task --prompt="Story 1.8: Add Task Cancellation Support

Reference: docs/epics.md lines 170-184
Context: lib/vel_tutor_web/controllers/task_controller.ex
Prerequisites: Story 1.7

As a user, I want to cancel running tasks that are no longer needed.

Acceptance Criteria:
1. POST /api/tasks/:id/cancel endpoint
2. Graceful termination of provider requests
3. Task status updated to cancelled with timestamp
4. Partial results saved if available
5. Refund/credit logic for cancelled tasks
6. Controller tests for cancellation stages
7. Audit log entry for cancellation

Tags: epic epic-1 api cancellation"

# Story 1.9
task-master add-task --prompt="Story 1.9: Implement Agent Configuration Management

Reference: docs/epics.md lines 187-203
Context: lib/vel_tutor_web/controllers/agent_controller.ex
Prerequisites: Story 1.1

As a user, I want to create and configure AI agents with custom provider preferences.

Acceptance Criteria:
1. POST /api/agents endpoint with JSONB config
2. Agent config: provider, model, temperature, max_tokens, system prompt
3. PUT /api/agents/:id updates (preserves history)
4. DELETE /api/agents/:id soft-delete (cascade archive tasks)
5. Config validation: fields, providers, numeric ranges
6. Unit tests for validation edge cases
7. Database migration for agents table

Tags: epic epic-1 agents configuration"

# Story 1.10
task-master add-task --prompt="Story 1.10: Add Agent Testing and Dry-Run Capability

Reference: docs/epics.md lines 206-222
Context: lib/vel_tutor_web/controllers/agent_controller.ex
Prerequisites: Story 1.9

As a user, I want to test my agent configuration without executing real tasks.

Acceptance Criteria:
1. POST /api/agents/:id/test endpoint with dry_run
2. Provider connectivity check (API key, model)
3. Sample prompt with token/cost estimation
4. Response time measurement
5. Configuration optimization suggestions
6. Test results in agent metadata
7. Integration tests with mocked providers

Tags: epic epic-1 agents testing"

# Story 1.11
task-master add-task --prompt="Story 1.11: Implement Comprehensive Audit Logging

Reference: docs/epics.md lines 225-241
Context: lib/vel_tutor/audit_log_context.ex
Prerequisites: Story 1.5

As a platform administrator, I want all user actions and AI decisions logged with full context.

Acceptance Criteria:
1. AuditLogContext module created
2. All controller actions logged: user_id, action, payload, IP, user_agent
3. AI provider calls logged: task_id, provider, model, tokens, cost, latency
4. System events: circuit breaker trips, failovers, errors
5. 90-day retention policy enforced
6. Query interface for admins: filter by user, action, date
7. Privacy: no PII without consent flag

Tags: epic epic-1 audit compliance"

# Story 1.12
task-master add-task --prompt="Story 1.12: Add Health Check and System Monitoring Endpoint

Reference: docs/epics.md lines 244-260
Context: lib/vel_tutor_web/controllers/health_controller.ex
Prerequisites: Story 1.3

As a DevOps engineer, I want a health check endpoint that validates all system dependencies.

Acceptance Criteria:
1. GET /api/health endpoint returns 200 OK when healthy
2. Checks: database connectivity, at least one AI provider reachable
3. Response: uptime, version, active provider count
4. <500ms response time
5. 503 Service Unavailable with detailed errors
6. Public endpoint (no auth required)
7. Integration tests for healthy/unhealthy scenarios

Tags: epic epic-1 health monitoring"

echo "Adding Epic 2 stories..."

# Story 2.1
task-master add-task --prompt="Story 2.1: Implement Workflow State Management

Reference: docs/epics.md lines 275-290
Context: lib/vel_tutor/workflow_context.ex
Prerequisites: Epic 1 complete

As a user, I want to create multi-step workflows that maintain state between AI operations.

Acceptance Criteria:
1. WorkflowContext module created
2. Workflow schema with JSONB state field
3. State persistence in PostgreSQL
4. State access API for downstream tasks
5. State immutability (versioned)
6. Unit tests for persistence/retrieval
7. Database migration for workflows table

Tags: epic epic-2 workflows state"

# Story 2.2
task-master add-task --prompt="Story 2.2: Add Conditional Workflow Routing

Reference: docs/epics.md lines 293-308
Context: lib/vel_tutor/workflow_context.ex
Prerequisites: Story 2.1

As a user, I want workflows to route to different steps based on AI output or conditions.

Acceptance Criteria:
1. Routing rules in workflow config (if/then/else)
2. Condition evaluation: text matching, sentiment, confidence thresholds
3. Dynamic next-step selection based on results
4. Routing visualization in status API
5. Unit tests for all routing conditions
6. Example workflows: sentiment-based routing, confidence branching

Tags: epic epic-2 workflows routing"

# Story 2.3
task-master add-task --prompt="Story 2.3: Implement Human-in-the-Loop Approval Gates

Reference: docs/epics.md lines 311-326
Context: lib/vel_tutor/workflow_context.ex
Prerequisites: Story 2.1

As a user, I want workflows to pause for human approval at critical decision points.

Acceptance Criteria:
1. Approval gate definition in workflow config
2. Workflow pauses with awaiting_approval status
3. POST /api/workflows/:id/approve for approval/rejection
4. Notification webhook at approval gate
5. Timeout configuration (auto-reject after X hours)
6. Approval history in workflow metadata
7. Integration tests for approval flow

Tags: epic epic-2 workflows approval hitl"

# Story 2.4
task-master add-task --prompt="Story 2.4: Add Workflow Template System

Reference: docs/epics.md lines 329-344
Context: lib/vel_tutor/workflow_template_context.ex
Prerequisites: Story 2.3

As a user, I want to save successful workflows as reusable templates.

Acceptance Criteria:
1. POST /api/workflow-templates creates template
2. Template: step definitions, routing rules, approval gates, prompts
3. POST /api/workflows/from-template/:id instantiates
4. Template marketplace (public templates)
5. Template versioning (v1, v2)
6. Unit tests for instantiation with variable substitution

Tags: epic epic-2 workflows templates"

# Story 2.5
task-master add-task --prompt="Story 2.5: Implement Parallel Task Execution in Workflows

Reference: docs/epics.md lines 347-363
Context: lib/vel_tutor/workflow_context.ex
Prerequisites: Story 2.1

As a user, I want workflows to execute multiple independent AI tasks in parallel.

Acceptance Criteria:
1. Parallel task groups in workflow config
2. Task spawning using Task.async_stream
3. Result aggregation when all complete
4. Failure handling (continue vs abort)
5. Concurrency limits (max 5 parallel per workflow)
6. Performance tests: parallel vs sequential
7. Workflow visualization shows parallel branches

Tags: epic epic-2 workflows parallel"

# Story 2.6
task-master add-task --prompt="Story 2.6: Add Workflow Error Handling and Recovery

Reference: docs/epics.md lines 366-382
Context: lib/vel_tutor/workflow_context.ex
Prerequisites: Story 2.2

As a user, I want workflows to gracefully handle errors and support retry strategies.

Acceptance Criteria:
1. Per-step retry configuration (max attempts, backoff)
2. Error categorization (retryable vs terminal)
3. Workflow rollback capability (undo state changes)
4. Error notification webhooks
5. Manual recovery: POST /api/workflows/:id/retry-from-step/:step_id
6. Integration tests for failure scenarios
7. Error analytics: common failure points dashboard

Tags: epic epic-2 workflows error-handling"

echo "Adding Epic 3 stories..."

# Story 3.1
task-master add-task --prompt="Story 3.1: Implement Real-Time Metrics Collection

Reference: docs/epics.md lines 397-411
Context: lib/vel_tutor/metrics_context.ex
Prerequisites: Epic 1 complete

As a platform developer, I want comprehensive metrics collected for all AI operations.

Acceptance Criteria:
1. MetricsContext module created
2. Metrics: task count, latency (P50/P95/P99), cost, tokens, provider
3. Time-series data in PostgreSQL (1-min granularity)
4. Background job aggregates hourly/daily rollups
5. Metrics table partitioned by date
6. Unit tests for calculation accuracy
7. Database migration for metrics tables

Tags: epic epic-3 analytics metrics"

# Story 3.2
task-master add-task --prompt="Story 3.2: Build Provider Performance Dashboard

Reference: docs/epics.md lines 414-430
Context: lib/vel_tutor_web/live/performance_dashboard_live.ex
Prerequisites: Story 3.1

As a user, I want to visualize provider performance metrics over time.

Acceptance Criteria:
1. Phoenix LiveView at /dashboard/performance
2. Charts: latency by provider, success rate, fallback frequency
3. Time range selector (hour, day, week, month)
4. Provider comparison view (OpenAI vs Groq vs Perplexity)
5. Real-time updates via Phoenix PubSub
6. Export to CSV functionality
7. LiveView tests for dashboard rendering

Tags: epic epic-3 analytics dashboard liveview"

# Story 3.3
task-master add-task --prompt="Story 3.3: Implement Cost Tracking and Budget Dashboard

Reference: docs/epics.md lines 433-449
Context: lib/vel_tutor_web/live/cost_dashboard_live.ex
Prerequisites: Story 3.1

As a user, I want detailed cost breakdowns by provider, agent, and time period.

Acceptance Criteria:
1. Cost calculation per task (tokens × pricing)
2. Phoenix LiveView at /dashboard/costs
3. Charts: cost by provider, trends, budget burn rate
4. Budget alerts at 80%/100% of monthly limit
5. Cost projection (estimated month-end based on usage)
6. Per-agent cost breakdown
7. Unit tests for cost calculation with various pricing models

Tags: epic epic-3 analytics cost budget"

# Story 3.4
task-master add-task --prompt="Story 3.4: Add Anomaly Detection and Alerting

Reference: docs/epics.md lines 452-469
Context: lib/vel_tutor/anomaly_detection.ex
Prerequisites: Story 3.1

As a platform administrator, I want automated anomaly detection for unusual patterns.

Acceptance Criteria:
1. Anomaly detection algorithm (mean + 3σ)
2. Monitored metrics: error rate, latency, cost per task, failures
3. Alert triggers: latency spike, error rate >10%, cost anomaly
4. Notification system: email, webhook, in-app
5. Alert history dashboard at /dashboard/alerts
6. Integration tests for anomaly detection
7. False positive rate <5%

Tags: epic epic-3 analytics anomaly alerts"

# Story 3.5
task-master add-task --prompt="Story 3.5: Build Task Execution History Explorer

Reference: docs/epics.md lines 472-487
Context: lib/vel_tutor_web/live/task_history_live.ex
Prerequisites: Epic 1 complete

As a user, I want to search and filter my task execution history.

Acceptance Criteria:
1. Phoenix LiveView at /dashboard/tasks with search/filters
2. Search by: description, date range, status, provider, agent
3. Pagination (50 tasks per page)
4. Task detail drill-down (full request/response, timing)
5. Export filtered results to JSON/CSV
6. LiveView tests for search and filtering
7. Query optimization (indexes on filter fields)

Tags: epic epic-3 analytics history search"

# Story 3.6
task-master add-task --prompt="Story 3.6: Implement Performance Benchmarking Tool

Reference: docs/epics.md lines 490-506
Context: lib/vel_tutor_web/live/benchmarks_live.ex
Prerequisites: Story 3.1

As a user, I want to benchmark different providers and configurations side-by-side.

Acceptance Criteria:
1. Benchmark runner: same prompt to multiple providers
2. Results comparison: latency, cost, output quality (user rates 1-5)
3. Statistical significance testing
4. Benchmark history for tracking improvements
5. Pre-configured suites (code generation, reasoning, research)
6. Phoenix LiveView at /dashboard/benchmarks
7. Integration tests for benchmark execution

Tags: epic epic-3 analytics benchmark"

echo "Adding Epic 4 stories..."

# Story 4.1
task-master add-task --prompt="Story 4.1: Implement Multi-Tenant Architecture

Reference: docs/epics.md lines 521-535
Context: lib/vel_tutor/organization_context.ex
Prerequisites: Epic 1 complete

As a platform administrator, I want to support multiple organizations with data isolation.

Acceptance Criteria:
1. Organization schema with tenant_id foreign key
2. Row-level security (RLS) policies in PostgreSQL
3. Tenant context set per request via Guardian claims
4. Database query scoping (auto-filtered by tenant_id)
5. Tenant onboarding API: POST /api/organizations
6. Migration script to add tenant_id to existing tables
7. Security audit: no cross-tenant data leakage

Tags: epic epic-4 enterprise multi-tenancy"

# Story 4.2
task-master add-task --prompt="Story 4.2: Build Advanced RBAC System

Reference: docs/epics.md lines 538-554
Context: lib/vel_tutor/rbac_context.ex
Prerequisites: Story 4.1

As an organization administrator, I want granular role-based permissions.

Acceptance Criteria:
1. Permission system: create_agent, execute_task, view_analytics, manage_users
2. Role definitions: org_admin, agent_manager, task_executor, viewer
3. Permission checks at controller and context layers
4. PUT /api/users/:id/roles endpoint for role assignment
5. Audit logging for permission changes
6. Unit tests for all permission combinations
7. Migration for roles and permissions tables

Tags: epic epic-4 enterprise rbac security"

# Story 4.3
task-master add-task --prompt="Story 4.3: Add Batch Task Operations

Reference: docs/epics.md lines 557-572
Context: lib/vel_tutor/batch_context.ex
Prerequisites: Epic 1 complete

As a user, I want to submit and manage multiple tasks as a batch.

Acceptance Criteria:
1. POST /api/batches endpoint accepts task array
2. Batch execution with concurrency control (max 20 parallel)
3. Batch status tracking (X/Y tasks complete)
4. Partial success handling (continue on failures)
5. Batch cancellation: POST /api/batches/:id/cancel
6. Batch results aggregation and download (JSON/CSV)
7. Integration tests for batch lifecycle

Tags: epic epic-4 enterprise batch"

# Story 4.4
task-master add-task --prompt="Story 4.4: Implement Streaming Response Support

Reference: docs/epics.md lines 575-591
Context: lib/vel_tutor/integration/openai_adapter.ex
Prerequisites: Story 1.2

As a user, I want to receive AI responses as they're generated (streaming).

Acceptance Criteria:
1. OpenAI streaming API integration (SSE from provider)
2. GET /api/tasks/:id/stream-response for token-by-token delivery
3. Groq streaming support (OpenAI-compatible)
4. Response buffering (deliver every 10 tokens or 100ms)
5. Graceful handling of stream interruptions
6. Integration tests for streaming lifecycle
7. Performance: <50ms time-to-first-token

Tags: epic epic-4 enterprise streaming"

# Story 4.5
task-master add-task --prompt="Story 4.5: Add Custom Model Fine-Tuning Support

Reference: docs/epics.md lines 594-610
Context: lib/vel_tutor/fine_tuning_context.ex
Prerequisites: Story 1.2

As a user, I want to fine-tune OpenAI models on my data and use them via vel_tutor.

Acceptance Criteria:
1. Fine-tuning job creation: POST /api/fine-tuning-jobs
2. Training data upload (JSONL format)
3. Job status tracking (pending, running, completed, failed)
4. Fine-tuned model registration (add to agent config)
5. Cost tracking for fine-tuning operations
6. Integration with OpenAI fine-tuning API
7. Unit tests for job lifecycle management

Tags: epic epic-4 enterprise fine-tuning"

# Story 4.6
task-master add-task --prompt="Story 4.6: Implement Rate Limit Customization

Reference: docs/epics.md lines 613-629
Context: lib/vel_tutor/rate_limit_plug.ex
Prerequisites: Epic 1 complete

As an organization administrator, I want to set custom rate limits per user or team.

Acceptance Criteria:
1. Rate limit config per user/org (tasks/hour, concurrent tasks)
2. Rate limit enforcement at API layer (Plug middleware)
3. PUT /api/users/:id/rate-limits endpoint (admin only)
4. 429 response with retry-after header
5. Rate limit usage dashboard (current vs limit)
6. Unit tests for rate limit enforcement
7. Background job resets hourly limits

Tags: epic epic-4 enterprise rate-limiting"

# Story 4.7
task-master add-task --prompt="Story 4.7: Add Webhook Notification System

Reference: docs/epics.md lines 632-648
Context: lib/vel_tutor/webhook_context.ex
Prerequisites: Epic 1 complete

As a user, I want to receive webhook notifications for task completion and errors.

Acceptance Criteria:
1. Webhook configuration: POST /api/webhooks with URL and event types
2. Events: task.completed, task.failed, batch.completed, workflow.paused
3. Webhook delivery with retry (3 attempts, exponential backoff)
4. Webhook signature verification (HMAC-SHA256)
5. Delivery history and failure logs
6. Integration tests with webhook receiver mock
7. Webhook test endpoint: POST /api/webhooks/:id/test

Tags: epic epic-4 enterprise webhooks"

# Story 4.8
task-master add-task --prompt="Story 4.8: Implement SOC 2 Compliance Hardening

Reference: docs/epics.md lines 651-667
Context: Multiple security files
Prerequisites: Epic 1 + Epic 3 complete

As a platform administrator, I want security controls aligned with SOC 2 requirements.

Acceptance Criteria:
1. Encryption at rest for sensitive fields (API keys, user data)
2. TLS 1.3 enforced for all connections
3. Session management hardening (secure cookies, CSRF)
4. Access log audit trail (all data access with justification)
5. Automated security scanning (OWASP dependency check)
6. Penetration testing report and remediation
7. Compliance documentation generated

Tags: epic epic-4 enterprise security compliance soc2"

# Story 4.9
task-master add-task --prompt="Story 4.9: Add Horizontal Scaling Support

Reference: docs/epics.md lines 670-686
Context: config/runtime.exs, fly.toml
Prerequisites: Epic 1 complete + load testing

As a DevOps engineer, I want vel_tutor to scale horizontally across multiple Fly.io machines.

Acceptance Criteria:
1. Stateless API design verification
2. Database connection pooling optimized (PgBouncer)
3. Phoenix PubSub multi-node (Redis adapter)
4. Distributed task queue (Oban with PostgreSQL)
5. Load testing: 1000 concurrent requests without errors
6. Auto-scaling policy configuration (Fly.io)
7. Multi-region deployment guide

Tags: epic epic-4 enterprise scaling devops"

# Story 4.10
task-master add-task --prompt="Story 4.10: Implement GraphQL API Alternative

Reference: docs/epics.md lines 689-705
Context: lib/vel_tutor_web/schema.ex
Prerequisites: Epic 1 + Epic 2 complete

As an API consumer, I want a GraphQL endpoint alongside REST.

Acceptance Criteria:
1. Absinthe library integrated for GraphQL
2. Schema definitions: User, Agent, Task, Workflow
3. Queries: user profile, agent list, task history, metrics
4. Mutations: create task, update agent, cancel task
5. Subscriptions: task status updates (WebSocket)
6. GraphQL playground at /api/graphiql
7. Integration tests for all queries/mutations

Tags: epic epic-4 enterprise graphql api"

echo "✅ All 48 epic stories added to Task Master!"
echo "Run 'task-master list' to see all tasks"
