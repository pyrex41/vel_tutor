# PgBouncer Setup for Horizontal Scaling

PgBouncer is a lightweight connection pooler for PostgreSQL that significantly improves database connection management in horizontally scaled deployments.

## Why PgBouncer?

- **Connection Pooling**: Reuses database connections across multiple app instances
- **Resource Efficiency**: Reduces PostgreSQL connection overhead
- **Scalability**: Handles thousands of client connections with minimal resources
- **Performance**: Reduces connection establishment latency

## Fly.io PgBouncer Setup

### Option 1: Fly.io Managed Postgres (Recommended)

Fly.io Postgres clusters come with PgBouncer built-in:

```bash
# Create Fly Postgres cluster (includes PgBouncer)
fly postgres create --name viral-engine-db --region iad

# Get connection string with PgBouncer
fly postgres connect -a viral-engine-db
```

Connection string format:
```
postgres://postgres:<password>@viral-engine-db.internal:5432/viral_engine
```

PgBouncer is automatically available on port `5432` for transaction pooling.

### Option 2: Standalone PgBouncer Configuration

If using external PostgreSQL, deploy PgBouncer as a separate Fly.io app:

1. **Create `pgbouncer.ini`**:

```ini
[databases]
viral_engine = host=your-postgres-host.com port=5432 dbname=viral_engine

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 5432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 50
min_pool_size = 10
reserve_pool_size = 10
reserve_pool_timeout = 3
max_db_connections = 100
max_user_connections = 100
server_lifetime = 3600
server_idle_timeout = 600
```

2. **Create `userlist.txt`**:

```txt
"postgres" "md5<hashed_password>"
```

3. **Deploy PgBouncer to Fly.io**:

```dockerfile
# Dockerfile.pgbouncer
FROM pgbouncer/pgbouncer:latest

COPY pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY userlist.txt /etc/pgbouncer/userlist.txt

EXPOSE 5432
```

```toml
# fly-pgbouncer.toml
app = "viral-engine-pgbouncer"
primary_region = "iad"

[http_service]
  internal_port = 5432
  protocol = "tcp"

[[services]]
  internal_port = 5432
  protocol = "tcp"

  [[services.ports]]
    port = 5432
```

```bash
fly deploy -c fly-pgbouncer.toml
```

## Application Configuration

Update `config/runtime.exs` to use PgBouncer:

```elixir
# Use PgBouncer connection string
database_url = System.get_env("DATABASE_URL") ||
               System.get_env("PGBOUNCER_URL")

config :viral_engine, ViralEngine.Repo,
  url: database_url,
  pool_size: 20,  # Increased for horizontal scaling
  queue_target: 50,
  queue_interval: 1000
```

## Pool Mode Comparison

### Transaction Pooling (Recommended)

```ini
pool_mode = transaction
```

**Pros:**
- Best for web applications
- Connections released after each transaction
- Highest connection reuse
- Supports prepared statements

**Cons:**
- Cannot use `SET` commands across requests
- No session-level temporary tables

### Session Pooling

```ini
pool_mode = session
```

**Pros:**
- Full PostgreSQL feature support
- Session-level state preserved

**Cons:**
- Lower connection reuse
- Requires more database connections

### Statement Pooling

```ini
pool_mode = statement
```

**Pros:**
- Maximum connection reuse

**Cons:**
- Very limited PostgreSQL feature support
- No multi-statement transactions
- Not recommended for most applications

## Monitoring PgBouncer

### Connection Stats

```sql
-- Connect to PgBouncer admin console
psql -h pgbouncer-host -p 5432 -U pgbouncer pgbouncer

-- View pool stats
SHOW POOLS;

-- View client connections
SHOW CLIENTS;

-- View server connections
SHOW SERVERS;

-- View statistics
SHOW STATS;
```

### Key Metrics to Monitor

- `cl_active`: Active client connections
- `cl_waiting`: Clients waiting for connection
- `sv_active`: Active server connections
- `sv_idle`: Idle server connections
- `maxwait`: Maximum wait time for connection (should be low)

## Troubleshooting

### Connection Pool Exhaustion

**Symptoms:**
- Slow response times
- `connection timeout` errors
- High `cl_waiting` count

**Solutions:**
1. Increase `default_pool_size`
2. Optimize long-running queries
3. Add more PgBouncer instances
4. Scale up database resources

### Connection Leaks

**Symptoms:**
- Growing `sv_idle` count
- Connections not being released

**Solutions:**
1. Check for unclosed transactions
2. Review application code for connection leaks
3. Reduce `server_idle_timeout`
4. Enable `server_check_query`

### Authentication Failures

**Symptoms:**
- `authentication failed` errors
- `no such user` errors

**Solutions:**
1. Verify `userlist.txt` has correct credentials
2. Ensure `auth_type` matches PostgreSQL config
3. Check database user permissions

## Performance Tuning

### Optimal Pool Sizes

For Viral Engine with horizontal scaling:

```ini
# Conservative (2-10 app instances)
default_pool_size = 50
max_db_connections = 100

# Moderate (10-50 app instances)
default_pool_size = 100
max_db_connections = 200

# Aggressive (50+ app instances)
default_pool_size = 200
max_db_connections = 400
```

### Connection Limits Formula

```
total_connections = (app_instances × pool_size) + reserve
max_db_connections ≥ total_connections
```

Example:
- 10 app instances
- 20 pool_size each
- 200 total connections needed
- Set `max_db_connections = 250` (with 50 reserve)

## Best Practices

1. **Use Transaction Pooling** for web applications
2. **Monitor Connection Stats** regularly via `SHOW POOLS`
3. **Set Appropriate Timeouts** (`server_idle_timeout`, `query_timeout`)
4. **Tune Pool Sizes** based on load testing results
5. **Use Connection Limits** to prevent database overload
6. **Enable Logging** for debugging (`log_connections`, `log_disconnections`)
7. **Run Health Checks** against PgBouncer status
8. **Deploy PgBouncer Close** to database (same region)

## Fly.io Specific Tips

### Internal Networking

Always use Fly.io's internal `.internal` DNS for database connections:

```bash
# Good: Internal networking (fast, free)
postgres://postgres:pass@viral-engine-db.internal:5432

# Avoid: External networking (slow, costs egress fees)
postgres://postgres:pass@viral-engine-db.fly.dev:5432
```

### Regional Proximity

Deploy PgBouncer in the same region as your database:

```toml
# fly-pgbouncer.toml
primary_region = "iad"  # Match your database region
```

### Scaling PgBouncer

PgBouncer is lightweight - one instance handles thousands of connections:

```toml
[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256  # PgBouncer uses minimal RAM
```

Only scale horizontally if seeing `max_client_conn` limits.

## Testing PgBouncer

### Connection Test

```bash
# Test direct PostgreSQL connection
psql postgres://postgres:pass@db.internal:5432/viral_engine

# Test PgBouncer connection
psql postgres://postgres:pass@pgbouncer.internal:5432/viral_engine

# Verify pooling is active
psql -h pgbouncer.internal -p 5432 -U pgbouncer pgbouncer -c "SHOW POOLS;"
```

### Load Test with PgBouncer

```bash
# Before: Direct database connection
k6 run --env DATABASE_URL=postgres://... load-test.js

# After: Through PgBouncer
k6 run --env DATABASE_URL=postgres://pgbouncer... load-test.js

# Compare:
# - Connection establishment time
# - Query latency
# - Max concurrent connections
```

## Integration with Viral Engine

PgBouncer is transparent to the application. No code changes required:

```elixir
# config/runtime.exs - works with or without PgBouncer
config :viral_engine, ViralEngine.Repo,
  url: System.get_env("DATABASE_URL"),  # Can point to PgBouncer
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20")
```

Simply update `DATABASE_URL` environment variable to point to PgBouncer.

## See Also

- [Official PgBouncer Documentation](https://www.pgbouncer.org/config.html)
- [Fly.io Postgres Docs](https://fly.io/docs/postgres/)
- [Ecto Pool Configuration](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.html#module-connection-pool)
