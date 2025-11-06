# Phase 2 Deployment Checklist - Vel Tutor Viral Growth Engine

**Version:** 1.0
**Last Updated:** November 5, 2025
**Deployment Scope:** Personalization Agent, Incentives Agent, Viral Loops, Metrics Dashboard

---

## Overview

This checklist guides the deployment of Phase 2 features to production. Phase 2 introduces:

- **Personalization Agent** (GenServer) - Adaptive learning recommendations
- **Incentives & Economy Agent** (GenServer) - Reward optimization and distribution
- **Enhanced Orchestrator** - Loop routing and multi-agent coordination
- **Buddy Challenge Loop** - Social viral mechanic with challenge decks
- **Results Rally Loop** - Achievement sharing and social proof
- **Phase 2 Dashboard** - Real-time agent health and metrics monitoring

**Deployment Time Estimate:** 45-60 minutes
**Rollback Time:** 10-15 minutes

---

## Pre-Deployment Checklist

### 1. Code Review & Testing

- [ ] **All Phase 2 tests passing**
  ```bash
  mix test test/viral_engine/phase2_integration_test.exs
  mix test test/viral_engine/challenge_context_test.exs
  mix test test/viral_engine/agents/orchestrator_test.exs
  mix test test/viral_engine/loops/buddy_challenge_test.exs
  mix test test/viral_engine/loops/results_rally_test.exs
  ```
  **Expected:** All tests green, no warnings

- [ ] **E2E tests passing**
  ```bash
  npm run test:e2e
  ```
  **Expected:** All critical user flows working (practice, diagnostic, challenges)

- [ ] **Code review approved**
  - [ ] PR #4 (or equivalent) reviewed and approved
  - [ ] No unresolved security issues
  - [ ] No hardcoded credentials or API keys

- [ ] **Compilation successful**
  ```bash
  MIX_ENV=prod mix compile --warnings-as-errors
  ```
  **Expected:** Clean compilation, no warnings

### 2. Database Migrations Verified

- [ ] **Migration files reviewed**
  ```
  priv/repo/migrations/20251106000435_phase2_schema.exs
  priv/repo/migrations/20251104140001_create_rewards.exs
  priv/repo/migrations/20251104140002_create_user_rewards.exs
  priv/repo/migrations/20251104090000_create_buddy_challenges.exs
  priv/repo/migrations/20251105211549_create_cohorts.exs
  priv/repo/migrations/20251105211621_add_multi_touch_attribution.exs
  ```

- [ ] **Migrations tested in staging**
  ```bash
  MIX_ENV=staging mix ecto.migrate
  MIX_ENV=staging mix ecto.rollback --step=6
  MIX_ENV=staging mix ecto.migrate
  ```
  **Expected:** Migrations run cleanly both directions

- [ ] **Data backups completed**
  - [ ] Production database backed up (timestamp: _____________)
  - [ ] Backup verified and accessible
  - [ ] Rollback tested in staging environment

- [ ] **Migration plan documented**
  - [ ] Estimated migration time: _________ minutes
  - [ ] Downtime required: YES / NO
  - [ ] Rollback procedure tested: YES / NO

### 3. Environment Configuration

- [ ] **Production environment variables set**
  ```bash
  # Required for Phase 2
  ANTHROPIC_API_KEY=sk-ant-...
  DATABASE_URL=ecto://...
  SECRET_KEY_BASE=...
  PORT=4000
  PHX_HOST=vel-tutor.com

  # Optional but recommended
  AI_CACHE_ENABLED=true
  AI_CACHE_TTL=3600
  AI_LOG_LEVEL=info
  AI_DAILY_BUDGET=50.0
  ```

- [ ] **PubSub configuration verified**
  - [ ] Phoenix.PubSub configured for multi-node (if applicable)
  - [ ] Redis/PostgreSQL PubSub adapter configured (if scaling)

- [ ] **Agent supervision tree verified**
  ```elixir
  # lib/viral_engine/application.ex
  children = [
    ViralEngine.Agents.Orchestrator,
    ViralEngine.Agents.Personalization,
    ViralEngine.Agents.IncentivesEconomy,
    # ...
  ]
  ```

- [ ] **Feature flags configured** (if using feature flagging)
  ```
  FEATURE_BUDDY_CHALLENGE=true
  FEATURE_RESULTS_RALLY=true
  FEATURE_PHASE2_DASHBOARD=true
  ```

### 4. Infrastructure Readiness

- [ ] **Server resources verified**
  - [ ] CPU: Sufficient for 3 additional GenServers
  - [ ] Memory: +200MB headroom for agent state
  - [ ] Disk: Space for new database tables and logs

- [ ] **Monitoring configured**
  - [ ] Application metrics (Telemetry)
  - [ ] Database query performance
  - [ ] GenServer health checks
  - [ ] Error tracking (Sentry, Rollbar, etc.)

- [ ] **Alerts configured**
  - [ ] Agent crash alerts
  - [ ] Database migration failures
  - [ ] HTTP 500 error rate spike
  - [ ] Memory usage threshold

- [ ] **Load testing completed** (optional for MVP)
  - [ ] 100 concurrent users on /challenge/:token
  - [ ] 100 concurrent users on /rally/:token
  - [ ] Agent response time < 2s under load

### 5. Team Readiness

- [ ] **Deployment schedule communicated**
  - [ ] Deployment time: _____________
  - [ ] Estimated downtime: _____________
  - [ ] Team members on-call: _____________

- [ ] **Rollback plan documented**
  - [ ] Rollback script tested
  - [ ] Team trained on rollback procedure
  - [ ] Rollback decision criteria defined

- [ ] **Documentation updated**
  - [ ] API documentation (if applicable)
  - [ ] User-facing feature docs
  - [ ] Internal runbook for Phase 2 features

---

## Deployment Steps

### Step 1: Pre-Deployment Backup (5 minutes)

```bash
# 1.1 Backup production database
pg_dump $DATABASE_URL > backups/pre_phase2_$(date +%Y%m%d_%H%M%S).sql

# 1.2 Verify backup
ls -lh backups/pre_phase2_*.sql
# Expected: Recent file with non-zero size

# 1.3 Test backup restore (in staging)
psql $STAGING_DATABASE_URL < backups/pre_phase2_*.sql
# Expected: Restore completes successfully
```

**Checkpoint:** ✅ Backup completed and verified

---

### Step 2: Deploy Code to Production (10 minutes)

```bash
# 2.1 Pull latest code on production server
cd /var/www/vel_tutor
git fetch origin
git checkout master
git pull origin master

# 2.2 Install dependencies
mix deps.get --only prod
npm install --prefix assets

# 2.3 Compile assets
npm run deploy --prefix assets
mix phx.digest

# 2.4 Compile application
MIX_ENV=prod mix compile
```

**Checkpoint:** ✅ Code deployed and compiled successfully

---

### Step 3: Run Database Migrations (15 minutes)

```bash
# 3.1 Dry-run migrations (check only)
MIX_ENV=prod mix ecto.migrate --check

# 3.2 Run migrations
MIX_ENV=prod mix ecto.migrate

# Expected output:
# [info] == Running 20251106000435 ViralEngine.Repo.Migrations.Phase2Schema.change/0 forward
# [info] create table rewards
# [info] create table user_rewards
# [info] create table challenge_decks
# [info] create table challenge_sessions
# [info] create table cohorts
# [info] create table attribution_touchpoints
# [info] == Migrated 20251106000435 in 0.3s
```

**Checkpoint:** ✅ Migrations completed successfully

---

### Step 4: Verify Database Schema (5 minutes)

```bash
# 4.1 Verify Phase 2 tables exist
MIX_ENV=prod mix ecto.migrate --check 2>&1 | grep -E "(rewards|challenge_decks|cohorts|attribution_touchpoints)"

# 4.2 Check table row counts (should be 0 initially)
psql $DATABASE_URL -c "SELECT
  (SELECT COUNT(*) FROM rewards) as rewards,
  (SELECT COUNT(*) FROM user_rewards) as user_rewards,
  (SELECT COUNT(*) FROM challenge_decks) as challenge_decks,
  (SELECT COUNT(*) FROM challenge_sessions) as challenge_sessions,
  (SELECT COUNT(*) FROM cohorts) as cohorts,
  (SELECT COUNT(*) FROM attribution_touchpoints) as attribution_touchpoints;"

# Expected: All counts = 0 (fresh deployment)
```

**Checkpoint:** ✅ Database schema verified

---

### Step 5: Restart Application (10 minutes)

```bash
# 5.1 Stop current application (method depends on deployment)
# Option A: Systemd
sudo systemctl stop vel_tutor

# Option B: Docker
docker-compose down

# Option C: Manual
kill -TERM $(cat /var/run/vel_tutor.pid)

# 5.2 Start application
# Option A: Systemd
sudo systemctl start vel_tutor

# Option B: Docker
docker-compose up -d

# Option C: Manual
MIX_ENV=prod mix phx.server &
echo $! > /var/run/vel_tutor.pid

# 5.3 Wait for startup (30 seconds)
sleep 30
```

**Checkpoint:** ✅ Application restarted

---

### Step 6: Post-Deployment Verification (15 minutes)

#### 6.1 Health Checks

```bash
# 6.1.1 Application health check
curl https://vel-tutor.com/api/health
# Expected: {"status": "ok", "timestamp": "..."}

# 6.1.2 Database connectivity
curl https://vel-tutor.com/api/health | jq '.database'
# Expected: "connected"

# 6.1.3 Agent health (check logs)
tail -f /var/log/vel_tutor/prod.log | grep -E "(Orchestrator|Personalization|IncentivesEconomy)"
# Expected: "Started ViralEngine.Agents.Orchestrator"
# Expected: "Started ViralEngine.Agents.Personalization"
# Expected: "Started ViralEngine.Agents.IncentivesEconomy"
```

#### 6.2 Route Verification

```bash
# 6.2.1 Challenge route
curl -I https://vel-tutor.com/challenge/test-token-12345
# Expected: 200 OK or 404 (token not found, but route works)

# 6.2.2 Rally route
curl -I https://vel-tutor.com/rally/test-token-67890
# Expected: 200 OK or 404 (token not found, but route works)

# 6.2.3 Phase 2 Dashboard
curl -I https://vel-tutor.com/dashboard/phase2
# Expected: 200 OK
```

#### 6.3 Agent Functionality

```bash
# 6.3.1 Test Personalization Agent (via IEx console)
MIX_ENV=prod iex -S mix
> ViralEngine.Agents.Personalization.get_recommendations(user_id: 1, subject_id: "math")
# Expected: {:ok, [%{content_id: ..., reason: ...}]}

# 6.3.2 Test Incentives Agent
> ViralEngine.Agents.IncentivesEconomy.calculate_reward(action: "complete_practice", user_id: 1)
# Expected: {:ok, %{points: 100, reason: ...}}

# 6.3.3 Test Orchestrator routing
> ViralEngine.Agents.Orchestrator.route_loop("buddy_challenge", %{user_id: 1})
# Expected: {:ok, :buddy_challenge}
```

#### 6.4 Integration Tests (Production Smoke Tests)

```bash
# 6.4.1 Run smoke test suite
MIX_ENV=prod mix test test/viral_engine/phase2_smoke_test.exs

# 6.4.2 Manual user flow test (via browser)
# - Visit https://vel-tutor.com
# - Complete a practice session
# - Check for reward notification
# - Verify challenge invite appears (if applicable)
```

**Checkpoint:** ✅ All verification tests passed

---

## Post-Deployment Monitoring (24 hours)

### Hour 0-1: Critical Monitoring

- [ ] **Error rates**
  - [ ] No HTTP 500 errors in first hour
  - [ ] Phoenix LiveView connections stable
  - [ ] Agent GenServers all running

- [ ] **Performance metrics**
  - [ ] Average response time < 500ms
  - [ ] Database query time < 100ms (p95)
  - [ ] Agent response time < 2s

- [ ] **Agent health**
  ```bash
  # Check agent supervisor status
  curl https://vel-tutor.com/dashboard/phase2 | grep "Agent Status"
  # Expected: All agents "Running"
  ```

### Hour 1-6: Feature Adoption

- [ ] **User engagement**
  - [ ] First challenge created: YES / NO (timestamp: _______)
  - [ ] First rally created: YES / NO (timestamp: _______)
  - [ ] First reward claimed: YES / NO (timestamp: _______)

- [ ] **Data validation**
  ```sql
  -- Check for new data in Phase 2 tables
  SELECT
    (SELECT COUNT(*) FROM challenge_sessions WHERE inserted_at > NOW() - INTERVAL '6 hours') as challenges,
    (SELECT COUNT(*) FROM user_rewards WHERE inserted_at > NOW() - INTERVAL '6 hours') as rewards,
    (SELECT COUNT(*) FROM attribution_touchpoints WHERE inserted_at > NOW() - INTERVAL '6 hours') as touchpoints;
  ```

### Hour 6-24: Stability Monitoring

- [ ] **K-Factor tracking**
  - [ ] Visit `/dashboard/k-factor`
  - [ ] Verify K-factor calculations running
  - [ ] Check for viral loops trending data

- [ ] **Agent performance**
  - [ ] Personalization Agent: Average response time < 2s
  - [ ] Incentives Agent: Reward calculations accurate
  - [ ] Orchestrator: Loop routing errors < 1%

- [ ] **Database performance**
  - [ ] No slow queries (> 1s)
  - [ ] Connection pool healthy
  - [ ] No migration-related errors

### 24-Hour Checkpoint

- [ ] **Feature flag decision**
  - [ ] Keep Phase 2 enabled: YES / NO
  - [ ] Any features to disable: _______________
  - [ ] Any hotfixes required: _______________

- [ ] **Rollback decision**
  - [ ] Rollback required: YES / NO
  - [ ] If YES, follow rollback procedure below

---

## Rollback Procedures

### When to Rollback

Trigger rollback immediately if:

1. **Critical errors:** HTTP 500 error rate > 5% for 10+ minutes
2. **Agent crashes:** Any agent crashes > 3 times in 1 hour
3. **Data corruption:** Invalid data written to Phase 2 tables
4. **Performance degradation:** Response time > 5s (p95) for 15+ minutes
5. **Business impact:** User complaints > 10 in first hour

### Rollback Steps (15 minutes)

#### Step 1: Stop Application

```bash
# Stop application (choose method based on deployment)
sudo systemctl stop vel_tutor
# OR
docker-compose down
```

#### Step 2: Revert Code

```bash
# 2.1 Checkout previous stable version
cd /var/www/vel_tutor
git log --oneline -5  # Find commit before Phase 2 deployment
git checkout <previous-commit-hash>

# 2.2 Reinstall dependencies
mix deps.get --only prod
npm install --prefix assets

# 2.3 Recompile
MIX_ENV=prod mix compile
npm run deploy --prefix assets
mix phx.digest
```

#### Step 3: Rollback Database Migrations

```bash
# Rollback the 6 Phase 2 migrations
MIX_ENV=prod mix ecto.rollback --step=6

# Expected output:
# [info] == Running 20251105211621 ViralEngine.Repo.Migrations.AddMultiTouchAttribution.change/0 backward
# [info] drop table attribution_touchpoints
# [info] == Migrated 20251105211621 in 0.1s
# ... (5 more migrations)
```

#### Step 4: Restore Database Backup (if needed)

```bash
# Only if data corruption detected
psql $DATABASE_URL < backups/pre_phase2_<timestamp>.sql
```

#### Step 5: Restart Application

```bash
# Restart with previous version
sudo systemctl start vel_tutor
# OR
docker-compose up -d

# Wait for startup
sleep 30
```

#### Step 6: Verify Rollback

```bash
# 6.1 Health check
curl https://vel-tutor.com/api/health
# Expected: {"status": "ok"}

# 6.2 Verify Phase 2 routes removed
curl -I https://vel-tutor.com/dashboard/phase2
# Expected: 404 Not Found

# 6.3 Check logs for errors
tail -f /var/log/vel_tutor/prod.log | grep ERROR
# Expected: No Phase 2-related errors
```

**Rollback Time:** ~15 minutes
**Data Loss:** Minimal (Phase 2 data only, existing user data preserved)

---

## Troubleshooting

### Issue: Agent fails to start

**Symptoms:**
```
[error] GenServer ViralEngine.Agents.Personalization terminating
** (stop) :no_anthropic_key
```

**Solution:**
```bash
# 1. Verify ANTHROPIC_API_KEY set
echo $ANTHROPIC_API_KEY

# 2. Add to environment
export ANTHROPIC_API_KEY=sk-ant-your-key-here

# 3. Restart application
sudo systemctl restart vel_tutor
```

---

### Issue: Migration fails

**Symptoms:**
```
[error] == Running migration failed
** (Postgrex.Error) ERROR 42P07: relation "rewards" already exists
```

**Solution:**
```bash
# 1. Check current migration status
MIX_ENV=prod mix ecto.migrations

# 2. If table exists but migration not recorded, mark as run
psql $DATABASE_URL -c "INSERT INTO schema_migrations (version) VALUES (20251104140001);"

# 3. Re-run migrations
MIX_ENV=prod mix ecto.migrate
```

---

### Issue: Challenge route returns 500

**Symptoms:**
- `/challenge/:token` returns HTTP 500
- Logs show: `** (UndefinedFunctionError) function ViralEngine.ChallengeContext.get_by_token/1 is undefined`

**Solution:**
```bash
# 1. Verify all Phase 2 files deployed
ls -la lib/viral_engine/challenge_context.ex
ls -la lib/viral_engine_web/live/challenge_live.ex

# 2. Recompile application
MIX_ENV=prod mix compile --force

# 3. Restart
sudo systemctl restart vel_tutor
```

---

### Issue: Database performance degradation

**Symptoms:**
- Slow queries on `challenge_sessions` or `attribution_touchpoints`
- Dashboard shows query time > 1s

**Solution:**
```sql
-- 1. Check for missing indexes
SELECT tablename, indexname FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('challenge_sessions', 'attribution_touchpoints');

-- 2. Add missing indexes (if needed)
CREATE INDEX CONCURRENTLY idx_challenge_sessions_user_id ON challenge_sessions(user_id);
CREATE INDEX CONCURRENTLY idx_attribution_touchpoints_user_id ON attribution_touchpoints(user_id);
CREATE INDEX CONCURRENTLY idx_attribution_touchpoints_created_at ON attribution_touchpoints(inserted_at);

-- 3. Analyze tables
ANALYZE challenge_sessions;
ANALYZE attribution_touchpoints;
```

---

## Sign-Off

### Deployment Completed

- **Deployed by:** _______________
- **Deployment date:** _______________
- **Deployment time:** _______________ (start) to _______________ (end)
- **Total downtime:** _______________ minutes
- **Issues encountered:** _______________
- **Rollback performed:** YES / NO

### 24-Hour Review

- **Date:** _______________
- **Reviewed by:** _______________
- **Status:** STABLE / ISSUES / ROLLED BACK
- **Notes:** _______________

### Post-Mortem (if issues occurred)

- **Root cause:** _______________
- **Impact:** _______________
- **Resolution:** _______________
- **Preventive measures:** _______________

---

## Next Steps After Successful Deployment

1. **Enable advanced features** (Week 2+)
   - [ ] Tune Personalization Agent learning rates
   - [ ] Optimize Incentives Agent reward curves
   - [ ] Add custom challenge deck templates

2. **Monitoring enhancements** (Week 2+)
   - [ ] Set up custom Grafana dashboards for agents
   - [ ] Configure PagerDuty alerts for agent crashes
   - [ ] Add Datadog APM for agent performance tracking

3. **Phase 3 planning** (Week 4+)
   - [ ] Review K-factor data and viral loop performance
   - [ ] Plan additional viral loops based on Phase 2 insights
   - [ ] Document lessons learned for future deployments

---

**Document Version:** 1.0
**Last Updated:** November 5, 2025
**Maintained by:** Vel Tutor Engineering Team
