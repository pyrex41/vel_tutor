# Vel Tutor - AI-Powered Learning Platform

[![Elixir](https://img.shields.io/badge/Elixir-1.15-brightpurple.svg)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.7-blue.svg)](https://hex.pm/packages/phoenix)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o-green.svg)](https://openai.com)
[![Groq](https://img.shields.io/badge/Groq-Llama%203.1-orange.svg)](https://groq.com)

Vel Tutor is an innovative educational platform that leverages advanced AI to provide personalized, adaptive learning experiences. Built with modern web technologies and powered by OpenAI GPT-4o and Groq Llama 3.1 models.

## 🎯 Quick Start

### Prerequisites

- **Node.js** 18+ 
- **Elixir** 1.15+
- **PostgreSQL** 13+
- **OpenAI API key** (required)
- **Groq API key** (recommended for speed)

### Environment Setup

1. **Clone and Install Dependencies**:
```bash
git clone <your-repository-url>
cd vel_tutor
mix deps.get
cd assets && npm install && cd ..
```

2. **Configure Environment Variables**:
```bash
cp .env.example .env
```

3. **Set API Keys** in `.env`:
```bash
# Primary AI Provider - REQUIRED
OPENAI_API_KEY=sk-proj-your_openai_api_key_here

# Fast Inference Provider - HIGHLY RECOMMENDED  
GROQ_API_KEY=gsk-your_groq_api_key_here

# Research Capabilities - OPTIONAL
PERPLEXITY_API_KEY=pplx-your_perplexity_key_here

# Database Configuration
DATABASE_URL=ecto://postgres:postgres@localhost/vel_tutor_dev

# Application Configuration
SECRET_KEY_BASE=$(mix phx.gen.secret)
PORT=4000
```

4. **Database Setup**:
```bash
mix ecto.create
mix ecto.migrate
```

5. **Configure AI Models** (Task Master):
```bash
# Initialize Task Master AI
task-master init

# Configure models for optimal performance
task-master models --set-main gpt-4o
task-master models --set-research gpt-4o-mini
task-master models --set-fallback groq-llama-3.1-70b-versatile

# Verify configuration
task-master models
```

6. **Start Development Servers**:
```bash
# Terminal 1: Phoenix Server
mix phx.server

# Terminal 2: Asset Watcher (Tailwind + ESBuild)
cd assets && npm run dev -- --watch && cd ..

# Terminal 3: Task Master MCP Server (optional, for AI tools)
npx -y task-master-ai
```

Visit `http://localhost:4000` to see the application running!

## 🏗️ Architecture Overview

### AI Integration Stack

Vel Tutor uses a sophisticated multi-provider AI architecture optimized for performance, cost, and reliability:

```
┌─────────────────────────────────────┐
│          OpenAI GPT-4o              │
│    ┌─────────────────────────────┐  │
│    │ Complex Reasoning &         │  │
│    │ Architecture Planning       │  │
│    │ $2.50/M input, $7.50/M out  │  │
│    └─────────────────────────────┘  │
│          Latency: 2-6s              │
└─────────────────┬───────────────────┘
                  │ Primary
                  ▼
┌─────────────────────────────────────┐
│        Groq Llama 3.1 70B           │
│    ┌─────────────────────────────┐  │
│    │ Code Generation &           │  │
│    │ Real-time Validation        │  │
│    │ $0.59/M input, $0.79/M out  │  │
│    └─────────────────────────────┘  │
│         Latency: 0.3-0.8s           │
└─────────────────┬───────────────────┘
                  │ Speed Layer
                  ▼
┌─────────────────────────────────────┐
│        GPT-4o-mini (Lightweight)    │
│    ┌─────────────────────────────┐  │
│    │ Task Management &           │  │
│    │ Research Operations         │  │
│    │ $0.15/M input, $0.60/M out  │  │
│    └─────────────────────────────┘  │
│          Latency: 0.8-2.1s          │
└─────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│        Perplexity (Research)        │
│    ┌─────────────────────────────┐  │
│    │ Web Research &              │  │
│    │ Documentation Enrichment    │  │
│    └─────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Technology Stack

**Backend**: Elixir 1.15 • Phoenix 1.7 • Ecto • PostgreSQL 13+
**Frontend**: React 18 • TypeScript 5 • Tailwind CSS 3 • Headless UI
**AI/ML**: OpenAI GPT-4o • Groq Llama 3.1 • Perplexity Sonar
**DevOps**: Docker • Fly.io • GitHub Actions • Task Master AI
**Development**: BMAD Methodology • TDD Workflows • AI Agent Teams

### Core Components

1. **Learning Engine** (`lib/vel_tutor/learning_engine/`):
   - Adaptive content recommendation
   - Personalized learning paths
   - Progress tracking and analytics
   - AI-powered assessment generation

2. **AI Orchestration** (`lib/viral_engine/`):
   - Multi-provider AI routing
   - Request caching and batching
   - Cost optimization and monitoring
   - Fallback and retry logic

3. **Content Management** (`lib/vel_tutor/content/`):
   - Dynamic content generation
   - Knowledge graph construction
   - Multi-format support (video, text, interactive)
   - AI-assisted content curation

4. **User Experience** (`assets/js/`):
   - Responsive React components
   - Real-time progress indicators
   - Interactive learning interfaces
   - Accessibility-first design

## 🚀 Development Workflow

### Task Master AI Integration

Vel Tutor uses Task Master AI for structured, AI-assisted development:

#### 1. Project Initialization
```bash
# Parse Product Requirements Document
task-master parse-prd .taskmaster/docs/prd-phase1.md

# Analyze task complexity
task-master analyze-complexity --research

# Expand tasks into subtasks
task-master expand --all --research
```

#### 2. Daily Development Loop
```bash
# Get next available task
task-master next

# Review task details
task-master show 1.2

# Log implementation progress
task-master update-subtask --id=1.2.1 --prompt="Implemented user authentication flow with JWT"

# Mark task complete
task-master set-status --id=1.2 --status=done
```

#### 3. AI-Assisted Development
```bash
# Research technical questions
task-master research --query="Best practices for adaptive learning algorithms in Elixir" --save-to=2.1

# Update multiple tasks with new requirements
task-master update --from=3 --prompt="Updated requirements: Add real-time collaboration features"

# Analyze code complexity
task-master analyze-complexity --ids="5,6,7" --research
```

### BMAD Agent Workflows

The project includes specialized BMAD (Business-Minded Agentic Development) agents:

#### Agent Team Composition
```yaml
# bmad/bmm/teams/team-fullstack.yaml
team: fullstack-education
agents:
  - architect: winston  # System architecture
  - developer: amelia   # Implementation
  - pm: john           # Product requirements
  - analyst: mary      # Research & analysis
  - test_architect: murat  # Quality assurance
  - documentation: paige   # Technical docs
```

#### Running Agent Workflows
```bash
# 1. Load Architect for system design
cd bmad/bmm/agents && claude architect.md
# Run: *create-architecture

# 2. Use Developer for implementation
claude developer.md
# Run: *develop-story

# 3. Validate with Test Architect
claude test_architect.md
# Run: *atdd

# 4. Document with Paige
claude paige.md
# Run: *document-project
```

#### Party Mode (Multi-Agent Collaboration)
```bash
# Load BMad Master for team discussions
cd bmad/core/agents && claude bmad-master.md
# Run: *party-mode

# Example discussion topics:
# - "Design adaptive learning architecture for 10K concurrent users"
# - "Review current authentication implementation trade-offs"
# - "Brainstorm gamification features for student engagement"
```

## 🛠️ Configuration

### AI Model Selection Strategy

| Role | Model | Provider | Context Window | Use Case | Speed | Cost |
|------|-------|----------|----------------|----------|-------|------|
| **Architect** | GPT-4o | OpenAI | 128K | System design, planning | Medium | Medium |
| **Developer** | Llama 3.1 70B | Groq | 8K | Code generation, testing | Very Fast | Low |
| **PM/Analyst** | GPT-4o | OpenAI | 128K | Requirements, research | Medium | Medium |
| **Task Mgmt** | GPT-4o-mini | OpenAI | 128K | Task operations, updates | Fast | Very Low |
| **Validation** | Mixtral 8x7B | Groq | 32K | Code review, testing | Very Fast | Very Low |
| **Research** | Sonar Large | Perplexity | 128K | Web research, docs | Medium | Medium |

### Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `OPENAI_API_KEY` | ✅ | Primary AI provider | `sk-proj-abc123...` |
| `GROQ_API_KEY` | ⚠️ | Fast inference | `gsk-xyz789...` |
| `PERPLEXITY_API_KEY` | ❓ | Research capabilities | `pplx-def456...` |
| `DATABASE_URL` | ✅ | PostgreSQL connection | `ecto://user:pass@localhost/db` |
| `SECRET_KEY_BASE` | ✅ | Phoenix encryption | `abc123...` (64 chars) |
| `PORT` | ❓ | Server port | `4000` |
| `FLY_APP_NAME` | ❓ | Fly.io app name | `vel-tutor` |

### MCP Server Configuration

The `.mcp.json` file configures AI tool integration for Claude Code:

```json
{
  "mcpServers": {
    "task-master-ai": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "task-master-ai"],
      "env": {
        "OPENAI_API_KEY": "YOUR_OPENAI_API_KEY_HERE",
        "GROQ_API_KEY": "YOUR_GROQ_API_KEY_HERE",
        "PERPLEXITY_API_KEY": "YOUR_PERPLEXITY_API_KEY_HERE"
      }
    },
    "bmad-core": {
      "type": "stdio", 
      "command": "node",
      "args": ["bmad/tools/mcp-server.js"],
      "env": {
        "OPENAI_API_KEY": "YOUR_OPENAI_API_KEY_HERE",
        "GROQ_API_KEY": "YOUR_GROQ_API_KEY_HERE"
      }
    }
  },
  "experimental": {
    "allowUnsignedTools": true,
    "enableToolUse": true
  }
}
```

## 📚 Project Structure

```
vel_tutor/
├── lib/                    # Elixir application code
│   ├── vel_tutor/         # Core application modules
│   │   ├── learning_engine/  # Adaptive learning algorithms
│   │   ├── content/         # Content management
│   │   └── ai_client/       # AI integration layer
│   └── viral_engine/       # AI orchestration & agents
│       ├── agents/         # Specialized AI agents
│       └── agent_decision/ # Decision routing
├── assets/                 # React frontend
│   ├── js/                 # React components
│   ├── css/                # Tailwind styles
│   └── images/             # Static assets
├── config/                 # Phoenix configuration
│   ├── dev.exs            # Development settings
│   ├── prod.exs           # Production settings
│   └── runtime.exs        # Runtime configuration
├── .taskmaster/           # Task Master AI integration
│   ├── tasks/             # Task files (auto-generated)
│   │   ├── tasks.json     # Main task database
│   │   └── task-*.md      # Individual task files
│   ├── docs/              # Product requirements
│   │   ├── prd-phase1.md  # Phase 1 requirements
│   │   └── prd-phase2.md  # Phase 2 requirements
│   ├── reports/           # Analysis reports
│   └── config.json        # AI model configuration
├── bmad/                  # BMAD agent framework
│   ├── bmm/               # Business methodology agents
│   │   ├── agents/        # Agent definitions
│   │   ├── workflows/     # Structured workflows
│   │   └── docs/          # Agent documentation
│   └── core/              # Core orchestration
│       ├── tasks/         # Workflow tasks
│       └── agents/        # Meta agents
├── docs/                  # Project documentation
│   ├── architecture.md    # System architecture
│   ├── api.md            # API documentation
│   └── migration-openai.md # Migration guide
├── test/                  # Test suite
│   ├── vel_tutor/         # Unit tests
│   └── viral_engine/      # AI integration tests
└── priv/repo/             # Database migrations
```

## 🧪 Testing Strategy

### Test Suite Structure

```elixir
# Test organization
test/
├── vel_tutor/                    # Application tests
│   ├── learning_engine_test.exs  # Core algorithms
│   ├── content_test.exs          # Content management
│   └── web/                      # Controller & view tests
├── viral_engine/                 # AI orchestration tests
│   ├── ai_integration_test.exs   # Multi-provider testing
│   ├── agents_test.exs           # Agent behavior
│   └── agent_decision_test.exs   # Routing logic
└── support/                      # Test helpers
    ├── conn_case.ex              # Phoenix connection
    └── data_case.ex              # Database fixtures
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/vel_tutor/learning_engine_test.exs

# Run with coverage report
mix test --cover

# Run AI integration tests (requires API keys)
MIX_ENV=test mix test test/viral_engine/ai_integration_test.exs

# Run frontend tests
cd assets && npm test && cd ..
```

### AI Integration Testing

The test suite includes comprehensive AI integration tests:

```elixir
# test/viral_engine/ai_integration_test.exs
defmodule ViralEngine.AIIntegrationTest do
  use ExUnit.Case, async: false
  
  describe "Multi-Provider AI Routing" do
    test "routes complex tasks to GPT-4o" do
      task = %{type: :planning, complexity: 8}
      {:ok, provider, model, _opts} = VelTutor.AIRouter.route_request(task)
      
      assert provider == :openai
      assert model == "gpt-4o"
    end
    
    test "routes code generation to Groq for speed" do
      task = %{type: :code_generation, complexity: 6}
      {:ok, provider, model, _opts} = VelTutor.AIRouter.route_request(task)
      
      assert provider == :groq
      assert model == "llama-3.1-70b-versatile"
    end
    
    test "falls back to Groq when OpenAI rate limited" do
      # Mock OpenAI rate limit error
      :meck.expect(OpenAI, :chat_completions, fn _ -> 
        {:error, %OpenAI.Error{status: 429, message: "Rate limit exceeded"}} 
      end)
      
      response = VelTutor.AIClient.chat(
        model: "gpt-4o",
        messages: [%{role: "user", content: "Test fallback"}]
      )
      
      assert String.contains?(response.model, "llama")
    end
  end
end
```

## 🚀 Deployment

### Docker Configuration

```dockerfile
# Dockerfile
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm postgresql-dev

WORKDIR /build
COPY . .

# Install Elixir dependencies
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix compile

# Build assets
WORKDIR /build/assets
RUN npm ci --include=dev && \
    npm run build && \
    npm prune --production

# Build release
WORKDIR /build
RUN mix assets.deploy
RUN mix release

# Production stage
FROM alpine:3.19
RUN apk add --no-cache libstdc++ ncurses-libs openssl bash

WORKDIR /app
COPY --from=builder /build/_build/prod/rel/vel_tutor ./

# Create non-root user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

USER appuser

EXPOSE 4000
CMD ["bin/vel_tutor", "start"]
```

### Fly.io Deployment

```bash
# 1. Install Fly CLI
curl -L https://fly.io/install.sh | sh

# 2. Launch application
fly launch

# 3. Configure secrets
fly secrets set \
  OPENAI_API_KEY=$OPENAI_API_KEY \
  GROQ_API_KEY=$GROQ_API_KEY \
  PERPLEXITY_API_KEY=$PERPLEXITY_API_KEY \
  SECRET_KEY_BASE=$(mix phx.gen.secret) \
  DATABASE_URL=$DATABASE_URL

# 4. Scale deployment
fly scale count 2
fly scale vm shared-cpu-1x --memory 1024

# 5. Deploy
fly deploy
```

### Production Configuration

**`config/prod.exs`**:
```elixir
# Production AI configuration with monitoring
config :vel_tutor, VelTutor.AIClient,
  providers: [
    openai: [
      api_key: System.get_env("OPENAI_API_KEY"),
      model: "gpt-4o",
      base_url: "https://api.openai.com/v1",
      timeout: 30_000,
      temperature: 0.1,
      max_tokens: 4096,
      rate_limit: 1000  # requests per hour
    ],
    groq: [
      api_key: System.get_env("GROQ_API_KEY"),
      model: "llama-3.1-70b-versatile",
      base_url: "https://api.groq.com/openai/v1", 
      timeout: 10_000,
      temperature: 0.1,
      max_tokens: 8192,
      rate_limit: 5000  # much higher for Groq
    ]
  ],
  fallback_strategy: :groq,
  enable_caching: true,
  cache_ttl: 3600,
  monitor_usage: true,
  log_level: :info

# Production database
config :vel_tutor, VelTutor.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: 20,
  timeout: 30_000

# Production telemetry
config :telemetry_metrics, metrics: [
  counter("vel_tutor.ai.request.total"),
  histogram("vel_tutor.ai.request.latency", buckets: [10, 50, 100, 250, 500, 1000, 5000]),
  last_value("vel_tutor.ai.cost.total_usd"),
  summary("vel_tutor.ai.tokens.per_request"),
  counter("vel_tutor.user.active_sessions"),
  histogram("vel_tutor.learning.path_generation_time")
]
```

## 📈 Performance & Cost Optimization

### Expected Performance Metrics

| Provider | Model | P50 Latency | P95 Latency | Input Cost | Output Cost | Use Case |
|----------|-------|-------------|-------------|------------|-------------|----------|
| OpenAI | GPT-4o | 2.1s | 5.8s | $2.50/M | $7.50/M | Complex reasoning |
| Groq | Llama 3.1 70B | 0.3s | 0.8s | $0.59/M | $0.79/M | Code generation |
| OpenAI | GPT-4o-mini | 0.8s | 2.1s | $0.15/M | $0.60/M | Task management |
| Groq | Mixtral 8x7B | 0.2s | 0.5s | $0.27/M | $0.27/M | Validation |

### Cost Optimization Strategies

1. **Intelligent Routing**: Route tasks to optimal provider/model
2. **Caching**: Cache AI responses for 1 hour (90% hit rate expected)
3. **Batching**: Batch similar requests (20-30% cost reduction)
4. **Fallbacks**: Use Groq when OpenAI is rate-limited
5. **Monitoring**: Real-time cost tracking and alerts

### Performance Monitoring

The application includes built-in telemetry:

```elixir
# lib/vel_tutor_web/telemetry.ex
defmodule VelTutorWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {TelemetryMetricsConsole, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # AI Performance
      counter("ai.request.total", tags: [:provider, :model]),
      histogram("ai.request.latency", buckets: [10, 50, 100, 250, 500, 1000, 5000]),
      last_value("ai.cost.total_usd"),
      summary("ai.tokens.per_request"),
      
      # Application Performance
      counter("user.active_sessions"),
      histogram("learning.path_generation_time", buckets: [100, 500, 1000, 5000]),
      counter("content.generated", tags: [:type]),
      
      # Database Performance
      counter("db.query.total", tags: [:table]),
      histogram("db.query.duration", buckets: [1, 5, 10, 25, 50, 100, 250])
    ]
  end
end
```

## 🔒 Security & Privacy

### API Key Management

- **Environment Variables**: All API keys stored in environment variables
- **Secrets Management**: Use Fly.io secrets or platform equivalent
- **Key Rotation**: Rotate API keys every 90 days
- **Access Control**: Restrict API key permissions to minimum required scopes

### Data Privacy

- **GDPR Compliance**: User data deletion capabilities
- **PII Redaction**: Personal data removed from AI prompts
- **Data Encryption**: PostgreSQL data encrypted at rest
- **Audit Logging**: All AI interactions logged for compliance

### Rate Limiting & Abuse Prevention

```elixir
# lib/vel_tutor_web/plugs/rate_limiter.ex
defmodule VelTutorWeb.RateLimiter do
  @behaviour Plug
  
  @max_requests 100
  @time_window 3600  # 1 hour
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case get_session_requests(conn) do
      nil -> 
        put_session_requests(conn, 1)
        conn
      
      count when count >= @max_requests ->
        conn
        |> put_status(429)
        |> Phoenix.Controller.json(%{error: "Rate limit exceeded"})
        |> Plug.Conn.halt()
      
      count ->
        put_session_requests(conn, count + 1)
        conn
    end
  end
  
  defp get_session_requests(conn) do
    Plug.Conn.get_session(conn, :request_count)
  end
  
  defp put_session_requests(conn, count) do
    conn
    |> Plug.Conn.put_session(:request_count, count)
    |> Plug.Conn.put_session(:request_start_time, 
       System.os_time(:second) - @time_window)
  end
end
```

## 🤝 Contributing

### Development Standards

1. **Code Style**:
   - Elixir: `mix format` + Credo
   - TypeScript: ESLint + Prettier
   - Git: Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)

2. **AI Usage Guidelines**:
   ```elixir
   # Good: AI-assisted with human validation
   @generated_by "gpt-4o" "2025-11-03"
   @reviewed_by "reuben" "2025-11-04"
   def calculate_adaptive_path(user_progress, content_metadata) do
     # AI-generated algorithm with human review
     # Edge cases manually validated
     ...
   end
   
   # Good: Human-written with AI optimization
   def generate_content_recommendations(session) do
     # Core logic hand-written by developer
     # AI used for performance optimization suggestions
     ai_suggestions = VelTutor.AI.suggest_content(session)
     validate_and_apply_suggestions(ai_suggestions)
   end
   ```

3. **Task Master Workflow**:
   ```bash
   # Create feature branch
   git checkout -b feat/learning-path-optimization
   
   # Add task via Task Master
   task-master add-task --prompt="Optimize adaptive learning path algorithm"
   
   # Follow structured workflow
   task-master next
   # Implement → task-master update-subtask → task-master set-status done
   
   # Create PR with task reference
   gh pr create --title "feat: optimize learning paths (task 3.2)" \
                --body "Implements task 3.2 from sprint planning"
   ```

### Pull Request Template

```markdown
## What

<!-- Brief description of changes -->

Closes #123

## Why

<!-- Business/technical justification -->

**Task Reference:** Task Master ID 3.2

## How

<!-- Implementation approach -->

- [x] Updated learning algorithm with AI assistance
- [x] Added comprehensive test coverage  
- [x] Performance benchmarks show 25% improvement
- [x] Documentation updated

## Testing

- [x] Unit tests: 100% coverage
- [x] Integration tests: All passing
- [x] AI integration tests: Multi-provider validation
- [x] Manual testing: Verified adaptive paths

## AI Usage

- **Model Used**: GPT-4o (OpenAI) for algorithm design
- **Model Used**: Llama 3.1 70B (Groq) for code generation
- **Human Review**: All AI-generated code reviewed and validated
- **Cost**: $0.12 total for this feature

## Performance Impact

- **Before**: 2.1s average path generation
- **After**: 1.6s average path generation (24% improvement)
- **Memory**: +15% peak usage during optimization
```

## 📄 API Documentation

### REST API Endpoints

**Authentication**:
- `POST /api/v1/sessions` - Create user session
- `DELETE /api/v1/sessions` - End user session

**Learning Content**:
- `GET /api/v1/content` - Get personalized content recommendations
- `POST /api/v1/content/:id/progress` - Update content progress
- `GET /api/v1/content/:id` - Get specific content details

**Assessments**:
- `POST /api/v1/assessments` - Submit assessment answers
- `GET /api/v1/assessments/:id/results` - Get assessment results
- `GET /api/v1/progress` - Get overall learning progress

**AI Features**:
- `POST /api/v1/ai/chat` - AI-powered learning assistant
- `GET /api/v1/ai/recommendations` - Get AI recommendations
- `POST /api/v1/ai/feedback` - Submit feedback for model improvement

### GraphQL Schema

```graphql
type Query {
  # User progress and content
  learningProgress(userId: ID!): LearningProgress!
  contentRecommendations(sessionId: ID!): [ContentRecommendation!]!
  assessmentResults(assessmentId: ID!): AssessmentResult!
  
  # AI-powered queries
  aiChat(input: AIChatInput!): AIChatResponse!
  aiRecommendations(sessionId: ID!): [AIRecommendation!]!
}

type Mutation {
  # Content interactions
  updateContentProgress(input: ContentProgressInput!): ContentProgress!
  submitAssessment(input: AssessmentInput!): AssessmentResult!
  
  # AI interactions
  sendAIChat(input: AIChatInput!): AIChatResponse!
  provideAIFeedback(input: AIFeedbackInput!): AIFeedbackResponse!
}

type LearningProgress {
  userId: ID!
  completedContent: [ContentProgress!]!
  totalProgress: Float!
  estimatedCompletion: String!
  aiInsights: [AIInsight!]!
}

type ContentRecommendation {
  id: ID!
  title: String!
  type: ContentType!
  difficulty: DifficultyLevel!
  estimatedTime: Int!
  aiScore: Float!
  priority: Int!
}

type AIRecommendation {
  id: ID!
  type: RecommendationType!
  content: String!
  confidence: Float!
  model: String!
  provider: String!
}
```

## 📊 Monitoring & Analytics

### Built-in Telemetry

The application includes comprehensive telemetry for monitoring:

1. **AI Performance**:
   - Request latency by provider/model
   - Token usage and cost tracking
   - Success/failure rates
   - Fallback usage patterns

2. **Application Performance**:
   - User session metrics
   - Learning path generation time
   - Content delivery performance
   - Database query analysis

3. **Business Metrics**:
   - Active learning sessions
   - Content completion rates
   - Assessment performance
   - User engagement patterns

### Health Check Endpoints

```elixir
# lib/vel_tutor_web/controllers/health_controller.ex
defmodule VelTutorWeb.HealthController do
  use VelTutorWeb, :controller
  
  def index(conn, _params) do
    json(conn, %{
      status: "healthy",
      uptime: get_uptime(),
      version: Application.spec(:vel_tutor, :vsn),
      ai_providers: get_ai_status(),
      database: get_db_status(),
      timestamp: DateTime.utc_now()
    })
  end
  
  def ai_status(conn, _params) do
    providers = [
      openai: test_openai_connection(),
      groq: test_groq_connection(),
      perplexity: test_perplexity_connection()
    ]
    
    status = for {provider, result} <- providers do
      %{
        provider: Atom.to_string(provider),
        status: result.status,
        latency: result.latency,
        model: result.model,
        last_test: result.timestamp
      }
    end
    
    json(conn, %{ai_providers: status})
  end
end
```

## 🔗 Related Projects

- **[BMAD Framework](bmad/)** - Business-Minded Agentic Development methodology
- **[Task Master AI](.taskmaster/)** - AI-powered task management system
- **[Viral Engine](lib/viral_engine/)** - Multi-agent AI orchestration library

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙌 Support & Community

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/your-org/vel_tutor/issues)
- **Discord**: Join the Vel Tutor community server
- **Email**: support@veltutor.com

---

*Built with ❤️ using the Elixir/Phoenix ecosystem, OpenAI GPT-4o, and Groq Llama 3.1*
*Follows BMAD methodology for structured agentic development*
*Powered by Task Master AI for intelligent workflow management*

**Current Version**: 1.0.0-alpha.1
**AI Migration Status**: ✅ Complete (OpenAI/Groq - 2025-11-03)