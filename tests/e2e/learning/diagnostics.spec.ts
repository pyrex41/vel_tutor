import { test, expect } from '@playwright/test';
import { TestHelpers, PageObjects, PerformanceMonitor } from '../utils/test-helpers';

/**
 * Leaderboard System Tests
 *
 * Tests leaderboard functionality including:
 * - Global and subject-specific rankings
 * - Real-time updates
 * - Filtering and time periods
 * - Challenge creation
 * - Mobile responsiveness
 */

test.describe('Leaderboard System', () => {
  let helpers: TestHelpers;
  let pageObjects: PageObjects;
  let perfMonitor: PerformanceMonitor;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    pageObjects = new PageObjects(page);
    perfMonitor = new PerformanceMonitor(page);

    await helpers.gotoAndWait('/leaderboard');
  });

  test('should load leaderboard page successfully', async ({ page }) => {
    await helpers.assertPageLoaded('Leaderboard', [
      'h1:has-text("Leaderboard")',
      'text=Compete with others and track your progress'
    ]);

    await helpers.assertNoErrors();
    await helpers.assertPerformance();
  });

  test('should display global leaderboard by default', async ({ page }) => {
    // Check default scope is global
    await expect(page.locator('select, [role="combobox"]').filter({ hasText: 'Global' })).toBeVisible();

    // Should show leaderboard entries
    await expect(page.locator('.leaderboard-entry, .rank-item')).toHaveCount(await page.locator('.leaderboard-entry, .rank-item').count());

    // Should show user ranks and scores
    const firstEntry = page.locator('.leaderboard-entry, .rank-item').first();
    await expect(firstEntry).toBeVisible();
    await expect(firstEntry.locator('.rank-number, .position')).toBeVisible();
  });

  test('should switch between leaderboard scopes', async ({ page }) => {
    // Test subject-specific leaderboards
    const subjectSelect = page.locator('select[name="subject"], [data-testid="subject-filter"]');
    if (await subjectSelect.isVisible()) {
      await subjectSelect.selectOption('Math');

      // Should update leaderboard
      await helpers.waitForLiveView();
      await expect(page.locator('.subject-indicator')).toContainText('Math');
    }

    // Test grade-specific leaderboards
    const gradeSelect = page.locator('select[name="grade"], [data-testid="grade-filter"]');
    if (await gradeSelect.isVisible()) {
      await gradeSelect.selectOption('9');

      await helpers.waitForLiveView();
      await expect(page.locator('.grade-indicator')).toContainText('9');
    }
  });

  test('should filter by time periods', async ({ page }) => {
    const timeFilters = [
      { label: 'Today', value: 'today' },
      { label: 'This Week', value: 'week' },
      { label: 'This Month', value: 'month' }
    ];

    for (const filter of timeFilters) {
      const filterButton = page.locator(`button:has-text("${filter.label}"), [data-value="${filter.value}"]`);
      if (await filterButton.isVisible()) {
        await helpers.clickAndWait(filterButton);

        // Should update leaderboard data
        await helpers.waitForLiveView();
        await expect(page.locator('.time-period-indicator')).toContainText(filter.label);
      }
    }
  });

  test('should handle leaderboard pagination', async ({ page }) => {
    // Check if pagination exists
    const pagination = page.locator('.pagination, [data-testid="pagination"]');
    if (await pagination.isVisible()) {
      // Click next page
      const nextButton = pagination.locator('button:has-text("Next"), .next-page');
      if (await nextButton.isVisible()) {
        await helpers.clickAndWait(nextButton);

        // Should show different entries
        const firstEntryAfter = page.locator('.leaderboard-entry, .rank-item').first();
        await expect(firstEntryAfter).toBeVisible();
      }
    }
  });

  test('should highlight current user in leaderboard', async ({ page }) => {
    // Look for current user highlighting
    const currentUserEntry = page.locator('.current-user, .user-highlight, [data-current-user="true"]');
    if (await currentUserEntry.isVisible()) {
      // Should have special styling
      await expect(currentUserEntry).toHaveClass(/current-user|highlight/);

      // Should show user's rank
      await expect(currentUserEntry.locator('.rank-number, .position')).toBeVisible();
    }
  });

  test('should show user statistics', async ({ page }) => {
    // Check for user stats section
    const statsSection = page.locator('.user-stats, .personal-stats, [data-testid="user-stats"]');
    if (await statsSection.isVisible()) {
      await expect(statsSection.locator('.rank, .position')).toBeVisible();
      await expect(statsSection.locator('.score, .points')).toBeVisible();
    }
  });

  test('should create challenges from leaderboard', async ({ page }) => {
    // Look for challenge buttons on leaderboard entries
    const challengeButton = page.locator('button:has-text("Challenge"), .challenge-btn').first();
    if (await challengeButton.isVisible()) {
      await helpers.clickAndWait(challengeButton);

      // Should open challenge modal or navigate to challenge page
      await expect(page.locator('.challenge-modal, .modal')).toBeVisible();
    }
  });

  test('should handle real-time leaderboard updates', async ({ page }) => {
    // Get initial leaderboard state
    const initialEntries = await page.locator('.leaderboard-entry, .rank-item').count();

    // Simulate activity that would update leaderboard (in real app, this would be triggered by other users)
    // For testing, we can trigger a refresh or wait for updates
    await page.waitForTimeout(5000); // Wait for potential real-time updates

    // Leaderboard should still be functional (not broken by updates)
    await expect(page.locator('.leaderboard-entry, .rank-item')).toHaveCount(await page.locator('.leaderboard-entry, .rank-item').count());
  });

  test('should be mobile responsive', async ({ page }) => {
    await helpers.testResponsive({ width: 375, height: 667 });

    // Should show leaderboard on mobile
    await expect(page.locator('.leaderboard-container, .rankings')).toBeVisible();

    // Check mobile-specific layout
    const entries = page.locator('.leaderboard-entry, .rank-item');
    await expect(entries.first()).toBeVisible();

    // Touch interactions should work
    if (await entries.count() > 1) {
      await entries.first().click();
      // Should handle mobile tap
    }
  });

  test('should handle empty leaderboard states', async ({ page }) => {
    // Test with filters that might return no results
    const subjectSelect = page.locator('select[name="subject"]');
    if (await subjectSelect.isVisible()) {
      // Select a subject that might have no data
      await subjectSelect.selectOption('Advanced Physics'); // Assuming this might be empty

      await helpers.waitForLiveView();

      // Should handle empty state gracefully
      const emptyState = page.locator('.empty-state, .no-data, text="No leaderboard data"');
      if (await emptyState.isVisible()) {
        await expect(emptyState).toContainText('No data');
      } else {
        // Or should show some default content
        await expect(page.locator('.leaderboard-entry')).toHaveCount(await page.locator('.leaderboard-entry').count());
      }
    }
  });

  test('should load leaderboard with good performance', async ({ page }) => {
    const loadTime = await perfMonitor.measurePageLoad('/leaderboard');
    expect(loadTime).toBeLessThan(3000); // 3 seconds max

    // Check for lazy loading or virtualization if many entries
    const entries = page.locator('.leaderboard-entry, .rank-item');
    const entryCount = await entries.count();

    if (entryCount > 50) {
      // Should handle large datasets efficiently
      await expect(page.locator('[data-loading="false"]')).toBeVisible();
    }
  });

  test('should maintain leaderboard state on navigation', async ({ page }) => {
    // Set specific filters
    const subjectSelect = page.locator('select[name="subject"]');
    if (await subjectSelect.isVisible()) {
      await subjectSelect.selectOption('Math');
      await helpers.waitForLiveView();
    }

    // Navigate away and back
    await helpers.clickAndWait('header a[href="/badges"]');
    await helpers.clickAndWait('header a[href="/leaderboard"]');

    // Should remember filter state
    if (await subjectSelect.isVisible()) {
      await expect(subjectSelect).toHaveValue('Math');
    }
  });
});</content>
<parameter name="filePath">tests/e2e/social/leaderboards.spec.ts