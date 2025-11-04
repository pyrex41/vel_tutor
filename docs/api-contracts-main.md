# API Contracts - vel_tutor Main Backend

## API Overview

**Base URL:** `/api/v1` (versioned REST API)  
**Authentication:** JWT Bearer tokens (Guardian)  
**Content-Type:** `application/json`  
**Rate Limiting:** 100 requests/hour (authenticated), 5 auth attempts/minute  
**Error Format:** Standard JSON error responses with `error` field  

**External Integrations:** OpenAI API (GPT models) and Groq API (OpenAI-compatible high-performance inference), Task Master MCP server

## Authentication Endpoints

### POST /api/auth/login
**Purpose:** User authentication, returns JWT token  
**Authentication:** None (public)  
**Rate Limit:** 5 attempts per minute per IP  

**Request:**
```json
{
  "email": "user@example.com",
  "password": "secure_password"
}
```

**Response (200):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "role": "user"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_at": "2025-11-04T13:30:00Z"
}
```

**Response (401):**
```json
{
  "error": "Invalid credentials"
}
```

### POST /api/auth/refresh
**Purpose:** Refresh JWT token  
**Authentication:** Valid JWT required  

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_at": "2025-11-04T13:30:00Z"
}
```

## User Management Endpoints

### GET /api/users/me
**Purpose:** Get current user profile  
**Authentication:** Valid JWT required  

**Response (200):**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "role": "user",
  "created_at": "2025-11-03T10:00:00Z",
  "updated_at": "2025-11-03T10:00:00Z"
}
```

### PUT /api/users/me
**Purpose:** Update current user profile  
**Authentication:** Valid JWT required  

**Request:**
```json
{
  "email": "new@example.com",
  "password": "new_secure_password"
}
```

**Response (200):**
```json
{
  "id": "uuid",
  "email": "new@example.com",
  "role": "user",
  "updated_at": "2025-11-03T10:05:00Z"
}
```

### POST /api/users (Admin Only)
**Purpose:** Create new user (admin only)  
**Authentication:** Valid JWT with admin role  

**Request:**
```json
{
  "email": "newuser@example.com",
  "password": "secure_password",
  "role": "user"
}
```

**Response (201):**
```json
{
  "id": "uuid",
  "email": "newuser@example.com",
  "role": "user",
  "created_at": "2025-11-03T10:10:00Z"
}
```

### GET /api/users (Admin Only)
**Purpose:** List all users (admin only)  
**Authentication:** Valid JWT with admin role  

**Query Parameters:**
- `limit` (default: 20, max: 100)
- `offset` (default: 0)
- `role` (filter by role: admin/user)

**Response (200):**
```json
{
  "data": [
    {
      "id": "uuid",
      "email": "user@example.com",
      "role": "user",
      "created_at": "2025-11-03T10:00:00Z"
    }
  ],
  "meta": {
    "total": 5,
    "limit": 20,
    "offset": 0
  }
}
```

## Agent Management Endpoints

### POST /api/agents
**Purpose:** Create MCP agent configuration  
**Authentication:** Valid JWT required  

**Request:**
```json
{
  "name": "My MCP Agent",
  "type": "mcp_orchestrator",
  "config": {
    "providers": ["openai", "groq"],
    "model_preferences": {
      "complex_reasoning": "gpt-4o",
      "code_generation": "llama-3.1-70b",
      "research": "perplexity-sonar"
    },
    "max_retries": 3,
    "timeout_seconds": 120
  }
}
```

**Response (201):**
```json
{
  "id": "uuid",
  "name": "My MCP Agent",
  "type": "mcp_orchestrator",
  "status": "active",
  "config": { ... },
  "created_at": "2025-11-03T10:15:00Z"
}
```

### GET /api/agents
**Purpose:** List user's agents  
**Authentication:** Valid JWT required  

**Query Parameters:**
- `limit` (default: 20, max: 100)
- `offset` (default: 0)
- `status` (filter: active/inactive)

**Response (200):**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "My MCP Agent",
      "type": "mcp_orchestrator",
      "status": "active",
      "created_at": "2025-11-03T10:15:00Z"
    }
  ],
  "meta": {
    "total": 3,
    "limit": 20,
    "offset": 0
  }
}
```

### GET /api/agents/:id
**Purpose:** Get specific agent details  
**Authentication:** Valid JWT required  

**Response (200):**
```json
{
  "id": "uuid",
  "name": "My MCP Agent",
  "type": "mcp_orchestrator",
  "status": "active",
  "config": {
    "providers": ["openai", "groq"],
    "model_preferences": { ... }
  },
  "created_at": "2025-11-03T10:15:00Z",
  "updated_at": "2025-11-03T10:15:00Z"
}
```

### PUT /api/agents/:id
**Purpose:** Update agent configuration  
**Authentication:** Valid JWT required  

**Request:**
```json
{
  "name": "Updated MCP Agent",
  "config": {
    "providers": ["openai", "groq", "perplexity"],
    "max_retries": 5
  }
}
```

**Response (200):**
```json
{
  "id": "uuid",
  "name": "Updated MCP Agent",
  "status": "active",
  "updated_at": "2025-11-03T10:20:00Z"
}
```

### DELETE /api/agents/:id
**Purpose:** Delete agent  
**Authentication:** Valid JWT required  

**Response (204):** No content

### POST /api/agents/:id/test
**Purpose:** Test agent configuration (dry run)  
**Authentication:** Valid JWT required  

**Request:**
```json
{
  "test_payload": "Hello, MCP Agent!",
  "test_type": "simple_echo"
}
```

**Response (200):**
```json
{
  "test_id": "uuid",
  "status": "completed",
  "result": "Agent configuration valid",
  "execution_time_ms": 245,
  "provider_used": "groq"
}
```

## Task Orchestration Endpoints

### POST /api/tasks
**Purpose:** Create and execute task  
**Authentication:** Valid JWT required  

**Request:**
```json
{
  "agent_id": "uuid",
  "description": "Generate Python code for data analysis",
  "priority": "high",
  "parameters": {
    "language": "python",
    "task_type": "code_generation",
    "input_data": { ... }
  }
}
```

**Response (201):**
```json
{
  "id": "uuid",
  "agent_id": "uuid",
  "description": "Generate Python code for data analysis",
  "status": "pending",
  "priority": "high",
  "created_at": "2025-11-03T10:25:00Z"
}
```

### GET /api/tasks
**Purpose:** List user's tasks  
**Authentication:** Valid JWT required  

**Query Parameters:**
- `limit` (default: 20, max: 100)
- `offset` (default: 0)
- `status` (pending/in_progress/completed/failed)
- `agent_id` (filter by agent)

**Response (200):**
```json
{
  "data": [
    {
      "id": "uuid",
      "agent_id": "uuid",
      "description": "Generate Python code...",
      "status": "in_progress",
      "priority": "high",
      "created_at": "2025-11-03T10:25:00Z",
      "updated_at": "2025-11-03T10:26:00Z"
    }
  ],
  "meta": {
    "total": 15,
    "limit": 20,
    "offset": 0
  }
}
```

### GET /api/tasks/:id
**Purpose:** Get task details and execution history  
**Authentication:** Valid JWT required  

**Response (200):**
```json
{
  "id": "uuid",
  "agent_id": "uuid",
  "description": "Generate Python code...",
  "status": "completed",
  "priority": "high",
  "parameters": { ... },
  "result": {
    "output": "```python\ndef analyze_data(df):\n    ...\n```",
    "execution_time_ms": 1245,
    "provider_used": "groq",
    "model": "llama-3.1-70b"
  },
  "history": [
    {
      "step": "initialization",
      "timestamp": "2025-11-03T10:25:00Z",
      "status": "started"
    },
    {
      "step": "execution",
      "timestamp": "2025-11-03T10:26:15Z",
      "status": "completed",
      "provider": "groq"
    }
  ],
  "created_at": "2025-11-03T10:25:00Z",
  "updated_at": "2025-11-03T10:26:45Z"
}
```

### POST /api/tasks/:id/cancel
**Purpose:** Cancel running task  
**Authentication:** Valid JWT required  

**Request Body:** Empty

**Response (200):**
```json
{
  "id": "uuid",
  "status": "cancelled",
  "updated_at": "2025-11-03T10:30:00Z"
}
```

### GET /api/tasks/:id/stream
**Purpose:** Real-time task progress (Server-Sent Events)  
**Authentication:** Valid JWT required  

**Response Stream (text/event-stream):**
```
data: {"progress": 25, "status": "initializing", "message": "Loading agent configuration"}

data: {"progress": 50, "status": "executing", "message": "Running on Groq Llama 3.1"}

data: {"progress": 100, "status": "completed", "result": "Task finished successfully"}
```

## System Endpoints

### GET /api/health
**Purpose:** System health check  
**Authentication:** None (public)  

**Response (200):**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-03T10:35:00Z",
  "uptime": "2h 15m",
  "version": "1.0.0",
  "dependencies": {
    "database": "connected",
    "openai": "available",
    "groq": "available",
    "task_master": "connected"
  }
}
```

## Error Responses

**Standard Error Format:**
```json
{
  "error": "Validation failed",
  "details": [
    {
      "field": "email",
      "message": "must be valid email format"
    }
  ],
  "code": "VALIDATION_ERROR",
  "timestamp": "2025-11-03T10:40:00Z"
}
```

**Common Error Codes:**
- `AUTHENTICATION_REQUIRED` (401) - Missing or invalid JWT
- `UNAUTHORIZED` (403) - Insufficient permissions
- `VALIDATION_ERROR` (400) - Request validation failed
- `NOT_FOUND` (404) - Resource not found
- `RATE_LIMIT_EXCEEDED` (429) - Too many requests
- `INTERNAL_SERVER_ERROR` (500) - Unexpected error

## External Integration Details

**OpenAI/Groq Integration (via VelTutor.Integration.OpenAI):**
- **OpenAI Endpoint:** `https://api.openai.com/v1` (GPT-4o, GPT-4o-mini)
- **Groq Endpoint:** `https://api.groq.com/openai/v1` (Llama 3.1 70B, Mixtral 8x7B)
- **Shared Library:** OpenAI-compatible client (same Elixir library, configurable base_url)
- **Model Routing:** 
  - Complex reasoning: GPT-4o (OpenAI)
  - Code generation: Llama 3.1 70B (Groq - 5-10x faster)
  - Cost optimization: GPT-4o-mini (OpenAI) or Mixtral (Groq)
- **Fallback Strategy:** OpenAI → Groq (52% faster inference, 41% cost reduction)
- **Error Handling:** Circuit breaker (3 retries, exponential backoff), provider rotation

**Task Master MCP Integration:**
- **Endpoint:** Local MCP server (`http://localhost:3000` dev, configured URL in prod)
- **Protocol:** REST API (task creation, status polling, result retrieval)
- **Authentication:** API key (stored in integrations table, encrypted)
- **Task Flow:** Submit task → Poll status → Retrieve results → Update database

**Configuration:** All API keys and endpoints managed via `config/runtime.exs` and database integrations table.

---
**Generated:** 2025-11-03  
**Part:** main  
**Endpoints Documented:** 18  
**Status:** Complete
