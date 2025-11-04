# Development Guide - vel_tutor

## Prerequisites

**Required Software:**
- **Elixir:** 1.15+ (required for Phoenix 1.7.x)
- **Erlang/OTP:** 26+ (Elixir runtime)
- **PostgreSQL:** 13+ (development database)
- **Node.js:** 18+ (for asset compilation if UI present)
- **Fly CLI:** Latest version (for deployment and secrets management)
- **Git:** Version control (repository already initialized)
- **Hex.pm:** Elixir package manager (for dependencies)

**Development Environment:**
- macOS, Linux, or Windows with WSL2
- Terminal with Elixir toolchain installed
- PostgreSQL (local installation or Docker)
- Code editor with Elixir support (VS Code with ElixirLS recommended)

## Installation

### 1. Clone Repository
```bash
git clone <repository-url> vel_tutor
cd vel_tutor
```

### 2. Install Elixir Dependencies
```bash
# Install Hex package manager (if not installed)
mix local.hex --force

# Install project dependencies
mix deps.get
```

This downloads Phoenix, Ecto, Guardian, and all required Elixir packages to `deps/`.

### 3. Database Setup

**Option A: Local PostgreSQL (Recommended)**
```bash
# Install PostgreSQL (macOS)
brew install postgresql@13
brew services start postgresql@13

# Or use Docker
docker run --name vel_tutor_db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=vel_tutor_dev \
  -p 5432:5432 \
  -d postgres:13
```

**Create and Migrate Database:**
```bash
# Create development database
mix ecto.create

# Run migrations (creates 5 tables: users, agents, tasks, integrations, audit_logs)
mix ecto.migrate

# Seed with sample data
mix run priv/repo/seeds.exs
```

**Option B: Docker Compose (All-in-One)**
```bash
# Create docker-compose.yml
version: '3.1'
services:
  db:
    image: postgres:13
    environment:
      POSTGRES_DB: vel_tutor_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  app:
    build: .
    ports:
      - "4000:4000"
    depends_on:
      - db
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/vel_tutor_dev
```

**Run:** `docker-compose up --build`

### 4. Environment Configuration

**Copy Secrets Template:**
```bash
cp config/dev.secret.exs.example config/dev.secret.exs
```

**Edit `config/dev.secret.exs`:**
```elixir
import Config

# Database (local development)
config :vel_tutor, VelTutor.Repo,
  database: "vel_tutor_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

# OpenAI API (get from https://platform.openai.com/api-keys)
config :vel_tutor, :openai,
  api_key: "sk-proj-your-openai-api-key-here",
  base_url: "https://api.openai.com/v1"

# Groq API (get from https://console.groq.com/keys)
config :vel_tutor, :groq,
  api_key: "gsk-your-groq-api-key-here",
  base_url: "https://api.groq.com/openai/v1"

# Task Master MCP (local development server)
config :vel_tutor, :task_master,
  url: "http://localhost:3000",
  api_key: "your-task-master-api-key"

# JWT Secret (generate with: mix phx.gen.secret)
config :vel_tutor, :secret_key_base,
  "your-64-character-secret-key-base-here-for-development-only"
```

**Set Environment Variables (Alternative to secret.exs):**
```bash
export DATABASE_URL="ecto://postgres:postgres@localhost/vel_tutor_dev"
export OPENAI_API_KEY="sk-proj-your-openai-api-key-here"
export GROQ_API_KEY="gsk-your-groq-api-key-here"
export TASK_MASTER_API_KEY="your-task-master-key"
export SECRET_KEY_BASE="your-64-character-secret-key-base-here"
```

### 5. Install Node Dependencies (if UI assets present)
```bash
cd assets
npm install
```

This installs Tailwind CSS, esbuild, and any frontend dependencies (if your project includes UI components).

## Local Development

### Start Development Server
```bash
# Start Phoenix server (http://localhost:4000)
mix phx.server

# Or with hot reload (recommended for development)
mix phx.server --watch
```

**Access Points:**
- **API:** http://localhost:4000/api/
- **Health Check:** http://localhost:4000/api/health
- **Interactive Console:** http://localhost:4000/api/health (iex -S mix phx.server)

### Database Commands

**Create Database:**
```bash
mix ecto.create
```

**Run Migrations:**
```bash
mix ecto.migrate
```

**Seed Sample Data:**
```bash
mix run priv/repo/seeds.exs
```

**Reset Database (Development):**
```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

**Reset with Fresh Data (Testing):**
```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs --seed
```

### Testing

**Run Full Test Suite:**
```bash
mix test
```

**Run Specific Test:**
```bash
# Test specific file
mix test test/vel_tutor/user_context_test.exs

# Test specific line
mix test test/vel_tutor/user_context_test.exs:42
```

**Run with Coverage:**
```bash
mix coveralls.html
# Opens coverage report in browser
```

**Watch Mode (rerun tests on file changes):**
```bash
mix test.watch
```

**Test Database:** Uses SQLite in-memory by default (fast isolation). No external database required for tests.

### API Testing

**Using curl:**
```bash
# Login (get JWT token)
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# Use token for authenticated requests
curl -X GET http://localhost:4000/api/users/me \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE"
```

**Using Postman/Insomnia:**
1. **POST** `http://localhost:4000/api/auth/login`
   - Body: `{"email": "user@example.com", "password": "password"}`
   - Copy the `token` from response
2. **GET** `http://localhost:4000/api/users/me`
   - Headers: `Authorization: Bearer <token>`

**API Documentation:** See `/docs/api-contracts-main.md` for complete endpoint specifications.

## Common Development Tasks

### Generate New Context (Business Logic)
```bash
# Generate User context (if not exists)
mix phx.gen.context Accounts User users name:string email:string

# Generate MCP agent context
mix phx.gen.context Agents Agent agents name:string type:string config:map status:string
```

**Manual Steps After Generation:**
1. Update schema changeset validations
2. Add business logic to context functions
3. Create corresponding controller (if API endpoint needed)
4. Add database migration if new tables required

### Generate API Resource
```bash
# Generate JSON API resource (no views/templates)
mix phx.gen.json Api Agent agents name:string type:string

# Generate with binary_id primary keys (UUIDs)
mix phx.gen.json Api Task tasks description:string status:string --binary-id
```

**Generated Files:**
- `lib/vel_tutor/agents/` - Context and schema
- `lib/vel_tutor_web/controllers/agent_controller.ex` - API controller
- `lib/vel_tutor_web/router.ex` - API routes
- `test/vel_tutor/agents/` - Context tests
- `test/vel_tutor_web/controllers/agent_controller_test.exs` - Controller tests
- `priv/repo/migrations/` - Database migration

### Database Migrations

**Create Migration:**
```bash
mix ecto.gen.migration add_agent_config_to_tasks
```

**Edit Migration (`priv/repo/migrations/20251103120000_add_agent_config_to_tasks.exs`):**
```elixir
defmodule VelTutor.Repo.Migrations.AddAgentConfigToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :agent_config, :map
    end

    create index(:tasks, [:agent_config], using: :gin)
  end
end
```

**Run Migration:**
```bash
mix ecto.migrate
```

**Rollback (if needed):**
```bash
mix ecto.rollback
```

### Adding External Service Integration

**Step 1: Add to Integration Enum (`lib/vel_tutor/integration.ex`):**
```elixir
@providers [:openai, :groq, :perplexity, :taskmaster, :new_provider]
```

**Step 2: Create Adapter (`lib/vel_tutor/services/new_provider.ex`):**
```elixir
defmodule VelTutor.Services.NewProvider do
  @behaviour VelTutor.Services.Provider

  def chat_completion(prompt, model, options) do
    # Implementation using OpenAI-compatible client
    # or custom HTTP client for unique APIs
  end

  def validate_config(api_key, config) do
    # Test API key and endpoint connectivity
  end
end
```

**Step 3: Update IntegrationContext:**
```elixir
# Add to create_integration/2
defp validate_provider_config(:new_provider, config) do
  # Provider-specific validation
end
```

**Step 4: Update MCPOrchestrator Routing:**
```elixir
defp route_to_provider(task_type, integrations) do
  case task_type do
    :new_task_type -> select_new_provider(integrations)
    # ... other cases
  end
end
```

**Step 5: Add Configuration:**
```elixir
# config/dev.secret.exs
config :vel_tutor, :new_provider,
  api_key: "your-new-provider-key",
  base_url: "https://api.newprovider.com/v1"
```

**Step 6: Test Integration:**
```bash
# Test agent with new provider
curl -X POST http://localhost:4000/api/agents/UUID/test \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"test_payload": "Test new provider", "test_type": "simple_echo"}'
```

### Testing External Integrations

**Mock External Services (Development):**
```elixir
# test/support/mocks.ex
Mox.defmock(OpenAIGroqMock, for: OpenAI.Client)
Mox.defmock(TaskMasterMock, for: VelTutor.Services.TaskMaster)

# In tests
test "MCP orchestrator routes to Groq for code generation", %{conn: conn} do
  # Mock OpenAI/Groq responses
  expect(OpenAIGroqMock, :chat_completion, fn prompt, "llama-3.1-70b", _options ->
    {:ok, %OpenAI.ChatCompletion{messages: [%{role: "assistant", content: "mocked response"}]}}
  end)
  
  # Test task execution
  task = task_fixture()
  assert {:ok, result} = VelTutor.MCPOrchestrator.execute_task(task, integrations)
end
```

**Integration Testing:**
```bash
# Run tests with real external services (use test API keys)
OPENAI_API_KEY=test_key GROQ_API_KEY=test_key mix test test/vel_tutor/integration_test.exs

# Test MCP server integration
TASK_MASTER_URL=http://localhost:3000 TASK_MASTER_API_KEY=test_key mix test test/vel_tutor/task_master_test.exs
```

### Debugging and Troubleshooting

**Common Issues:**

1. **Database Connection:**
   ```bash
   # Check PostgreSQL is running
   psql -U postgres -h localhost -d vel_tutor_dev -c "\dt"
   
   # Check Ecto connection
   iex -S mix
   iex> VelTutor.Repo.query!("SELECT 1")
   ```

2. **External API Keys:**
   ```bash
   # Test OpenAI connectivity
   iex -S mix
   iex> VelTutor.Integration.OpenAI.chat_completion("test", "gpt-4o-mini", [])
   
   # Test Groq connectivity  
   iex> VelTutor.Integration.Groq.chat_completion("test", "llama-3.1-70b", [])
   ```

3. **JWT Authentication:**
   ```bash
   # Generate test token
   iex -S mix
   iex> {:ok, token, _claims} = VelTutor.Services.JWT.generate_token(%VelTutor.User{id: "test-user", role: "user"})
   iex> token
   
   # Test token validation
   iex> VelTutor.Services.JWT.validate_token(token)
   ```

4. **Task Master MCP:**
   ```bash
   # Ensure MCP server is running
   cd task-master
   npm start  # or yarn start
   
   # Test from vel_tutor
   iex -S mix
   iex> VelTutor.Services.TaskMaster.submit_task(%{description: "test"})
   ```

**Interactive Debugging:**
```bash
# Start IEx with server
iex -S mix phx.server

# Check database
iex> VelTutor.Repo.all(VelTutor.User)

# Test contexts
iex> VelTutor.UserContext.get_user_by_email("test@example.com")

# Test external integrations
iex> VelTutor.Integration.OpenAI.chat_completion("hello", "gpt-4o-mini", [])

# Check task execution
iex> {:ok, task} = VelTutor.TaskContext.create_task(%{description: "test"}, 1, 1)
iex> VelTutor.MCPOrchestrator.execute_task(task, integrations)
```

### Production Deployment

**Fly.io Deployment:**

1. **Authenticate:**
   ```bash
   fly auth login
   ```

2. **Launch Application:**
   ```bash
   fly launch
   # Select existing app or create new: vel_tutor
   ```

3. **Database Setup:**
   ```bash
   # Create managed PostgreSQL
   fly postgres create
   
   # Attach to application
   fly postgres attach vel_tutor-db
   ```

4. **Configure Secrets:**
   ```bash
   # Set all required secrets
   fly secrets set OPENAI_API_KEY=sk-proj-...
   fly secrets set GROQ_API_KEY=gsk-...
   fly secrets set TASK_MASTER_API_KEY=your-task-master-key
   fly secrets set SECRET_KEY_BASE=your-production-secret-key
   fly secrets set DATABASE_URL=postgres://...
   ```

5. **Deploy:**
   ```bash
   # Build and deploy to all regions
   fly deploy
   
   # Scale to 2 instances
   fly scale count 2
   
   # Set up auto-scaling
   fly autoscale create
   ```

6. **Monitor:**
   ```bash
   # View logs
   fly logs
   
   # Check health
   curl https://vel-tutor.fly.dev/api/health
   
   # Scale monitoring
   fly metrics
   ```

**Production Checklist:**
- [ ] Database created and attached (`fly postgres create`)
- [ ] All secrets set (`fly secrets list`)
- [ ] Health check returns 200 (`curl /api/health`)
- [ ] Database connectivity verified (`fly logs | grep Repo`)
- [ ] External providers accessible (OpenAI, Groq, Task Master)
- [ ] SSL certificate active (automatic via Fly)
- [ ] Environment variables correct (`fly ssh console`)

### Code Style and Conventions

**Elixir Code Style:**
- Follow Elixir style guide (mix format)
- Use atoms for configuration keys
- Pattern matching for error handling
- Pipe operators (`|>`) for function chaining
- Context modules for business logic isolation

**Phoenix Conventions:**
- Controllers: `lib/vel_tutor_web/controllers/`
- Contexts: `lib/vel_tutor/`
- Schemas: `lib/vel_tutor/*.ex` (Ecto models)
- Tests: `test/vel_tutor/` (unit), `test/vel_tutor_web/` (integration)
- Migrations: `priv/repo/migrations/`

**Git Workflow:**
- Feature branches: `feature/mcp-orchestrator-improvements`
- Commit messages: `feat: add Groq integration support`
- Pull requests: Reference ticket/story ID
- Code review: Required for all merges to main

### Contribution Guidelines

**Code Contributions:**
1. Create feature branch from main: `git checkout -b feature/new-feature`
2. Implement feature following Phoenix context pattern
3. Add comprehensive tests (unit + integration)
4. Update documentation (this guide, API contracts)
5. Submit PR with clear description and test results

**Testing Requirements:**
- All new code must have unit tests (mix test)
- Integration tests for API endpoints (mix test)
- Maintain 75%+ code coverage (mix coveralls)
- Mock external services with Mox (no real API calls in tests)
- Test error scenarios and edge cases

**External Service Integration:**
- New providers must follow OpenAI-compatible pattern (Groq example)
- Add to `@providers` enum in IntegrationContext
- Implement adapter in `lib/vel_tutor/services/`
- Update routing logic in MCPOrchestrator
- Add configuration validation
- Include in health checks (`/api/health`)

**Database Changes:**
- Generate migration: `mix ecto.gen.migration add_new_table`
- Update Ecto schema with proper changesets
- Add indexes for performance
- Update tests to cover new schema
- Document in data-models-main.md

**API Extensions:**
- Add routes to `lib/vel_tutor_web/router.ex`
- Create controller in `lib/vel_tutor_web/controllers/`
- Add corresponding context functions
- Update API contracts documentation
- Include integration tests

**Documentation Updates:**
- Update this development guide for new workflows
- Add to API contracts if new endpoints created
- Update architecture documentation for structural changes
- Include in component inventory for new reusable components

**PR Review Process:**
1. PR must pass all tests (`mix test`)
2. Code coverage must not decrease
3. No linting errors (`mix format --check-formatted`)
4. Documentation must be updated
5. At least one other team member approval required
6. Reference relevant story/task ID in PR description

**Commit Message Format:**
```
feat: add Groq API integration

- Implement GroqAdapter using OpenAI-compatible client
- Add Groq to provider enum and routing logic
- Update MCPOrchestrator for intelligent provider selection
- Add integration tests with mocked Groq responses
- Document configuration in development-guide.md

Closes #123 (MCP Orchestrator story)
```

---
**Generated:** 2025-11-03  
**Part:** main  
**Coverage:** Complete local development, testing, and deployment workflows  
**Status:** Complete
