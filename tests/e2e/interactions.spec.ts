import { test, expect } from '@playwright/test';

/**
 * UI Interactions Tests
 *
 * Tests for common user interactions and navigation flows.
 * Authentication is handled automatically by TestAuthPlug.
 */

test.describe('UI Interactions', () => {
  test('should navigate between pages', async ({ page }) => {
    // Start at home
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Verify we're on home
    await expect(page).toHaveURL('/');

    // Navigate to activity feed
    await page.goto('/activity');
    await expect(page).toHaveURL('/activity');

    // Navigate to diagnostic
    await page.goto('/diagnostic');
    await expect(page).toHaveURL('/diagnostic');
  });

  test('should handle page loads without errors', async ({ page }) => {
    const pageErrors: string[] = [];
    page.on('pageerror', error => {
      pageErrors.push(error.message);
    });

    // Load home page
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Load activity page
    await page.goto('/activity');
    await page.waitForLoadState('networkidle');

    // Should have no critical errors
    const criticalErrors = pageErrors.filter(err =>
      err.toLowerCase().includes('failed to fetch') ||
      err.toLowerCase().includes('network error')
    );

    expect(criticalErrors.length).toBe(0);
  });

  test('should display content on home page', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Page should have some content
    const bodyText = await page.textContent('body');
    expect(bodyText?.length).toBeGreaterThan(0);
  });
});
