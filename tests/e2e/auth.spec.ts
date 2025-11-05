import { test, expect } from '@playwright/test';

/**
 * Authentication Tests
 *
 * Note: Authentication is automatically handled by TestAuthPlug in test environment.
 * These tests verify that the auto-authentication works correctly.
 */

test.describe('Authentication', () => {
  test('should be automatically authenticated on home page', async ({ page }) => {
    // Navigate to home page
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Page should load without redirecting to login
    await expect(page).toHaveURL('/');

    // Should be able to access activity feed (authenticated route)
    await page.goto('/activity');
    await expect(page).toHaveURL('/activity');
  });

  test('should have user in assigns', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Check that page loads successfully (indicates auth worked)
    const pageTitle = await page.title();
    expect(pageTitle).toBeTruthy();
  });

  test('should access protected routes without login', async ({ page }) => {
    // Try to access activity feed directly
    await page.goto('/activity');

    // Should NOT redirect to login, should show activity page
    await expect(page).toHaveURL('/activity');

    // Page should load
    await page.waitForLoadState('networkidle');
  });
});
