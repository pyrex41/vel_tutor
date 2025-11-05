import { test, expect } from '@playwright/test';

/**
 * Dashboard/Activity Feed Tests
 *
 * Tests for the activity feed and main app functionality.
 * Authentication is handled automatically by TestAuthPlug.
 */

test.describe('Activity Feed', () => {
  test('should load activity feed page', async ({ page }) => {
    await page.goto('/activity');

    // Wait for page to load
    await page.waitForLoadState('networkidle');

    // Should be on activity page
    await expect(page).toHaveURL('/activity');

    // Page should have loaded successfully
    const pageContent = await page.textContent('body');
    expect(pageContent).toBeTruthy();
  });

  test('should display home page', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Should show home page
    const pageTitle = await page.title();
    expect(pageTitle).toBeTruthy();
  });

  test('should navigate to diagnostic assessment', async ({ page }) => {
    await page.goto('/diagnostic');
    await page.waitForLoadState('networkidle');

    // Should load diagnostic page
    await expect(page).toHaveURL('/diagnostic');
  });
});
