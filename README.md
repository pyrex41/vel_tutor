# Vel Tutor - AI-Powered Tutoring Platform

## Overview

Vel Tutor is an innovative AI-driven tutoring platform built with Elixir and Phoenix. The system leverages advanced AI agents, real-time collaboration features, and a modular architecture to provide personalized learning experiences. Key components include multi-agent orchestration, viral engagement mechanics, and comprehensive analytics for educational outcomes.

## Architecture

### Core Components

- **Viral Engine**: Handles user engagement, gamification, and viral growth mechanics
- **AI Agents**: Specialized agents for different tutoring roles (analyst, architect, developer, etc.)
- **Real-time Features**: Phoenix Channels for live sessions and collaborative learning
- **Task Management**: Integrated Task Master AI for workflow orchestration
- **Analytics & Metrics**: Comprehensive tracking of learning progress and engagement

### Technology Stack

- **Backend**: Elixir 1.15+, Phoenix 1.7+
- **Database**: PostgreSQL with Ecto ORM
- **Real-time**: Phoenix Channels with Phoenix LiveView
- **AI Integration**: Multi-model support (Claude, GPT, Gemini, etc.)
- **Task Orchestration**: Task Master AI with MCP integration
- **Deployment**: Fly.io with multi-region support

## Project Structure

```
vel_tutor/
├── config/                 # Phoenix configuration files
├── docs/                   # Architecture docs and API contracts
│   ├── stories/           # Implementation stories and context
│   ├── api-contracts-main.md
│   └── architecture.md
├── lib/                    # Core application code
│   ├── viral_engine/      # Main business logic
│   │   ├── accounts/      # User management
│   │   ├── agents/        # AI agent implementations
│   │   ├── integration/   # External service integrations
│   │   └── workers/       # Background job workers
│   └── viral_engine_web/  # Phoenix web layer
│       ├── controllers/   # HTTP controllers
│       ├── live/          # LiveView components
│       └── channels/      # Real-time channels
├── bmad/                   # AI Agent Management System
│   ├── bmm/              # Business Management Module
│   ├── core/             # Core agent functionality
│   └── docs/             # Agent documentation
├── .taskmaster/           # Task Master AI configuration
├── .claude/               # Claude Code integration
├── test/                  # Test suite
└── priv/                  # Database migrations and static assets
```

## Getting Started

### Prerequisites

- Elixir 1.15+
- Erlang/OTP 26+
- PostgreSQL 13+
- Node.js 18+ (for assets)
- Git

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd vel_tutor
```

2. **Install dependencies**
```bash
# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies
cd assets && npm install && cd ..

# Copy configuration
cp config/runtime.exs.example config/runtime.exs
cp .env.example .env
```

3. **Configure environment**
Edit `.env` with your database credentials and API keys:
```bash
# Database
DATABASE_URL=postgresql://username:password@localhost/vel_tutor_dev

# AI API Keys (at least one required)
ANTHROPIC_API_KEY=your_claude_key
OPENAI_API_KEY=your_openai_key
GOOGLE_API_KEY=your_gemini_key

# Task Master AI (optional but recommended)
PERPLEXITY_API_KEY=your_perplexity_key
```

4. **Set up database**
```bash
# Create and migrate database
mix ecto.create
mix ecto.migrate

# Seed initial data (optional)
mix run priv/repo/seeds.exs
```

5. **Compile and start**
```bash
# Compile the application
mix compile

# Start the Phoenix server
mix phx.server
```

The application will be available at `http://localhost:4000`.

## Development Workflow

### Task Management with Task Master AI

This project uses Task Master AI for structured development workflows:

1. **Initialize Task Master**
```bash
task-master init
```

2. **Parse Product Requirements**
Create a PRD in `.taskmaster/docs/prd.txt` and parse it:
```bash
task-master parse-prd .taskmaster/docs/prd.txt
```

3. **Analyze and Expand Tasks**
```bash
# Analyze task complexity
task-master analyze-complexity --research

# Expand complex tasks into subtasks
task-master expand --all --research
```

4. **Daily Development Loop**
```bash
# Find next task
task-master next

# View task details
task-master show <task-id>

# Update task progress
task-master update-subtask --id=<id> --prompt="implementation notes..."

# Complete tasks
task-master set-status --id=<id> --status=done
```

### AI Agent Integration

The project includes BMAD (Business Management AI Development) system with specialized agents:

- **BMM Agents**: Business-focused agents for analysis, planning, and UX design
- **Core Agents**: Development and orchestration agents
- **Workflow Agents**: Automated task execution and validation

Configure AI models:
```bash
task-master models --setup
```

### Multi-Claude Development

For parallel development, use Git worktrees:

```bash
# Create worktrees for different features
git worktree add ../vel_tutor-auth feature/auth-system
git worktree add ../vel_tutor-frontend feature/liveview-components

# Run Claude Code in each worktree
cd ../vel_tutor-auth && claude
cd ../vel_tutor-frontend && claude
```

## Key Features

### 1. AI-Powered Tutoring

- **Multi-Agent System**: Specialized AI agents for different tutoring roles
- **Real-time Sessions**: Live collaborative learning sessions
- **Personalized Learning Paths**: Adaptive content based on student progress
- **Progress Analytics**: Detailed learning metrics and improvement tracking

### 2. Viral Engagement Mechanics

- **Social Learning**: Group study sessions and peer collaboration
- **Gamification**: Achievement badges and progress milestones
- **Referral System**: Viral growth through student invitations
- **Challenge System**: Competitive learning challenges

### 3. Real-time Collaboration

- **Live Sessions**: Real-time tutoring with multiple participants
- **Shared Whiteboards**: Collaborative problem-solving
- **Instant Feedback**: AI-powered real-time assessment
- **Presence Detection**: Live user status and availability

### 4. Developer Experience

- **Task Master AI**: Automated task management and workflow orchestration
- **MCP Integration**: Seamless AI tool integration
- **Multi-model Support**: Flexible AI provider configuration
- **Comprehensive Testing**: Full test suite with load testing

## Configuration

### Database Configuration

Update `config/runtime.exs` for production:

```elixir
config :viral_engine, ViralEngine.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

### AI Model Configuration

Configure via Task Master AI:

```bash
# Set primary model (recommended: Claude 3.5 Sonnet)
task-master models --set-main claude-3-5-sonnet-20241022

# Set research model (recommended: Perplexity)
task-master models --set-research perplexity-llama-3.1-sonar-large-128k-online

# Set fallback model
task-master models --set-fallback gpt-4o-mini
```

### Feature Flags

Environment-based feature toggles in `config/runtime.exs`:

```elixir
config :viral_engine, :features,
  ai_tutoring: true,
  viral_sharing: true,
  real_time_collaboration: true,
  analytics_dashboard: true
```

## Deployment

### Fly.io Deployment

1. **Install Fly CLI**
```bash
curl -L https://fly.io/install.sh | sh
fly auth login
```

2. **Configure Fly**
```bash
# Generate fly.toml (if not present)
fly launch

# Configure secrets
fly secrets set ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
fly secrets set DATABASE_URL=$DATABASE_URL
```

3. **Deploy**
```bash
fly deploy
```

### Docker Deployment

Build and run with Docker:

```dockerfile
# Dockerfile
FROM elixir:1.15

WORKDIR /app
COPY . .

RUN mix deps.get
RUN mix compile

EXPOSE 4000
CMD ["mix", "phx.server"]
```

```bash
# Build and run
docker build -t vel_tutor .
docker run -p 4000:4000 -e DATABASE_URL=... vel_tutor
```

## Testing

### Unit and Integration Tests

```bash
# Run test suite
mix test

# Run specific test file
mix test test/viral_engine/agents/

# Run tests with coverage
mix coveralls.html
```

### Load Testing

K6 load tests are included:

```bash
# Basic load test
k6 run test/load/k6-basic-load.js

# Stress test
k6 run test/load/k6-stress-test.js
```

### End-to-End Testing

```bash
# Run E2E tests (requires Cypress)
cd assets && npm run cypress:open
```

## AI Agent System (BMAD)

### Agent Roles

The BMAD system includes specialized AI agents:

1. **BMM Analyst**: Requirements analysis and business logic validation
2. **BMM Architect**: System design and architecture decisions
3. **BMM Developer**: Code implementation and refactoring
4. **BMM UX Designer**: User experience and interface design
5. **BMM PM**: Project management and task orchestration
6. **Core Agents**: Cross-cutting concerns and orchestration

### Agent Workflows

Agents operate through structured workflows defined in `bmad/workflows/`:

- **Daily Standup**: Automated progress reporting
- **Code Review**: Automated pull request analysis
- **Task Planning**: Intelligent task decomposition
- **Documentation**: Auto-generated docs and API references

### Agent Configuration

Configure agent behavior in `bmad/_cfg/agents/`:

```yaml
# bmad/_cfg/agents/analyst.yaml
role: analyst
model: claude-3-5-sonnet-20241022
context_window: 128000
specialization:
  - business_requirements
  - user_stories
  - acceptance_criteria
```

## Task Master AI Integration

### Core Workflow

Task Master AI manages the development workflow:

1. **PRD Parsing**: Convert requirements documents to actionable tasks
2. **Complexity Analysis**: Identify tasks needing decomposition
3. **Task Expansion**: Break complex tasks into manageable subtasks
4. **Dependency Management**: Track task relationships and prerequisites
5. **Progress Tracking**: Automated status updates and completion validation

### Key Commands

```bash
# Project setup
task-master init
task-master parse-prd .taskmaster/docs/prd.txt

# Daily workflow
task-master next                    # Get next task
task-master show 1.2               # View task details
task-master update-subtask --id=1.2 --prompt="..."  # Log progress

# Task management
task-master expand --id=1 --research  # Create subtasks
task-master set-status --id=1.2 --status=done  # Mark complete

# Analysis
task-master analyze-complexity --research
task-master complexity-report
```

### MCP Integration

Task Master exposes an MCP server for Claude Code integration:

1. **Configure MCP** in `.mcp.json`
2. **Enable tools** in `.claude/settings.json`
3. **Use slash commands** for common workflows

## Monitoring and Analytics

### Built-in Metrics

- **Learning Analytics**: Student progress and engagement metrics
- **System Health**: Application performance and error rates
- **AI Usage**: Model performance and cost tracking
- **Viral Metrics**: User acquisition and retention

### External Monitoring

Configure in `config/runtime.exs`:

```elixir
# Sentry for error tracking
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: Mix.env()

# Prometheus metrics
config :prom_ex,
  grafana: :disabled,
  dashboard_path: "/metrics/dashboards",
  plugins: [
    PromEx.Plugins.Application,
    PromEx.Plugins.Beam,
    {PromEx.Plugins.Phoenix, router: ViralEngineWeb.Router},
    PromEx.Plugins.Prometheus
  ]
```

## Contributing

### Development Guidelines

1. **Follow Task Master workflow** for all features
2. **Use feature branches**: `git checkout -b feature/task-id-description`
3. **Write comprehensive tests** for all changes
4. **Update documentation** in `docs/` and `bmad/docs/`
5. **Use conventional commits**:
   ```
   feat: add user authentication (task 1.2)
   fix: resolve race condition in live sessions (task 2.3)
   docs: update API documentation (task 3.1)
   ```

### Code Style

- Follow Elixir style guidelines
- Use `mix format` before committing
- Write comprehensive type specs
- Add Dialyzer annotations for complex functions

### Pull Request Template

1. **Reference Task Master ID**: Include task ID in title and description
2. **Test Results**: Include test coverage and load test results
3. **Documentation**: Confirm docs are updated
4. **AI Review**: Include BMAD agent review results

## Security

### Authentication & Authorization

- JWT-based authentication with refresh tokens
- Role-based access control (RBAC)
- Rate limiting on all endpoints
- CSRF protection enabled

### Data Protection

- Passwords hashed with Argon2
- Sensitive data encrypted at rest
- GDPR-compliant data handling
- Audit logging for all user actions

### Security Headers

Configured in `lib/viral_engine_web/endpoint.ex`:

```elixir
plug CORSPlug, origin: ["https://app.veltutor.com"]
plug :put_secure_browser_headers,
  %{
    "x-frame-options" => "SAMEORIGIN",
    "x-xss-protection" => "1; mode=block",
    "x-content-type-options" => "nosniff",
    "referrer-policy" => "strict-origin-when-cross-origin"
  }
```

## API Documentation

### OpenAPI Specification

Auto-generated API docs available at `/api/docs` (when enabled).

### Key Endpoints

```elixir
# User Management
POST /api/users        # Create user
POST /api/sessions     # Login
DELETE /api/sessions   # Logout

# Learning Sessions
GET /api/sessions      # List sessions
POST /api/sessions     # Create session
WS /live/sessions/:id  # Real-time session

# AI Features
POST /api/ai/analyze   # Analyze learning progress
POST /api/ai/tutor     # Request AI tutoring
GET /api/ai/agents     # List available agents
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: [docs/](docs/)
- **API Reference**: `/api/docs`
- **Task Management**: Use Task Master AI commands
- **AI Agents**: Configure via BMAD system
- **Community**: Join our Discord or Matrix channels

## Roadmap

### Phase 1: Core Platform (Complete)
- [x] User authentication and profiles
- [x] Basic learning sessions
- [x] AI agent integration
- [x] Task Master AI setup

### Phase 2: Advanced Features (In Progress)
- [ ] Viral sharing mechanics
- [ ] Advanced analytics dashboard
- [ ] Multi-language support
- [ ] Mobile-responsive UI

### Phase 3: Enterprise Features
- [ ] Team and classroom management
- [ ] Advanced reporting and compliance
- [ ] Integration with LMS systems
- [ ] White-label deployment options

---

*Vel Tutor - Empowering learning through intelligent, collaborative AI tutoring*