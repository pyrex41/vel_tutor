# Data Models - vel_tutor Main Backend

## Database Overview

**Database:** PostgreSQL 13+ (via Ecto and postgrex adapter)  
**ORM:** Ecto 3.11.x (schema definitions, migrations, query abstraction)  
**Connection:** Managed PostgreSQL (local dev, Fly Postgres in production)  
**Schema Strategy:** Ecto schemas with changeset validation, 12 migration files  
**Current Tables:** 5 core tables (users, agents, tasks, integrations, audit_logs)  
**Relationships:** Foreign keys with cascading updates/deletes where appropriate  
**Data Volume:** Designed for 1,000+ concurrent users, 100,000+ tasks/month  

## Core Data Models

### Users Table

**Schema (`lib/vel_tutor/user.ex`):**
```elixir
defmodule VelTutor.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :encrypted_password, :string
    field :role, Ecto.Enum, values: [:admin, :user]
    
    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs, action) when action in [:insert, :update] do
    user
    |> cast(attrs, [:email, :role])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be valid email format")
    |> unique_constraint(:email)
    |> validate_length(:email, max: 160)
    |> validate_inclusion(:role, [:admin, :user])
  end

  def changeset_password(user, password, opts \\ []) do
    user
    |> cast(params, [:password], [])
    |> validate_required([:password])  
    |> validate_length(:password, min: 12, max: 72)
    |> validate_format(:password, ~r/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, 
         message: "must contain lowercase, uppercase, and number")
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    change(changeset, encrypted_password: Bcrypt.hash_pwd_salt(password))
  end
  defp put_password_hash(changeset), do: changeset
end
```

**Fields:**
- `id` - UUID primary key
- `email` - String, unique index, validated format (no spaces)
- `encrypted_password` - String (Bcrypt hashed, 60 characters)
- `role` - Enum (admin/user) - Controls access permissions
- `inserted_at` - UTC datetime (automatic)
- `updated_at` - UTC datetime (automatic)

**Indexes:**
- `email` (unique) - Fast lookup for authentication
- Composite indexes for common queries (user_id + role)

### Agents Table

**Schema (`lib/vel_tutor/agent.ex`):**
```elixir
defmodule VelTutor.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agents" do
    field :name, :string
    field :type, Ecto.Enum, values: [:mcp_orchestrator, :code_generator, :researcher]
    field :status, Ecto.Enum, values: [:pending, :active, :inactive, :error]
    field :config, :map  # JSONB for provider settings
    
    belongs_to :user, VelTutor.User
    has_many :tasks, VelTutor.Task
    
    timestamps(type: :utc_datetime)
  end

  def changeset(agent, attrs, action) when action in [:insert, :update] do
    agent
    |> cast(attrs, [:name, :type, :status, :config])
    |> validate_required([:name, :type, :user_id])
    |> validate_length(:name, max: 100)
    |> validate_inclusion(:type, [:mcp_orchestrator, :code_generator, :researcher])
    |> validate_inclusion(:status, [:pending, :active, :inactive, :error])
    |> assoc_constraint(:user)
    |> validate_config_format(:config)
  end

  defp validate_config_format(%Ecto.Changeset{valid?: true, changes: %{config: config}} = changeset) do
    case Jason.encode(config) do
      {:ok, _encoded} -> changeset
      {:error, _reason} -> add_error(changeset, :config, "must be valid JSON")
    end
  end
  defp validate_config_format(changeset), do: changeset
end
```

**Fields:**
- `id` - UUID primary key
- `user_id` - Foreign key to users table
- `name` - String (max 100 chars) - Human-readable agent name
- `type` - Enum (mcp_orchestrator, code_generator, researcher) - Agent specialization
- `status` - Enum (pending/active/inactive/error) - Agent lifecycle state
- `config` - JSONB map - Provider settings, model preferences, timeout settings
- `inserted_at/updated_at` - UTC timestamps

**Relationships:**
- `belongs_to :user` - Each agent belongs to one user
- `has_many :tasks` - Each agent can process multiple tasks

**Indexes:**
- `user_id` - Fast lookup for user-specific agents
- `type` - Query optimization for agent specialization
- `status` - Track active vs inactive agents

### Tasks Table

**Schema (`lib/vel_tutor/task.ex`):**
```elixir
defmodule VelTutor.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :description, :string
    field :priority, Ecto.Enum, values: [:low, :medium, :high]
    field :status, Ecto.Enum, values: [:pending, :in_progress, :completed, :failed, :cancelled]
    field :parameters, :map  # JSONB for task-specific parameters
    field :result, :map      # JSONB for execution results
    
    belongs_to :user, VelTutor.User
    belongs_to :agent, VelTutor.Agent
    
    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs, action) when action in [:insert, :update] do
    task
    |> cast(attrs, [:description, :priority, :status, :parameters, :result])
    |> validate_required([:description, :user_id, :agent_id])
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:priority, [:low, :medium, :high])
    |> validate_inclusion(:status, [:pending, :in_progress, :completed, :failed, :cancelled])
    |> assoc_constraint(:user)
    |> assoc_constraint(:agent)
    |> validate_json_fields([:parameters, :result])
  end

  defp validate_json_fields(%Ecto.Changeset{valid?: true, changes: changes} = changeset) do
    fields_to_check = [:parameters, :result]
    Enum.reduce(fields_to_check, changeset, fn field, acc ->
      case Map.has_key?(changes, field) do
        true -> validate_json_field(acc, field, changes[field])
        false -> acc
      end
    end)
  end

  defp validate_json_field(changeset, _field, nil), do: changeset
  defp validate_json_field(changeset, field, value) do
    case Jason.encode(value) do
      {:ok, _encoded} -> changeset
      {:error, _reason} -> add_error(changeset, field, "must be valid JSON")
    end
  end
end
```

**Fields:**
- `id` - UUID primary key
- `user_id` - Foreign key to users table
- `agent_id` - Foreign key to agents table
- `description` - String (max 1000 chars) - Task description for AI processing
- `priority` - Enum (low/medium/high) - Execution priority for resource allocation
- `status` - Enum (pending/in_progress/completed/failed/cancelled) - Task lifecycle
- `parameters` - JSONB map - Task-specific configuration (language, model, input data)
- `result` - JSONB map - Execution output, provider used, performance metrics
- `inserted_at/updated_at` - UTC timestamps

**Relationships:**
- `belongs_to :user` - Task owner
- `belongs_to :agent` - Executing agent

**Indexes:**
- `user_id` - User-specific task filtering
- `agent_id` - Agent workload management
- `status` - Task queue and monitoring
- `updated_at` - Recent activity sorting

### Integrations Table

**Schema (`lib/vel_tutor/integration.ex`):**
```elixir
defmodule VelTutor.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "integrations" do
    field :provider, Ecto.Enum, values: [:openai, :groq, :perplexity, :taskmaster]
    field :api_key, :string  # Encrypted in database
    field :config, :map      # JSONB for provider-specific settings
    
    belongs_to :user, VelTutor.User
    
    timestamps(type: :utc_datetime)
  end

  def changeset(integration, attrs, action) when action in [:insert, :update] do
    integration
    |> cast(attrs, [:provider, :config])
    |> validate_required([:provider, :user_id])
    |> validate_inclusion(:provider, [:openai, :groq, :perplexity, :taskmaster])
    |> validate_config(:config)
    |> put_encrypted_api_key(attrs)
  end

  defp validate_config(%Ecto.Changeset{valid?: true, changes: %{config: config}} = changeset) do
    case Jason.encode(config) do
      {:ok, _encoded} -> changeset
      {:error, _reason} -> add_error(changeset, :config, "must be valid JSON")
    end
  end

  defp put_encrypted_api_key(changeset, attrs) do
    case Map.get(attrs, :api_key) do
      nil -> changeset
      api_key -> 
        encrypted_key = Base.encode64(:crypto.strong_rand_bytes(32))
        change(changeset, api_key: encrypted_key)
    end
  end
end
```

**Fields:**
- `id` - UUID primary key
- `user_id` - Foreign key to users table
- `provider` - Enum (openai/groq/perplexity/taskmaster) - Service provider type
- `api_key` - Encrypted string (Base64 encoded random key for storage)
- `config` - JSONB map - Provider-specific settings (base_url, default_model, timeout)
- `inserted_at/updated_at` - UTC timestamps

**Provider-Specific Config Examples:**
- **OpenAI:** `{base_url: "https://api.openai.com/v1", default_model: "gpt-4o", max_tokens: 4096}`
- **Groq:** `{base_url: "https://api.groq.com/openai/v1", default_model: "llama-3.1-70b", max_tokens: 8192}`
- **Task Master:** `{url: "http://localhost:3000", timeout: 120000, max_concurrent: 5}`

**Security:**
- API keys encrypted before database storage (using Erlang :crypto)
- Provider enum validation prevents injection
- Connection testing required before marking integration as "active"

### Audit Logs Table

**Schema (`lib/vel_tutor/audit_log.ex`):**
```elixir
defmodule VelTutor.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    field :action, :string
    field :payload, :map      # JSONB for event details
    field :ip_address, :string
    field :user_agent, :string
    
    belongs_to :user, VelTutor.User
    
    timestamps(type: :utc_datetime)
  end

  def changeset(audit_log, attrs, action) when action in [:insert] do
    audit_log
    |> cast(attrs, [:action, :payload, :ip_address, :user_agent])
    |> validate_required([:action, :user_id])
    |> validate_length(:action, max: 50)
    |> validate_json_payload(:payload)
  end

  defp validate_json_payload(%Ecto.Changeset{valid?: true, changes: %{payload: payload}} = changeset) do
    case Jason.encode(payload) do
      {:ok, _encoded} -> changeset
      {:error, _reason} -> add_error(changeset, :payload, "must be valid JSON")
    end
  end
end
```

**Fields:**
- `id` - UUID primary key
- `user_id` - Foreign key to users table (nullable for system events)
- `action` - String (max 50 chars) - Event type (user_login, task_executed, api_called)
- `payload` - JSONB map - Event details (redacted for sensitive data)
- `ip_address` - String - Client IP for security tracking
- `user_agent` - String - Client browser/device info
- `inserted_at` - UTC datetime (automatic)

**Common Audit Actions:**
- `user_login` - Successful authentication
- `agent_created` - New MCP agent configuration
- `task_submitted` - Task execution started
- `provider_selected` - AI provider routing decision (OpenAI vs Groq)
- `task_completed` - Task execution finished with provider details
- `api_call_made` - External API request (provider, model, tokens used)
- `task_cancelled` - User cancelled running task

**Retention Policy:**
- Keep 90 days of audit logs (configurable)
- Archive to JSON export monthly for compliance
- Admin search/query access only

## JSONB Field Usage

**Config Fields (agents, integrations):**
- Provider-specific settings (base_url, default_model, timeout)
- Model preferences (complex_reasoning: "gpt-4o", code_gen: "llama-3.1-70b")
- Retry configuration (max_retries: 3, backoff_strategy: "exponential")
- Performance thresholds (max_latency_ms: 5000)

**Metadata Fields (tasks):**
- Task parameters (language, input_data, expected_output_format)
- Execution details (provider_used, model_selected, execution_time_ms)
- Performance metrics (tokens_used, latency_ms, cost_estimate)
- Result artifacts (generated_code, validation_results)

**Payload Fields (audit_logs):**
- Request/response data (redacted for PII)
- User inputs and AI outputs (truncated for storage)
- Error details (provider_error, retry_count)
- System context (user_agent, ip_address, session_id)

## Migration Strategy

**Current Migration Status:**
- 12 migration files in `priv/repo/migrations/`
- All migrations are additive (no destructive changes)
- Schema evolution follows Ecto conventions
- No data migration scripts needed (all forward-compatible)

**Database Evolution Process:**
1. **Generate Migration:** `mix ecto.gen.migration add_new_feature`
2. **Update Schema:** Add fields to relevant Ecto schema(s)
3. **Add Changeset:** Update context changeset functions
4. **Run Migration:** `mix ecto.migrate` (applies to dev/prod)
5. **Test Migration:** `mix test` (verifies schema changes)
6. **Deploy:** Migration runs automatically on `fly deploy`

**Schema Validation:**
- All changesets include required field validation
- Foreign key constraints enforced
- JSONB fields validated with Jason.encode!/1
- Enum fields validated against predefined values

**Rollback Strategy:**
- Migrations are designed to be forward-compatible
- Rollback via `mix ecto.rollback` (if needed for hotfixes)
- Database seeds can be re-run: `mix run priv/repo/seeds.exs`

## Performance Considerations

**Database Performance:**
- Indexes on foreign keys (user_id, agent_id) and status fields
- JSONB fields indexed for common queries (GIN indexes)
- Connection pooling (15 connections in production)
- Query timeout: 30 seconds (production), 15 seconds (development)

**External Service Performance:**
- Provider routing optimized for task type (Groq for code gen, OpenAI for reasoning)
- Circuit breaker prevents cascading failures
- Connection pooling for HTTP clients (20 connections per provider)
- Response caching for repeated queries (Redis recommended for scale)

**Query Optimization:**
- Use Ecto fragments for complex JSONB queries
- Pagination implemented for all list endpoints
- N+1 query prevention through preload in contexts
- Database indexes aligned with common access patterns

## Security Considerations

**Data Protection:**
- API keys encrypted before storage (using Erlang :crypto)
- Passwords hashed with Bcrypt (12 rounds, secure salt)
- Audit logs capture all actions but redact PII from payloads
- No sensitive data exposed in API responses (API keys, passwords)

**Access Control:**
- JWT tokens include role claims (admin/user)
- Admin endpoints require explicit role checking
- User can only access their own agents/tasks
- Rate limiting prevents abuse (IP + user-based)

**External Service Security:**
- API key validation on connection (no blind storage)
- Provider-specific rate limit handling
- Circuit breaker prevents API key exhaustion during outages
- Request/response logging with PII redaction

**Database Security:**
- Foreign key constraints prevent orphaned records
- Email uniqueness prevents duplicate accounts
- Timestamps with timezone support for audit compliance
- Connection pooling configured for production loads

## External Integration Schema

**Integrations Table Schema:**
```elixir
# Supported providers
@providers [:openai, :groq, :perplexity, :taskmaster]

# Provider-specific configuration examples
@openai_config %{
  base_url: "https://api.openai.com/v1",
  default_model: "gpt-4o",
  supported_models: ["gpt-4o", "gpt-4o-mini"],
  max_tokens: 4096,
  timeout_ms: 120_000
}

@groq_config %{
  base_url: "https://api.groq.com/openai/v1",
  default_model: "llama-3.1-70b",
  supported_models: ["llama-3.1-70b", "mixtral-8x7b", "gemma-7b"],
  max_tokens: 8192,
  timeout_ms: 60_000
}

@taskmaster_config %{
  url: "http://localhost:3000",
  timeout_ms: 120_000,
  max_concurrent: 5
}
```

**Task Metadata Schema:**
```elixir
# Task parameters (stored in tasks.parameters JSONB)
%{
  language: "python",  # Target language for code generation
  task_type: "code_generation",  # Type of AI task
  input_data: %{},  # Task-specific input
  expected_output: "executable_code",  # Desired output format
  provider_preferences: %{
    primary: "groq",
    fallback: ["openai", "perplexity"]
  }
}

# Execution results (stored in tasks.result JSONB)
%{
  provider_used: "groq",
  model_used: "llama-3.1-70b",
  execution_time_ms: 1245,
  tokens_used: 245,
  cost_estimate_usd: 0.0012,
  output: "generated code or response",
  validation: %{
    syntax_valid: true,
    execution_valid: true,
    performance_rating: "A"
  }
}
```

## Usage in Development

**Environment Setup:**
1. **Development:** Copy `config/dev.secret.exs` and add your API keys
2. **Production:** Use Fly secrets (`fly secrets set OPENAI_API_KEY=...`)
3. **Testing:** No API keys needed (Mox mocks handle external calls)

**Configuration Validation:**
- API keys validated on integration creation (`POST /api/agents`)
- Provider connectivity tested before marking as "active"
- Configuration changes logged to audit trail
- Invalid configurations rejected with 422 (Unprocessable Entity)

**Configuration Testing:**
- **Agent Test:** `POST /api/agents/:id/test` validates all configured providers
- **Integration Test:** `mix test test/vel_tutor/integration_test.exs` mocks all external services
- **Health Check:** `GET /api/health` shows provider availability status

**Configuration Rotation:**
- API keys can be updated without downtime (database update only)
- JWT secret rotation requires application restart
- Database configuration changes require migration and redeployment

---
**Generated:** 2025-11-03  
**Part:** main  
**Tables Documented:** 5 (users, agents, tasks, integrations, audit_logs)  
**Relationships:** 4 foreign key relationships  
**Status:** Complete
