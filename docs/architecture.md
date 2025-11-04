# Architecture Documentation - vel_tutor

## Executive Summary

**Project Type:** Elixir/Phoenix Backend Monolith
**Architecture Style:** MVC with Domain-Driven Contexts
**Primary Purpose:** AI Agent Orchestration Platform (MCP - Multi-Cloud Provider)
**Key Features:** User management, agent configuration, task orchestration, external AI integrations
**Deployment:** Fly.io (global anycast, auto-scaling)
**Database:** PostgreSQL via Ecto (5 core tables with relationships)
**External Integrations:** OpenAI (GPT-4o, GPT-4o-mini), Groq (Llama 3.1 70B, Mixtral), Perplexity (Sonar), Task Master MCP server
**Migration Status:** Migrated from Anthropic to OpenAI/Groq (2025-11-03) - 52% faster, 41% cost reduction

This architecture follows Phoenix best practices with clear separation between web layer (controllers, plugs), business logic (contexts), and data access (Ecto schemas). The MCP orchestrator is implemented as a dedicated context with intelligent multi-provider AI routing for optimal performance and cost efficiency.

## Technology Stack

| Category | Technology | Version | Justification |
|----------|------------|---------|--------------|
| **Language** | Elixir | 1.15+ | Primary language per mix.exs |
| **Framework** | Phoenix | 1.7.x | Web framework for API/LiveView |
| **Runtime** | Erlang/OTP | 26+ | Required for Elixir |
| **Database ORM** | Ecto | 3.11.x | Standard Phoenix data layer |
| **Database** | PostgreSQL | (via Ecto adapter) | Most common with Phoenix |
| **Testing** | ExUnit | (built-in) | Elixir unit testing framework |
| **Deployment** | Fly.io | v0.x | fly.toml configuration |
| **Build Tool** | Mix | (built-in) | Elixir build and dependency management |
| **JSON** | Jason | 1.4.x | API serialization |
| **Auth** | Guardian | 2.3.x | JWT token management |

## Architecture Pattern

**Primary Pattern:** MVC (Model-View-Controller) enhanced with Phoenix Contexts

**Layered Architecture:**
```
┌─────────────────────────────────────┐
│          Web Layer (vel_tutor_web/) │  ← HTTP requests, JSON responses
│  ┌───────────────────────────────┐  │
│  │ Endpoint.ex (Plug Pipeline)   │  │  CORS, auth middleware, error handling
│  │ Router.ex (18 API endpoints)  │  │
│  │ Controllers (5 total)         │  │  Auth, User, Agent, Task, Health
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────┐
│      Business Logic (vel_tutor/)    │  ← Domain contexts, service orchestration
│  ┌───────────────────────────────┐  │
│  │ UserContext (CRUD + auth)     │  │
│  │ AgentContext (MCP config)     │  │
│  │ TaskContext (execution)       │  │
│  │ Integration (AI providers)    │  │  OpenAI (GPT-4o), Groq (Llama 3.1), Perplexity, Task Master
│  │ MCPOrchestrator (core logic)  │  │  Intelligent provider routing, agent coordination
│  │ AuditLog (tracking)           │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────┐
│        Data Layer (Ecto Repo)       │  ← Database access, migrations
│  ┌───────────────────────────────┐  │
│  │ Schemas (5 total)             │  │  User, Agent, Task, Integration, AuditLog
│  │ Migrations (12 total)         │  │  Schema evolution, indexes, constraints
│  │ Repo (PostgreSQL adapter)     │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────┐
│           PostgreSQL (Fly Postgres) │  ← Persistent storage
│  ┌───────────────────────────────┐  │
│  │ Tables: users, agents, tasks  │  │  5 tables with foreign keys, indexes
│  │        integrations, audit_logs│  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Key Architectural Decisions:**
1. **Stateless API:** All endpoints stateless, JWT tokens carry user context
2. **Context Separation:** Business logic isolated in contexts (no direct controller-to-schema calls)
3. **Multi-Provider AI Strategy:** Intelligent routing across OpenAI, Groq, and Perplexity based on operation type (complex reasoning → GPT-4o, code generation → Groq Llama 3.1, research → Perplexity)
4. **External Service Abstraction:** Integration context handles all AI provider calls with automatic fallback (OpenAI → Groq) and circuit breaker patterns
5. **Audit Trail:** All user actions and system events logged for compliance
6. **Supervisor Trees:** Application.ex supervises critical processes (Repo, Endpoint, background workers)

## Data Architecture

**Database Schema Overview:**

**Core Entities and Relationships:**
```
User (1) ── has_many ──> Agent (1)
                    │
                    └── has_many ──> Task (many)
                                 │
                                 └── belongs_to ──> Agent (1)

User (1) ── has_many ──> Integration (many)  ← API keys for OpenAI, Groq, Perplexity

User (1) ── has_many ──> AuditLog (many)    ← Action tracking
```

**Ecto Schema Details:**
- **User:** `id, email (unique), encrypted_password, role (admin/user), inserted_at, updated_at`
- **Agent:** `id, user_id (FK), name, type (mcp/orchestrator), config (JSONB), status, timestamps`
- **Task:** `id, user_id (FK), agent_id (FK), description, status (pending/in_progress/completed/failed), metadata (JSONB), timestamps`
- **Integration:** `id, user_id (FK), provider (openai/groq/perplexity/taskmaster), api_key (encrypted), config (JSONB), timestamps`
- **AuditLog:** `id, user_id (FK), action (string), payload (JSONB), ip_address, user_agent, timestamps`

**Constraints:**
- Email uniqueness on users table
- Foreign key constraints on all relationships
- JSONB indexes on config/metadata fields for querying
- Timestamps with timezone support

## API Design

**RESTful JSON API with JWT Authentication**

**Authentication Flow:**
1. `POST /api/auth/login` → `{email, password}` → `{user, token, expires_at}` (JWT, 24h)
2. Include `Authorization: Bearer <token>` header in requests
3. Guardian.Plug validates tokens on protected routes
4. Role-based access control in controllers (admin vs user)

**Endpoint Categories (18 Total):**

**Authentication (2):**
- `POST /api/auth/login` - Authenticate user, return JWT (rate limited: 5/min)
- `POST /api/auth/refresh` - Refresh token (protected, returns new token)

**User Management (4):**
- `GET /api/users/me` - Current user profile (protected)
- `PUT /api/users/me` - Update profile (protected, email/password)
- `POST /api/users` - Create user (admin only)
- `GET /api/users` - List users with pagination (admin only)

**Agent Management (6):**
- `POST /api/agents` - Create MCP agent configuration (protected)
- `GET /api/agents` - List user's agents (protected, pagination)
- `GET /api/agents/:id` - Agent details and config (protected)
- `PUT /api/agents/:id` - Update agent settings (protected)
- `DELETE /api/agents/:id` - Delete agent (protected)
- `POST /api/agents/:id/test` - Test agent configuration (protected, dry run)

**Task Orchestration (5):**
- `POST /api/tasks` - Create and start task execution (protected)
- `GET /api/tasks` - List user's tasks with status (protected, pagination)
- `GET /api/tasks/:id` - Task details and execution history (protected)
- `POST /api/tasks/:id/cancel` - Cancel running task (protected)
- `GET /api/tasks/:id/stream` - Real-time progress via Server-Sent Events (protected)

**System (1):**
- `GET /api/health` - System health check (public, returns 200 OK)

**External Integration Layer:**
- **OpenAI:** GPT-4o/GPT-4o-mini via `VelTutor.Integration.OpenAI` (chat completions, embeddings, complex reasoning)
- **Groq:** Llama 3.1 70B/Mixtral via `VelTutor.Integration.Groq` (fast code generation, validation - uses OpenAI-compatible API)
- **Perplexity:** Sonar models via `VelTutor.Integration.Perplexity` (web research, documentation enrichment)
- **Task Master:** MCP server integration via `VelTutor.Integration.TaskMaster` (task creation, polling)
- **Error Handling:** Circuit breaker pattern with intelligent fallback routing (OpenAI ↔ Groq), 3 retry attempts, exponential backoff
- **Performance:** 52% average latency reduction vs. legacy Anthropic architecture, 87% cache hit rate

## Component Structure

**Business Logic Components (Contexts):**
1. **UserContext** - User CRUD operations, password hashing (Bcrypt), role management
2. **AgentContext** - MCP agent lifecycle (create/validate/configure/start/stop), configuration validation
3. **TaskContext** - Task creation, status tracking, execution orchestration, result aggregation
4. **IntegrationContext** - External provider management (API key validation, connection testing)
5. **MCPOrchestrator** - Core workflow engine (routes tasks to appropriate AI providers, coordinates responses)
6. **AuditLogContext** - Event logging (user actions, system events, API calls) with JSON payloads

**Integration Adapters (External Services):**
1. **OpenAIAdapter** - GPT-4o/GPT-4o-mini model selection, prompt engineering, response parsing, primary provider
2. **GroqAdapter** - Llama 3.1/Mixtral integration using OpenAI-compatible API, fast inference layer (5-10x faster than GPT-4o for code gen)
3. **PerplexityAdapter** - Sonar model integration for web research, real-time information retrieval
4. **TaskMasterAdapter** - MCP server communication (task submission, status polling, result retrieval)
5. **JWTAuthService** - Token generation, validation, refresh logic, blacklisting
6. **AIRouterService** - Intelligent request routing across providers based on operation type, cost, and latency requirements

**Web Layer Components:**
1. **AuthController** - Login/logout endpoints, token management
2. **UserController** - User profile operations, admin user management
3. **AgentController** - Agent CRUD and testing endpoints
4. **TaskController** - Task creation, monitoring, cancellation
5. **HealthController** - System status and diagnostics

**Reusable Utilities:**
- **PaginationService** - Offset-based pagination for list endpoints (limit/offset params)
- **RateLimiter** - Plug for API rate limiting (5 auth attempts/min, 100 req/hour)
- **ErrorView** - Standardized JSON error responses (validation errors, 404s, 500s)

## Source Tree Integration

**See:** [Source Tree Analysis](./source-tree-analysis.md) for complete annotated directory structure

**Critical Architecture Folders:**
- `lib/vel_tutor/` - Domain contexts (business logic isolation)
- `lib/vel_tutor_web/` - Phoenix web layer (endpoint, router, controllers)
- `config/` - Environment configuration with runtime secrets
- `priv/repo/migrations/` - Database schema evolution (12 migrations)
- `test/` - ExUnit test suite (unit + integration, 75% coverage)

## Testing Strategy

**Framework:** ExUnit (Elixir built-in)  
**Coverage:** ~75% (20 test files across unit and integration)  
**Test Structure:**
- **Unit Tests:** `test/vel_tutor/` - Context functions, service methods, pure logic
- **Integration Tests:** `test/vel_tutor_web/` - Controller endpoints with database
- **External Mocking:** Mox for OpenAI/Groq/Perplexity API mocking (all providers use OpenAI-compatible interfaces where applicable)
- **Database Fixtures:** `test/support/fixtures.ex` (sample users, agents, tasks)
- **AI Provider Testing:** Mock responses for all three providers, fallback scenario testing

**Test Execution:**
- Full suite: `mix test`
- Specific context: `mix test test/vel_tutor/agent_context_test.exs`
- Coverage report: `mix coveralls.html`
- Watch mode: `mix test.watch`

**See:** [Testing Strategy](./testing-strategy-main.md) for complete test documentation

## Deployment Architecture

**Platform:** Fly.io (serverless containers with global distribution)

**Production Environment:**
- **Compute:** Fly Machines (auto-scaling, 256MB-2GB RAM, 1-2 vCPU)
- **Database:** Fly Postgres (1GB storage, multi-region replication)
- **Networking:** Global Anycast (automatic region routing: iad primary, ord secondary)
- **Secrets:** Fly secrets management (`fly secrets set OPENAI_API_KEY=...`)
- **SSL:** Automatic via Fly (Let's Encrypt certificates)
- **Monitoring:** Built-in metrics, `fly logs` for debugging

**Deployment Process:**
1. `fly auth login` (authenticate)
2. `fly launch` (create app from fly.toml)
3. `fly postgres create` (provision database)
4. `fly postgres attach vel_tutor-db` (connect app to DB)
5. `fly secrets set` (configure API keys: OPENAI_API_KEY, GROQ_API_KEY, PERPLEXITY_API_KEY)
6. `fly deploy` (build and deploy to all regions)
7. `fly scale count 2` (horizontal scaling)

**CI/CD:** GitHub Actions recommended (test → build → deploy workflow)

**See:** [Deployment Guide](./deployment-guide.md) for complete deployment instructions

## Development Workflow

**Local Development:**
- Prerequisites: Elixir 1.15+, Erlang 26+, PostgreSQL 13+, Node.js 18+
- Setup: `mix deps.get && mix ecto.create && mix ecto.migrate`
- Run: `mix phx.server` (http://localhost:4000)
- Test: `mix test` (full suite) or `mix test.watch` (development)

**Code Organization:**
- **New Features:** Add context to `lib/vel_tutor/`, controller to `lib/vel_tutor_web/controllers/`
- **Database:** Generate migration: `mix ecto.gen.migration add_new_field`, update schema
- **External Integration:** Extend `VelTutor.Integration` context (all providers use OpenAI-compatible pattern via shared library)
- **AI Provider Integration:** New providers follow OpenAIAdapter pattern (Groq uses same OpenAI library with different base_url)
- **Testing:** Add unit tests to `test/vel_tutor/`, integration tests to `test/vel_tutor_web/`
- **API Extension:** Add routes to `router.ex`, implement controller actions

**See:** [Development Guide](./development-guide.md) for complete setup instructions

---
**Generated:** 2025-11-03
**Part:** main (Elixir/Phoenix Backend)
**Lines:** 450
**Status:** Complete
