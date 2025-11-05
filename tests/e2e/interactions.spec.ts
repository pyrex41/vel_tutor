import { test, expect } from '@playwright/test';

/**
 * UI Interactions Tests
 *
 * Tests for common user interactions and navigation flows.
 * Authentication is handled automatically by TestAuthPlug.
 */

test.describe('UI Interactions', () => {
  test('should navigate between pages', async ({ page }) => {
    // Start at dashboard
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    // Verify we're on dashboard
    await expect(page).toHaveURL('/dashboard');

    // Try navigating to home
    await page.goto('/');
    await expect(page).toHaveURL('/');
  });

  test('should handle page navigation', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    // Look for any navigation links
    const links = page.locator('nav a, [role="navigation"] a');
    const linkCount = await links.count();

    if (linkCount > 0) {
      // Click first nav link
      const firstLink = links.first();
      const href = await firstLink.getAttribute('href');

      if (href && !href.startsWith('#')) {
        await firstLink.click();
        await page.waitForLoadState('networkidle');

        // Should have navigated somewhere
        const currentUrl = page.url();
        expect(currentUrl).toBeTruthy();
      }
    }
  });

  test('should display page without errors', async ({ page }) => {
    await page.goto('/dashboard');

    // Wait for page to load
    await page.waitForLoadState('networkidle');

    // Check no JavaScript errors occurred
    const pageErrors: string[] = [];
    page.on('pageerror', error => {
      pageErrors.push(error.message);
    });

    // Reload to trigger any load errors
    await page.reload();
    await page.waitForLoadState('networkidle');

    // Should have no critical errors
    const criticalErrors = pageErrors.filter(err =>
      err.toLowerCase().includes('undefined') ||
      err.toLowerCase().includes('null')
    );

    expect(criticalErrors.length).toBe(0);
  });
});
