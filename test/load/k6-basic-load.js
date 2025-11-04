/**
 * Basic Load Test for Viral Engine API
 *
 * Tests core API endpoints under sustained load to verify horizontal scaling.
 *
 * Usage:
 *   k6 run test/load/k6-basic-load.js
 *   k6 run --vus 100 --duration 5m test/load/k6-basic-load.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const taskCreationDuration = new Trend('task_creation_duration');
const taskStatusDuration = new Trend('task_status_duration');

// Test configuration
export const options = {
  stages: [
    { duration: '1m', target: 50 },   // Ramp up to 50 VUs
    { duration: '3m', target: 100 },  // Ramp up to 100 VUs
    { duration: '2m', target: 200 },  // Spike to 200 VUs
    { duration: '2m', target: 100 },  // Scale down to 100 VUs
    { duration: '2m', target: 0 },    // Ramp down to 0 VUs
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'], // 95% of requests under 500ms
    'errors': ['rate<0.01'],            // Error rate under 1%
    'http_req_failed': ['rate<0.01'],   // Failed requests under 1%
  },
};

// Environment variables
const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const TENANT_ID = __ENV.TENANT_ID || 'test-tenant-id';
const USER_ID = __ENV.USER_ID || '1';

export default function () {
  // Test 1: Health Check
  const healthRes = http.get(`${BASE_URL}/api/health`, {
    headers: {
      'Content-Type': 'application/json',
      'X-Tenant-ID': TENANT_ID,
    },
  });

  check(healthRes, {
    'health check status is 200': (r) => r.status === 200,
  }) || errorRate.add(1);

  sleep(1);

  // Test 2: Create Task
  const createTaskPayload = JSON.stringify({
    description: `Load test task ${Date.now()}`,
    agent_id: 'openai-gpt4',
    user_id: USER_ID,
  });

  const createTaskRes = http.post(`${BASE_URL}/api/tasks`, createTaskPayload, {
    headers: {
      'Content-Type': 'application/json',
      'X-Tenant-ID': TENANT_ID,
    },
  });

  const taskCreationSuccess = check(createTaskRes, {
    'task creation status is 201': (r) => r.status === 201,
    'task creation returns task_id': (r) => JSON.parse(r.body).task_id !== undefined,
  });

  taskCreationDuration.add(createTaskRes.timings.duration);

  if (!taskCreationSuccess) {
    errorRate.add(1);
    return; // Skip status check if creation failed
  }

  const taskId = JSON.parse(createTaskRes.body).task_id;

  sleep(0.5);

  // Test 3: Get Task Status
  const statusRes = http.get(`${BASE_URL}/api/tasks/${taskId}`, {
    headers: {
      'Content-Type': 'application/json',
      'X-Tenant-ID': TENANT_ID,
    },
  });

  check(statusRes, {
    'task status is 200': (r) => r.status === 200,
    'task status returns task data': (r) => JSON.parse(r.body).task_id === taskId,
  }) || errorRate.add(1);

  taskStatusDuration.add(statusRes.timings.duration);

  sleep(1);

  // Test 4: List Tasks (pagination test)
  const listRes = http.get(`${BASE_URL}/api/tasks?user_id=${USER_ID}&limit=10&offset=0`, {
    headers: {
      'Content-Type': 'application/json',
      'X-Tenant-ID': TENANT_ID,
    },
  });

  check(listRes, {
    'list tasks status is 200': (r) => r.status === 200,
    'list tasks returns array': (r) => Array.isArray(JSON.parse(r.body).tasks),
  }) || errorRate.add(1);

  sleep(1);
}

export function handleSummary(data) {
  return {
    'test/load/results/k6-basic-load-summary.json': JSON.stringify(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options = {}) {
  const indent = options.indent || '';
  const enableColors = options.enableColors || false;

  let summary = `\n${indent}Load Test Summary\n${indent}${'='.repeat(50)}\n\n`;

  // HTTP metrics
  summary += `${indent}HTTP Metrics:\n`;
  summary += `${indent}  Requests: ${data.metrics.http_reqs.values.count}\n`;
  summary += `${indent}  Failed: ${data.metrics.http_req_failed.values.rate.toFixed(2)}%\n`;
  summary += `${indent}  Duration (p95): ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += `${indent}  Duration (avg): ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;

  // Custom metrics
  if (data.metrics.errors) {
    summary += `\n${indent}Error Rate: ${(data.metrics.errors.values.rate * 100).toFixed(2)}%\n`;
  }

  if (data.metrics.task_creation_duration) {
    summary += `\n${indent}Task Creation:\n`;
    summary += `${indent}  Duration (p95): ${data.metrics.task_creation_duration.values['p(95)'].toFixed(2)}ms\n`;
    summary += `${indent}  Duration (avg): ${data.metrics.task_creation_duration.values.avg.toFixed(2)}ms\n`;
  }

  if (data.metrics.task_status_duration) {
    summary += `\n${indent}Task Status:\n`;
    summary += `${indent}  Duration (p95): ${data.metrics.task_status_duration.values['p(95)'].toFixed(2)}ms\n`;
    summary += `${indent}  Duration (avg): ${data.metrics.task_status_duration.values.avg.toFixed(2)}ms\n`;
  }

  // VU metrics
  summary += `\n${indent}Virtual Users:\n`;
  summary += `${indent}  Peak: ${data.metrics.vus_max.values.max}\n`;
  summary += `${indent}  Average: ${data.metrics.vus.values.avg.toFixed(2)}\n`;

  summary += `\n${indent}${'='.repeat(50)}\n`;

  return summary;
}
