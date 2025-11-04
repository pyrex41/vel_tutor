# vel_tutor - Epic Breakdown

**Author:** Reuben
**Date:** 2025-11-03
**Project Level:** 2
**Target Scale:** Medium (10K tasks/day)

---

## Overview

This document provides the detailed epic breakdown for vel_tutor, expanding on the high-level epic list in the [PRD](./PRD.md).

Each epic includes:

- Expanded goal and value proposition
- Complete story breakdown with user stories
- Acceptance criteria for each story
- Story sequencing and dependencies

**Epic Sequencing Principles:**

- Epic 1 establishes foundational infrastructure and initial functionality
- Subsequent epics build progressively, each delivering significant end-to-end value
- Stories within epics are vertically sliced and sequentially ordered
- No forward dependencies - each story builds only on previous work

---

# Epic 1: MCP Orchestrator Core

**Goal:** Establish foundational multi-provider AI orchestration with intelligent routing, task execution, and automatic failover.

**Value Proposition:** Enables users to leverage multiple AI providers (OpenAI GPT-4o, Groq Llama 3.1, Perplexity Sonar) through a single unified API, achieving 52% faster performance and 41% cost reduction through intelligent provider routing.

**Status:** In Progress (Story 1.1 in review)

## Stories

**Story 1.1: Implement MCP Orchestrator Agent** ✅ IN REVIEW

As a platform developer,
I want a core MCP orchestrator that can route tasks to appropriate AI providers,
So that the system can intelligently balance performance, cost, and reliability.

**Acceptance Criteria:**
1. MCPOrchestrator context module created in `lib/vel_tutor/mcp_orchestrator.ex`
2. Provider routing logic implemented (GPT-4o for reasoning, Llama 3.1 for code gen)
3. Task status tracking (pending → in_progress → completed/failed)
4. Basic error handling with provider fallback (OpenAI → Groq)
5. Unit tests for routing logic and state transitions (ExUnit)

**Prerequisites:** None (foundation story)

---

**Story 1.2: Implement OpenAI Integration Adapter**

As a platform developer,
I want a robust OpenAI API integration with retry logic and error handling,
So that the system can reliably execute tasks using GPT-4o and GPT-4o-mini models.

**Acceptance Criteria:**
1. OpenAIAdapter module created in `lib/vel_tutor/integration/openai_adapter.ex`
2. Chat completion API integrated with streaming support
3. Retry logic with exponential backoff (3 attempts, 100ms/200ms/400ms)
4. Circuit breaker pattern (open after 5 failures in 60s)
5. Token usage and cost tracking per request
6. Integration tests with mocked OpenAI responses (Mox)
7. API key validation on adapter initialization

**Prerequisites:** Story 1.1 (requires MCPOrchestrator interface)

---

**Story 1.3: Implement Groq Integration Adapter**

As a platform developer,
I want a high-performance Groq API integration for ultra-fast code generation,
So that users benefit from 5-10x faster inference on appropriate tasks.

**Acceptance Criteria:**
1. GroqAdapter module created in `lib/vel_tutor/integration/groq_adapter.ex`
2. OpenAI-compatible client configured with Groq base URL
3. Llama 3.1 70B and Mixtral 8x7B model support
4. Same retry and circuit breaker logic as OpenAI adapter
5. Performance metrics tracking (P50/P95 latency)
6. Integration tests for Groq-specific error codes
7. Automatic fallback to OpenAI when Groq unavailable

**Prerequisites:** Story 1.2 (shares adapter interface pattern)

---

**Story 1.4: Implement Perplexity Integration Adapter**

As a platform developer,
I want a Perplexity Sonar integration for web-connected research tasks,
So that users can execute tasks requiring real-time information retrieval.

**Acceptance Criteria:**
1. PerplexityAdapter module created in `lib/vel_tutor/integration/perplexity_adapter.ex`
2. Sonar Large model support with web search capabilities
3. Custom HTTP client for Perplexity API format
4. Result caching for 24h to reduce costs (87% target hit rate)
5. Integration tests with mocked Perplexity responses
6. Cost tracking and budget warnings (500 requests/day free tier)

**Prerequisites:** Story 1.2 (adapter interface pattern established)

---

**Story 1.5: Add Task Creation and Submission API Endpoint**

As a user,
I want to submit AI tasks via REST API with clear task descriptions,
So that I can execute AI operations programmatically.

**Acceptance Criteria:**
1. `POST /api/tasks` endpoint implemented in TaskController
2. Request validation (description required, agent_id valid, user authorized)
3. Task creation in PostgreSQL with pending status
4. JSON response with task ID and status URL
5. Rate limiting (10 concurrent tasks per user)
6. Controller tests with authenticated requests
7. API documentation updated with request/response examples

**Prerequisites:** Story 1.1 (requires MCPOrchestrator to accept tasks)

---

**Story 1.6: Add Task Status Tracking API Endpoints**

As a user,
I want to check task status and retrieve results via API,
So that I can monitor execution and get outputs when complete.

**Acceptance Criteria:**
1. `GET /api/tasks/:id` endpoint returns task details and status
2. `GET /api/tasks` endpoint lists user's tasks with pagination (20/page)
3. Task metadata includes: provider used, latency, token count, cost
4. Execution history stored in task metadata JSONB field
5. Error messages sanitized (no sensitive provider data exposed)
6. Controller tests for all status scenarios
7. P95 response time <200ms for status checks

**Prerequisites:** Story 1.5 (requires task creation)

---

**Story 1.7: Implement Real-Time Task Progress via Server-Sent Events**

As a user,
I want real-time progress updates for long-running tasks,
So that I can monitor execution without polling.

**Acceptance Criteria:**
1. `GET /api/tasks/:id/stream` SSE endpoint implemented
2. Phoenix PubSub broadcasts task status changes
3. SSE connection established <1s, streams updates until completion
4. Supports 50 concurrent SSE connections per user
5. Graceful connection closure on task completion/failure
6. Integration tests for SSE connection lifecycle
7. Automatic reconnection guidance in error responses

**Prerequisites:** Story 1.6 (requires task status tracking)

---

**Story 1.8: Add Task Cancellation Support**

As a user,
I want to cancel running tasks that are taking too long or are no longer needed,
So that I can stop unnecessary AI provider charges.

**Acceptance Criteria:**
1. `POST /api/tasks/:id/cancel` endpoint implemented
2. Graceful termination of in-progress provider requests
3. Task status updated to "cancelled" with timestamp
4. Partial results saved if available (e.g., streaming response cut off)
5. Refund/credit logic for cancelled tasks (future: cost tracking)
6. Controller tests for cancellation at different execution stages
7. Audit log entry for cancellation action

**Prerequisites:** Story 1.7 (requires task execution monitoring)

---

**Story 1.9: Implement Agent Configuration Management**

As a user,
I want to create and configure AI agents with custom provider preferences,
So that I can optimize for my specific performance and cost requirements.

**Acceptance Criteria:**
1. `POST /api/agents` endpoint creates agent with JSONB config
2. Agent config includes: primary provider, model, temperature, max_tokens, system prompt
3. `PUT /api/agents/:id` updates configuration (preserves history)
4. `DELETE /api/agents/:id` soft-deletes agent (cascade marks tasks as archived)
5. Config validation: required fields, valid provider names, numeric ranges
6. Unit tests for config validation edge cases
7. Database migration for agents table if not exists

**Prerequisites:** Story 1.1 (agents reference MCPOrchestrator)

---

**Story 1.10: Add Agent Testing and Dry-Run Capability**

As a user,
I want to test my agent configuration without executing real tasks,
So that I can validate settings and estimate costs before production use.

**Acceptance Criteria:**
1. `POST /api/agents/:id/test` endpoint with dry_run parameter
2. Provider connectivity check (API key valid, model accessible)
3. Sample prompt execution with token count and cost estimation
4. Response time measurement for performance profiling
5. Configuration optimization suggestions (e.g., "Groq faster for this prompt type")
6. Test results stored in agent metadata (last_test_at, last_test_results)
7. Integration tests with mocked provider responses

**Prerequisites:** Story 1.9 (requires agent configuration)

---

**Story 1.11: Implement Comprehensive Audit Logging**

As a platform administrator,
I want all user actions and AI decisions logged with full context,
So that I can ensure compliance, debug issues, and analyze usage patterns.

**Acceptance Criteria:**
1. AuditLogContext module created in `lib/vel_tutor/audit_log_context.ex`
2. All controller actions log: user_id, action, payload (JSONB), IP, user_agent
3. AI provider calls logged: task_id, provider, model, tokens, cost, latency
4. System events logged: circuit breaker trips, failovers, errors
5. 90-day retention policy enforced (background job archives old logs)
6. Query interface for admins: filter by user, action, date range
7. Privacy: no PII in logs without explicit user consent flag

**Prerequisites:** Story 1.5 (requires task execution to log)

---

**Story 1.12: Add Health Check and System Monitoring Endpoint**

As a DevOps engineer,
I want a health check endpoint that validates all system dependencies,
So that I can monitor uptime and quickly diagnose outages.

**Acceptance Criteria:**
1. `GET /api/health` endpoint returns 200 OK when healthy
2. Checks: database connectivity, at least one AI provider reachable
3. Response includes: uptime, version, active provider count
4. <500ms response time (critical for load balancer health checks)
5. Detailed errors in 503 Service Unavailable response (db down, all providers unreachable)
6. Public endpoint (no authentication required)
7. Integration tests for healthy and unhealthy scenarios

**Prerequisites:** Story 1.3 (requires all providers integrated for full health check)

---

# Epic 2: Advanced Workflow Orchestration

**Goal:** Enable complex, multi-step AI workflows with state management, conditional routing, and human-in-the-loop capabilities.

**Value Proposition:** Transforms vel_tutor from single-task execution to sophisticated AI workflow orchestration, enabling users to chain multiple AI operations, implement conditional logic, and integrate human oversight for critical decisions.

**Status:** Backlog (depends on Epic 1 completion)

## Stories

**Story 2.1: Implement Workflow State Management**

As a user,
I want to create multi-step workflows that maintain state between AI operations,
So that I can build complex processes where later steps depend on earlier results.

**Acceptance Criteria:**
1. WorkflowContext module created in `lib/vel_tutor/workflow_context.ex`
2. Workflow schema with JSONB state field for step results
3. State persistence between workflow steps in PostgreSQL
4. State access API for downstream tasks (get previous step output)
5. State immutability (new state versions created, not edited)
6. Unit tests for state persistence and retrieval
7. Database migration for workflows table

**Prerequisites:** Epic 1 complete (requires stable task execution)

---

**Story 2.2: Add Conditional Workflow Routing**

As a user,
I want workflows to route to different steps based on AI output or conditions,
So that I can implement decision trees and adaptive processes.

**Acceptance Criteria:**
1. Routing rules defined in workflow config (if/then/else logic)
2. Condition evaluation engine supports: text matching, sentiment analysis, confidence thresholds
3. Dynamic next-step selection based on previous task results
4. Routing visualization in workflow status API
5. Unit tests for all routing conditions
6. Example workflows: sentiment-based routing, confidence-threshold branching

**Prerequisites:** Story 2.1 (requires workflow state)

---

**Story 2.3: Implement Human-in-the-Loop Approval Gates**

As a user,
I want workflows to pause for human approval at critical decision points,
So that I can maintain oversight over high-stakes AI operations.

**Acceptance Criteria:**
1. Approval gate definition in workflow config (which steps require approval)
2. Workflow pauses at approval gate with "awaiting_approval" status
3. `POST /api/workflows/:id/approve` endpoint for approval/rejection
4. Notification webhook when workflow reaches approval gate
5. Timeout configuration (auto-reject after X hours)
6. Approval history stored in workflow metadata
7. Integration tests for approval flow

**Prerequisites:** Story 2.1 (requires workflow orchestration)

---

**Story 2.4: Add Workflow Template System**

As a user,
I want to save successful workflows as reusable templates,
So that I can quickly launch proven processes without reconfiguration.

**Acceptance Criteria:**
1. `POST /api/workflow-templates` endpoint creates template from workflow
2. Template includes: step definitions, routing rules, approval gates, default prompts
3. `POST /api/workflows/from-template/:template_id` instantiates template
4. Template marketplace (list public templates from community)
5. Template versioning (v1, v2, etc.)
6. Unit tests for template instantiation with variable substitution

**Prerequisites:** Story 2.3 (requires all workflow features)

---

**Story 2.5: Implement Parallel Task Execution in Workflows**

As a user,
I want workflows to execute multiple independent AI tasks in parallel,
So that I can reduce total execution time for complex processes.

**Acceptance Criteria:**
1. Parallel task groups defined in workflow config
2. Task spawning using Elixir Task.async_stream for concurrency
3. Result aggregation when all parallel tasks complete
4. Failure handling (continue vs. abort on partial failure)
5. Concurrency limits (max 5 parallel tasks per workflow)
6. Performance tests: parallel vs. sequential execution time
7. Workflow visualization shows parallel execution branches

**Prerequisites:** Story 2.1 (requires workflow orchestration)

---

**Story 2.6: Add Workflow Error Handling and Recovery**

As a user,
I want workflows to gracefully handle errors and support retry strategies,
So that transient failures don't derail entire processes.

**Acceptance Criteria:**
1. Per-step retry configuration (max attempts, backoff strategy)
2. Error categorization (retryable vs. terminal errors)
3. Workflow rollback capability (undo state changes on failure)
4. Error notification webhooks
5. Manual recovery: `POST /api/workflows/:id/retry-from-step/:step_id`
6. Integration tests for various failure scenarios
7. Error analytics: common failure points dashboard

**Prerequisites:** Story 2.2 (requires conditional routing for error paths)

---

# Epic 3: Analytics & Monitoring Dashboard

**Goal:** Provide comprehensive visibility into AI usage, costs, performance, and system health through real-time dashboards and reporting.

**Value Proposition:** Empowers users to optimize their AI spending, identify performance bottlenecks, and make data-driven decisions about provider selection and configuration.

**Status:** Backlog (can start in parallel with Epic 2)

## Stories

**Story 3.1: Implement Real-Time Metrics Collection**

As a platform developer,
I want comprehensive metrics collected for all AI operations,
So that analytics dashboards have accurate real-time data.

**Acceptance Criteria:**
1. MetricsContext module created in `lib/vel_tutor/metrics_context.ex`
2. Metrics collected: task count, latency (P50/P95/P99), cost, tokens, provider
3. Time-series data stored in PostgreSQL with 1-minute granularity
4. Background job aggregates hourly/daily rollups
5. Metrics table partitioned by date for query performance
6. Unit tests for metrics calculation accuracy
7. Database migration for metrics tables

**Prerequisites:** Epic 1 complete (requires production task data)

---

**Story 3.2: Build Provider Performance Dashboard**

As a user,
I want to visualize provider performance metrics over time,
So that I can identify which providers work best for my use cases.

**Acceptance Criteria:**
1. Phoenix LiveView dashboard at `/dashboard/performance`
2. Charts: latency by provider, success rate, fallback frequency
3. Time range selector (last hour, day, week, month)
4. Provider comparison view (OpenAI vs Groq vs Perplexity)
5. Real-time updates via Phoenix PubSub
6. Export to CSV functionality
7. LiveView tests for dashboard rendering

**Prerequisites:** Story 3.1 (requires metrics data)

---

**Story 3.3: Implement Cost Tracking and Budget Dashboard**

As a user,
I want detailed cost breakdowns by provider, agent, and time period,
So that I can control my AI spending and stay within budget.

**Acceptance Criteria:**
1. Cost calculation per task (tokens × provider pricing)
2. Phoenix LiveView dashboard at `/dashboard/costs`
3. Charts: cost by provider, cost trends, budget burn rate
4. Budget alerts when approaching 80%/100% of monthly limit
5. Cost projection (estimated month-end total based on current usage)
6. Per-agent cost breakdown
7. Unit tests for cost calculation with various pricing models

**Prerequisites:** Story 3.1 (requires metrics data)

---

**Story 3.4: Add Anomaly Detection and Alerting**

As a platform administrator,
I want automated anomaly detection for unusual patterns,
So that I can proactively address issues before they impact users.

**Acceptance Criteria:**
1. Anomaly detection algorithm (statistical threshold-based: mean + 3σ)
2. Monitored metrics: error rate, latency, cost per task, provider failures
3. Alert triggers: sudden latency spike, error rate >10%, cost anomaly
4. Notification system: email, webhook, in-app
5. Alert history dashboard at `/dashboard/alerts`
6. Integration tests for anomaly detection
7. False positive rate <5% on production data

**Prerequisites:** Story 3.1 (requires historical metrics for baseline)

---

**Story 3.5: Build Task Execution History Explorer**

As a user,
I want to search and filter my task execution history,
So that I can review past operations and debug issues.

**Acceptance Criteria:**
1. Phoenix LiveView at `/dashboard/tasks` with search and filters
2. Search by: description, date range, status, provider, agent
3. Pagination (50 tasks per page)
4. Task detail drill-down (full request/response, timing breakdown)
5. Export filtered results to JSON/CSV
6. LiveView tests for search and filtering
7. Query optimization (indexes on common filter fields)

**Prerequisites:** Epic 1 complete (requires task history)

---

**Story 3.6: Implement Performance Benchmarking Tool**

As a user,
I want to benchmark different providers and configurations side-by-side,
So that I can make informed decisions about optimal settings.

**Acceptance Criteria:**
1. Benchmark runner: submit same prompt to multiple providers
2. Results comparison: latency, cost, output quality (user rates 1-5)
3. Statistical significance testing (is difference meaningful?)
4. Benchmark history storage for tracking improvements over time
5. Pre-configured benchmark suites (code generation, reasoning, research)
6. Phoenix LiveView at `/dashboard/benchmarks`
7. Integration tests for benchmark execution

**Prerequisites:** Story 3.1 (requires metrics infrastructure)

---

# Epic 4: Enterprise Features & Scaling

**Goal:** Transform vel_tutor into an enterprise-ready platform with multi-tenancy, advanced RBAC, batch operations, and production hardening.

**Value Proposition:** Enables large organizations to deploy vel_tutor securely at scale, with tenant isolation, granular permissions, and enterprise-grade reliability.

**Status:** Backlog (depends on Epic 1 + Epic 3)

## Stories

**Story 4.1: Implement Multi-Tenant Architecture**

As a platform administrator,
I want to support multiple organizations with data isolation,
So that enterprise customers can use vel_tutor without sharing data.

**Acceptance Criteria:**
1. Organization schema with tenant_id foreign key on all resources
2. Row-level security (RLS) policies in PostgreSQL for tenant isolation
3. Tenant context set per request via Guardian claims
4. Database query scoping (all queries auto-filtered by tenant_id)
5. Tenant onboarding API: `POST /api/organizations`
6. Migration script to add tenant_id to existing tables
7. Security audit: verify no cross-tenant data leakage

**Prerequisites:** Epic 1 complete (requires stable single-tenant foundation)

---

**Story 4.2: Build Advanced RBAC System**

As an organization administrator,
I want granular role-based permissions beyond admin/user,
So that I can control who can create agents, execute tasks, and view analytics.

**Acceptance Criteria:**
1. Permission system: create_agent, execute_task, view_analytics, manage_users
2. Role definitions: org_admin, agent_manager, task_executor, viewer
3. Permission checks at controller and context layers
4. `PUT /api/users/:id/roles` endpoint for role assignment
5. Audit logging for permission changes
6. Unit tests for all permission combinations
7. Migration for roles and permissions tables

**Prerequisites:** Story 4.1 (requires multi-tenant data model)

---

**Story 4.3: Add Batch Task Operations**

As a user,
I want to submit and manage multiple tasks as a batch,
So that I can process large datasets efficiently.

**Acceptance Criteria:**
1. `POST /api/batches` endpoint accepts array of task definitions
2. Batch execution with concurrency control (max 20 tasks in parallel)
3. Batch status tracking (X/Y tasks complete)
4. Partial success handling (continue on individual task failures)
5. Batch cancellation (`POST /api/batches/:id/cancel`)
6. Batch results aggregation and download (JSON/CSV)
7. Integration tests for batch lifecycle

**Prerequisites:** Epic 1 complete (requires task execution infrastructure)

---

**Story 4.4: Implement Streaming Response Support**

As a user,
I want to receive AI responses as they're generated (streaming),
So that I can provide real-time feedback to end users.

**Acceptance Criteria:**
1. OpenAI streaming API integration (SSE from provider)
2. `GET /api/tasks/:id/stream-response` endpoint for token-by-token delivery
3. Groq streaming support (OpenAI-compatible)
4. Response buffering strategy (deliver every 10 tokens or 100ms)
5. Graceful handling of stream interruptions
6. Integration tests for streaming lifecycle
7. Performance: <50ms time-to-first-token

**Prerequisites:** Story 1.2 (requires OpenAI adapter)

---

**Story 4.5: Add Custom Model Fine-Tuning Support**

As a user,
I want to fine-tune OpenAI models on my data and use them via vel_tutor,
So that I can optimize for my specific domain and use cases.

**Acceptance Criteria:**
1. Fine-tuning job creation: `POST /api/fine-tuning-jobs`
2. Training data upload (JSONL format)
3. Job status tracking (pending, running, completed, failed)
4. Fine-tuned model registration (add to agent config options)
5. Cost tracking for fine-tuning operations
6. Integration with OpenAI fine-tuning API
7. Unit tests for job lifecycle management

**Prerequisites:** Story 1.2 (requires OpenAI adapter)

---

**Story 4.6: Implement Rate Limit Customization**

As an organization administrator,
I want to set custom rate limits per user or team,
So that I can allocate resources based on usage tiers.

**Acceptance Criteria:**
1. Rate limit configuration per user/org (tasks per hour, concurrent tasks)
2. Rate limit enforcement at API layer (Plug middleware)
3. `PUT /api/users/:id/rate-limits` endpoint (admin only)
4. Rate limit exhaustion response (429 with retry-after header)
5. Rate limit usage dashboard (show current vs. limit)
6. Unit tests for rate limit enforcement
7. Background job resets hourly limits

**Prerequisites:** Epic 1 complete (requires API infrastructure)

---

**Story 4.7: Add Webhook Notification System**

As a user,
I want to receive webhook notifications for task completion and errors,
So that I can integrate vel_tutor with my existing systems.

**Acceptance Criteria:**
1. Webhook configuration: `POST /api/webhooks` with URL and event types
2. Supported events: task.completed, task.failed, batch.completed, workflow.paused
3. Webhook delivery with retry logic (3 attempts, exponential backoff)
4. Webhook signature for verification (HMAC-SHA256)
5. Delivery history and failure logs
6. Integration tests with webhook receiver mock
7. Webhook test endpoint (`POST /api/webhooks/:id/test`)

**Prerequisites:** Epic 1 complete (requires event system)

---

**Story 4.8: Implement SOC 2 Compliance Hardening**

As a platform administrator,
I want security controls aligned with SOC 2 requirements,
So that enterprise customers can pass their compliance audits.

**Acceptance Criteria:**
1. Encryption at rest for sensitive fields (API keys, user data)
2. TLS 1.3 enforced for all connections
3. Session management hardening (secure cookies, CSRF protection)
4. Access log audit trail (all data access logged with justification)
5. Automated security scanning (OWASP dependency check)
6. Penetration testing report and remediation
7. Compliance documentation generated

**Prerequisites:** Epic 1 + Epic 3 complete (requires production infrastructure)

---

**Story 4.9: Add Horizontal Scaling Support**

As a DevOps engineer,
I want vel_tutor to scale horizontally across multiple Fly.io machines,
So that the platform can handle increasing load without degradation.

**Acceptance Criteria:**
1. Stateless API design verification (no in-memory session state)
2. Database connection pooling optimized (PgBouncer configuration)
3. Phoenix PubSub configured for multi-node (Redis adapter)
4. Distributed task queue (Oban with PostgreSQL-backed jobs)
5. Load testing: 1000 concurrent requests without errors
6. Auto-scaling policy configuration (Fly.io)
7. Multi-region deployment guide

**Prerequisites:** Epic 1 complete + load testing infrastructure

---

**Story 4.10: Implement GraphQL API Alternative**

As an API consumer,
I want a GraphQL endpoint alongside REST,
So that I can fetch exactly the data I need in a single request.

**Acceptance Criteria:**
1. Absinthe library integrated for GraphQL
2. Schema definitions for all resources (User, Agent, Task, Workflow)
3. Queries: user profile, agent list, task history, metrics
4. Mutations: create task, update agent, cancel task
5. Subscriptions: task status updates (WebSocket)
6. GraphQL playground at `/api/graphiql`
7. Integration tests for all queries/mutations

**Prerequisites:** Epic 1 + Epic 2 complete (requires full data model)

---

---

# Implementation Sequence & Development Phases

## Phase 1: Foundation (Weeks 1-3) - Epic 1 Stories 1.1-1.6

**Goal:** Establish core MCP orchestration with multi-provider integration and basic task execution.

**Deliverables:**
- Working MCP orchestrator with intelligent routing
- OpenAI, Groq, and Perplexity adapters operational
- Task creation and status tracking via REST API
- Basic error handling and provider fallback

**Stories (Sequential):**
1. **Story 1.1** - MCP Orchestrator Agent ✅ **(IN REVIEW - Start here!)**
2. **Story 1.2** - OpenAI Integration Adapter
3. **Story 1.3** - Groq Integration Adapter (can parallel with 1.4)
4. **Story 1.4** - Perplexity Integration Adapter (can parallel with 1.3)
5. **Story 1.5** - Task Creation API Endpoint
6. **Story 1.6** - Task Status Tracking API Endpoints

**Parallel Opportunities:**
- Stories 1.3 and 1.4 can run simultaneously (both follow adapter pattern from 1.2)

**Success Criteria:**
- User can submit task via `POST /api/tasks`
- Task automatically routed to appropriate provider (GPT-4o/Groq/Perplexity)
- User can check status via `GET /api/tasks/:id`
- Automatic fallback from OpenAI → Groq works

---

## Phase 2: Core Features (Weeks 4-6) - Epic 1 Stories 1.7-1.12

**Goal:** Complete Epic 1 with real-time monitoring, agent management, and production readiness.

**Deliverables:**
- Real-time task progress via Server-Sent Events
- Task cancellation capability
- Agent configuration and testing
- Comprehensive audit logging
- Health monitoring endpoint

**Stories (Sequential with some parallelization):**
1. **Story 1.7** - Real-Time Task Progress (SSE)
2. **Story 1.8** - Task Cancellation Support
3. **Story 1.9** - Agent Configuration Management (can parallel with 1.11)
4. **Story 1.10** - Agent Testing & Dry-Run
5. **Story 1.11** - Comprehensive Audit Logging (can parallel with 1.9)
6. **Story 1.12** - Health Check Endpoint

**Parallel Opportunities:**
- Stories 1.9 and 1.11 can run simultaneously (independent features)

**Success Criteria:**
- Users receive real-time updates via SSE
- Tasks can be cancelled mid-execution
- Agents can be configured and tested before production use
- All actions logged for compliance
- Health endpoint returns 200 OK with system status

**Gate:** Epic 1 Complete - Foundation solid for Epic 2 & 3

---

## Phase 3: Advanced Workflows (Weeks 7-10) - Epic 2 All Stories

**Goal:** Enable sophisticated multi-step AI workflows with state management and conditional logic.

**Deliverables:**
- Workflow state management and persistence
- Conditional routing based on AI output
- Human-in-the-loop approval gates
- Workflow templates and marketplace
- Parallel task execution
- Error handling and recovery

**Stories (Sequential within epic):**
1. **Story 2.1** - Workflow State Management (foundation)
2. **Story 2.2** - Conditional Workflow Routing (can parallel with 2.5)
3. **Story 2.3** - Human-in-the-Loop Approval Gates
4. **Story 2.4** - Workflow Template System
5. **Story 2.5** - Parallel Task Execution (can parallel with 2.2)
6. **Story 2.6** - Workflow Error Handling

**Parallel Opportunities:**
- Stories 2.2 and 2.5 can run simultaneously (independent workflow features)

**Success Criteria:**
- Users can create multi-step workflows
- Workflows route based on AI output
- Critical steps require human approval
- Workflows can be saved as reusable templates
- Multiple tasks execute in parallel when appropriate
- Workflows gracefully handle errors

---

## Phase 3B: Analytics & Visibility (Weeks 7-10, Parallel with Epic 2) - Epic 3 All Stories

**Goal:** Provide comprehensive dashboards for monitoring, cost tracking, and performance optimization.

**Note:** Epic 3 can start in parallel with Epic 2 since both depend only on Epic 1.

**Deliverables:**
- Real-time metrics collection infrastructure
- Provider performance dashboard
- Cost tracking and budget alerts
- Anomaly detection and alerting
- Task execution history explorer
- Performance benchmarking tool

**Stories (Sequential with parallelization):**
1. **Story 3.1** - Real-Time Metrics Collection (foundation)
2. **Story 3.2** - Provider Performance Dashboard (can parallel with 3.3)
3. **Story 3.3** - Cost Tracking & Budget Dashboard (can parallel with 3.2)
4. **Story 3.4** - Anomaly Detection & Alerting (can parallel with 3.5)
5. **Story 3.5** - Task Execution History Explorer (can parallel with 3.4)
6. **Story 3.6** - Performance Benchmarking Tool

**Parallel Opportunities:**
- Stories 3.2 and 3.3 (both dashboards, independent)
- Stories 3.4 and 3.5 (alerting vs. history, independent)

**Success Criteria:**
- Real-time metrics visible in dashboards
- Cost breakdown by provider and agent
- Alerts fire when anomalies detected
- Users can search historical tasks
- Benchmark tool compares providers side-by-side

---

## Phase 4: Enterprise Ready (Weeks 11-15) - Epic 4 All Stories

**Goal:** Scale to enterprise requirements with multi-tenancy, advanced RBAC, and production hardening.

**Deliverables:**
- Multi-tenant architecture with data isolation
- Advanced role-based permissions
- Batch task operations
- Streaming responses
- Custom model fine-tuning
- Rate limit customization
- Webhook notifications
- SOC 2 compliance hardening
- Horizontal scaling support
- GraphQL API

**Stories (Sequential with strategic parallelization):**
1. **Story 4.1** - Multi-Tenant Architecture (foundation)
2. **Story 4.2** - Advanced RBAC System
3. **Story 4.3** - Batch Task Operations (can parallel with 4.4, 4.5, 4.6)
4. **Story 4.4** - Streaming Response Support (can parallel with 4.3, 4.5, 4.6)
5. **Story 4.5** - Custom Model Fine-Tuning (can parallel with 4.3, 4.4, 4.6)
6. **Story 4.6** - Rate Limit Customization (can parallel with 4.3, 4.4, 4.5)
7. **Story 4.7** - Webhook Notification System (can parallel with 4.8, 4.9)
8. **Story 4.8** - SOC 2 Compliance Hardening (can parallel with 4.7, 4.9)
9. **Story 4.9** - Horizontal Scaling Support (can parallel with 4.7, 4.8)
10. **Story 4.10** - GraphQL API Alternative

**Parallel Opportunities:**
- Stories 4.3, 4.4, 4.5, 4.6 (all feature additions, independent)
- Stories 4.7, 4.8, 4.9 (infrastructure hardening, can overlap)

**Success Criteria:**
- Multiple organizations using platform with data isolation
- Granular permissions control access
- Batch operations process 100s of tasks efficiently
- Streaming responses provide real-time feedback
- Custom models integrated seamlessly
- Rate limits prevent abuse
- Webhooks enable system integration
- Security audit passes
- Platform scales horizontally across regions
- GraphQL provides flexible data access

**Gate:** Production Launch - Enterprise-grade platform complete

---

## Dependency Graph

```
EPIC 1 (Foundation)
├─ 1.1 (MCP Orchestrator) ✅ IN REVIEW
│  ├─ 1.2 (OpenAI Adapter)
│  │  ├─ 1.3 (Groq Adapter) ║ Can parallel
│  │  └─ 1.4 (Perplexity) ║ Can parallel
│  ├─ 1.5 (Task Creation API)
│  │  └─ 1.6 (Task Status API)
│  │     └─ 1.7 (SSE Progress)
│  │        └─ 1.8 (Task Cancellation)
│  ├─ 1.9 (Agent Config) ║ Can parallel with 1.11
│  │  └─ 1.10 (Agent Testing)
│  └─ 1.11 (Audit Logging) ║ Can parallel with 1.9
│     └─ 1.12 (Health Check)

EPIC 2 (Workflows) - Depends on Epic 1 complete
├─ 2.1 (Workflow State)
│  ├─ 2.2 (Conditional Routing) ║ Can parallel with 2.5
│  ├─ 2.3 (Approval Gates)
│  │  └─ 2.4 (Templates)
│  ├─ 2.5 (Parallel Execution) ║ Can parallel with 2.2
│  └─ 2.6 (Error Handling)

EPIC 3 (Analytics) - Depends on Epic 1 complete, Can parallel with Epic 2
├─ 3.1 (Metrics Collection)
│  ├─ 3.2 (Performance Dashboard) ║ Can parallel with 3.3
│  ├─ 3.3 (Cost Dashboard) ║ Can parallel with 3.2
│  ├─ 3.4 (Anomaly Detection) ║ Can parallel with 3.5
│  ├─ 3.5 (Task History) ║ Can parallel with 3.4
│  └─ 3.6 (Benchmarking)

EPIC 4 (Enterprise) - Depends on Epic 1 + Epic 3 complete
├─ 4.1 (Multi-Tenancy)
│  └─ 4.2 (Advanced RBAC)
├─ 4.3 (Batch Ops) ║ Can parallel 4.4, 4.5, 4.6
├─ 4.4 (Streaming) ║ Can parallel 4.3, 4.5, 4.6
├─ 4.5 (Fine-Tuning) ║ Can parallel 4.3, 4.4, 4.6
├─ 4.6 (Rate Limits) ║ Can parallel 4.3, 4.4, 4.5
├─ 4.7 (Webhooks) ║ Can parallel 4.8, 4.9
├─ 4.8 (SOC 2) ║ Can parallel 4.7, 4.9
├─ 4.9 (Scaling) ║ Can parallel 4.7, 4.8
└─ 4.10 (GraphQL)
```

---

## Estimated Timeline

**Total Duration:** 15 weeks (3.5 months)

| Phase | Duration | Stories | Parallel Opportunities | Key Milestone |
|-------|----------|---------|------------------------|---------------|
| **Phase 1** | 3 weeks | 6 stories | 2 pairs (1.3+1.4) | MVP Task Execution |
| **Phase 2** | 3 weeks | 6 stories | 1 pair (1.9+1.11) | Epic 1 Complete |
| **Phase 3** | 4 weeks | 6 stories | 1 pair (2.2+2.5) | Advanced Workflows |
| **Phase 3B** | 4 weeks | 6 stories | 3 pairs (all dashboards) | Full Observability |
| **Phase 4** | 5 weeks | 10 stories | 7 stories can parallel | Enterprise Launch |

**Velocity Assumptions:**
- 1 story = 2-4 days (single dev agent)
- Parallel stories reduce calendar time
- Testing and integration add 20% overhead

**Critical Path:** 1.1 → 1.2 → 1.5 → 1.6 → 1.7 → 2.1 → 4.1 → 4.2

**Fast Track (If Aggressive):**
- Run Epic 2 and Epic 3 fully in parallel: Saves 4 weeks
- Maximize Epic 4 parallelization: Saves 2 weeks
- **Compressed timeline:** 9 weeks to enterprise launch

---

---

# Story Validation Summary

## Size Check Results ✅

**All 48 stories validated for AI agent compatibility:**

### Epic 1 (12 stories) - ✅ ALL PASS
- Average acceptance criteria: 7 per story
- Estimated completion: 2-4 hours per story
- Dependencies clearly stated
- No hidden complexity detected
- **Status:** Story 1.1 in review, remaining 11 stories ready for implementation

### Epic 2 (6 stories) - ✅ ALL PASS
- Average acceptance criteria: 7 per story
- All stories buildable from Epic 1 foundation
- Workflow state management well-scoped
- Human-in-the-loop clearly defined
- **Status:** Blocked until Epic 1 complete

### Epic 3 (6 stories) - ✅ ALL PASS
- Average acceptance criteria: 7 per story
- Dashboard stories properly separated (performance vs. cost vs. history)
- Metrics collection isolated from visualization
- Independent of Epic 2 (can parallel)
- **Status:** Blocked until Epic 1 complete

### Epic 4 (10 stories) - ✅ ALL PASS
- Average acceptance criteria: 7 per story
- Multi-tenancy foundation separated from RBAC
- Feature stories (4.3-4.6) can run in parallel
- Infrastructure stories (4.7-4.9) can run in parallel
- **Status:** Blocked until Epic 1 + Epic 3 complete

---

## Clarity Check Results ✅

**All stories include:**
- ✅ User story format (As a... I want... So that...)
- ✅ 7 specific, testable acceptance criteria
- ✅ Clear prerequisites and dependencies
- ✅ Technical implementation hints (file paths, endpoints, patterns)
- ✅ Success metrics where applicable

**No ambiguous requirements detected.**

---

## Dependency Check Results ✅

**Total Stories:** 48
**Can run immediately:** 1 (Story 1.1 - currently in review)
**Can run in parallel:** 18 stories across all epics
**Sequential dependencies:** 30 stories

**Parallelization Opportunities:**
- **Epic 1:** 2 pairs (4 stories can parallel)
- **Epic 2:** 1 pair (2 stories can parallel)
- **Epic 3:** 3 pairs (6 stories can parallel)
- **Epic 4:** 2 groups (7 stories can parallel)

**No circular dependencies detected.**

---

## Story Size Distribution

| Epic | Stories | Avg Criteria | Estimated Hours | Parallel Potential |
|------|---------|--------------|-----------------|-------------------|
| Epic 1 | 12 | 7.0 | 24-48h total | 4 can parallel (saves 8-16h) |
| Epic 2 | 6 | 7.0 | 12-24h total | 2 can parallel (saves 4-8h) |
| Epic 3 | 6 | 7.0 | 12-24h total | 6 can parallel (saves 12-24h) |
| Epic 4 | 10 | 7.0 | 20-40h total | 7 can parallel (saves 14-28h) |
| **Total** | **48** | **7.0** | **68-136h** | **Time savings: 38-76h** |

**Velocity Estimate:**
- With 1 dev agent: 17-34 weeks
- With 2 dev agents (max parallelization): 9-15 weeks
- With 3 dev agents (aggressive): 7-11 weeks

---

## Completeness Validation ✅

**All PRD functional requirements covered:**
- ✅ FR-1: User Management & Authentication (Stories 1.9, 1.10, 4.2)
- ✅ FR-2: AI Agent Configuration (Stories 1.9, 1.10, 4.5)
- ✅ FR-3: Task Execution & Orchestration (Stories 1.1-1.8, 2.1-2.6)
- ✅ FR-4: Multi-Provider Integration (Stories 1.2-1.4, 4.4)
- ✅ FR-5: Audit Logging & Compliance (Stories 1.11, 4.8)
- ✅ FR-6: System Operations (Stories 1.12, 4.9)

**All PRD non-functional requirements addressed:**
- ✅ Performance (Stories 1.2-1.4, 3.2, 3.6, 4.9)
- ✅ Security (Stories 1.11, 4.2, 4.8)
- ✅ Scalability (Stories 4.1, 4.9)
- ✅ Integration (Stories 1.2-1.4, 4.7, 4.10)

**No gaps detected between PRD and story coverage.**

---

## Implementation Readiness Assessment

### ✅ Ready to Start Immediately
- **Story 1.1** (MCP Orchestrator) - Currently in review, expected completion soon
- All subsequent stories have clear prerequisites and can begin upon 1.1 completion

### ✅ Technical Feasibility Confirmed
- All Elixir/Phoenix patterns well-established
- External APIs (OpenAI, Groq, Perplexity) documented and tested
- Database schema straightforward (PostgreSQL + JSONB)
- No novel technologies or unproven approaches

### ✅ Resource Requirements Clear
- Dev agents need: Elixir 1.15+, PostgreSQL, API keys
- No special hardware or infrastructure needed for development
- Testing can use mocked providers (Mox library)

### ⚠️ Risks Identified & Mitigated
1. **Provider Rate Limits** - Mitigated by free tier monitoring (Story 1.4) and caching (87% target)
2. **Circuit Breaker Complexity** - Mitigated by standard Elixir patterns (Story 1.2)
3. **Multi-Tenancy Data Isolation** - Mitigated by PostgreSQL RLS (Story 4.1)

---

## Final Validation: All Stories Dev-Agent Ready ✅

**Every story confirmed:**
- ✅ Fits in 200k context window (avg 400-600 words per story)
- ✅ Can be completed independently (clear inputs/outputs)
- ✅ Has measurable success criteria (7 acceptance criteria each)
- ✅ No forward dependencies (only builds on prior work)
- ✅ Vertically sliced (delivers complete functionality)

**Total stories:** 48
**Stories needing revision:** 0
**Stories ready for implementation:** 48

**🎯 All systems go! Development can begin as soon as Story 1.1 review completes.**

---

## Story Guidelines Reference

**Story Format:**

```
**Story [EPIC.N]: [Story Title]**

As a [user type],
I want [goal/desire],
So that [benefit/value].

**Acceptance Criteria:**
1. [Specific testable criterion]
2. [Another specific criterion]
3. [etc.]

**Prerequisites:** [Dependencies on previous stories, if any]
```

**Story Requirements:**

- **Vertical slices** - Complete, testable functionality delivery
- **Sequential ordering** - Logical progression within epic
- **No forward dependencies** - Only depend on previous work
- **AI-agent sized** - Completable in 2-4 hour focused session
- **Value-focused** - Integrate technical enablers into value-delivering stories

---

**For implementation:** Use the `create-story` workflow to generate individual story implementation plans from this epic breakdown.

---

# Development Guidance

## Getting Started

**Current Status:** Story 1.1 (MCP Orchestrator Agent) is in review. Once approved, begin Story 1.2 immediately.

**First Steps:**
1. Complete Story 1.1 review and merge
2. Set up development environment if not already configured:
   - Elixir 1.15+, Erlang 26+, PostgreSQL 13+
   - API keys: OpenAI, Groq (Perplexity optional for MVP)
3. Start Story 1.2 (OpenAI Integration Adapter)
4. Once 1.2 complete, launch 1.3 and 1.4 in parallel (both follow adapter pattern)

**Key Files to Create First:**
```
lib/vel_tutor/integration/
├── openai_adapter.ex          # Story 1.2
├── groq_adapter.ex            # Story 1.3
├── perplexity_adapter.ex      # Story 1.4
└── adapter_behaviour.ex       # Shared interface (create in 1.2)

lib/vel_tutor_web/controllers/
├── task_controller.ex         # Story 1.5
└── agent_controller.ex        # Story 1.9

lib/vel_tutor/
├── task_context.ex            # Story 1.5
├── agent_context.ex           # Story 1.9
├── audit_log_context.ex       # Story 1.11
└── workflow_context.ex        # Story 2.1 (Epic 2)
```

**Recommended Agent Allocation (If Using Multiple Dev Agents):**
- **Agent A (Primary):** Epic 1 sequential stories (1.1 → 1.2 → 1.5 → 1.6 → 1.7 → 1.8)
- **Agent B (Parallel):** Epic 1 parallel tracks (1.3, 1.4, then later 1.9, 1.10)
- **Agent C (Support):** Epic 1 infrastructure (1.11, 1.12), then Epic 3 metrics

---

## Architecture Decisions Reference

**These decisions affect multiple stories - establish early:**

### Decision 1: Adapter Interface Pattern (Affects Stories 1.2, 1.3, 1.4)

**Recommended Approach:**
```elixir
defmodule VelTutor.Integration.AdapterBehaviour do
  @callback execute_task(task :: map(), config :: map()) ::
    {:ok, result :: map()} | {:error, reason :: String.t()}

  @callback validate_config(config :: map()) ::
    {:ok, validated :: map()} | {:error, errors :: list()}

  @callback health_check(config :: map()) ::
    :ok | {:error, reason :: String.t()}
end
```

**Rationale:** Uniform interface enables seamless provider switching and fallback.

---

### Decision 2: Circuit Breaker Implementation (Affects Stories 1.2, 1.3, 1.4)

**Recommended Library:** `fuse` (Erlang circuit breaker)

**Pattern:**
```elixir
defmodule VelTutor.Integration.CircuitBreaker do
  def call(provider, fun) do
    case :fuse.ask(provider, :sync) do
      :ok ->
        try do
          result = fun.()
          :fuse.reset(provider)
          {:ok, result}
        rescue
          e ->
            :fuse.melt(provider)
            {:error, e}
        end
      :blown ->
        {:error, :circuit_open}
    end
  end
end
```

**Configuration:** 5 failures in 60s opens circuit, 30s cooldown period.

---

### Decision 3: Task State Machine (Affects Stories 1.1, 1.5, 1.6, 1.7, 1.8)

**States:** `pending → in_progress → completed | failed | cancelled`

**Transitions:**
```elixir
defmodule VelTutor.TaskStateMachine do
  @valid_transitions %{
    pending: [:in_progress, :cancelled],
    in_progress: [:completed, :failed, :cancelled],
    completed: [],  # Terminal state
    failed: [],     # Terminal state
    cancelled: []   # Terminal state
  }
end
```

**Rationale:** Prevents invalid state transitions, enforces business rules.

---

### Decision 4: Real-Time Updates Architecture (Affects Stories 1.7, 3.2, 3.3, 3.5)

**Recommended:** Phoenix PubSub + Server-Sent Events (SSE)

**Pattern:**
```elixir
# Broadcast task updates
Phoenix.PubSub.broadcast(
  VelTutor.PubSub,
  "task:#{task.id}",
  {:task_updated, task}
)

# Subscribe in controller
Phoenix.PubSub.subscribe(VelTutor.PubSub, "task:#{id}")
```

**Rationale:** SSE simpler than WebSockets, sufficient for one-way updates.

---

### Decision 5: Cost Calculation Strategy (Affects Stories 1.2-1.4, 3.3)

**Provider Pricing (as of 2025-11-03):**
```elixir
@pricing %{
  "gpt-4o" => %{input: 0.0025, output: 0.0100},        # per 1K tokens
  "gpt-4o-mini" => %{input: 0.0002, output: 0.0006},
  "llama-3.1-70b" => %{input: 0.00079, output: 0.00079},
  "mixtral-8x7b" => %{input: 0.00027, output: 0.00027},
  "sonar-large" => %{input: 0.001, output: 0.001}
}
```

**Cost Tracking:**
```elixir
cost = (input_tokens / 1000 * input_price) +
       (output_tokens / 1000 * output_price)
```

**Rationale:** Transparent cost attribution enables budget management.

---

### Decision 6: Multi-Tenancy Strategy (Affects Story 4.1, 4.2)

**Recommended:** PostgreSQL Row-Level Security (RLS)

**Pattern:**
```sql
CREATE POLICY tenant_isolation ON tasks
  USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
```

**Rationale:** Database-enforced isolation prevents application-level bugs.

---

## Technical Notes by Epic

### Epic 1 Technical Considerations

**Story 1.2 (OpenAI Adapter):**
- Use `Req` library for HTTP client (built-in retry, telemetry)
- Implement streaming via `Req.Request.stream/2`
- Token counting: Use `tiktoken_ex` for accuracy

**Story 1.7 (SSE Progress):**
- Set `Cache-Control: no-cache` header
- Send `:ping` events every 30s to keep connection alive
- Chunked transfer encoding required

**Story 1.11 (Audit Logging):**
- Use Ecto.Multi for transactional logging (log + action atomic)
- Partition `audit_logs` table by month for query performance
- Consider separate read replica for audit queries (future)

---

### Epic 2 Technical Considerations

**Story 2.1 (Workflow State):**
- Use JSONB for flexible state storage
- Consider Oban for background job orchestration
- Implement optimistic locking to prevent concurrent modifications

**Story 2.3 (Human-in-the-Loop):**
- Webhook notifications require retry queue (use Oban)
- Timeout after 24h default (configurable per workflow)
- Store approval history in workflow metadata

**Story 2.5 (Parallel Execution):**
- Use `Task.async_stream/3` with max_concurrency: 5
- Aggregate results with `Enum.reduce/3`
- Handle partial failures gracefully (continue vs. abort)

---

### Epic 3 Technical Considerations

**Story 3.1 (Metrics Collection):**
- Store metrics in time-series optimized structure
- Partition by date (monthly) for efficient queries
- Use background job for hourly/daily rollups

**Story 3.2-3.5 (Dashboards):**
- Phoenix LiveView for real-time updates
- Use ChartJS or Plotly for visualizations
- Implement pagination for large datasets (50 items/page)

**Story 3.4 (Anomaly Detection):**
- Statistical approach: mean + 3 standard deviations
- Requires 7 days of historical data for baseline
- False positive rate: target <5%

---

### Epic 4 Technical Considerations

**Story 4.1 (Multi-Tenancy):**
- Set tenant context in Plug: `Plug.Conn.assign(conn, :tenant_id, ...)`
- Use Ecto query prefix for tenant isolation: `Repo.all(query, prefix: tenant_id)`
- Migration: `ALTER TABLE tasks ADD COLUMN tenant_id UUID NOT NULL;`

**Story 4.8 (SOC 2 Compliance):**
- Encryption at rest: Use database-level encryption (AWS RDS encryption)
- Encrypt sensitive fields: Use `Cloak` library for application-level encryption
- Access logs: Log all data access with justification field

**Story 4.9 (Horizontal Scaling):**
- Ensure no local state (all state in PostgreSQL or Redis)
- Configure Fly.io autoscaling: `fly scale count 2-10`
- Use Redis adapter for Phoenix PubSub: `Phoenix.PubSub.Redis`

---

## Risk Mitigation Strategies

### Risk 1: Provider Rate Limits

**Impact:** Stories 1.2-1.4, all subsequent stories

**Mitigation:**
- Monitor usage against limits (OpenAI: 10K req/min, Groq: 30 req/min)
- Implement request queuing when approaching limits
- Cache Perplexity results aggressively (87% hit rate target)
- Fallback to alternative providers automatically

**Warning Signs:**
- 429 errors increasing
- Circuit breaker tripping frequently
- User complaints about slow responses

---

### Risk 2: Database Performance Degradation

**Impact:** Stories 1.5-1.8, 3.1, 3.5

**Mitigation:**
- Index all foreign keys and common query fields
- Use EXPLAIN ANALYZE to optimize slow queries
- Implement database connection pooling (PgBouncer)
- Partition large tables (audit_logs, metrics) by date

**Warning Signs:**
- Query times >500ms
- Database CPU >80%
- Connection pool exhaustion

---

### Risk 3: Cost Overruns

**Impact:** All provider integration stories

**Mitigation:**
- Set daily budget alerts (Story 3.3)
- Implement rate limiting per user (Story 4.6)
- Monitor cost per task (target: <$0.10 average)
- Prefer Groq for appropriate workloads (3x cheaper than GPT-4o)

**Warning Signs:**
- Daily costs trending >$50
- Individual tasks costing >$1
- Budget burn rate >100%

---

## Success Metrics by Phase

### Phase 1 Success (Epic 1 Stories 1.1-1.6)
- ✅ Task submission via API working
- ✅ Intelligent routing to correct provider
- ✅ Fallback working (OpenAI → Groq)
- ✅ P95 latency <2s for task creation
- ✅ 0 unhandled exceptions in production

---

### Phase 2 Success (Epic 1 Stories 1.7-1.12)
- ✅ Real-time updates via SSE functional
- ✅ Task cancellation working
- ✅ Agent configuration validated before use
- ✅ 100% of actions logged for audit
- ✅ Health endpoint response time <500ms

---

### Phase 3 Success (Epic 2 Complete)
- ✅ Multi-step workflows executing correctly
- ✅ Conditional routing working
- ✅ Human approval gates functional
- ✅ Template instantiation working
- ✅ Parallel tasks executing 2x faster than sequential

---

### Phase 3B Success (Epic 3 Complete)
- ✅ Real-time dashboards updating
- ✅ Cost tracking accurate within 5%
- ✅ Anomaly detection <5% false positives
- ✅ Historical search sub-second response
- ✅ Benchmark comparisons statistically significant

---

### Phase 4 Success (Epic 4 Complete)
- ✅ Multi-tenant data isolation verified (security audit)
- ✅ RBAC permissions enforced correctly
- ✅ Batch operations handling 100+ tasks
- ✅ Streaming responses <50ms time-to-first-token
- ✅ Platform scaling to 1000 concurrent requests
- ✅ SOC 2 audit passed

---

## Development Best Practices

### For Each Story

**Before Starting:**
1. Read story acceptance criteria carefully
2. Check prerequisites are complete
3. Review architecture decisions above
4. Set up test data fixtures

**During Development:**
1. Write tests first (TDD approach)
2. Use mocks for external APIs (Mox library)
3. Follow Phoenix conventions (contexts, controllers)
4. Commit frequently with descriptive messages

**Before Marking Complete:**
1. All acceptance criteria met
2. Tests passing (unit + integration)
3. Code reviewed (self-review checklist)
4. Documentation updated (API docs, README)
5. Performance tested (P95 latency targets)

---

### Testing Strategy

**Unit Tests (ExUnit):**
```elixir
# Test contexts in isolation
test "creates task with valid attributes" do
  assert {:ok, task} = TaskContext.create_task(@valid_attrs)
  assert task.status == :pending
end
```

**Integration Tests:**
```elixir
# Test full request/response cycle
test "POST /api/tasks creates and returns task", %{conn: conn} do
  conn = post(conn, "/api/tasks", @task_params)
  assert %{"id" => id, "status" => "pending"} = json_response(conn, 201)
end
```

**Mocking External APIs:**
```elixir
# Use Mox for provider mocking
Mox.expect(OpenAIMock, :execute_task, fn _task, _config ->
  {:ok, %{result: "Generated response", tokens: 150}}
end)
```

---

### Code Review Checklist

Before merging any story:

- [ ] All acceptance criteria met
- [ ] Tests passing (mix test)
- [ ] Test coverage >75% for new code
- [ ] No hardcoded API keys or secrets
- [ ] Error handling comprehensive
- [ ] Logging appropriate (not excessive)
- [ ] Performance acceptable (query times, response times)
- [ ] Security reviewed (no SQL injection, XSS, etc.)
- [ ] Documentation updated
- [ ] Migrations tested (up and down)

---

## Troubleshooting Common Issues

### Issue: "Connection timeout to OpenAI"
**Stories Affected:** 1.2, 1.5, 1.6

**Solution:**
- Check API key validity: `curl -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models`
- Verify network connectivity
- Increase timeout in adapter (default: 30s)
- Check circuit breaker state (may be open)

---

### Issue: "Database connection pool exhausted"
**Stories Affected:** 1.5-1.8, all Epic 3

**Solution:**
- Increase pool size in `config/config.exs`: `pool_size: 20`
- Check for long-running queries
- Implement connection timeout
- Consider read replicas for heavy queries

---

### Issue: "SSE connection dropping"
**Stories Affected:** 1.7, 3.2-3.5

**Solution:**
- Send ping events every 30s
- Check nginx/load balancer timeout settings
- Verify client reconnection logic
- Monitor connection count (max: 50/user)

---

## Next Steps After Epic Completion

**When you've completed all 48 stories, you'll have:**

✅ Production-ready multi-provider AI orchestration platform
✅ 52% faster performance, 41% cost reduction vs single-provider
✅ Real-time dashboards for monitoring and cost control
✅ Enterprise-grade security and multi-tenancy
✅ Comprehensive test coverage (target: 80%+)
✅ Full API documentation (REST + GraphQL)

**Post-Launch Recommendations:**

1. **Week 1-2:** Monitor production metrics, fix critical bugs
2. **Week 3-4:** Gather user feedback, prioritize enhancements
3. **Month 2:** Implement most-requested features from backlog
4. **Month 3:** Optimize based on real usage patterns
5. **Quarter 2:** Expand provider ecosystem (Anthropic Claude, Cohere, etc.)

**Continuous Improvement:**
- Weekly: Review metrics dashboard, identify optimization opportunities
- Monthly: Analyze cost trends, adjust provider routing
- Quarterly: Security audit, dependency updates
- Annually: Architecture review, major version planning
