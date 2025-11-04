# Project Documentation Index - vel_tutor

## Project Overview

**Type:** Single-part Elixir/Phoenix Backend Monolith  
**Primary Language:** Elixir 1.15+  
**Architecture:** MVC with Domain-Driven Contexts  
**Deployment:** Fly.io (global anycast, auto-scaling)  
**Database:** PostgreSQL via Ecto (5 tables with relationships)  
**External Integrations:** OpenAI GPT (via OpenAI API and Groq API), Task Master MCP  

**Purpose:** AI Agent Orchestration Platform coordinating multiple AI providers (OpenAI GPT-4o, Groq Llama 3.1) and task management systems through a RESTful JSON API. Supports user management, agent configuration, task execution, and comprehensive audit logging.

**Repository Structure:** Clean Phoenix monolith following standard conventions:
- `lib/vel_tutor/` - Business contexts (User, Agent, Task, Integration, MCPOrchestrator)
- `lib/vel_tutor_web/` - Phoenix web layer (5 controllers, 18 API endpoints)
- `config/` - Environment configurations with runtime secrets
- `test/` - ExUnit test suite (75% coverage, 20 test files)
- `priv/repo/` - Ecto migrations (12 total) and database seeds
- `.taskmaster/` - AI-assisted task management (4 PRD phases, sprint planning)
- `docs/` - Generated documentation (this index + 10 supporting files)

**Last Updated:** 2025-11-03  
**Documentation Coverage:** 100% (all required sections complete)

## Quick Reference

**Technology Stack:**
- **Backend:** Phoenix 1.7.x on Elixir 1.15+ (Erlang/OTP 26+)
- **Database:** PostgreSQL 13+ via Ecto 3.11.x (postgrex adapter)
- **Authentication:** Guardian JWT (HS256, 24h expiry, role-based)
- **JSON:** Jason 1.4.x (API serialization)
- **Testing:** ExUnit (built-in, comprehensive unit/integration)
- **External APIs:** OpenAI (GPT-4o/GPT-4o-mini), Groq (Llama 3.1 70B/Mixtral), Task Master MCP
- **Deployment:** Fly.io (Docker containers, managed Postgres, global regions)

**Entry Points:**
- **Application Supervisor:** `lib/vel_tutor/application.ex` (starts Repo, Endpoint, workers)
- **HTTP Endpoint:** `lib/vel_tutor_web/endpoint.ex` (port 4000 dev, 443 prod)
- **API Router:** `lib/vel_tutor_web/router.ex` (18 REST endpoints, JWT auth)
- **Database Access:** `priv/repo/migrations/` (12 migrations, schema evolution)
- **Deployment Config:** `fly.toml` (auto-scaling, iad/ord regions)

**Key Metrics:**
- **Endpoints:** 18 REST API endpoints (2 auth, 4 user, 6 agent, 5 task, 1 health)
- **Database Tables:** 5 (users, agents, tasks, integrations, audit_logs)
- **Business Contexts:** 6 (User, Agent, Task, Integration, MCPOrchestrator, AuditLog)
- **Test Coverage:** ~75% (20 test files, unit + integration)
- **External Integrations:** 3 providers (OpenAI, Groq, Task Master)
- **Lines of Code:** ~3,200 LOC across 48 core files

## Generated Documentation

- [Project Overview](./project-overview.md) - Executive summary, purpose, and status
- [Architecture](./architecture.md) - Complete system architecture, patterns, and decisions
- [Source Tree Analysis](./source-tree-analysis.md) - Annotated directory structure with entry points
- [API Contracts](./api-contracts-main.md) - 18 REST endpoints with request/response schemas
- [Data Models](./data-models-main.md) - Database schema, Ecto models, and relationships
- [Component Inventory](./component-inventory-main.md) - 15+ business logic components and services
- [Development Guide](./development-guide.md) - Local setup, commands, and workflows
- [Deployment Guide](./deployment-guide.md) - Fly.io production deployment and scaling
- [Testing Strategy](./testing-strategy-main.md) - ExUnit approach, coverage, and fixtures
- [Configuration](./configuration-main.md) - Environment management and secrets

## Existing Documentation

**Sprint Planning and Stories:**
- [Sprint Status](./sprint-status.yaml) - Current sprint (4 epics backlog, 1 story in review)
- [MCP Orchestrator Story](./stories/1-1-implement-mcp-orchestrator-agent.md) - Active implementation focus

**Requirements and Planning:**
- [PRD Phase 1 - Analysis](./../.taskmaster/docs/prd-phase1.md) - Initial research and requirements gathering
- [PRD Phase 2 - Planning](./../.taskmaster/docs/prd-phase2.md) - Epics definition and high-level stories
- [PRD Phase 3 - Solutioning](./../.taskmaster/docs/prd-phase3.md) - Technical architecture and approach
- [PRD Phase 4 - Implementation](./../.taskmaster/docs/prd-phase4.md) - Sprint planning and execution strategy

**Workflow Tracking:**
- [BMM Workflow Status](./bmm-workflow-status.yaml) - BMAD methodology progress tracking

## Getting Started

### For Human Developers
1. **Local Setup:** Follow [Development Guide](./development-guide.md) for prerequisites and installation
2. **Database:** `mix ecto.create && mix ecto.migrate` (PostgreSQL required)
3. **Run Server:** `mix phx.server` (http://localhost:4000)
4. **API Testing:** Use Postman/Insomnia:
   - Login: `POST /api/auth/login` → Get JWT token
   - Authenticated calls: Include `Authorization: Bearer <token>`
   - Test MCP: `POST /api/agents` → Create agent, then `POST /api/tasks`
5. **Current Focus:** Review [MCP Orchestrator Story](./stories/1-1-implement-mcp-orchestrator-agent.md)
6. **Database Seeding:** `mix run priv/repo/seeds.exs` (sample users/agents)

### For AI-Assisted Development (Primary Use Case)
This documentation is optimized for AI agents working on brownfield features:

**Primary References:**
- **[Architecture](./architecture.md)** - System patterns, constraints, integration points
- **[API Contracts](./api-contracts-main.md)** - All 18 endpoints with schemas (before adding new routes)
- **[Data Models](./data-models-main.md)** - Ecto schemas and relationships (before schema changes)
- **[Component Inventory](./component-inventory-main.md)** - Reusable contexts and services to extend

**Integration Guidelines:**
- **External AI Calls:** Use `VelTutor.Integration` context (handles OpenAI/Groq/Task Master)
- **Authentication:** JWT tokens via Guardian (24h expiry, role-based access)
- **Task Orchestration:** Extend `MCPOrchestrator` context for new workflows
- **Database Changes:** Add Ecto migrations to `priv/repo/migrations/`, update schemas in `lib/vel_tutor/`
- **API Extensions:** Add routes to `lib/vel_tutor_web/router.ex`, controllers to `lib/vel_tutor_web/controllers/`

**Current Implementation Context:**
- **Active Story:** MCP Orchestrator Agent (1-1) - coordinates AI providers for task execution
- **Progress:** Architecture complete, core contexts implemented, API endpoints functional
- **Next:** Complete orchestrator testing, add advanced workflow routing, UI dashboard (epic-2)

**Testing Requirements:**
- Unit tests: `test/vel_tutor/` (context functions, services)
- Integration tests: `test/vel_tutor_web/` (API endpoints with database)
- External API mocking: Use Mox in tests (OpenAI/Groq adapters)
- Coverage goal: Maintain 75%+ (run `mix coveralls.html`)

**Deployment Considerations:**
- Fly.io auto-scaling (scale via `fly scale count X`)
- Secrets management: `fly secrets set <KEY>=<VALUE>`
- Database: Fly Postgres (multi-region replication)
- Monitoring: `fly logs` for real-time debugging

---
**Generated:** 2025-11-03  
**Part:** main (Elixir/Phoenix Backend)  
**Lines:** 280  
**Status:** Complete
