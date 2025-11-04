# Configuration Management - vel_tutor Main Backend

## Environment Configuration

**Primary Configuration Strategy:** Phoenix runtime configuration with secrets management

**Configuration Loading Order:**
1. `config/config.exs` - Base configuration (imported by all environments)
2. `config/dev.exs` - Development overrides (port 4000, debug logging)
3. `config/test.exs` - Test environment (in-memory SQLite, no external services)
4. `config/prod.exs` - Production settings (SSL, caching, rate limiting)
5. `config/runtime.exs` - Runtime secrets (loaded from environment variables)

## Database Configuration

**Development (`config/dev.exs`):**
```elixir
config :vel_tutor, VelTutor.Repo,
  database: "vel_tutor_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10

# Ecto migrations
config :vel_tutor, :ecto_repos, [VelTutor.Repo]
```

**Test (`config/test.exs`):**
```elixir
# Use SQLite for tests (in-memory)
config :vel_tutor, VelTutor.Repo,
  database: "test_vel_tutor.sqlite3",
  pool: Ecto.Adapters.SQL.Sandbox
```

**Production (`config/prod.exs` + `runtime.exs`):**
```elixir
# Loaded from FLY_DATABASE_URL environment variable
config :vel_tutor, VelTutor.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: 15,
  timeout: 30_000

# SSL and connection pooling optimized for Fly Postgres
config :vel_tutor, VelTutor.Repo,
  ssl: true,
  socket_options: [:inet6],
  parameters: [application_name: "vel_tutor"]
```

## External Services Configuration

**External Services:**
- OpenAI API key in runtime.exs (secrets management)
- Groq API key (OpenAI-compatible endpoint)
- Task Master MCP configuration (local server integration)
- Fly.io deployment secrets

**API Provider Configuration (`config/runtime.exs`):**
```elixir
# OpenAI Configuration
config :vel_tutor, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  base_url: "https://api.openai.com/v1",
  default_model: "gpt-4o",
  timeout: 120_000,
  max_retries: 3

# Groq Configuration (OpenAI-compatible)
config :vel_tutor, :groq,
  api_key: System.get_env("GROQ_API_KEY"),
  base_url: "https://api.groq.com/openai/v1",
  default_model: "llama-3.1-70b",
  timeout: 60_000,
  max_retries: 2

# Task Master MCP
config :vel_tutor, :task_master,
  url: System.get_env("TASK_MASTER_URL") || "http://localhost:3000",
  api_key: System.get_env("TASK_MASTER_API_KEY"),
  timeout: 120_000

# Perplexity API (if used for research tasks)
config :vel_tutor, :perplexity,
  api_key: System.get_env("PERPLEXITY_API_KEY"),
  base_url: "https://api.perplexity.ai/chat/completions",
  default_model: "llama-3.1-sonar-small-128k-online"
```

**Environment Variables Required:**
```
OPENAI_API_KEY=sk-proj-...
GROQ_API_KEY=gsk-...
TASK_MASTER_API_KEY=your-taskmaster-key
DATABASE_URL=postgresql://...
FLY_DATABASE_URL=postgresql://...
PORT=4000  # Development only
```

**Secrets Management Strategy:**
- **Development:** Local environment variables or `.env` file (not committed)
- **Production:** Fly.io secrets (`fly secrets set OPENAI_API_KEY=...`)
- **Security:** API keys encrypted in database (integrations table), never hardcoded
- **Rotation:** API keys can be rotated without downtime (database update only)

## Phoenix Endpoint Configuration

**Development (`config/dev.exs`):**
```elixir
config :vel_tutor, VelTutorWeb.Endpoint,
  url: [host: "localhost", port: 4000],
  debug_errors: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts --public:/static], cd: Path.expand("../assets", __DIR__)}
  ]

# Enable code reloading
config :vel_tutor, VelTutorWeb.Endpoint, 
  live_reload: [
    patterns: [
      ~w(*.ex:VelTutorWeb.Endpoint),
      ~w(*.exs:VelTutorWeb.Endpoint),
      ~w(*.ex:VelTutor),
      ~w(*.exs:VelTutor),
      ~w(*.ex:VelTutorWeb),
      ~w(*.exs:VelTutorWeb),
      ~w(priv/static/!(fonts|[Ecto]|[Livetex]|[Web]/*.[html|js|css]))
    ]
  ]
```

**Production (`config/prod.exs`):**
```elixir
config :vel_tutor, VelTutorWeb.Endpoint,
  url: [host: "vel-tutor.fly.dev", port: 443],
  cache_static_manifest: "priv/static/cache_manifest.json",
  force_ssl: true,
  http: [
    port: 4000,
    transport_options: [socket_opts: [:inet6]]
  ],
  https: [
    port: 443,
    cipher_suite_options: [
      ssl_ciphers: [
        "ECDHE-ECDSA-AES128-GCM-SHA256",
        "ECDHE-RSA-AES128-GCM-SHA256",
        "ECDHE-ECDSA-AES128-SHA256",
        "ECDHE-RSA-AES128-SHA256"
      ]
    ]
  ]

# Router configuration
config :vel_tutor, :guardian,
  issuer: "vel_tutor",
  ttl: {24, :hours},
  verify_issuer: true,
  serializer: VelTutor.GuardianSerializer,
  serializer_by: :id
```

## Secrets Management

**Runtime Secrets (`config/runtime.exs`):**
All sensitive configuration loaded from environment variables at runtime:

```elixir
import Config

# Database (loaded from DATABASE_URL or FLY_DATABASE_URL)
database_url =
  System.get_env("DATABASE_URL") ||
  System.get_env("FLY_DATABASE_URL") ||
  raise("environment variable DATABASE_URL is missing")

config :vel_tutor, VelTutor.Repo,
  url: database_url,
  pool_size: 15

# External API Providers
config :vel_tutor, :openai,
  api_key: System.get_env("OPENAI_API_KEY") || raise("OPENAI_API_KEY missing"),
  base_url: System.get_env("OPENAI_BASE_URL") || "https://api.openai.com/v1"

config :vel_tutor, :groq,
  api_key: System.get_env("GROQ_API_KEY") || raise("GROQ_API_KEY missing"),
  base_url: System.get_env("GROQ_BASE_URL") || "https://api.groq.com/openai/v1"

config :vel_tutor, :task_master,
  url: System.get_env("TASK_MASTER_URL") || "http://localhost:3000",
  api_key: System.get_env("TASK_MASTER_API_KEY") || raise("TASK_MASTER_API_KEY missing")

# Application secret key (for Guardian JWT)
config :vel_tutor, :secret_key_base,
  System.get_env("SECRET_KEY_BASE") ||
  raise("environment variable SECRET_KEY_BASE is missing")

# Guardian JWT configuration
config :guardian, Guardian,
  issuer: "vel_tutor",
  ttl: {24, :hours},
  verify_issuer: true,
  serializer: VelTutor.GuardianSerializer

# Phoenix endpoint secret (for dev only - prod uses Guardian)
if config_env() == :dev do
  config :phoenix, :json_library, Jason
  config :plug, :validate_json_data_keys, true
end
```

**Development Secrets Template (`config/dev.secret.exs`):**
```elixir
import Config

# Copy this file to config/dev.secret.exs and uncomment/edit:

# config :vel_tutor, :openai,
#   api_key: "sk-proj-your-openai-key-here"

# config :vel_tutor, :groq,
#   api_key: "gsk-your-groq-key-here"

# config :vel_tutor, :task_master,
#   api_key: "your-task-master-key-here"

# config :vel_tutor, :secret_key_base,
#   "your-64-character-secret-key-base-here"

# Database (local development)
config :vel_tutor, VelTutor.Repo,
  database: "vel_tutor_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"
```

**Production Secrets (Fly.io):**
```bash
# Set via Fly CLI
fly secrets set OPENAI_API_KEY=sk-proj-...
fly secrets set GROQ_API_KEY=gsk-...
fly secrets set TASK_MASTER_API_KEY=your-taskmaster-key
fly secrets set SECRET_KEY_BASE=64-random-characters-for-jwt-signing
```

## Provider-Specific Configuration

**OpenAI Configuration:**
- **API Key:** `OPENAI_API_KEY` (required for GPT models)
- **Base URL:** `OPENAI_BASE_URL` (default: https://api.openai.com/v1)
- **Default Model:** GPT-4o (configurable per agent)
- **Organization:** Not required (personal/team account)
- **Usage:** Complex reasoning tasks, embeddings

**Groq Configuration:**
- **API Key:** `GROQ_API_KEY` (required for Llama/Mixtral models)
- **Base URL:** `GROQ_BASE_URL` (https://api.groq.com/openai/v1 - OpenAI-compatible)
- **Default Model:** llama-3.1-70b (fastest for code generation)
- **Performance:** 5-10x faster inference than GPT-4o, 41% cost reduction
- **Compatibility:** Uses same OpenAI Elixir client library (only base_url and model names differ)
- **Usage:** Code generation, validation tasks, lightweight reasoning

**Task Master MCP Configuration:**
- **URL:** `TASK_MASTER_URL` (http://localhost:3000 dev, configured in prod)
- **API Key:** `TASK_MASTER_API_KEY` (authentication for MCP server)
- **Timeout:** 120 seconds for task operations
- **Protocol:** REST API over HTTP/2
- **Local Development:** MCP server must be running locally for full testing

## CORS Configuration

**Development (`config/dev.exs`):**
```elixir
config :cors_plug,
  origin: ["http://localhost:3000", "http://localhost:3001"],
  max_age: 24 * 60 * 60,
  send_headers: true

config :vel_tutor, VelTutorWeb.Endpoint,
  check_origin: false  # Allow all origins in dev
```

**Production (`config/prod.exs`):**
```elixir
config :cors_plug,
  origin: [
    "https://vel-tutor.fly.dev",
    "https://your-frontend-domain.com"
  ],
  max_age: 24 * 60 * 60,
  send_headers: true

config :vel_tutor, VelTutorWeb.Endpoint,
  check_origin: true  # Enforce CORS in production
```

## Logging and Monitoring

**Logger Configuration:**
- **Development:** Console logger with metadata, debug level
- **Production:** Structured logging to Fly logs, info level minimum
- **Audit Logging:** All API calls and user actions logged to audit_logs table

**Monitoring Endpoints:**
- `GET /api/health` - System health (database, providers, uptime)
- **Fly.io Integration:** Built-in metrics dashboard, log streaming
- **Performance Tracking:** MCP orchestrator logs execution times and provider selection

## Development vs Production Differences

**Development Environment:**
- Database: Local PostgreSQL (localhost:5432)
- Logging: Debug level, console output
- External Services: Local Task Master MCP (http://localhost:3000)
- Rate Limits: Disabled or relaxed
- Error Details: Full stack traces for debugging

**Production Environment:**
- Database: Fly Postgres (multi-region, encrypted connection)
- Logging: Structured JSON logs to Fly logging
- External Services: Production API endpoints (OpenAI, Groq)
- Rate Limits: Enforced (100/hour authenticated, 5/min auth)
- Error Details: User-friendly messages only (no stack traces)
- SSL: Mandatory (redirect HTTP to HTTPS)
- Caching: Enabled for static assets and API responses

## Security Configuration

**Authentication:**
- JWT tokens (HS256 signing, 24h expiry)
- Token blacklisting on logout
- Role-based access control (admin/user)
- Password requirements: 12+ characters, complexity validation

**Data Protection:**
- API keys encrypted in database (integrations table)
- Passwords hashed with Bcrypt (12 rounds)
- Audit logs capture IP address and user agent for security events
- No sensitive data exposed in API responses (passwords, API keys redacted)

**Rate Limiting:**
- Authentication endpoints: 5 attempts per minute per IP
- Protected endpoints: 100 requests per hour per user
- Burst protection: 10 concurrent requests per user
- Implementation: ETS-based sliding window in RateLimiter plug

**External Service Security:**
- API keys validated on connection (no blind storage)
- Provider-specific error handling (quota exceeded, rate limits)
- Circuit breaker prevents cascading failures
- Request/response logging for debugging (redacted in production)

## Database Configuration Details

**Ecto Repository (`config/repo.exs`):**
```elixir
use Ecto.Repo,
  otp_app: :vel_tutor,
  adapter: Ecto.Adapters.Postgres,
  source_url: System.get_env("DATABASE_URL")

# Custom repository settings
defmodule VelTutor.Repo do
  use Ecto.Repo,
    otp_app: :vel_tutor,
    adapter: Ecto.Adapters.Postgres,
    source_url: System.get_env("DATABASE_URL")

  use Ecto.Repo.RepoCallbacks

  # Custom query tags for monitoring
  @impl true
  def query_tags(_type, Ecto.Query.Source{source: source}, opts) do
    opts
    |> Keyword.put(:source, source)
    |> Keyword.put(:prefix, "vel_tutor")
  end
end
```

**Migration Configuration:**
- All migrations in `priv/repo/migrations/` follow Ecto conventions
- Timestamps include timezone support
- Foreign key constraints enforced
- JSONB fields indexed for performance

**Connection Pooling:**
- Development: 10 connections
- Production: 15 connections (Fly.io optimized)
- Timeout: 30 seconds (production), 15 seconds (development)
- SSL: Enabled in production, disabled in development

## Performance Configuration

**Phoenix Endpoint (`config/prod.exs`):**
```elixir
# Optimized for production
config :vel_tutor, VelTutorWeb.Endpoint,
  http: [
    port: 4000,
    transport_options: [socket_opts: [:inet6]]
  ],
  https: [
    port: 443,
    cipher_suite_options: [
      ssl_ciphers: [
        "ECDHE-ECDSA-AES256-GCM-SHA384",
        "ECDHE-RSA-AES256-GCM-SHA384",
        "ECDHE-ECDSA-AES128-GCM-SHA256",
        "ECDHE-RSA-AES128-GCM-SHA256"
      ]
    ]
  ],
  check_origin: true,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Static asset caching
config :vel_tutor, VelTutorWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  render_errors: [view: VelTutorWeb.ErrorView, accepts: ~w(json)]
```

**External Service Timeouts:**
- OpenAI API: 120 seconds (complex reasoning)
- Groq API: 60 seconds (optimized for speed)
- Task Master MCP: 120 seconds (task execution timeout)
- Database queries: 30 seconds (production), 15 seconds (development)

**Connection Pooling:**
- Database: 15 connections (production), 10 (development)
- HTTP clients: 20 connections per provider (OpenAI, Groq, Task Master)
- ETS tables: Configurable size for rate limiting and caching

## Monitoring and Logging

**Application Logging:**
- **Console Backend:** Development (debug level)
- **Structured Logging:** Production (JSON format for log aggregation)
- **Log Levels:** Debug (dev), Info (prod), Error (all environments)
- **Metadata:** User ID, request ID, provider used, execution time

**External Service Monitoring:**
- **OpenAI:** Request/response logging, rate limit tracking, quota monitoring
- **Groq:** Performance metrics (latency, tokens per minute), cost tracking
- **Task Master:** Connection status, task success rates, error patterns

**Health Check Endpoint:** `GET /api/health`
- Database connectivity
- Provider availability (OpenAI, Groq, Task Master)
- System uptime and metrics
- Background worker status

**Performance Metrics:**
- API response times (P50, P95, P99)
- Provider selection success rates
- Task execution latency (per provider)
- Database query performance
- Memory and CPU usage (via Fly.io metrics)

## Development Workflow Integration

**Local Development Configuration:**
- Database: Local PostgreSQL (localhost:5432)
- External Services: Mocked or local endpoints (Task Master localhost:3000)
- Logging: Verbose console output for debugging
- Rate Limits: Disabled or significantly relaxed

**Testing Configuration:**
- Database: SQLite in-memory (fast test isolation)
- External Services: Mox mocks for all API providers
- Logging: Captured output only (no console spam)
- Rate Limits: Disabled completely

**Production Configuration:**
- Database: Fly Postgres (multi-region, encrypted)
- External Services: Production API endpoints with real keys
- Logging: Structured JSON to centralized logging
- Rate Limits: Enforced (100/hour authenticated, 5/min auth)
- Security: SSL mandatory, audit logging enabled

## Environment-Specific Overrides

**Development Overrides (`config/dev.exs`):**
- Phoenix server on port 4000 (HTTP only)
- Database: Local PostgreSQL with verbose query logging
- External services: Mock endpoints or relaxed validation
- Rate limiting: Disabled (for easier testing)
- Error details: Full stack traces for debugging

**Test Overrides (`config/test.exs`):**
- Database: In-memory SQLite (no external DB dependency)
- External services: All mocked with Mox (no real API calls)
- Phoenix endpoint: Disabled (no HTTP server needed)
- Logging: Silent (captured only)
- Rate limiting: Disabled
- Seed data: Minimal test data loaded

**Production Overrides (`config/prod.exs`):**
- Database: Fly Postgres (production URL from DATABASE_URL)
- External services: Production endpoints with real API keys
- Phoenix endpoint: HTTPS only, CORS restricted to frontend domains
- Rate limiting: Fully enforced (100/hour, 5/min auth)
- Error details: User-friendly messages only (no stack traces)
- Security: All security features enabled (SSL, audit logging)

## Secrets Rotation

**API Key Rotation Process:**
1. Generate new API key from provider dashboard
2. Update database: `UPDATE integrations SET api_key = :new_key WHERE provider = :provider AND user_id = :user_id`
3. Update Fly secrets: `fly secrets set PROVIDER_API_KEY=new_key`
4. Test connectivity: `POST /api/agents/:id/test` (uses new key)
5. Verify old key is no longer functional (optional: immediate invalidation)

**JWT Secret Rotation:**
1. Generate new 64-character secret key
2. Update `SECRET_KEY_BASE` environment variable
3. Deploy with new secret (old tokens remain valid until expiry)
4. Implement token refresh rotation (recommended for high-security)

**Database Secret Rotation:**
- Fly Postgres: `fly postgres reconfigure` (rotates connection strings)
- Application restart required after secret changes
- No data migration needed (handled by connection string)

## Configuration Best Practices

**Security:**
- Never commit API keys to version control
- Use environment variables for all secrets (no .env files in repo)
- Validate API key format before storing (provider-specific validation)
- Rotate secrets regularly (90-day cycle recommended)
- Audit log all configuration changes and API key validations

**Performance:**
- Cache compiled templates and static assets in production
- Use database connection pooling (15 connections in prod)
- Configure HTTP client timeouts appropriately (120s for OpenAI, 60s for Groq)
- Enable query caching for repeated database operations
- Monitor provider quotas and implement graceful degradation

**Monitoring:**
- Track API key usage and costs per provider
- Monitor external service latency and error rates
- Log all configuration changes with timestamps
- Alert on quota limits (80% threshold)
- Performance metrics for provider routing decisions

**Development:**
- Use `config/dev.secret.exs` template for local secrets
- Mock external services during development (Mox + test database)
- Enable verbose logging for troubleshooting
- Use development database for local testing
- Consider Docker Compose for consistent local environment

**Production:**
- All secrets managed via Fly secrets (no local files)
- Database connection pooling optimized for load
- Rate limiting and security headers enforced
- Structured logging for centralized log aggregation
- Health checks and monitoring endpoints active

---
**Generated:** 2025-11-03  
**Part:** main  
**Configuration Sources:** 8 files analyzed  
**External Services:** OpenAI, Groq, Task Master (3 providers)  
**Status:** Complete
