#!/bin/bash
# deploy_phase2.sh - Deploy Phase 2 MCP Agents to Fly.io

set -e

echo "🚀 Deploying Phase 2 Agents to Fly.io..."

# Check for required environment variables
if [ -z "$CLAUDE_API_KEY" ]; then
    echo "❌ CLAUDE_API_KEY environment variable is required"
    exit 1
fi

if [ -z "$DATABASE_URL" ]; then
    echo "❌ DATABASE_URL environment variable is required"
    exit 1
fi

# Deploy Personalization Agent
echo "📝 Deploying Personalization Agent..."
fly mcp launch \
  "mix run --no-halt -e ViralEngine.Agents.Personalization" \
  --server personalization-agent \
  --region iad \
  --vm-size shared-cpu-1x \
  --auto-stop 5m \
  --secret CLAUDE_API_KEY="${CLAUDE_API_KEY}" \
  --secret DATABASE_URL="${DATABASE_URL}"

# Deploy Incentives & Economy Agent
echo "💰 Deploying Incentives & Economy Agent..."
fly mcp launch \
  "mix run --no-halt -e ViralEngine.Agents.IncentivesEconomy" \
  --server incentives-agent \
  --region iad \
  --vm-size shared-cpu-1x \
  --auto-stop 5m \
  --secret DATABASE_URL="${DATABASE_URL}"

# Re-deploy Orchestrator with Phase 2 logic
echo "🎯 Re-deploying Orchestrator with Phase 2 logic..."
fly deploy --config fly.orchestrator.toml

echo "✅ Phase 2 agents deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Test agent connectivity: fly mcp inspect --server personalization-agent"
echo "2. Monitor agent health: fly mcp logs --server personalization-agent"
echo "3. Run integration tests to verify viral loops work end-to-end"