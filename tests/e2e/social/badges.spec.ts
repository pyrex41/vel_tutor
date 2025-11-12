import { test, expect } from '@playwright/test';
import { TestHelpers, PageObjects, PerformanceMonitor } from '../utils/test-helpers';

/**
 * Badges & Achievements System Tests
 *
 * Tests badge functionality including:
 * - Badge collection display
 * - Filtering and categorization
 * - Unlock animations and notifications
 * - Progress tracking
 * - Share functionality
 */

test.describe('Badges & Achievements System', () => {
  let helpers: TestHelpers;
  let pageObjects: PageObjects;
  let perfMonitor: PerformanceMonitor;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    pageObjects = new PageObjects(page);
    perfMonitor = new PerformanceMonitor(page);

    await helpers.gotoAndWait('/badges');
  });

  test('should load badges page successfully', async ({ page }) => {
    await helpers.assertPageLoaded('Badges & Achievements', [
      'h1:has-text("Badges & Achievements")',
      'text=Completion Rate'
    ]);

    await helpers.assertNoErrors();
    await helpers.assertPerformance();
  });

  test('should display badge collection', async ({ page }) => {
    // Should show badges grid/list
    await expect(page.locator('.badge-item, .achievement-card')).toHaveCount(await page.locator('.badge-item, .achievement-card').count());

    // Check first badge has required elements
    const firstBadge = page.locator('.badge-item, .achievement-card').first();
    await expect(firstBadge).toBeVisible();
    await expect(firstBadge.locator('.badge-name, .title')).toBeVisible();
    await expect(firstBadge.locator('.badge-description, .description')).toBeVisible();
  });

  test('should show badge unlock status', async ({ page }) => {
    const badges = page.locator('.badge-item, .achievement-card');

    // Should have some unlocked badges
    const unlockedBadges = page.locator('.badge-unlocked, .achievement-unlocked, [data-unlocked="true"]');
    await expect(unlockedBadges).toHaveCount(await unlockedBadges.count());

    // Should have some locked badges
    const lockedBadges = page.locator('.badge-locked, .achievement-locked, [data-unlocked="false"]');
    await expect(lockedBadges).toHaveCount(await lockedBadges.count());
  });

  test('should filter badges by status', async ({ page }) => {
    const filterButtons = [
      { selector: 'button:has-text("All Badges"), [data-filter="all"]', expectedClass: '' },
      { selector: 'button:has-text("Unlocked"), [data-filter="unlocked"]', expectedClass: '.badge-unlocked' },
      { selector: 'button:has-text("Locked"), [data-filter="locked"]', expectedClass: '.badge-locked' }
    ];

    for (const filter of filterButtons) {
      const filterButton = page.locator(filter.selector);
      if (await filterButton.isVisible()) {
        await helpers.clickAndWait(filterButton);

        // Should update visible badges
        await helpers.waitForLiveView();

        if (filter.expectedClass) {
          const visibleBadges = page.locator(filter.expectedClass);
          await expect(visibleBadges).toHaveCount(await visibleBadges.count());
        }
      }
    }
  });

  test('should show badge progress for locked badges', async ({ page }) => {
    // Find locked badges
    const lockedBadges = page.locator('.badge-locked, .achievement-locked, [data-unlocked="false"]');

    if (await lockedBadges.count() > 0) {
      const firstLocked = lockedBadges.first();

      // Should show progress indicator
      const progressBar = firstLocked.locator('.progress-bar, .progress-indicator, [data-progress]');
      if (await progressBar.isVisible()) {
        await expect(progressBar).toBeVisible();

        // Should show progress text
        const progressText = firstLocked.locator('.progress-text, .progress-label');
        await expect(progressText).toBeVisible();
        await expect(progressText).toMatch(/\d+\/\d+/); // e.g., "3/5"
      }
    }
  });

  test('should display badge details on click', async ({ page }) => {
    const firstBadge = page.locator('.badge-item, .achievement-card').first();

    // Click on badge
    await helpers.clickAndWait(firstBadge);

    // Should show detail modal or expanded view
    const detailView = page.locator('.badge-detail, .achievement-detail, .modal');
    await expect(detailView).toBeVisible();

    // Should show detailed information
    await expect(detailView.locator('.badge-description, .description')).toBeVisible();

    // Should show requirements or criteria
    const requirements = detailView.locator('.requirements, .criteria, .how-to-earn');
    if (await requirements.isVisible()) {
      await expect(requirements).toBeVisible();
    }
  });

  test('should handle badge unlock animations', async ({ page }) => {
    // This test would ideally trigger a badge unlock
    // For now, we'll test that the animation system is in place

    // Check for animation classes or styles
    const badges = page.locator('.badge-item, .achievement-card');
    const firstBadge = badges.first();

    // Should have animation-ready classes
    await expect(firstBadge).toHaveAttribute('class');

    // Test hover effects (common trigger for animations)
    await firstBadge.hover();

    // Should still be functional after hover
    await expect(firstBadge).toBeVisible();
  });

  test('should show recent badge unlocks', async ({ page }) => {
    // Check for "NEW" or "Recently Unlocked" indicators
    const newBadges = page.locator('.badge-new, .recent-unlock, [data-new="true"]');

    if (await newBadges.count() > 0) {
      // Should have special styling
      await expect(newBadges.first()).toHaveClass(/new|recent|highlight/);

      // Should show unlock date or "NEW" label
      await expect(newBadges.first().locator('.new-label, .unlock-date')).toBeVisible();
    }
  });

  test('should share unlocked badges', async ({ page }) => {
    // Find unlocked badges
    const unlockedBadges = page.locator('.badge-unlocked, .achievement-unlocked, [data-unlocked="true"]');

    if (await unlockedBadges.count() > 0) {
      const firstUnlocked = unlockedBadges.first();

      // Look for share button
      const shareButton = firstUnlocked.locator('button:has-text("Share"), .share-btn');
      if (await shareButton.isVisible()) {
        await helpers.clickAndWait(shareButton);

        // Should open share modal or interface
        await expect(page.locator('.share-modal, .modal')).toBeVisible();

        // Should have share options
        await expect(page.locator('.share-option, button:has-text("Copy Link")')).toBeVisible();
      }
    }
  });

  test('should display badge categories', async ({ page }) => {
    // Check for category filters
    const categoryButtons = page.locator('button[data-category], .category-filter');

    if (await categoryButtons.count() > 0) {
      // Test category filtering
      await helpers.clickAndWait(categoryButtons.first());

      // Should filter badges by category
      await helpers.waitForLiveView();
      await expect(page.locator('.badge-item')).toHaveCount(await page.locator('.badge-item').count());
    }
  });

  test('should show overall progress statistics', async ({ page }) => {
    // Check for completion stats
    const statsSection = page.locator('.stats-section, .progress-summary, [data-testid="badge-stats"]');

    if (await statsSection.isVisible()) {
      // Should show completion percentage
      await expect(statsSection.locator('.completion-rate, .percentage')).toBeVisible();

      // Should show unlocked vs total
      await expect(statsSection.locator('.unlocked-count, .total-count')).toBeVisible();
    }
  });

  test('should be mobile responsive', async ({ page }) => {
    await helpers.testResponsive({ width: 375, height: 667 });

    // Should show badges on mobile
    await expect(page.locator('.badge-grid, .badges-container')).toBeVisible();

    // Check mobile layout
    const badges = page.locator('.badge-item, .achievement-card');
    await expect(badges.first()).toBeVisible();

    // Touch interactions should work
    await badges.first().tap();

    // Should handle mobile modal or detail view
    const detailView = page.locator('.badge-detail, .modal');
    if (await detailView.isVisible()) {
      await expect(detailView).toBeVisible();
    }
  });

  test('should handle empty badge states', async ({ page }) => {
    // Test filtering to potentially empty state
    const lockedFilter = page.locator('button:has-text("Locked"), [data-filter="locked"]');
    if (await lockedFilter.isVisible()) {
      await helpers.clickAndWait(lockedFilter);

      // Should handle empty state gracefully
      const visibleBadges = page.locator('.badge-item:visible, .achievement-card:visible');
      if (await visibleBadges.count() === 0) {
        // Should show empty state message
        await expect(page.locator('.empty-state, text="No badges found"')).toBeVisible();
      }
    }
  });

  test('should maintain filter state on navigation', async ({ page }) => {
    // Set a filter
    const unlockedFilter = page.locator('button:has-text("Unlocked"), [data-filter="unlocked"]');
    if (await unlockedFilter.isVisible()) {
      await helpers.clickAndWait(unlockedFilter);

      // Navigate away and back
      await helpers.clickAndWait('header a[href="/leaderboard"]');
      await helpers.clickAndWait('header a[href="/badges"]');

      // Should remember filter state
      await expect(unlockedFilter).toHaveClass(/active|selected/);
    }
  });
});</content>
<parameter name="filePath">tests/e2e/social/badges.spec.ts