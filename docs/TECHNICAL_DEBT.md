# Technical Debt - Vel Tutor

## Analytics & Experimentation (Task #11)

### 1. FVM (First Value Moment) Tracking Assumption

**File:** `lib/viral_engine/viral_metrics_context.ex:326`
**Function:** `funnel_analysis/2`

**Issue:**
The funnel analysis currently assumes 80% of signups reach their First Value Moment (FVM) because we don't have actual FVM tracking implemented yet.

**Current Code:**
```elixir
# For FVM, we'd need to join with user events
# For now, assume 80% of signups reach FVM
fvm_reached = trunc(signups * 0.8)
```

**Impact:**
- K-factor calculations may be optimistic
- Funnel drop-off analysis is incomplete
- Cannot accurately measure true viral conversion

**Solution:**
Implement proper FVM event tracking:

1. **Define FVM Events per User Type:**
   - **Students:** Complete first diagnostic test
   - **Parents:** View first progress report
   - **Tutors:** Complete first tutoring session

2. **Add FVM Event Tracking:**
   ```elixir
   # In relevant contexts
   ViralEngine.Analytics.track_event(%{
     user_id: user_id,
     event_type: "fvm_reached",
     event_name: "completed_first_diagnostic",
     timestamp: DateTime.utc_now()
   })
   ```

3. **Update Funnel Analysis:**
   ```elixir
   # Join with user_events table
   fvm_reached = from(e in UserEvent,
     join: l in AttributionLink, on: e.user_id == l.referred_user_id,
     where: e.event_type == "fvm_reached" and l.inserted_at > ^cutoff,
     select: count(e.id, :distinct)
   ) |> Repo.one() || 0
   ```

**Effort:** ~2-3 hours
- Schema changes: 30 minutes
- Event tracking integration: 1 hour
- Query updates: 30 minutes
- Testing: 1 hour

**Priority:** Medium (affects analytics accuracy but not core functionality)

**Workaround:** Current 80% assumption is conservative and based on industry benchmarks for freemium products.

---

### 2. User Activity Tracking for Retention Cohorts

**File:** `lib/viral_engine/viral_metrics_context.ex:277`
**Function:** `retention_cohort/1`

**Issue:**
Retention cohort analysis requires user activity tracking (last_active_at timestamps) which is not currently implemented.

**Current Code:**
```elixir
def retention_cohort(weeks_back \\ 12) do
  # This would require a users table with last_activity tracking
  Logger.info("Retention cohort analysis requires user activity tracking")

  %{
    cohorts: [],
    note: "Requires user activity tracking implementation"
  }
end
```

**Impact:**
- Cannot measure how referred users compare to organic users in terms of retention
- Missing key metric for viral loop effectiveness

**Solution:**
1. Add `last_active_at` column to users table
2. Track user activity via session or heartbeat mechanism
3. Implement retention calculation per cohort

**Effort:** ~4-6 hours

**Priority:** Low (nice-to-have for advanced analytics)

---

### 3. Cross-Device Attribution

**Issue:**
Current attribution relies on cookies and URL tokens. Mobile app deep links and cross-device scenarios may lose attribution.

**Impact:**
- Some conversions may not be properly attributed to referrers
- K-factor calculations may be underestimated

**Solution:**
- Implement device fingerprinting
- Add email-based attribution matching
- Support deep link parameters for mobile

**Effort:** ~8-10 hours

**Priority:** Medium (affects attribution accuracy)

---

### 4. Timer Cleanup in LiveViews

**Status:** ✅ RESOLVED (November 5, 2025)

**Issue:**
K-factor and Experiment dashboards used `:timer.send_interval` without proper cleanup, potentially causing memory leaks.

**Solution Applied:**
```elixir
# Store timer reference in socket assigns
{:ok, timer_ref} = :timer.send_interval(60_000, self(), :refresh_metrics)
assign(socket, :timer_ref, timer_ref)

# Clean up on terminate
def terminate(_reason, socket) do
  if timer_ref = socket.assigns[:timer_ref] do
    :timer.cancel(timer_ref)
  end
  :ok
end
```

**Files Fixed:**
- `lib/viral_engine_web/live/k_factor_dashboard_live.ex`
- `lib/viral_engine_web/live/experiment_dashboard_live.ex`

---

### 5. Nil Safety in Efficiency Calculations

**Status:** ✅ RESOLVED (November 5, 2025)

**Issue:**
`loop_efficiency_analysis/1` could crash if source_data had nil k_factor or conversion_rate values.

**Solution Applied:**
```elixir
# Add nil checks with fallback to 0.0
k_factor = source_data.k_factor || 0.0
conv_rate = source_data.conversion_rate || 0.0
efficiency_score = k_factor * (conv_rate / 100)
```

**File Fixed:**
- `lib/viral_engine/viral_metrics_context.ex`

---

## General Technical Debt

### Database Indexes

**Status:** Partially implemented

**Missing Indexes:**
- `attribution_events.event_type` - for funnel analysis filtering
- `users.last_active_at` - when user activity tracking is implemented
- `attribution_links.inserted_at` - for time-based queries (may already exist)

**Effort:** 15 minutes per index

---

## Monitoring & Alerting

**Missing:**
- Prometheus/Grafana metrics for K-factor trends
- Alert thresholds for K-factor drops
- Automated experiment winner notifications

**Effort:** ~8-12 hours for full monitoring stack

**Priority:** Medium

---

## Documentation

**Missing:**
- API documentation for experiment management endpoints
- User guide for dashboard usage
- Migration guide for FVM tracking implementation

**Effort:** ~4-6 hours

**Priority:** Low (current inline docs are sufficient for MVP)

---

*Last Updated: November 5, 2025*
