#!/bin/bash
# scripts/load_test.sh

echo "Starting load test environment..."

# Start Redis
docker run -d --name redis-load-test -p 6379:6379 redis:7

# Start application in load test mode
MIX_ENV=test mix phx.server &
APP_PID=$!

# Wait for app to start
sleep 5

echo "Running WebSocket load tests..."
mix test test/load/websocket_load_test.exs --trace

echo "Running Presence load tests..."
mix test test/load/presence_load_test.exs --trace

# Cleanup
kill $APP_PID
docker stop redis-load-test
docker rm redis-load-test

echo "Load tests complete!"