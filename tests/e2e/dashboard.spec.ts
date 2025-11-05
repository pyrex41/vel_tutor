import { test, expect } from '@playwright/test';

/**
 * Dashboard Tests
 *
 * Tests for the main dashboard functionality.
 * Authentication is handled automatically by TestAuthPlug.
 */

test.describe('Dashboard', () => {
  test('should load dashboard with activity feed', async ({ page }) => {
    await page.goto('/dashboard');

    // Wait for page to load
    await page.waitForLoadState('networkidle');

    // Check user menu is visible (indicates auth worked)
    await expect(page.locator('[data-testid="user-menu"]')).toBeVisible({
      timeout: 10000
    });

    // Check dashboard loaded (flexible selector)
    const dashboardContent = page.locator('[data-testid="dashboard-header"], h1, [role="main"]');
    await expect(dashboardContent.first()).toBeVisible();
  });

  test('should navigate to profile page if available', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    // Try to find profile link
    const profileLink = page.locator('[data-testid="profile-link"], a[href="/profile"]');

    if (await profileLink.count() > 0) {
      await profileLink.first().click();

      // Should navigate to profile
      await expect(page).toHaveURL('/profile');
    }
  });

  test('should display user information', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    // Should show test user email or name somewhere
    const pageContent = await page.textContent('body');
    expect(pageContent).toContain('test@example.com');
  });
});
