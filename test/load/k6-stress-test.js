/**
 * Stress Test for Viral Engine Horizontal Scaling
 *
 * Tests system behavior under extreme load to identify breaking points.
 *
 * Usage:
 *   k6 run test/load/k6-stress-test.js
 *   k6 run --env SPIKE=true test/load/k6-stress-test.js
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const batchCreationDuration = new Trend('batch_creation_duration');
const webhookCreationDuration = new Trend('webhook_creation_duration');
const streamingConnectionDuration = new Trend('streaming_connection_duration');
const totalRequests = new Counter('total_requests');

// Test configuration
const isSpike = __ENV.SPIKE === 'true';

export const options = {
  scenarios: {
    // Scenario 1: Sustained load
    sustained_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 100 },
        { duration: '5m', target: 100 },
        { duration: '2m', target: 0 },
      ],
      gracefulRampDown: '30s',
    },

    // Scenario 2: Spike test (optional)
    spike_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: isSpike
        ? [
            { duration: '30s', target: 50 },
            { duration: '1m', target: 500 },  // Spike!
            { duration: '30s', target: 50 },
            { duration: '30s', target: 0 },
          ]
        : [{ duration: '1s', target: 0 }],  // Skip if not spike test
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    'http_req_duration': ['p(95)<1000', 'p(99)<2000'],
    'errors': ['rate<0.05'], // 5% error rate acceptable under stress
    'http_req_failed': ['rate<0.05'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const TENANT_ID = __ENV.TENANT_ID || 'test-tenant-id';
const USER_ID = __ENV.USER_ID || '1';
const ORG_ID = __ENV.ORG_ID || '1';

export default function () {
  totalRequests.add(1);

  // Test Group 1: Batch Operations
  group('Batch Operations', function () {
    const batchPayload = JSON.stringify({
      name: `Stress test batch ${__VU}-${Date.now()}`,
      user_id: USER_ID,
      organization_id: ORG_ID,
      tasks: generateBatchTasks(10), // 10 tasks per batch
      concurrency_limit: 5,
    });

    const batchRes = http.post(`${BASE_URL}/api/batches`, batchPayload, {
      headers: {
        'Content-Type': 'application/json',
        'X-Tenant-ID': TENANT_ID,
      },
    });

    const batchSuccess = check(batchRes, {
      'batch creation status is 201': (r) => r.status === 201,
      'batch returns batch_id': (r) => {
        try {
          return JSON.parse(r.body).batch_id !== undefined;
        } catch (e) {
          return false;
        }
      },
    });

    batchCreationDuration.add(batchRes.timings.duration);
    if (!batchSuccess) errorRate.add(1);

    if (batchSuccess) {
      const batchId = JSON.parse(batchRes.body).batch_id;

      // Check batch status
      const statusRes = http.get(`${BASE_URL}/api/batches/${batchId}`, {
        headers: {
          'X-Tenant-ID': TENANT_ID,
        },
      });

      check(statusRes, {
        'batch status is 200': (r) => r.status === 200,
      }) || errorRate.add(1);
    }
  });

  sleep(0.5);

  // Test Group 2: Webhook Management
  group('Webhook Management', function () {
    const webhookPayload = JSON.stringify({
      user_id: USER_ID,
      organization_id: ORG_ID,
      url: `https://webhook.site/stress-test-${__VU}`,
      event_types: ['task.completed', 'batch.completed'],
      description: `Stress test webhook ${__VU}`,
    });

    const webhookRes = http.post(`${BASE_URL}/api/webhooks`, webhookPayload, {
      headers: {
        'Content-Type': 'application/json',
        'X-Tenant-ID': TENANT_ID,
      },
    });

    const webhookSuccess = check(webhookRes, {
      'webhook creation status is 201': (r) => r.status === 201,
      'webhook returns webhook_id': (r) => {
        try {
          return JSON.parse(r.body).webhook_id !== undefined;
        } catch (e) {
          return false;
        }
      },
    });

    webhookCreationDuration.add(webhookRes.timings.duration);
    if (!webhookSuccess) errorRate.add(1);
  });

  sleep(0.5);

  // Test Group 3: Concurrent Task Creation
  group('Concurrent Task Creation', function () {
    const taskPayloads = Array(5)
      .fill(null)
      .map((_, i) =>
        JSON.stringify({
          description: `Stress test task ${__VU}-${i}-${Date.now()}`,
          agent_id: 'openai-gpt4',
          user_id: USER_ID,
        })
      );

    const requests = taskPayloads.map((payload) => ({
      method: 'POST',
      url: `${BASE_URL}/api/tasks`,
      body: payload,
      params: {
        headers: {
          'Content-Type': 'application/json',
          'X-Tenant-ID': TENANT_ID,
        },
      },
    }));

    const responses = http.batch(requests);

    responses.forEach((res) => {
      check(res, {
        'concurrent task status is 201': (r) => r.status === 201,
      }) || errorRate.add(1);
    });
  });

  sleep(1);

// Test Group 4: Presence Simulation (PubSub load)
group('Presence Simulation', function () {
  const presencePayload = JSON.stringify({
    action: 'join',
    user_id: `${USER_ID}-${__VU}-${Math.floor(Math.random() * 1000)}`,
    subject: 'practice',
    meta: { name: `User${__VU}`, role: 'student' }
  });

  const presenceRes = http.post(`${BASE_URL}/api/presence/simulate`, presencePayload, {
    headers: {
      'Content-Type': 'application/json',
      'X-Tenant-ID': TENANT_ID,
    },
  });

  check(presenceRes, {
    'presence join status is 200': (r) => r.status === 200,
  }) || errorRate.add(1);

  const presenceDuration = new Trend('presence_join_duration');
  presenceDuration.add(presenceRes.timings.duration);
});

  sleep(1);
}

function generateBatchTasks(count) {
  return Array(count)
    .fill(null)
    .map((_, i) => ({
      id: `task-${i}`,
      description: `Batch task ${i}`,
      agent_id: 'openai-gpt4',
    }));
}

export function handleSummary(data) {
  const passed = data.metrics.errors.values.rate < 0.05 && data.metrics.http_req_failed.values.rate < 0.05;

  const summary = {
    'test/load/results/k6-stress-test-summary.json': JSON.stringify(data),
    stdout: generateTextSummary(data, passed),
  };

  return summary;
}

function generateTextSummary(data, passed) {
  const banner = passed ? '✅ STRESS TEST PASSED' : '❌ STRESS TEST FAILED';

  let summary = `\n${'='.repeat(60)}\n${banner}\n${'='.repeat(60)}\n\n`;

  summary += `Total Requests: ${data.metrics.total_requests.values.count}\n`;
  summary += `Total Duration: ${(data.state.testRunDurationMs / 1000 / 60).toFixed(2)} minutes\n\n`;

  summary += `HTTP Performance:\n`;
  summary += `  Success Rate: ${((1 - data.metrics.http_req_failed.values.rate) * 100).toFixed(2)}%\n`;
  summary += `  Error Rate: ${(data.metrics.errors.values.rate * 100).toFixed(2)}%\n`;
  summary += `  Requests/sec: ${data.metrics.http_reqs.values.rate.toFixed(2)}\n`;
  summary += `  Duration (p95): ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += `  Duration (p99): ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n`;
  summary += `  Duration (max): ${data.metrics.http_req_duration.values.max.toFixed(2)}ms\n\n`;

  summary += `Component Performance:\n`;

  if (data.metrics.batch_creation_duration) {
    summary += `  Batch Creation (p95): ${data.metrics.batch_creation_duration.values['p(95)'].toFixed(2)}ms\n`;
  }

  if (data.metrics.webhook_creation_duration) {
    summary += `  Webhook Creation (p95): ${data.metrics.webhook_creation_duration.values['p(95)'].toFixed(2)}ms\n`;
  }

  summary += `\nVirtual Users:\n`;
  summary += `  Peak: ${data.metrics.vus_max.values.max}\n`;
  summary += `  Average: ${data.metrics.vus.values.avg.toFixed(2)}\n\n`;

  summary += `Data Transfer:\n`;
  summary += `  Sent: ${(data.metrics.data_sent.values.count / 1024 / 1024).toFixed(2)} MB\n`;
  summary += `  Received: ${(data.metrics.data_received.values.count / 1024 / 1024).toFixed(2)} MB\n\n`;

  summary += `${'='.repeat(60)}\n`;

  return summary;
}
