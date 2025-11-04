# Deployment Guide - vel_tutor

## Platform Overview

**Primary Platform:** Fly.io (serverless containers with global distribution)  
**Database:** Fly Postgres (managed PostgreSQL with multi-region replication)  
**Architecture:** Single Elixir/Phoenix backend monolith  
**Scaling:** Auto-scaling containers (Fly Machines)  
**Networking:** Global anycast with automatic region routing  
**SSL:** Automatic Let's Encrypt certificates  
**Monitoring:** Built-in Fly metrics and log streaming  

## Infrastructure Requirements

**Compute Resources:**
- **Development:** Local machine (1 CPU, 2GB RAM minimum)
- **Production:** Fly Machines (256MB-2GB RAM, 1-2 vCPU, auto-scaling)
- **Scaling:** Horizontal scaling (1-10 instances), vertical scaling (CPU/memory)

**Database:**
- **Development:** Local PostgreSQL 13+ (Docker recommended)
- **Production:** Fly Postgres (1GB storage, multi-region, encrypted connections)
- **Backup:** Automated daily backups (Fly Postgres)
- **Replication:** Multi-region read replicas (iad primary, ord secondary)

**External Services:**
- **OpenAI API:** GPT-4o/GPT-4o-mini models (complex reasoning, embeddings)
- **Groq API:** Llama 3.1 70B, Mixtral 8x7B (high-performance code generation)
- **Task Master MCP:** Local/development server or production instance
- **Domain:** Custom domain or Fly subdomain (vel-tutor.fly.dev)

## Deployment Process

### Prerequisites

1. **Fly CLI Installation:**
   ```bash
   # macOS
   brew install flyctl
   
   # Ubuntu/Debian
   curl -L https://fly.io/install.sh | sh
   
   # Verify installation
   fly version
   ```

2. **Account Setup:**
   ```bash
   # Login to Fly
   fly auth login
   
   # Create organization (if needed)
   fly orgs create vel-tutor-org
   fly orgs set default vel-tutor-org
   ```

3. **GitHub Integration (for CI/CD):**
   - Link Fly account to GitHub repository
   - Configure GitHub Actions workflow (optional but recommended)

### Step 1: Initial Application Launch

**Create fly.toml (if not exists):**
```toml
app = "vel-tutor"
primary_region = "iad"

[build]
  builder = "herokuish"

[http_service]
  internal_port = 8080
  force_ssl = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0
  processes = ["app"]

[[http_service.checks]]
  grace_period = "10s"
  interval = "30s"
  method = "GET"
  path = "/api/health"
  protocol = "http"
  timeout = "5s"
  tls_skip_verify = false

[env]
  PHX_HOST = "vel-tutor.fly.dev"
  PORT = "8080"
```

**Launch Application:**
```bash
# Launch creates app and deploys initial version
fly launch

# If prompted, select:
# - Organization: vel-tutor-org
# - App name: vel-tutor
# - Region: iad (US East)
```

### Step 2: Database Setup

**Create Managed PostgreSQL:**
```bash
# Create database (1GB storage, multi-region)
fly postgres create

# List available databases
fly postgres list

# Example output: vel-tutor-db (iad) [free]
```

**Attach Database to Application:**
```bash
# Attach database to vel-tutor app
fly postgres attach vel-tutor-db

# Verify attachment
fly postgres list --app vel-tutor
```

**Database Configuration:**
The DATABASE_URL will be automatically injected into your application via Fly's environment variables.

### Step 3: Configure Secrets

**Set All Required Secrets:**
```bash
# JWT Secret (generate with: mix phx.gen.secret)
fly secrets set SECRET_KEY_BASE=your-64-character-production-secret-key

# OpenAI API Key
fly secrets set OPENAI_API_KEY=sk-proj-your-production-openai-key

# Groq API Key
fly secrets set GROQ_API_KEY=gsk-your-production-groq-key

# Task Master MCP API Key
fly secrets set TASK_MASTER_API_KEY=your-production-task-master-key

# Database (automatically set by Fly Postgres)
# DATABASE_URL will be set automatically after attachment

# Additional environment variables
fly secrets set MIX_ENV=prod
fly secrets set PHX_HOST=vel-tutor.fly.dev
```

**Verify Secrets:**
```bash
# List all secrets (partially masked)
fly secrets list

# Check specific secret
fly secrets get OPENAI_API_KEY
```

### Step 4: Deploy Application

**Initial Deployment:**
```bash
# Deploy to all regions (iad primary, ord secondary)
fly deploy

# Monitor deployment
fly status
fly logs
```

**Deployment Verification:**
```bash
# Check application status
fly status

# View real-time logs
fly logs

# Test health endpoint
curl https://vel-tutor.fly.dev/api/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-03T14:00:00Z",
  "uptime": "0h 5m",
  "version": "1.0.0",
  "dependencies": {
    "database": "connected",
    "openai": "available",
    "groq": "available",
    "task_master": "connected"
  }
}
```

### Step 5: Configure Scaling and Monitoring

**Horizontal Scaling:**
```bash
# Scale to 2 instances (recommended minimum for production)
fly scale count 2

# Scale to 0 for zero-downtime deploys (optional)
fly scale count 0
fly deploy
fly scale count 2
```

**Auto-Scaling Configuration:**
```bash
# Create autoscale policy
fly autoscale create

# Set minimum and maximum instances
fly autoscale set min=1 max=5

# Configure based on CPU usage
fly autoscale set-min-instance-count 1
fly autoscale set-max-per-usage 5 --cpu 0.5
```

**Memory and CPU:**
```bash
# Check current resources
fly scale show

# Scale vertically (more CPU/memory)
fly scale vm shared-cpu-1x --memory=512

# Scale to dedicated CPU (high traffic)
fly scale vm dedicated-cpu-1x --memory=1024
```

### Step 6: Database Management

**Database Console Access:**
```bash
# Connect to production database
fly postgres connect vel-tutor-db

# Run SQL queries
psql> \dt  # List tables
psql> SELECT * FROM users LIMIT 5;
psql> \q
```

**Database Backups:**
```bash
# Create manual backup
fly postgres snapshot create vel-tutor-db-backup-2025-11-03

# List backups
fly postgres snapshot list

# Restore from backup (if needed)
fly postgres snapshot restore vel-tutor-db-backup-2025-11-03
```

**Database Scaling:**
```bash
# Scale storage (if needed)
fly postgres resize vel-tutor-db --size 2

# Add read replicas (multi-region)
fly postgres create-replica iad
fly postgres create-replica ord
```

### Step 7: Monitoring and Logging

**Real-time Logs:**
```bash
# Stream logs from all instances
fly logs

# Follow logs (like tail -f)
fly logs -f

# Filter by time range
fly logs --since 5m

# Filter by specific service
fly logs --app vel-tutor --service app
```

**Metrics Dashboard:**
```bash
# View metrics in browser
fly metrics dashboard

# CLI metrics
fly metrics list
fly metrics samples --app vel-tutor --service app --since 1h
```

**Health Monitoring:**
```bash
# Manual health check
curl -I https://vel-tutor.fly.dev/api/health

# Automated monitoring (integrate with external service)
# Response should be 200 OK with JSON status
```

**Log Analysis:**
```bash
# Search logs for errors
fly logs | grep ERROR

# Search for specific user
fly logs | grep "user_id: uuid"

# Search for OpenAI calls
fly logs | grep "openai"

# Search for Groq calls
fly logs | grep "groq"
```

### Step 8: CI/CD Integration

**GitHub Actions Workflow (`.github/workflows/deploy.yml`):**
```yaml
name: Deploy to Fly

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.15.0'
        otp-version: '26'
    
    - name: Install dependencies
      run: |
        mix deps.get
        mix deps.compile
    
    - name: Run tests
      run: mix test
    
    - name: Check formatting
      run: mix format --check-formatted
    
    - name: Run dialyzer
      run: mix dialyzer

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to Fly
      uses: superfly/flyctl-actions@master
      env:
        FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
      with:
        working-directory: .
        args: "deploy --remote-only"
```

**Environment Variables in GitHub:**
- `FLY_API_TOKEN` - Fly.io API token (Settings → Secrets)
- `OPENAI_API_KEY` - OpenAI API key
- `GROQ_API_KEY` - Groq API key
- `TASK_MASTER_API_KEY` - Task Master API key

### Step 9: Environment-Specific Deployments

**Staging Environment:**
```bash
# Create staging app
fly apps create vel-tutor-staging

# Deploy to staging
fly deploy --app vel-tutor-staging

# Use staging-specific secrets
fly secrets set --app vel-tutor-staging OPENAI_API_KEY=sk-staging-key
```

**Production Environment:**
```bash
# Deploy to production
fly deploy --app vel-tutor

# Verify production deployment
fly status --app vel-tutor
curl https://vel-tutor.fly.dev/api/health
```

**Blue-Green Deployment (Zero Downtime):**
```bash
# Scale production to 0
fly scale count 0 --app vel-tutor

# Deploy new version to staging
fly deploy --app vel-tutor-staging

# Test staging
curl https://vel-tutor-staging.fly.dev/api/health

# If staging passes, swap traffic
fly apps proxy update vel-tutor --upstream vel-tutor-staging

# Scale down staging, scale up production
fly scale count 0 --app vel-tutor-staging
fly scale count 2 --app vel-tutor
```

### Step 10: Post-Deployment Verification

**Health Check:**
```bash
# Verify all services are healthy
curl https://vel-tutor.fly.dev/api/health

# Expected response:
# {
#   "status": "healthy",
#   "dependencies": {
#     "database": "connected",
#     "openai": "available",
#     "groq": "available", 
#     "task_master": "connected"
#   }
# }
```

**Database Verification:**
```bash
# Connect to production database
fly postgres connect vel_tutor-db

# Verify tables exist
psql> \dt
# Expected: users, agents, tasks, integrations, audit_logs

# Check sample data
psql> SELECT count(*) FROM users;
```

**API Testing:**
```bash
# Test authentication
curl -X POST https://vel-tutor.fly.dev/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'

# Test agent creation
curl -X POST https://vel-tutor.fly.dev/api/agents \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"name":"Test Agent","type":"mcp_orchestrator","config":{"providers":["openai","groq"]}}'
```

**Monitoring Setup:**
```bash
# Set up log monitoring
fly logs -f | grep ERROR  # Watch for errors

# Monitor metrics
fly metrics dashboard

# Set up alerts (if using external monitoring)
# Alert on 5xx errors > 1% of requests
# Alert on response time > 5000ms (95th percentile)
# Alert on database connection pool exhaustion
```

### Troubleshooting

**Common Deployment Issues:**

1. **Database Connection Failed:**
   ```bash
   # Check DATABASE_URL secret
   fly secrets get DATABASE_URL
   
   # Verify database is attached
   fly postgres list --app vel-tutor
   
   # Check database status
   fly postgres status vel-tutor-db
   ```

2. **Secret Not Found:**
   ```bash
   # List all secrets
   fly secrets list
   
   # Set missing secret
   fly secrets set OPENAI_API_KEY=sk-proj-...
   ```

3. **Health Check Failing:**
   ```bash
   # Check logs for specific errors
   fly logs | grep "health"
   
   # Test individual dependencies
   iex -S mix
   iex> VelTutor.Repo.query!("SELECT 1")  # Database
   iex> VelTutor.Integration.OpenAI.health_check()  # OpenAI
   ```

4. **Application Crashing:**
   ```bash
   # View recent logs
   fly logs --since 10m
   
   # Check for Elixir crashes
   fly logs | grep -i "error\|crash\|exception"
   
   # Restart application
   fly restart
   ```

5. **Slow Performance:**
   ```bash
   # Check resource usage
   fly scale show
   
   # Monitor database connections
   fly postgres query-stats vel-tutor-db
   
   # Check external API latency
   fly logs | grep -E "(openai|groq|task_master)" | grep "timeout"
   ```

**Rollback Procedure:**
```bash
# Scale down to 0 instances
fly scale count 0

# Deploy previous version (tag or commit)
fly deploy --image flyio/vel-tutor:<previous-tag>

# Scale back up
fly scale count 2

# Monitor rollback
fly logs -f
```

### Security Hardening

**Production Security Checklist:**
- [ ] All secrets set via `fly secrets set` (no hardcoded values)
- [ ] Database connection uses SSL (automatic with Fly Postgres)
- [ ] API rate limiting enabled (100/hour authenticated)
- [ ] CORS configured for specific domains only
- [ ] Health check endpoint protected or rate-limited
- [ ] JWT tokens have short expiry (24h) with refresh mechanism
- [ ] Audit logging enabled for all user actions
- [ ] Database backups configured (daily automatic)
- [ ] SSL certificates active (Let's Encrypt)
- [ ] Environment variables validated on startup

**API Security:**
- JWT authentication on all protected endpoints
- Rate limiting (5 auth/min, 100/hour authenticated)
- Input validation on all request parameters
- SQL injection protection (Ecto parameterized queries)
- XSS protection (JSON API, no HTML rendering)
- CSRF protection (stateless API, CSRF not applicable)

**Database Security:**
- Connection pooling with timeout protection
- No direct SQL queries (all via Ecto)
- Foreign key constraints enabled
- Audit logging for all data modifications
- Regular backups with point-in-time recovery

### Cost Optimization

**External Service Cost Management:**
- **OpenAI:** GPT-4o-mini for simple tasks ($0.15/1M input tokens)
- **Groq:** Llama 3.1 70B for code generation (41% cheaper than GPT-4o)
- **Intelligent Routing:** Route based on cost/performance
- **Caching:** Cache common responses (AI responses, database queries)
- **Quota Monitoring:** Track usage and alert at 80% of monthly quota

**Infrastructure Cost Management:**
- Auto-scaling (scale to 0 during low traffic)
- Reserved instances for database (if usage predictable)
- Multi-region but minimal replicas (iad primary, ord backup)
- Monitor and optimize database query performance

### Performance Monitoring

**Key Metrics to Track:**
1. **API Response Time:** P50 < 200ms, P95 < 1000ms
2. **External API Latency:** OpenAI < 2000ms, Groq < 500ms
3. **Task Execution Time:** Average < 30s, P95 < 120s
4. **Database Query Time:** Average < 50ms, P95 < 200ms
5. **Error Rate:** < 1% of requests should return 5xx errors
6. **Provider Success Rate:** > 99% successful AI completions

**Alert Thresholds:**
- API response time > 2000ms (5xx errors)
- External API failure rate > 5%
- Database connection pool exhaustion
- Memory usage > 80% of allocated
- CPU usage > 90% sustained

### Rollout Strategy

**Canary Deployment:**
```bash
# Deploy to 10% of traffic first
fly scale count 1 --app vel-tutor-canary
fly traffic split 90 vel-tutor 10 vel-tutor-canary

# Monitor canary for 30 minutes
fly logs -f --app vel-tutor-canary

# If successful, promote to 100%
fly traffic split 0 vel-tutor-canary 100 vel-tutor

# Scale down canary
fly scale count 0 --app vel-tutor-canary
```

**Blue-Green Deployment:**
```bash
# Deploy new version to staging
fly deploy --app vel-tutor-staging

# Test staging thoroughly
curl https://vel-tutor-staging.fly.dev/api/health

# Swap traffic (zero downtime)
fly apps proxy update vel-tutor --upstream vel-tutor-staging

# Scale down old production
fly scale count 0 --app vel-tutor-old
```

### Disaster Recovery

**Database Recovery:**
```bash
# Restore from latest backup
fly postgres snapshot restore vel-tutor-db-backup-latest

# Point-in-time recovery (within 5 minutes)
fly postgres snapshot restore vel-tutor-db-backup-2025-11-03-1400
```

**Application Recovery:**
```bash
# Restart all instances
fly restart

# Redeploy from last known good version
fly deploy --image flyio/vel-tutor:v1.0.0

# Scale up from zero
fly scale count 2
```

**External Service Recovery:**
- OpenAI/Groq failover handled by MCPOrchestrator (automatic provider rotation)
- Database failover handled by Fly Postgres (multi-region)
- Task Master MCP: Local fallback to direct execution if MCP unavailable

### Support and Maintenance

**Common Issues and Solutions:**

1. **"Connection refused" on database:**
   ```bash
   # Check if database is running
   fly postgres status vel-tutor-db
   
   # Restart database if needed
   fly postgres restart vel-tutor-db
   ```

2. **"Secret not found" errors:**
   ```bash
   # List secrets
   fly secrets list
   
   # Set missing secrets
   fly secrets set OPENAI_API_KEY=sk-proj-...
   ```

3. **Slow API responses:**
   ```bash
   # Check resource usage
   fly scale show
   
   # Monitor external API latency
   fly logs | grep -E "(openai|groq)" | grep "timeout"
   
   # Scale up if needed
   fly scale vm shared-cpu-2x
   ```

4. **Health check failing:**
   ```bash
   # Check logs for specific errors
   fly logs | grep "health"
   
   # Test individual components
   iex -S mix
   iex> VelTutor.Repo.query!("SELECT 1")  # Database
   iex> VelTutor.Integration.OpenAI.health_check()  # OpenAI
   ```

**Support Contacts:**
- **Primary:** Project maintainer (contact via GitHub issues)
- **External Services:**
  - OpenAI: https://platform.openai.com/support
  - Groq: https://console.groq.com/support
  - Fly.io: https://fly.io/support
  - Task Master MCP: Local team or vendor support

**Version History:**
- **v1.0.0** (2025-11-03): Initial deployment with OpenAI/Groq integration
- **v1.1.0** (Future): UI Dashboard (epic-2), advanced orchestration features
- **v1.2.0** (Future): Analytics and reporting (epic-3)
- **v2.0.0** (Future): Multi-tenant support, enterprise scaling (epic-4)

---
**Generated:** 2025-11-03  
**Part:** main  
**Platform:** Fly.io  
**Environment:** Multi-environment (dev/test/prod)  
**Status:** Complete
