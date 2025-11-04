# Guardrail Dashboard - Admin Guide

## Overview
The Guardrail Dashboard provides real-time monitoring of viral loop health across fraud detection, bot prevention, opt-out rates, and COPPA compliance.

## Accessing the Dashboard
**URL**: `/dashboard/guardrails` (Admin only)

## Key Metrics

### Health Score (0-100)
- **Excellent (90-100)**: All systems operating normally
- **Good (75-89)**: Minor issues detected
- **Fair (60-74)**: Action recommended
- **Warning (40-59)**: Immediate attention needed
- **Critical (<40)**: Urgent intervention required

### Deductions Breakdown
- **Fraud**: Up to -30 points (flagged IPs)
- **Bot Behavior**: Up to -20 points (rapid clicks)
- **Opt-out Rates**: Up to -20 points (disengagement)
- **COPPA Violations**: Up to -30 points (PII leaks)

## Features

### Auto-Refresh
Dashboard automatically updates every 30 seconds with latest metrics.

### Period Selection
Choose monitoring window:
- **7 days** (default): Recent trends
- **14 days**: Medium-term patterns
- **30 days**: Long-term analysis

### Alert System
Active alerts display:
- **Critical**: COPPA violations (take immediate action)
- **High**: Fraud patterns (>5 flagged IPs)
- **Medium**: Bot activity (>3 devices) or high opt-outs (>30%)

## Interpreting Metrics

### Fraud Detection
- Flags IPs with >10 clicks/day (configurable)
- Lists top suspicious IP addresses with click counts
- **Action**: Review flagged IPs, consider blocking repeat offenders

### Bot Detection
- Identifies devices with 3+ clicks within 5 seconds
- **Action**: Implement CAPTCHA for flagged devices

### Opt-out Rates
- **Parent Shares**: % never viewed
- **Attribution Links**: % with zero clicks
- **Study Sessions**: Average participant count
- **Action**: Improve engagement if rates exceed 30%

### COPPA Compliance
- Scans for PII in parent shares and progress reels
- **Action**: Remove PII immediately if violations found

### Conversion Anomalies
- High volume referrers (>10 conversions/day)
- Suspicious conversion rates (>80%)
- **Action**: Investigate referrers for gaming the system

## Best Practices

1. **Daily Monitoring**: Check dashboard daily during viral campaigns
2. **Alert Response**: Address critical alerts within 1 hour
3. **Trend Analysis**: Use 14-day view to identify patterns
4. **Documentation**: Log all alert responses and actions taken
5. **Configuration Review**: Adjust thresholds in `config/runtime.exs` as needed

## Troubleshooting

### High Fraud Flags
- Verify flags are genuine (check IP geolocation)
- Adjust `FRAUD_DETECTION_THRESHOLD` if too sensitive
- Consider rate limiting at CDN level

### COPPA Violations
- Audit data collection forms
- Implement PII detection in validation layer
- Train team on COPPA compliance requirements

### Performance Issues
- Dashboard loading slowly: Check database indexes
- Queries timing out: Reduce monitoring period (use 7-day view)
- Auto-refresh causing issues: Increase refresh interval in code

## Configuration

Environment variables (see `config/runtime.exs.example`):
```bash
FRAUD_DETECTION_THRESHOLD=10
BOT_DETECTION_TIME_WINDOW=5
ALERT_OPT_OUT_THRESHOLD=30.0
```

## Support
For issues or questions, contact the engineering team or file a bug report.
