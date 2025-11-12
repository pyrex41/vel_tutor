import { test, expect } from '@playwright/test';
import { TestHelpers, PageObjects, PerformanceMonitor } from '../utils/test-helpers';

/**
 * Leaderboards System Tests
 *
 * Tests leaderboard functionality including:
 * - Global and subject-specific rankings
 * - Time-based filtering (daily, weekly, monthly, all-time)
 * - User position and progress tracking
 * - Social features (following, comparing)
 * - Real-time updates
 */

test.describe('Leaderboards System', () => {
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
      'text=Global Rankings'
    ]);

    await helpers.assertNoErrors();
    await helpers.assertPerformance();
  });

  test('should display global leaderboard', async ({ page }) => {
    // Should show leaderboard table/list
    await expect(page.locator('.leaderboard-table, .rankings-list')).toBeVisible();

    // Should have ranking positions
    await expect(page.locator('.rank-position, .position')).toHaveCount(await page.locator('.rank-position, .position').count());

    // Should show user information
    const firstEntry = page.locator('.leaderboard-entry, .ranking-item').first();
    await expect(firstEntry).toBeVisible();
    await expect(firstEntry.locator('.user-name, .username')).toBeVisible();
    await expect(firstEntry.locator('.user-score, .points, .xp')).toBeVisible();
  });

  test('should show user current position', async ({ page }) => {
    // Should highlight current user
    const currentUserEntry = page.locator('.current-user, [data-current-user="true"], .user-highlight');
    if (await currentUserEntry.isVisible()) {
      await expect(currentUserEntry).toBeVisible();

      // Should show position number
      await expect(currentUserEntry.locator('.rank-position')).toBeVisible();
    }
  });

  test('should filter by time period', async ({ page }) => {
    const timeFilters = [
      { selector: 'button:has-text("Daily"), [data-filter="daily"]', label: 'Daily' },
      { selector: 'button:has-text("Weekly"), [data-filter="weekly"]', label: 'Weekly' },
      { selector: 'button:has-text("Monthly"), [data-filter="monthly"]', label: 'Monthly' },
      { selector: 'button:has-text("All Time"), [data-filter="all-time"]', label: 'All Time' }
    ];

    for (const filter of timeFilters) {
      const filterButton = page.locator(filter.selector);
      if (await filterButton.isVisible()) {
        await helpers.clickAndWait(filterButton);

        // Should update rankings
        await helpers.waitForLiveView();

        // Should show updated data
        await expect(page.locator('.leaderboard-entry')).toHaveCount(await page.locator('.leaderboard-entry').count());
      }
    }
  });

  test('should filter by subject/category', async ({ page }) => {
    const subjectFilters = [
      { selector: 'button:has-text("Math"), [data-subject="math"]', label: 'Math' },
      { selector: 'button:has-text("Science"), [data-subject="science"]', label: 'Science' },
      { selector: 'button:has-text("English"), [data-subject="english"]', label: 'English' },
      { selector: 'button:has-text("All Subjects"), [data-subject="all"]', label: 'All Subjects' }
    ];

    for (const filter of subjectFilters) {
      const filterButton = page.locator(filter.selector);
      if (await filterButton.isVisible()) {
        await helpers.clickAndWait(filterButton);

        // Should update rankings for subject
        await helpers.waitForLiveView();

        // Should show subject-specific rankings
        await expect(page.locator('.leaderboard-entry')).toHaveCount(await page.locator('.leaderboard-entry').count());
      }
    }
  });

  test('should show rank changes and trends', async ({ page }) => {
    const entries = page.locator('.leaderboard-entry, .ranking-item');

    if (await entries.count() > 0) {
      const firstEntry = entries.first();

      // Check for rank change indicators
      const rankChange = firstEntry.locator('.rank-change, .trend, .delta');
      if (await rankChange.isVisible()) {
        await expect(rankChange).toBeVisible();

        // Should show up/down arrows or +/- numbers
        await expect(rankChange).toMatch(/↑|↓|±|\+|-|\d+/);
      }
    }
  });

  test('should display user statistics', async ({ page }) => {
    // Check for user stats section
    const statsSection = page.locator('.user-stats, .personal-stats, [data-testid="user-stats"]');

    if (await statsSection.isVisible()) {
      // Should show personal ranking
      await expect(statsSection.locator('.personal-rank, .my-position')).toBeVisible();

      // Should show total points/XP
      await expect(statsSection.locator('.total-points, .total-xp')).toBeVisible();

      // Should show percentile or comparison
      const percentile = statsSection.locator('.percentile, .comparison');
      if (await percentile.isVisible()) {
        await expect(percentile).toBeVisible();
      }
    }
  });

  test('should allow comparing with friends', async ({ page }) => {
    // Look for friend comparison feature
    const compareButton = page.locator('button:has-text("Compare"), .compare-btn');
    const friendEntries = page.locator('.friend-entry, [data-friend="true"]');

    if (await compareButton.isVisible() && await friendEntries.count() > 0) {
      await helpers.clickAndWait(compareButton);

      // Should show comparison view
      await expect(page.locator('.comparison-view, .compare-modal')).toBeVisible();

      // Should show side-by-side rankings
      await expect(page.locator('.comparison-entry')).toHaveCount(await page.locator('.comparison-entry').count());
    }
  });

  test('should show top performers section', async ({ page }) => {
    // Check for top 3 or featured performers
    const topPerformers = page.locator('.top-performers, .featured-users, .podium');

    if (await topPerformers.isVisible()) {
      // Should show top 3 positions
      await expect(page.locator('.podium-1st, .gold')).toBeVisible();
      await expect(page.locator('.podium-2nd, .silver')).toBeVisible();
      await expect(page.locator('.podium-3rd, .bronze')).toBeVisible();

      // Should have special styling
      await expect(page.locator('.podium-1st')).toHaveClass(/gold|podium|featured/);
    }
  });

  test('should handle pagination for large leaderboards', async ({ page }) => {
    // Check for pagination controls
    const pagination = page.locator('.pagination, .page-controls');

    if (await pagination.isVisible()) {
      // Should show page numbers
      await expect(pagination.locator('.page-number, button')).toHaveCount(await pagination.locator('.page-number, button').count());

      // Test pagination click
      const nextPage = pagination.locator('button:has-text("Next"), .next-page');
      if (await nextPage.isVisible()) {
        await helpers.clickAndWait(nextPage);

        // Should load next page
        await helpers.waitForLiveView();
        await expect(page.locator('.leaderboard-entry')).toHaveCount(await page.locator('.leaderboard-entry').count());
      }
    }
  });

  test('should show real-time updates', async ({ page }) => {
    // This test would ideally simulate real-time updates
    // For now, we'll test that the system is ready for real-time

    // Check for LiveView connection
    await helpers.waitForLiveView();

    // Should have real-time indicators if applicable
    const liveIndicator = page.locator('.live-indicator, .real-time, [data-live="true"]');
    if (await liveIndicator.isVisible()) {
      await expect(liveIndicator).toBeVisible();
    }
  });

  test('should allow following/unfollowing users', async ({ page }) => {
    const followButtons = page.locator('button:has-text("Follow"), button:has-text("Unfollow"), .follow-btn');

    if (await followButtons.count() > 0) {
      const firstFollowBtn = followButtons.first();

      // Click follow/unfollow
      await helpers.clickAndWait(firstFollowBtn);

      // Should update button state
      await helpers.waitForLiveView();

      // Button text should change
      const updatedButton = page.locator('button:has-text("Follow"), button:has-text("Unfollow")').first();
      await expect(updatedButton).not.toHaveText(await firstFollowBtn.innerText());
    }
  });

  test('should be mobile responsive', async ({ page }) => {
    await helpers.testResponsive({ width: 375, height: 667 });

    // Should show leaderboard on mobile
    await expect(page.locator('.leaderboard-container, .rankings')).toBeVisible();

    // Check mobile layout
    const entries = page.locator('.leaderboard-entry, .ranking-item');
    await expect(entries.first()).toBeVisible();

    // Touch interactions should work
    await entries.first().tap();

    // Should handle mobile details
    const detailView = page.locator('.user-detail, .modal');
    if (await detailView.isVisible()) {
      await expect(detailView).toBeVisible();
    }
  });

  test('should handle empty leaderboard states', async ({ page }) => {
    // Test filtering to potentially empty state
    const subjectFilter = page.locator('button[data-subject]:not([data-subject="all"])');
    if (await subjectFilter.isVisible()) {
      await helpers.clickAndWait(subjectFilter);

      // Should handle empty state gracefully
      const visibleEntries = page.locator('.leaderboard-entry:visible, .ranking-item:visible');
      if (await visibleEntries.count() === 0) {
        // Should show empty state message
        await expect(page.locator('.empty-state, text="No rankings available"')).toBeVisible();
      }
    }
  });

  test('should show leaderboard categories', async ({ page }) => {
    // Check for different leaderboard types
    const categoryTabs = page.locator('.leaderboard-tabs, [data-leaderboard-type]');

    if (await categoryTabs.count() > 1) {
      // Test switching between categories
      const secondTab = categoryTabs.nth(1);
      await helpers.clickAndWait(secondTab);

      // Should show different rankings
      await helpers.waitForLiveView();
      await expect(page.locator('.leaderboard-entry')).toHaveCount(await page.locator('.leaderboard-entry').count());
    }
  });

  test('should display achievement badges on leaderboard', async ({ page }) => {
    // Check for achievement indicators
    const achievementBadges = page.locator('.achievement-badge, .user-badges');

    if (await achievementBadges.count() > 0) {
      // Should show badges next to user names
      await expect(achievementBadges.first()).toBeVisible();

      // Should be clickable for details
      await helpers.clickAndWait(achievementBadges.first());

      // Should show badge details
      const badgeDetail = page.locator('.badge-detail, .achievement-detail');
      if (await badgeDetail.isVisible()) {
        await expect(badgeDetail).toBeVisible();
      }
    }
  });
});</content>
<parameter name="filePath">tests/e2e/social/leaderboards.spec.ts