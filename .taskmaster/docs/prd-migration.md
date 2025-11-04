# Migration PRD: PR #1 Integration & Production Readiness

**Version:** 1.0
**Created:** 2025-11-04
**Status:** Draft
**Owner:** Engineering Team
**Priority:** Critical Path

---

## Executive Summary

### Context
PR #1 (`claude/task-master-13-011CUnCwHS8ipXJMbWRqhy5x`) delivers the final 2 tasks (24-25) of the viral engine implementation:
- **Task 24**: Guardrail Metrics Dashboard for fraud detection and COPPA compliance monitoring
- **Task 25**: Weekly Performance Report System with AI-generated insights

The PR adds **2,166 lines of code** across 7 new implementation files and completes all 25 viral engine tasks.

### Current Status
✅ **Implementation Files**: All 7 files present in PR branch
✅ **Router Integration**: Routes added to `/dashboard/guardrails` and `/dashboard/reports`
⚠️ **Test Coverage**: No test files included (critical gap)
⚠️ **Database Indexes**: Missing indexes for fraud/bot detection queries
⚠️ **Configuration**: Hardcoded thresholds need to be moved to config
⚠️ **Email Delivery**: Placeholder implementation (acceptable, but needs UI feedback)
⚠️ **Oban Configuration**: Needs optimization (queue concurrency, retry policies)

### Goal
Transform PR #1 from "needs work" to "production-ready" by addressing 10 critical issues identified in code review, ensuring security, performance, and maintainability standards are met.

### Success Criteria
1. ✅ All tests passing with >80% coverage for critical paths
2. ✅ Database queries optimized with proper indexes (P95 <500ms for dashboard)
3. ✅ All hardcoded values moved to application config
4. ✅ Email delivery system ready (with clear UI feedback for placeholder)
5. ✅ Oban workers configured for production load
6. ✅ Comprehensive documentation for admins
7. ✅ Telemetry events for observability
8. ✅ Feature flags for gradual rollout
9. ✅ Security audit completed (COPPA, fraud detection, XSS)
10. ✅ Load testing passed (1000+ concurrent users)

---

## Critical Issues from Code Review

### Priority 1: Critical Path (Blockers for Merge)

#### Issue #1: Missing Test Coverage ⛔
**Impact**: HIGH - No automated validation of fraud detection, COPPA compliance, or report generation
**Risk**: Security vulnerabilities, regression bugs, compliance violations

**Current State**: No test files in PR
**Required**: Strategic test coverage for high-risk areas

#### Issue #2: Missing Database Indexes ⛔
**Impact**: HIGH - Fraud/bot detection queries will be slow at scale
**Risk**: Dashboard timeouts, poor user experience

**Current State**: No indexes on `attribution_events` table for IP/device queries
**Required**: Composite indexes for fraud detection queries

#### Issue #3: Hardcoded Configuration Values ⚠️
**Impact**: MEDIUM - Cannot adjust thresholds without code changes
**Risk**: Inflexibility in production, difficult tuning

**Current State**: Thresholds like `threshold = 10` hardcoded in contexts
**Required**: Runtime configuration with environment variable support

### Priority 2: Configuration & Performance

#### Issue #4: Oban Queue Configuration ⚠️
**Impact**: MEDIUM - Single worker will bottleneck report generation
**Risk**: 8+ minute delays for 100 reports

**Current State**: `performance_reports: 1` (single worker)
**Required**: Increased concurrency, retry policies, dead letter queue

#### Issue #5: Email Delivery Placeholder ⚠️
**Impact**: MEDIUM - Users expect email delivery but it's not implemented
**Risk**: Confusion, manual workarounds

**Current State**: `TODO: Replace with actual email sending`
**Required**: Clear UI feedback + Oban email queue infrastructure

#### Issue #6: Health Score Algorithm Documentation ⚠️
**Impact**: LOW - Algorithm is unclear for maintenance
**Risk**: Bugs in scoring logic, inconsistent behavior

**Current State**: Algorithm exists but not well-documented
**Required**: Inline code comments with examples

### Priority 3: Observability & Rollout

#### Issue #7: Missing Telemetry Events ⚠️
**Impact**: MEDIUM - Cannot monitor system health in production
**Risk**: Silent failures, delayed incident response

**Current State**: Basic telemetry events added
**Required**: Comprehensive events for fraud alerts, report generation, email delivery

#### Issue #8: No Feature Flags ⚠️
**Impact**: LOW - All-or-nothing deployment
**Risk**: Cannot roll back easily

**Current State**: No feature flag system
**Required**: Flags for dashboard, reports, email delivery

#### Issue #9: No Performance Benchmarks ⚠️
**Impact**: MEDIUM - Unknown production behavior
**Risk**: Unexpected slowdowns at scale

**Current State**: Claims P95 <500ms but not verified
**Required**: Load tests with 1000+ concurrent users

#### Issue #10: Security Audit Needed ⚠️
**Impact**: HIGH - COPPA compliance, fraud detection, XSS risks
**Risk**: Regulatory violations, security breaches

**Current State**: PII detection algorithm not validated
**Required**: Security review of COPPA logic, XSS protection, SQL injection prevention

---

## Epic 1: Validate Implementation & Add Missing Tests

**Priority:** Critical
**Estimated Effort:** 3 days
**Dependencies:** None
**Owner:** Lead Engineer + QA Engineer

### Overview
Validate all 7 implementation files are working correctly and add strategic test coverage for high-risk areas.

### Stories

#### Story 1.1: Validate All Implementation Files Present
**Acceptance Criteria:**
- All 7 files verified in current branch:
  - `lib/viral_engine/guardrail_metrics_context.ex` (415 lines) ✅
  - `lib/viral_engine_web/live/guardrail_dashboard_live.ex` (580 lines) ✅
  - `lib/viral_engine/performance_report.ex` (95 lines) ✅
  - `lib/viral_engine/performance_report_context.ex` (560 lines) ✅
  - `lib/viral_engine/workers/performance_report_worker.ex` (145 lines) ✅
  - `lib/viral_engine_web/live/performance_report_live.ex` (680 lines) ✅
  - `priv/repo/migrations/20251104210000_create_performance_reports.exs` ✅
- Routes verified in `router.ex`:
  - `/dashboard/guardrails` → `GuardrailDashboardLive` ✅
  - `/dashboard/reports` → `PerformanceReportLive` ✅
  - `/dashboard/reports/:id` → `PerformanceReportLive` ✅
- Codebase compiles successfully
- No syntax errors

**Implementation:**
```bash
# Verify compilation
mix compile --warnings-as-errors

# List all new files
git diff master --name-only | grep -E "(guardrail|performance_report)"
```

#### Story 1.2: Add Unit Tests for GuardrailMetricsContext
**Acceptance Criteria:**
- Test file created: `test/viral_engine/guardrail_metrics_context_test.exs`
- ✅ Test `detect_suspicious_clicks/1`:
  - Returns suspicious IPs when threshold exceeded (>10 clicks/IP/day)
  - Returns empty list when no fraud detected
  - Respects date range filtering
  - Handles edge cases (nil IP, empty dataset)
- ✅ Test `detect_bot_behavior/1`:
  - Flags devices with rapid clicks (3+ in 5 seconds)
  - Returns empty list when no bots detected
  - Handles edge cases (single click per device)
- ✅ Test `compute_opt_out_rates/1`:
  - Calculates correct percentages for parent shares
  - Handles zero denominators
  - Respects date range
- ✅ Test `scan_for_pii/1`:
  - Detects email addresses in text
  - Detects phone numbers (various formats)
  - Detects SSNs (with/without dashes)
  - Returns empty list for clean text
- ✅ Test `compute_health_score/1`:
  - Calculates correct deductions (-30 fraud, -20 bots, -20 opt-out, -30 COPPA)
  - Enforces floor of 0 (no negative scores)
  - Enforces category caps (max deductions per category)
  - Generates correct alert severity levels

**Sample Test:**
```elixir
defmodule ViralEngine.GuardrailMetricsContextTest do
  use ViralEngine.DataCase, async: true

  alias ViralEngine.GuardrailMetricsContext
  alias ViralEngine.{AttributionEvent, Repo}

  describe "detect_suspicious_clicks/1" do
    test "flags IP with >10 clicks per day" do
      # Create 15 clicks from same IP on same day
      ip = "192.168.1.1"
      for _ <- 1..15 do
        insert(:attribution_event, ip_address: ip, event_type: "click")
      end

      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 1, threshold: 10)

      assert result.total_flagged_ips == 1
      assert hd(result.suspicious_ips).ip_address == ip
      assert hd(result.suspicious_ips).click_count >= 10
    end

    test "returns empty when no fraud detected" do
      # Create 5 clicks from different IPs
      for i <- 1..5 do
        insert(:attribution_event, ip_address: "192.168.1.#{i}", event_type: "click")
      end

      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 1, threshold: 10)

      assert result.total_flagged_ips == 0
      assert result.suspicious_ips == []
    end
  end

  describe "scan_for_pii/1" do
    test "detects email addresses" do
      text = "Contact me at john@example.com for details"

      result = GuardrailMetricsContext.scan_for_pii(text)

      assert Enum.any?(result, fn item -> item.type == "email" end)
    end

    test "returns empty for clean text" do
      text = "This is clean text with no PII"

      result = GuardrailMetricsContext.scan_for_pii(text)

      assert result == []
    end
  end

  describe "compute_health_score/1" do
    test "calculates correct deductions" do
      # Setup test data with known fraud/bot patterns
      setup_test_attribution_events()

      result = GuardrailMetricsContext.compute_health_score(days: 7)

      assert result.health_score >= 0
      assert result.health_score <= 100
      assert is_list(result.components.fraud.suspicious_ips)
      assert is_integer(result.components.fraud.deduction)
    end

    test "enforces minimum score of 0" do
      # Setup massive fraud/bot activity
      setup_extreme_fraud_scenario()

      result = GuardrailMetricsContext.compute_health_score(days: 7)

      assert result.health_score >= 0
    end
  end
end
```

#### Story 1.3: Add Unit Tests for PerformanceReportContext
**Acceptance Criteria:**
- Test file created: `test/viral_engine/performance_report_context_test.exs`
- ✅ Test `generate_weekly_report/1`:
  - Creates report record with correct dates
  - Calculates K-factor from metrics context
  - Generates insights (5+ insights)
  - Generates recommendations (3+ recommendations)
  - Populates loop performance by source
  - Includes top referrers (up to 10)
  - Handles empty data (no viral events yet)
- ✅ Test `generate_monthly_report/1`:
  - Correct date range (30 days)
  - Report type = "monthly"
- ✅ Test trend calculations:
  - `determine_trend/2` returns "up", "down", "stable"
  - 5% threshold for stability
- ✅ Test insights generation:
  - Viral threshold insight (K >= 1.0)
  - Top loop identified
  - Health warnings (<75 score)

**Sample Test:**
```elixir
defmodule ViralEngine.PerformanceReportContextTest do
  use ViralEngine.DataCase, async: true

  alias ViralEngine.PerformanceReportContext

  describe "generate_weekly_report/1" do
    test "creates report with correct fields" do
      # Setup test viral events
      setup_viral_events()

      {:ok, report} = PerformanceReportContext.generate_weekly_report()

      assert report.report_type == "weekly"
      assert report.k_factor >= 0.0
      assert is_list(report.insights)
      assert length(report.insights) >= 3
      assert is_list(report.recommendations)
      assert length(report.recommendations) >= 2
      assert is_map(report.loop_performance)
    end

    test "handles empty data gracefully" do
      # No viral events
      {:ok, report} = PerformanceReportContext.generate_weekly_report()

      assert report.k_factor == 0.0
      assert report.total_conversions == 0
      assert report.loop_performance == %{}
    end
  end
end
```

#### Story 1.4: Add Integration Tests for LiveViews
**Acceptance Criteria:**
- Test file created: `test/viral_engine_web/live/guardrail_dashboard_live_test.exs`
- ✅ Test dashboard mounts successfully
- ✅ Test health score renders
- ✅ Test fraud metrics render
- ✅ Test bot metrics render
- ✅ Test COPPA metrics render

**Sample Test:**
```elixir
defmodule ViralEngineWeb.GuardrailDashboardLiveTest do
  use ViralEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "guardrail dashboard" do
    test "mounts and displays health score", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard/guardrails")

      assert html =~ "Health Score"
      assert html =~ "Fraud Detection"
      assert html =~ "Bot Detection"
      assert html =~ "COPPA Compliance"
    end
  end
end
```

---

## Epic 2: Database Performance & Indexes

**Priority:** Critical
**Estimated Effort:** 1 day
**Dependencies:** Epic 1 (Story 1.1)
**Owner:** Database Engineer

### Overview
Add missing database indexes for fraud detection, bot detection, and health score queries to ensure P95 latency <500ms for dashboard loads.

### Stories

#### Story 2.1: Add Fraud Detection Indexes
**Acceptance Criteria:**
- New migration created: `20251105_add_fraud_detection_indexes.exs`
- Indexes added with `CONCURRENTLY` (safe for production):
  - `idx_attribution_events_ip_address` on `attribution_events(ip_address)`
  - `idx_attribution_events_fraud_detection` on `attribution_events(ip_address, inserted_at)`
  - `idx_attribution_events_event_type` on `attribution_events(event_type, inserted_at)`
- Migration runs successfully
- Query performance improved >90% (before/after benchmark)

**Migration:**
```elixir
defmodule ViralEngine.Repo.Migrations.AddFraudDetectionIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Index for fraud detection queries (group by IP)
    create_if_not_exists index(:attribution_events, [:ip_address],
      concurrently: true,
      name: :idx_attribution_events_ip_address
    )

    # Composite index for date-filtered fraud queries
    create_if_not_exists index(:attribution_events, [:ip_address, :inserted_at],
      concurrently: true,
      name: :idx_attribution_events_fraud_detection
    )

    # Index for event type filtering
    create_if_not_exists index(:attribution_events, [:event_type, :inserted_at],
      concurrently: true,
      name: :idx_attribution_events_event_type
    )
  end

  def down do
    drop_if_exists index(:attribution_events, [:ip_address], name: :idx_attribution_events_ip_address)
    drop_if_exists index(:attribution_events, [:ip_address, :inserted_at], name: :idx_attribution_events_fraud_detection)
    drop_if_exists index(:attribution_events, [:event_type, :inserted_at], name: :idx_attribution_events_event_type)
  end
end
```

#### Story 2.2: Add Bot Detection Indexes
**Acceptance Criteria:**
- Indexes added:
  - `idx_attribution_events_device_fingerprint` on `attribution_events(device_fingerprint)`
  - `idx_attribution_events_bot_detection` on `attribution_events(device_fingerprint, inserted_at)`
- Query performance improved >90%

**Migration:**
```elixir
defmodule ViralEngine.Repo.Migrations.AddBotDetectionIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Index for bot detection queries (group by device)
    create_if_not_exists index(:attribution_events, [:device_fingerprint],
      concurrently: true,
      name: :idx_attribution_events_device_fingerprint
    )

    # Composite index for rapid click detection (device + time window)
    create_if_not_exists index(:attribution_events, [:device_fingerprint, :inserted_at],
      concurrently: true,
      name: :idx_attribution_events_bot_detection
    )
  end

  def down do
    drop_if_exists index(:attribution_events, [:device_fingerprint], name: :idx_attribution_events_device_fingerprint)
    drop_if_exists index(:attribution_events, [:device_fingerprint, :inserted_at], name: :idx_attribution_events_bot_detection)
  end
end
```

#### Story 2.3: Add Health Score Query Indexes
**Acceptance Criteria:**
- Indexes on tables used for opt-out rate calculations:
  - `study_sessions(inserted_at)`
  - `parent_shares(inserted_at, view_count)`
  - `attribution_links(inserted_at, click_count)`
- Query performance improved for health score computation

**Migration:**
```elixir
defmodule ViralEngine.Repo.Migrations.AddHealthScoreIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Study sessions for opt-out rate calculations
    create_if_not_exists index(:study_sessions, [:inserted_at],
      concurrently: true,
      name: :idx_study_sessions_inserted_at
    )

    # Parent shares for opt-out and COPPA metrics
    create_if_not_exists index(:parent_shares, [:inserted_at, :view_count],
      concurrently: true,
      name: :idx_parent_shares_opt_out
    )

    # Attribution links for zero-click detection
    create_if_not_exists index(:attribution_links, [:inserted_at, :click_count],
      concurrently: true,
      name: :idx_attribution_links_opt_out
    )
  end

  def down do
    drop_if_exists index(:study_sessions, [:inserted_at], name: :idx_study_sessions_inserted_at)
    drop_if_exists index(:parent_shares, [:inserted_at, :view_count], name: :idx_parent_shares_opt_out)
    drop_if_exists index(:attribution_links, [:inserted_at, :click_count], name: :idx_attribution_links_opt_out)
  end
end
```

#### Story 2.4: Benchmark Query Performance
**Acceptance Criteria:**
- Before/after benchmarks for all guardrail queries:
  - `detect_suspicious_clicks/1` - Target: P95 <100ms
  - `detect_bot_behavior/1` - Target: P95 <150ms
  - `compute_opt_out_rates/1` - Target: P95 <200ms
  - `compute_health_score/1` - Target: P95 <300ms
- Dashboard load time - Target: P95 <500ms
- Results documented in `.taskmaster/docs/performance-benchmarks.md`

---

## Epic 3: Configuration Management

**Priority:** High
**Estimated Effort:** 2 days
**Dependencies:** Epic 1 (Story 1.1)
**Owner:** DevOps Engineer + Developer

### Overview
Move all hardcoded thresholds and configuration values to `runtime.exs` with environment variable support for production flexibility.

### Stories

#### Story 3.1: Create Configuration Namespace
**Acceptance Criteria:**
- New `:viral_guardrails` config namespace in `config/runtime.exs`
- Environment variables defined:
  - `FRAUD_IP_CLICK_THRESHOLD` (default: 10)
  - `FRAUD_IP_CLICK_WINDOW_DAYS` (default: 1)
  - `BOT_RAPID_CLICK_THRESHOLD` (default: 3)
  - `BOT_RAPID_CLICK_WINDOW_SECONDS` (default: 5)
  - `CONVERSION_ANOMALY_THRESHOLD` (default: 0.8)
  - `HEALTH_SCORE_FRAUD_DEDUCTION` (default: 2)
  - `HEALTH_SCORE_BOT_DEDUCTION` (default: 2)
  - `HEALTH_SCORE_COPPA_MULTIPLIER` (default: 0.333)
  - `COPPA_COMPLIANCE_TARGET` (default: 0.99)
- Configuration validates on startup (e.g., thresholds > 0)

**Configuration File:** `config/runtime.exs`

```elixir
# config/runtime.exs
if config_env() == :prod do
  config :viral_engine, :viral_guardrails,
    fraud_detection: [
      ip_click_threshold:
        String.to_integer(System.get_env("FRAUD_IP_CLICK_THRESHOLD") || "10"),
      ip_click_window_days:
        String.to_integer(System.get_env("FRAUD_IP_CLICK_WINDOW_DAYS") || "1")
    ],
    bot_detection: [
      rapid_click_threshold:
        String.to_integer(System.get_env("BOT_RAPID_CLICK_THRESHOLD") || "3"),
      rapid_click_window_seconds:
        String.to_integer(System.get_env("BOT_RAPID_CLICK_WINDOW_SECONDS") || "5")
    ],
    conversion_anomaly: [
      high_rate_threshold:
        String.to_float(System.get_env("CONVERSION_ANOMALY_THRESHOLD") || "0.8")
    ],
    health_score: [
      fraud_deduction:
        String.to_integer(System.get_env("HEALTH_SCORE_FRAUD_DEDUCTION") || "2"),
      bot_deduction:
        String.to_integer(System.get_env("HEALTH_SCORE_BOT_DEDUCTION") || "2"),
      coppa_deduction_multiplier:
        String.to_float(System.get_env("HEALTH_SCORE_COPPA_MULTIPLIER") || "0.333"),
      fraud_max_deduction: 30,
      bot_max_deduction: 20,
      opt_out_max_deduction: 20,
      coppa_max_deduction: 30
    ],
    coppa_compliance: [
      target_rate:
        String.to_float(System.get_env("COPPA_COMPLIANCE_TARGET") || "0.99")
    ]
end

# Development/test defaults
if config_env() in [:dev, :test] do
  config :viral_engine, :viral_guardrails,
    fraud_detection: [
      ip_click_threshold: 10,
      ip_click_window_days: 1
    ],
    bot_detection: [
      rapid_click_threshold: 3,
      rapid_click_window_seconds: 5
    ],
    conversion_anomaly: [
      high_rate_threshold: 0.8
    ],
    health_score: [
      fraud_deduction: 2,
      bot_deduction: 2,
      coppa_deduction_multiplier: 0.333,
      fraud_max_deduction: 30,
      bot_max_deduction: 20,
      opt_out_max_deduction: 20,
      coppa_max_deduction: 30
    ],
    coppa_compliance: [
      target_rate: 0.99
    ]
end
```

#### Story 3.2: Update GuardrailMetricsContext to Use Config
**Acceptance Criteria:**
- `detect_suspicious_clicks/1` reads threshold from config
- `detect_bot_behavior/1` reads thresholds from config
- `compute_health_score/1` reads deduction values from config
- `compute_coppa_compliance/1` reads target rate from config
- All hardcoded values removed
- Backward compatibility maintained (opts can override config)

**Implementation:**
```elixir
# lib/viral_engine/guardrail_metrics_context.ex

def detect_suspicious_clicks(opts \\ []) do
  config = Application.get_env(:viral_engine, :viral_guardrails)
  fraud_config = Keyword.get(config, :fraud_detection)

  days = opts[:days] || Keyword.get(fraud_config, :ip_click_window_days, 7)
  threshold = opts[:threshold] || Keyword.get(fraud_config, :ip_click_threshold, 10)

  # ... rest of function
end

def detect_bot_behavior(opts \\ []) do
  config = Application.get_env(:viral_engine, :viral_guardrails)
  bot_config = Keyword.get(config, :bot_detection)

  time_window_seconds = opts[:time_window] || Keyword.get(bot_config, :rapid_click_window_seconds, 5)
  min_clicks = opts[:min_clicks] || Keyword.get(bot_config, :rapid_click_threshold, 3)

  # ... rest of function
end

def compute_health_score(opts \\ []) do
  config = Application.get_env(:viral_engine, :viral_guardrails)
  health_config = Keyword.get(config, :health_score)

  fraud_deduction = Keyword.get(health_config, :fraud_deduction, 2)
  bot_deduction = Keyword.get(health_config, :bot_deduction, 2)
  coppa_multiplier = Keyword.get(health_config, :coppa_deduction_multiplier, 0.333)

  # ... rest of function with configurable deductions
end
```

#### Story 3.3: Update .env.example with New Variables
**Acceptance Criteria:**
- `.env.example` file updated with all new variables
- Variable descriptions include:
  - Purpose
  - Default value
  - Valid range/format
  - Impact of changing value

**Documentation:**
```bash
# .env.example

# ===========================================
# VIRAL GUARDRAILS CONFIGURATION
# ===========================================

# Fraud Detection Settings
FRAUD_IP_CLICK_THRESHOLD=10            # Clicks per IP per day to flag as suspicious (min: 5, recommended: 10-20)
FRAUD_IP_CLICK_WINDOW_DAYS=1           # Time window for fraud detection (min: 1, max: 7)

# Bot Detection Settings
BOT_RAPID_CLICK_THRESHOLD=3            # Clicks within time window to flag as bot (min: 2, recommended: 3-5)
BOT_RAPID_CLICK_WINDOW_SECONDS=5       # Time window for rapid click detection (min: 3, max: 10)

# Conversion Anomaly Detection
CONVERSION_ANOMALY_THRESHOLD=0.8       # Conversion rate threshold (0.0-1.0, recommended: 0.7-0.9)

# Health Score Algorithm
HEALTH_SCORE_FRAUD_DEDUCTION=2         # Points deducted per flagged IP (recommended: 1-3)
HEALTH_SCORE_BOT_DEDUCTION=2           # Points deducted per flagged device (recommended: 1-3)
HEALTH_SCORE_COPPA_MULTIPLIER=0.333    # COPPA violation severity multiplier (recommended: 0.25-0.5)

# COPPA Compliance Target
COPPA_COMPLIANCE_TARGET=0.99           # Target compliance rate (0.0-1.0, recommended: 0.95-0.99)
```

---

## Epic 4: Oban Queue Optimization

**Priority:** High
**Estimated Effort:** 1 day
**Dependencies:** Epic 1 (Story 1.1)
**Owner:** Backend Engineer

### Overview
Optimize Oban configuration for production load: increase queue concurrency, add retry policies, and add email delivery queue.

### Stories

#### Story 4.1: Increase Queue Concurrency & Add Email Queue
**Acceptance Criteria:**
- `performance_reports` queue concurrency increased from 1 to 5
- New `email_delivery` queue added with concurrency 10
- Configuration tested with simulated load
- Oban plugin configuration updated

**Configuration:** `config/config.exs`

```elixir
config :viral_engine, Oban,
  repo: ViralEngine.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},  # Keep jobs for 7 days
    {Oban.Plugins.Cron, crontab: [
      # Weekly reports: Every Monday at 9:00 AM UTC
      {"0 9 * * 1", ViralEngine.Workers.PerformanceReportWorker,
        args: %{type: "weekly"}},

      # Monthly reports: 1st of month at 10:00 AM UTC
      {"0 10 1 * *", ViralEngine.Workers.PerformanceReportWorker,
        args: %{type: "monthly"}}
    ]}
  ],
  queues: [
    default: 10,
    webhooks: 20,
    batch: 50,
    performance_reports: 5,    # UPDATED: Increased from 1
    email_delivery: 10         # NEW: Dedicated email queue
  ]
```

#### Story 4.2: Add Retry Policies to Workers
**Acceptance Criteria:**
- Exponential backoff for failed jobs
- Max 3 retry attempts for performance reports
- Max 5 retry attempts for email delivery
- Retry configuration documented

**Implementation:**
```elixir
# lib/viral_engine/workers/performance_report_worker.ex

defmodule ViralEngine.Workers.PerformanceReportWorker do
  use Oban.Worker,
    queue: :performance_reports,
    max_attempts: 3,
    priority: 2,
    unique: [period: 60]  # Prevent duplicate jobs within 60s

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "weekly"}} = job) do
    case ViralEngine.PerformanceReportContext.generate_weekly_report() do
      {:ok, report} ->
        Logger.info("Generated weekly report #{report.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to generate weekly report: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ... rest of worker
end
```

---

## Epic 5: Email Delivery System with UI Feedback

**Priority:** High
**Estimated Effort:** 2 days
**Dependencies:** Epic 4
**Owner:** Backend Engineer + Product Manager

### Overview
Create email delivery infrastructure with **clear UI feedback** about placeholder status. Build Oban-based email queue ready for future Swoosh/SendGrid integration.

### Stories

#### Story 5.1: Create EmailDeliveryWorker
**Acceptance Criteria:**
- New Oban worker: `ViralEngine.Workers.EmailDeliveryWorker`
- Queue: `:email_delivery` (concurrency: 10)
- Max attempts: 5
- Handles email delivery with placeholder (logs only)
- Tracks delivery status in database

**Implementation:**
```elixir
# lib/viral_engine/workers/email_delivery_worker.ex

defmodule ViralEngine.Workers.EmailDeliveryWorker do
  @moduledoc """
  Oban worker for email delivery.

  Currently a placeholder that logs email content.
  Future: Integrate with Swoosh/SendGrid for actual delivery.
  """

  use Oban.Worker,
    queue: :email_delivery,
    max_attempts: 5,
    priority: 1,
    unique: [
      period: 60,
      fields: [:args],
      keys: [:report_id, :recipient_emails]
    ]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    report_id = Map.get(args, "report_id")
    recipient_emails = Map.get(args, "recipient_emails", [])

    Logger.info("EmailDeliveryWorker: Delivering report #{report_id} to #{inspect(recipient_emails)}")

    case ViralEngine.PerformanceReportContext.deliver_report(report_id, recipient_emails) do
      {:ok, _report} ->
        Logger.info("Report #{report_id} delivered successfully (placeholder)")
        :ok

      {:error, reason} ->
        Logger.error("Failed to deliver report #{report_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Schedules email delivery for a performance report.
  """
  def schedule_delivery(report_id, recipient_emails) when is_list(recipient_emails) do
    %{report_id: report_id, recipient_emails: recipient_emails}
    |> new()
    |> Oban.insert()
  end
end
```

#### Story 5.2: Add UI Feedback for Email Placeholder
**Acceptance Criteria:**
- "Email Delivery" badge in report detail view showing **"Coming Soon"**
- Tooltip explaining: "Email delivery will be available in v1.1. Reports can be viewed in the dashboard."
- Email input form present but with disclaimer text
- "Queue Email" button shows info message: "Email queued for future delivery (placeholder)"
- Admin documentation explains placeholder status

**UI Implementation:**
```elixir
# lib/viral_engine_web/live/performance_report_live.ex

defp render_email_section(assigns) do
  ~H"""
  <div class="email-delivery-section">
    <div class="flex items-center gap-2">
      <h3>Email Delivery</h3>
      <span class="badge badge-info" phx-hook="Tooltip" data-tooltip="Email delivery coming soon in v1.1">
        Coming Soon
      </span>
    </div>

    <form phx-submit="queue-email" class="mt-4">
      <div class="form-group">
        <label for="recipient_emails">Recipient Emails (comma-separated)</label>
        <input
          type="text"
          id="recipient_emails"
          name="recipient_emails"
          placeholder="admin@example.com, team@example.com"
          class="form-input"
        />
        <p class="text-sm text-gray-600 mt-2">
          ℹ️ Email delivery is currently a placeholder. Reports are logged for future integration with SendGrid/Swoosh.
        </p>
      </div>

      <button type="submit" class="btn btn-primary">
        Queue Email (Placeholder)
      </button>
    </form>

    <%= if @email_queued do %>
      <div class="alert alert-info mt-4">
        ✅ Email queued for future delivery. Check logs for report content.
      </div>
    <% end %>
  </div>
  """
end

def handle_event("queue-email", %{"recipient_emails" => emails_str}, socket) do
  recipient_emails = String.split(emails_str, ",") |> Enum.map(&String.trim/1)

  case PerformanceReportContext.deliver_report(socket.assigns.report.id, recipient_emails) do
    {:ok, _report} ->
      {:noreply,
        socket
        |> put_flash(:info, "Email queued for delivery (placeholder). Check application logs for report content.")
        |> assign(email_queued: true)
      }

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Failed to queue email: #{inspect(reason)}")}
  end
end
```

#### Story 5.3: Document Future Swoosh/SendGrid Integration
**Acceptance Criteria:**
- Technical design document for email integration in `.taskmaster/docs/email-integration-design.md`
- Includes:
  - Swoosh configuration example
  - SendGrid API integration steps
  - Email template system architecture
  - Testing strategy for email delivery
  - Rollout plan (feature flag controlled)
- Placeholder TODOs documented in code with ticket references

---

## Epic 6: Documentation

**Priority:** Medium
**Estimated Effort:** 2 days
**Dependencies:** Epic 1, Epic 3
**Owner:** Technical Writer + Developer

### Overview
Create comprehensive documentation for health score algorithm, admin guides, and manual operations.

### Stories

#### Story 6.1: Document Health Score Algorithm
**Acceptance Criteria:**
- Inline code comments explain algorithm in `compute_health_score/1`
- Markdown document: `.taskmaster/docs/health-score-algorithm.md`
- Includes:
  - Base score (100 points)
  - Deduction formulas for each component
  - Category caps (fraud: -30, bots: -20, opt-out: -20, COPPA: -30)
  - Floor enforcement (minimum score: 0)
  - Example calculations with edge cases
  - Alert severity thresholds

**Documentation Example:**
```markdown
# Health Score Algorithm

## Algorithm

### Base Score
Start with **100 points**.

### Deductions

#### 1. Fraud Detection (-0 to -30 points, capped)
- **Formula**: `min(flagged_ips * 2, 30)`
- **Logic**: Each flagged IP deducts 2 points
- **Example**:
  - 5 flagged IPs → -10 points
  - 20 flagged IPs → -30 points (capped)

#### 2. Bot Detection (-0 to -20 points, capped)
- **Formula**: `min(flagged_devices * 2, 20)`

#### 3. Opt-Out Rates (-0 to -20 points, capped)
- **Formula**: `min(avg_opt_out_rate * 20, 20)`

#### 4. COPPA Compliance (-0 to -30 points, capped)
- **Formula**: `min((1.0 - compliance_rate) * 100 * 0.333, 30)`

### Final Score
- **Formula**: `max(100 - total_deductions, 0)`
- **Floor**: Score cannot go below 0
```

#### Story 6.2: Create Admin Guide for Guardrail Dashboard
**Acceptance Criteria:**
- Markdown document: `.taskmaster/docs/admin-guide-guardrails.md`
- Includes:
  - Dashboard overview
  - How to interpret health score
  - How to investigate fraud alerts
  - How to investigate bot alerts
  - How to monitor COPPA compliance
  - FAQ section

#### Story 6.3: Document Manual Report Generation
**Acceptance Criteria:**
- IEx commands documented for generating reports on-demand
- Included in admin guide and README

**Documentation:**
```elixir
# Manual Report Generation

## Via IEx Console

# Generate weekly report (last 7 days)
{:ok, report} = ViralEngine.PerformanceReportContext.generate_weekly_report()

# Generate monthly report (last 30 days)
{:ok, report} = ViralEngine.PerformanceReportContext.generate_monthly_report()

# Generate custom date range report
{:ok, report} = ViralEngine.PerformanceReportContext.generate_weekly_report(
  start_date: ~D[2025-10-01],
  end_date: ~D[2025-10-07]
)

# Queue email delivery (placeholder)
ViralEngine.PerformanceReportContext.deliver_report(
  report.id,
  ["admin@example.com", "team@example.com"]
)
```

---

## Epic 7: Telemetry & Observability

**Priority:** Medium
**Estimated Effort:** 1 day
**Dependencies:** Epic 1
**Owner:** DevOps Engineer + Developer

### Overview
Add comprehensive telemetry events for monitoring guardrail health, report generation, and email delivery in production.

### Stories

#### Story 7.1: Add Telemetry Events for Guardrail Health
**Acceptance Criteria:**
- Event: `[:viral_engine, :guardrails, :health_score]`
  - Metadata: `%{score: integer, severity: string, components: map}`
- Event: `[:viral_engine, :guardrails, :fraud_detected]`
  - Metadata: `%{flagged_ips: integer, threshold_used: integer}`
- Event: `[:viral_engine, :guardrails, :bot_detected]`
  - Metadata: `%{flagged_devices: integer, detection_params: map}`
- Events logged to application logs

**Implementation:**
```elixir
# lib/viral_engine/guardrail_metrics_context.ex

def compute_health_score(opts \\ []) do
  # ... calculation logic ...

  result = %{
    health_score: final_score,
    severity: determine_severity(final_score),
    components: %{
      fraud: fraud_data,
      bots: bot_data,
      opt_out: opt_out_data,
      coppa: coppa_data
    }
  }

  # Emit telemetry event
  :telemetry.execute(
    [:viral_engine, :guardrails, :health_score],
    %{score: final_score},
    %{
      severity: result.severity,
      components: result.components
    }
  )

  result
end
```

#### Story 7.2: Add Telemetry Events for Report Generation
**Acceptance Criteria:**
- Event: `[:viral_engine, :reports, :generation_started]`
- Event: `[:viral_engine, :reports, :generation_completed]`
  - Measurements: `%{duration_ms: integer}`
  - Metadata: `%{report_id: integer, k_factor: float, health_score: integer}`
- Event: `[:viral_engine, :reports, :generation_failed]`

---

## Success Metrics

### Critical Path (Must-Have)
- ✅ All tests passing with >80% coverage for critical paths
- ✅ Database indexes added and performance verified (<100ms queries)
- ✅ Configuration externalized (no hardcoded values)
- ✅ Oban queues configured for production (concurrency: 5+)

### High Priority (Should-Have)
- ✅ Email delivery infrastructure ready (placeholder with UI feedback)
- ✅ Documentation complete (health score, admin guides)
- ✅ Telemetry events implemented

### Medium Priority (Nice-to-Have)
- ✅ Load testing passed (P95 <500ms)
- ✅ Security audit completed

---

## Timeline Estimate

### Week 1: Critical Path
- Epic 1: Tests & Validation (3 days)
- Epic 2: Database Indexes (1 day)

### Week 2: Configuration & Infrastructure
- Epic 3: Configuration Management (2 days)
- Epic 4: Oban Optimization (1 day)
- Epic 5: Email Delivery System (2 days)

### Week 3: Documentation & Observability
- Epic 6: Documentation (2 days)
- Epic 7: Telemetry (1 day)

**Total Estimated Effort**: 2-3 weeks

---

## Next Steps

1. **Review PRD**: Engineering team review
2. **Parse with Task Master**: `task-master parse-prd .taskmaster/docs/prd-migration.md --append`
3. **Expand Tasks**: `task-master expand --all --research`
4. **Start Implementation**: Work through tasks systematically

---

**Document Status**: Ready for Task Master parsing ✅
**Last Updated**: 2025-11-04
**Version**: 1.0
**Branch**: `pr-review` (claude/task-master-13-011CUnCwHS8ipXJMbWRqhy5x)
