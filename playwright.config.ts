import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright Configuration for Vel Tutor E2E Tests
 *
 * Features:
 * - Chrome-focused setup for reliability
 * - Automatic Phoenix server startup
 * - Global test data seeding
 * - Retries and parallelization for CI/CD
 */
export default defineConfig({
  // Test directory
  testDir: './tests/e2e',

  // Global setup script (runs before all tests)
  globalSetup: require.resolve('./tests/e2e/global-setup.ts'),

  // Maximum time one test can run for
  timeout: 30 * 1000,

  // Expect timeout
  expect: {
    timeout: 5000,
  },

  // Run tests in files in parallel
  fullyParallel: true,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // Retry on CI only
  retries: process.env.CI ? 2 : 0,

  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,

  // Reporter to use
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list'],
  ],

  // Shared settings for all the projects below
  use: {
    // Base URL to use in actions like `await page.goto('/')`
    baseURL: 'http://localhost:4000',

    // Collect trace when retrying the failed test
    trace: 'on-first-retry',

    // Screenshot on failure
    screenshot: 'only-on-failure',

    // Video on failure
    video: 'retain-on-failure',
  },

  // Configure projects for major browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Run Phoenix server before starting the tests
  webServer: {
    command: 'mix phx.server',
    url: 'http://localhost:4000',
    reuseExistingServer: !process.env.CI,
    timeout: 180 * 1000, // Increased timeout for server startup
    stdout: 'pipe',
    stderr: 'pipe',
    env: {
      MIX_ENV: 'test',
      PORT: '4000',
    },
  },
});
