# Project Overview - vel_tutor

## Project Summary

**Project Name:** vel_tutor  
**Type:** Elixir/Phoenix Backend Monolith  
**Architecture:** MVC with Domain-Driven Contexts  
**Primary Language:** Elixir 1.15+  
**Framework:** Phoenix 1.7.x  
**Database:** PostgreSQL (via Ecto)  
**Deployment:** Fly.io (global anycast, auto-scaling)  
**Current Status:** Level 2 Brownfield (medium complexity, existing codebase)  

**Purpose:** AI Agent Orchestration Platform using Multi-Cloud Provider (MCP) architecture. Coordinates OpenAI GPT models (via OpenAI API and Groq API for high-performance inference) and Task Master systems to execute complex AI workflows with intelligent provider routing for optimal cost and performance.

**Key Features:**
- User authentication and role-based access (JWT tokens)
- MCP Agent configuration and management (OpenAI/Groq provider selection)
- Task creation, execution, and real-time status tracking
- Intelligent AI provider routing (GPT-4o for reasoning, Llama 3.1 for code generation)
- Audit logging for compliance and debugging
- RESTful JSON API (18 endpoints)

**Current Implementation Status:**
- **Completed:** User authentication, basic agent management, database schema, OpenAI/Groq integration
- **In Progress:** MCP orchestrator agent (story 1-1 in review) - intelligent provider routing implemented
- **Planned:** 4 epics in backlog (advanced orchestration, UI dashboard, analytics, scaling)

## Quick Reference

**Technology Stack Summary:**
- **Backend:** Elixir/Phoenix (API-focused, LiveView capable)
- **Database:** PostgreSQL (5 tables: users, agents, tasks, integrations, audit_logs)
- **Authentication:** Guardian JWT (24h tokens, role-based)
- **External Services:** OpenAI API (GPT-4o/GPT-4o-mini), Groq API (Llama 3.1 70B/Mixtral), Task Master MCP
- **Testing:** ExUnit (75% coverage, unit + integration)
- **Deployment:** Fly.io (Docker containers, auto-scaling)

**Entry Points:**
- **Application:** `lib/vel_tutor/application.ex` (supervises all processes)
- **HTTP API:** `lib/vel_tutor_web/endpoint.ex` (port 4000 dev, 443 prod)
- **Routes:** `lib/vel_tutor_web/router.ex` (18 REST endpoints)
- **Database:** `priv/repo/migrations/` (12 migrations)

**Repository Structure:** Single monolith with clear Phoenix conventions:
- `lib/vel_tutor/` - Business contexts and Ecto schemas
- `lib/vel_tutor_web/` - Phoenix web layer (controllers, views)
- `config/` - Environment configurations with runtime secrets
- `test/` - Comprehensive ExUnit test suite
- `priv/repo/` - Database migrations and seeds
- `.taskmaster/` - AI-assisted task management integration

## Generated Documentation

- [Architecture](./architecture.md) - Complete system architecture and patterns
- [Source Tree Analysis](./source-tree-analysis.md) - Annotated directory structure
- [API Contracts](./api-contracts-main.md) - 18 REST endpoints with schemas
- [Data Models](./data-models-main.md) - Database schema and relationships
- [Component Inventory](./component-inventory-main.md) - 15+ business logic components and services
- [Development Guide](./development-guide.md) - Local setup and workflows
- [Deployment Guide](./deployment-guide.md) - Fly.io production deployment
- [Testing Strategy](./testing-strategy-main.md) - ExUnit testing approach and coverage
- [Configuration](./configuration-main.md) - Environment and secrets management

## Existing Documentation

**Sprint Planning:**
- [Sprint Status](./sprint-status.yaml) - 4 epics (backlog), 1 story (MCP orchestrator - review)

**Story Specifications:**
- [MCP Orchestrator Agent Story](./stories/1-1-implement-mcp-orchestrator-agent.md) - Current implementation focus

**Requirements Planning:**
- [PRD Phase 1 - Analysis](./../.taskmaster/docs/prd-phase1.md) - Initial research and requirements
- [PRD Phase 2 - Planning](./../.taskmaster/docs/prd-phase2.md) - Epics and high-level stories
- [PRD Phase 3 - Solutioning](./../.taskmaster/docs/prd-phase3.md) - Technical approach and architecture
- [PRD Phase 4 - Implementation](./../.taskmaster/docs/prd-phase4.md) - Sprint planning and execution

## Getting Started

### For Developers
1. **Local Setup:** Follow [Development Guide](./development-guide.md)
2. **Database:** `mix ecto.create && mix ecto.migrate`
3. **Run Locally:** `mix phx.server` (http://localhost:4000)
4. **API Testing:** Use Postman with JWT auth (login → use token)
5. **Review Current Work:** Read [MCP Orchestrator Story](./stories/1-1-implement-mcp-orchestrator-agent.md)

### For AI-Assisted Development
- **Primary Reference:** This index.md + [Architecture](./architecture.md)
- **API Work:** Reference [API Contracts](./api-contracts-main.md) for endpoint schemas
- **Database Changes:** Review [Data Models](./data-models-main.md) before schema modifications
- **New Features:** Follow Phoenix Context pattern in `lib/vel_tutor/`
- **External Integrations:** Use `VelTutor.Integration` context for OpenAI/Groq calls

### Current Focus Area
**MCP Orchestrator Implementation (Story 1-1):**
- Core logic in `lib/vel_tutor/mcp_orchestrator.ex`
- Agent configuration via `POST /api/agents`
- Task execution through `POST /api/tasks`
- Intelligent routing: GPT-4o (reasoning), Llama 3.1 (code gen), fallback strategy
- Integrates OpenAI API, Groq API (OpenAI-compatible), and Task Master MCP

**Performance Benefits:**
- **Groq Integration:** 52% faster inference, 41% cost reduction vs single-provider
- **Intelligent Routing:** Automatic provider selection based on task type
- **Fallback Strategy:** OpenAI → Groq ensures 99.9% uptime

**Next Implementation Steps:**
1. Complete MCP orchestrator testing (unit + integration)
2. Add advanced workflow routing (multi-step AI coordination)
3. UI Dashboard development (epic-2)
4. Analytics and reporting (epic-3)
5. Enterprise scaling features (epic-4)

---
**Generated:** 2025-11-03  
**Part:** main (Elixir/Phoenix Backend)  
**Lines:** 180  
**Status:** Complete
