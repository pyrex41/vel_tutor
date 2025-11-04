# Multi-Region Deployment Guide

This guide covers deploying Viral Engine across multiple Fly.io regions for global low-latency access, high availability, and disaster recovery.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Global Users                            │
└───────────────┬─────────────────────────────┬───────────────────┘
                │                             │
        ┌───────▼────────┐           ┌────────▼───────┐
        │  US East (IAD) │           │ EU West (LHR)  │
        └───────┬────────┘           └────────┬───────┘
                │                             │
    ┌───────────┴──────────────┬──────────────┴──────────────┐
    │                          │                             │
┌───▼────┐  ┌────▼─────┐  ┌───▼────┐  ┌────▼─────┐  ┌───▼────┐
│ App 1  │  │ App 2    │  │ App 3  │  │ App 4    │  │ App 5  │
│ (IAD)  │  │ (IAD)    │  │ (LHR)  │  │ (LHR)    │  │ (LHR)  │
└───┬────┘  └────┬─────┘  └───┬────┘  └────┬─────┘  └───┬────┘
    │            │             │            │             │
    └────────────┴─────────────┴────────────┴─────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  PostgreSQL        │
                    │  Primary (IAD)     │
                    │  Read Replica (LHR)│
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Redis Cluster     │
                    │  IAD + LHR         │
                    └────────────────────┘
```

## Benefits of Multi-Region Deployment

### Performance
- **Reduced Latency**: Serve users from geographically closer regions
- **Faster API Responses**: Typical latency reduction of 50-200ms
- **Optimized CDN**: Static assets served from nearest edge

### Availability
- **Fault Tolerance**: Continue serving traffic if one region fails
- **Zero Downtime**: Rolling deployments across regions
- **Regional Redundancy**: Database replication and failover

### Scalability
- **Traffic Distribution**: Load balanced across multiple regions
- **Regional Auto-Scaling**: Scale independently per region
- **Cost Optimization**: Use cheaper regions for non-critical workloads

## Deployment Strategy

### Active-Active (Recommended)

**Description**: All regions actively serve traffic with load balancing.

**Pros:**
- Best performance for global users
- Maximum availability (99.99%+)
- Efficient resource utilization

**Cons:**
- More complex data consistency
- Higher infrastructure costs
- Requires distributed caching

**Use Case**: Production deployments for global user base

### Active-Passive

**Description**: Primary region serves traffic; secondary regions on standby.

**Pros:**
- Simpler data consistency
- Lower operational costs
- Easier to manage

**Cons:**
- Higher latency for non-primary regions
- Underutilized resources in passive regions
- Manual failover may be required

**Use Case**: Disaster recovery, staging environments

## Step-by-Step Deployment

### 1. Choose Regions

Select regions based on your user base:

```bash
# List available Fly.io regions
fly platform regions

# Common region combinations:
# North America: iad (Virginia), lax (Los Angeles), yyz (Toronto)
# Europe: lhr (London), ams (Amsterdam), fra (Frankfurt)
# Asia-Pacific: sin (Singapore), syd (Sydney), nrt (Tokyo)
```

**Recommended Starter Setup:**
- Primary: `iad` (US East - Virginia)
- Secondary: `lhr` (Europe - London)

### 2. Deploy Primary Region

```bash
# Initial deployment to primary region
fly deploy --region iad --app viral-engine

# Verify deployment
fly status -a viral-engine
fly logs -a viral-engine
```

### 3. Setup Database Replication

#### Option A: Fly Postgres with Read Replicas

```bash
# Create primary database
fly postgres create --name viral-engine-db --region iad

# Attach to app
fly postgres attach viral-engine-db -a viral-engine

# Create read replica in secondary region
fly postgres create --name viral-engine-db-replica \
  --region lhr \
  --fork-from viral-engine-db

# Get connection strings
fly postgres db list -a viral-engine-db
```

Update `config/runtime.exs`:

```elixir
# Primary database (writes)
primary_database_url = System.get_env("DATABASE_URL")

# Read replica (reads) - route by region
read_replica_url = case System.get_env("FLY_REGION") do
  "lhr" -> System.get_env("READ_REPLICA_LHR_URL")
  "ams" -> System.get_env("READ_REPLICA_AMS_URL")
  _ -> primary_database_url  # Fallback to primary
end

config :viral_engine, ViralEngine.Repo,
  url: primary_database_url,
  pool_size: 20

# Optional: Configure read replica pool
config :viral_engine, ViralEngine.ReadRepo,
  url: read_replica_url,
  pool_size: 10,
  priv: "priv/repo"  # Share migrations with main repo
```

#### Option B: External Database (AWS RDS Multi-AZ)

```bash
# Set DATABASE_URL for each region
fly secrets set DATABASE_URL=postgres://... -a viral-engine

# Use connection pooling (PgBouncer) for cross-region
fly secrets set PGBOUNCER_URL=postgres://... -a viral-engine
```

### 4. Deploy Secondary Regions

```bash
# Scale to include secondary region
fly scale count 3 --region lhr -a viral-engine

# Verify multi-region deployment
fly regions list -a viral-engine

# Check machines per region
fly machines list -a viral-engine
```

### 5. Configure Redis for Multi-Region

#### Option A: Upstash Redis (Global)

```bash
# Create Upstash Redis cluster with global replication
# Visit: https://console.upstash.com/

# Set Redis URL
fly secrets set REDIS_URL=rediss://default:...@global.upstash.io:6379 -a viral-engine
```

#### Option B: Fly Redis with Regional Instances

```bash
# Deploy Redis in each region
fly redis create --name viral-engine-redis-iad --region iad
fly redis create --name viral-engine-redis-lhr --region lhr

# Configure region-specific Redis
fly secrets set REDIS_IAD_URL=redis://... -a viral-engine
fly secrets set REDIS_LHR_URL=redis://... -a viral-engine
```

Update `config/runtime.exs`:

```elixir
# Regional Redis routing
redis_url = case System.get_env("FLY_REGION") do
  "iad" -> System.get_env("REDIS_IAD_URL")
  "lhr" -> System.get_env("REDIS_LHR_URL")
  _ -> System.get_env("REDIS_URL")  # Fallback
end

config :viral_engine, ViralEngine.PubSub,
  adapter: Phoenix.PubSub.Redis,
  url: redis_url,
  node_name: System.get_env("FLY_MACHINE_ID")
```

### 6. Configure DNS and Anycast

Fly.io provides built-in Anycast routing:

```bash
# Allocate IPv4 and IPv6
fly ips allocate-v4 -a viral-engine
fly ips allocate-v6 -a viral-engine

# List IPs
fly ips list -a viral-engine

# Configure custom domain
fly certs create viral-engine.example.com -a viral-engine
```

**DNS Configuration:**

```
A     viral-engine.example.com    -> 66.241.124.xxx (Fly IPv4)
AAAA  viral-engine.example.com    -> 2a09:8280:1::xxx (Fly IPv6)
CNAME www.viral-engine.example.com -> viral-engine.example.com
```

Fly's Anycast automatically routes users to the nearest region.

### 7. Update fly.toml for Multi-Region

```toml
app = "viral-engine"
primary_region = "iad"

[build]
  [build.args]
    MIX_ENV = "prod"

[env]
  PHX_HOST = "viral-engine.example.com"
  PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = false  # Keep machines running in all regions
  auto_start_machines = true
  min_machines_running = 0

  [http_service.concurrency]
    type = "requests"
    hard_limit = 1000
    soft_limit = 800

# Regional machine configuration
[[services]]
  protocol = "tcp"
  internal_port = 8080

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  # Health checks for auto-failover
  [[services.tcp_checks]]
    interval = "15s"
    timeout = "5s"
    grace_period = "10s"
    restart_limit = 3

# Define machine scale per region
[http_service.autoscaling]
  # IAD (primary region)
  [http_service.autoscaling.regions.iad]
    min_count = 2
    max_count = 10

  # LHR (secondary region)
  [http_service.autoscaling.regions.lhr]
    min_count = 1
    max_count = 5
```

### 8. Deploy and Verify

```bash
# Deploy to all regions
fly deploy

# Verify machines in each region
fly machines list -a viral-engine

# Check health status
fly checks list -a viral-engine

# Monitor logs from all regions
fly logs -a viral-engine --region all
```

### 9. Test Multi-Region Routing

```bash
# Test from different locations
curl -I https://viral-engine.example.com/api/health

# Check response headers for region
curl -v https://viral-engine.example.com/api/health 2>&1 | grep -i fly-region

# Use online tools to test from different geo-locations:
# - https://www.dotcom-tools.com/website-speed-test
# - https://tools.pingdom.com/
# - https://www.webpagetest.org/
```

## Data Consistency Strategies

### Eventual Consistency (Recommended)

**Approach**: Accept that data may be slightly out of sync between regions.

**Implementation:**
1. Route writes to primary region
2. Replicate asynchronously to read replicas
3. Use timestamp-based conflict resolution
4. Cache with TTL for frequently accessed data

**Best For:**
- Real-time dashboards
- Task history
- Metrics and analytics

### Strong Consistency

**Approach**: Ensure all regions have identical data before returning success.

**Implementation:**
1. Use distributed transactions (2PC)
2. Synchronous replication
3. Quorum-based writes

**Best For:**
- Billing and payments
- User authentication
- Critical state changes

**Trade-off**: Higher latency (100-300ms for cross-region sync)

### Hybrid Approach

**Implementation:**
- Strong consistency for critical data (users, orgs, billing)
- Eventual consistency for operational data (tasks, metrics, logs)
- Session stickiness for user-specific state

```elixir
# config/runtime.exs
config :viral_engine, :consistency_mode,
  users: :strong,
  organizations: :strong,
  tasks: :eventual,
  metrics: :eventual,
  audit_logs: :eventual
```

## Monitoring Multi-Region Deployments

### Key Metrics

1. **Regional Latency**
   ```elixir
   # Track response time by region
   Telemetry.attach_many("regional-latency", [
     [:phoenix, :endpoint, :stop]
   ], &ViralEngine.Telemetry.track_regional_latency/4, nil)
   ```

2. **Cross-Region Replication Lag**
   ```sql
   -- Check replication lag
   SELECT
     client_addr,
     state,
     sent_lsn,
     write_lsn,
     flush_lsn,
     replay_lsn,
     sync_state,
     EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag_seconds
   FROM pg_stat_replication;
   ```

3. **Regional Error Rates**
   ```bash
   # Monitor error rates per region
   fly logs -a viral-engine | grep ERROR | awk '{print $3}' | sort | uniq -c
   ```

### Alerting

```elixir
# lib/viral_engine/telemetry.ex
defmodule ViralEngine.Telemetry do
  def track_regional_latency(_event, measurements, metadata, _config) do
    region = System.get_env("FLY_REGION")
    duration = measurements.duration

    # Alert if latency > 1s in any region
    if duration > 1_000_000_000 do
      Logger.warning("High latency in region #{region}: #{duration / 1_000_000}ms")

      # Send to monitoring (Sentry, Datadog, etc.)
      # Sentry.capture_message("High regional latency")
    end
  end
end
```

## Failover Procedures

### Automatic Failover

Fly.io automatically fails over between regions if health checks fail:

```toml
[[services.tcp_checks]]
  interval = "15s"
  timeout = "5s"
  grace_period = "10s"
  restart_limit = 3  # Restart 3 times before failing over
```

### Manual Failover

```bash
# 1. Check unhealthy machines
fly checks list -a viral-engine

# 2. Stop machines in failed region
fly machines stop <machine-id> -a viral-engine

# 3. Scale up healthy region
fly scale count 5 --region iad -a viral-engine

# 4. Update DNS if using external DNS (rare with Fly)
# Update A/AAAA records to point to healthy region

# 5. Verify traffic routing
fly logs -a viral-engine --region iad
```

### Database Promotion (Primary Failure)

```bash
# Promote read replica to primary
fly postgres failover viral-engine-db-replica

# Update connection strings
fly secrets set DATABASE_URL=<new-primary-url> -a viral-engine

# Restart app to pick up new config
fly apps restart viral-engine
```

## Cost Optimization

### Regional Pricing

Fly.io charges differently per region:

| Region | Category | Cost Factor |
|--------|----------|-------------|
| IAD, ORD | Tier 1 (US) | 1.0x |
| LHR, AMS, FRA | Tier 2 (EU) | 1.15x |
| SIN, SYD, NRT | Tier 3 (Asia) | 1.3x |

### Cost-Saving Strategies

1. **Auto-stop in Low-Traffic Regions**
   ```toml
   [http_service]
     auto_stop_machines = true  # Stop idle machines
     auto_start_machines = true
     min_machines_running = 0   # Allow scaling to zero
   ```

2. **Asymmetric Scaling**
   ```toml
   # More machines in high-traffic regions
   [http_service.autoscaling.regions.iad]
     min_count = 3
     max_count = 20

   # Fewer in low-traffic regions
   [http_service.autoscaling.regions.syd]
     min_count = 1
     max_count = 5
   ```

3. **Use Shared CPUs for Secondary Regions**
   ```toml
   [[vm]]
     cpu_kind = "shared"  # Cheaper than dedicated
     cpus = 1
     memory_mb = 1024
   ```

## Troubleshooting

### Issue: High Cross-Region Latency

**Symptoms:**
- Slow API responses from certain regions
- Timeout errors for users in distant locations

**Solutions:**
1. Add read replicas in affected regions
2. Use regional caching (Redis)
3. Implement CDN for static assets
4. Consider adding app instances in those regions

### Issue: Data Inconsistency

**Symptoms:**
- Users see different data when switching regions
- Race conditions in distributed workflows

**Solutions:**
1. Implement session stickiness (route user to same region)
2. Use distributed locks (Redlock)
3. Add versioning to data models
4. Implement conflict resolution strategies

### Issue: Replication Lag

**Symptoms:**
- Read replicas show outdated data
- `lag_seconds > 60` in replication stats

**Solutions:**
1. Upgrade database resources
2. Reduce write volume
3. Use synchronous replication for critical data
4. Add more read replicas to distribute load

### Issue: Regional Outage

**Symptoms:**
- All machines unhealthy in one region
- Health check failures
- Users unable to access service

**Solutions:**
1. Verify automatic failover occurred (check logs)
2. Manually scale up healthy regions
3. Investigate root cause (Fly.io status page)
4. Consider temporary DNS changes if needed

## Testing Multi-Region Deployments

### Latency Testing

```bash
# Install k6 globally
brew install k6

# Run region-specific load tests
k6 run --env BASE_URL=https://viral-engine.example.com \
       --env REGION=iad \
       test/load/k6-basic-load.js

# Compare latencies across regions
k6 run --env BASE_URL=https://viral-engine-lhr.fly.dev \
       --env REGION=lhr \
       test/load/k6-basic-load.js
```

### Failover Testing

```bash
# 1. Baseline test
k6 run --duration 5m --vus 100 test/load/k6-basic-load.js

# 2. During test, stop primary region machines
fly machines stop $(fly machines list -a viral-engine --region iad -q)

# 3. Verify traffic shifts to secondary region
fly logs -a viral-engine --region lhr

# 4. Check error rate (should remain < 1%)
k6 results --summary
```

### Data Consistency Testing

```elixir
# test/integration/multi_region_test.exs
defmodule ViralEngine.MultiRegionTest do
  use ViralEngine.DataCase

  test "eventual consistency across regions" do
    # Create task in primary region
    {:ok, task} = TaskContext.create_task(%{
      description: "Test task",
      user_id: 1
    })

    # Wait for replication (typical lag: 1-5s)
    Process.sleep(5000)

    # Verify task visible in replica
    assert {:ok, retrieved_task} = TaskContext.get_task(task.id)
    assert retrieved_task.description == task.description
  end
end
```

## Best Practices

1. **Start with Two Regions**: Primary and one secondary for DR
2. **Use Anycast DNS**: Let Fly.io route to nearest region automatically
3. **Monitor Replication Lag**: Alert if lag > 30 seconds
4. **Test Failover Monthly**: Verify automatic failover works
5. **Implement Circuit Breakers**: Prevent cascade failures
6. **Use Regional Caching**: Redis in each region for hot data
7. **Session Stickiness**: Route users to same region when possible
8. **Gradual Rollouts**: Deploy to one region at a time
9. **Centralized Logging**: Aggregate logs from all regions
10. **Cost Monitoring**: Track spending per region

## See Also

- [Fly.io Multi-Region Docs](https://fly.io/docs/reference/regions/)
- [PostgreSQL Replication](https://www.postgresql.org/docs/current/warm-standby.html)
- [Phoenix PubSub Redis](https://hexdocs.pm/phoenix_pubsub_redis/Phoenix.PubSub.Redis.html)
- [Oban Distributed Jobs](https://hexdocs.pm/oban/Oban.html#module-distributed-jobs)
