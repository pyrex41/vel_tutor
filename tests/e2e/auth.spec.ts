import { test, expect } from '@playwright/test';

/**
 * Authentication Tests
 *
 * Note: Authentication is automatically handled by TestAuthPlug in test environment.
 * These tests verify that the auto-authentication works correctly.
 */

test.describe('Authentication', () => {
  test('should be automatically authenticated', async ({ page }) => {
    // Navigate to dashboard - should work without login
    await page.goto('/dashboard');

    // Should see authenticated user elements
    await expect(page.locator('[data-testid="user-menu"]')).toBeVisible({
      timeout: 10000
    });
  });

  test('should have user session available', async ({ page }) => {
    await page.goto('/');

    // Check that user token is in session
    const cookies = await page.context().cookies();
    const hasSession = cookies.some(cookie =>
      cookie.name.includes('session') || cookie.name.includes('user')
    );

    expect(hasSession).toBeTruthy();
  });

  test('should access protected routes', async ({ page }) => {
    // Try to access a protected route
    await page.goto('/dashboard');

    // Should NOT redirect to login
    await expect(page).toHaveURL('/dashboard');
  });
});
