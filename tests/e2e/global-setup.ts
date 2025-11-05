import { execSync } from 'child_process';

/**
 * Global setup for Playwright E2E tests
 * Runs once before all tests to seed test data
 */
async function globalSetup() {
  console.log('🌱 Setting up test data...');

  try {
    // Run Elixir test seed task
    execSync('mix run priv/repo/seeds_test.exs', {
      stdio: 'inherit',
      env: { ...process.env, MIX_ENV: 'test' }
    });
    console.log('✅ Test data seeded successfully');
  } catch (error) {
    console.error('❌ Failed to seed test data:', error);
    throw error;
  }
}

export default globalSetup;
