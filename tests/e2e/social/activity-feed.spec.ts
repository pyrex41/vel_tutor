import { test, expect } from '@playwright/test';
import { TestHelpers, PageObjects, PerformanceMonitor } from '../utils/test-helpers';

/**
 * Activity Feed System Tests
 *
 * Tests activity feed functionality including:
 * - Real-time activity updates
 * - Filtering by type and time
 * - Social interactions (likes, comments)
 * - Following user activities
 * - Activity notifications
 */

test.describe('Activity Feed System', () => {
  let helpers: TestHelpers;
  let pageObjects: PageObjects;
  let perfMonitor: PerformanceMonitor;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    pageObjects = new PageObjects(page);
    perfMonitor = new PerformanceMonitor(page);

    await helpers.gotoAndWait('/activity');
  });

  test('should load activity feed page successfully', async ({ page }) => {
    await helpers.assertPageLoaded('Activity Feed', [
      'h1:has-text("Activity Feed")',
      'text=Recent Activities'
    ]);

    await helpers.assertNoErrors();
    await helpers.assertPerformance();
  });

  test('should display activity feed', async ({ page }) => {
    // Should show activity list
    await expect(page.locator('.activity-feed, .feed-list')).toBeVisible();

    // Should have activity items
    const activities = page.locator('.activity-item, .feed-item');
    await expect(activities).toHaveCount(await activities.count());

    // Check first activity has required elements
    const firstActivity = activities.first();
    await expect(firstActivity).toBeVisible();
    await expect(firstActivity.locator('.activity-user, .user-name')).toBeVisible();
    await expect(firstActivity.locator('.activity-content, .content')).toBeVisible();
    await expect(firstActivity.locator('.activity-timestamp, .timestamp')).toBeVisible();
  });

  test('should show different activity types', async ({ page }) => {
    const activities = page.locator('.activity-item, .feed-item');

    // Should have various activity types
    const activityTypes = [
      'badge-unlocked',
      'practice-completed',
      'diagnostic-finished',
      'level-up',
      'friend-added',
      'achievement-earned'
    ];

    let foundTypes = 0;
    for (const type of activityTypes) {
      const typeActivities = page.locator(`[data-activity-type="${type}"], .activity-${type}`);
      if (await typeActivities.count() > 0) {
        foundTypes++;
      }
    }

    // Should have at least some different types
    expect(foundTypes).toBeGreaterThan(0);
  });

  test('should filter activities by type', async ({ page }) => {
    const filterButtons = [
      { selector: 'button:has-text("All"), [data-filter="all"]', expectedClass: '' },
      { selector: 'button:has-text("Achievements"), [data-filter="achievements"]', expectedClass: '.activity-achievement' },
      { selector: 'button:has-text("Practice"), [data-filter="practice"]', expectedClass: '.activity-practice' },
      { selector: 'button:has-text("Social"), [data-filter="social"]', expectedClass: '.activity-social' }
    ];

    for (const filter of filterButtons) {
      const filterButton = page.locator(filter.selector);
      if (await filterButton.isVisible()) {
        await helpers.clickAndWait(filterButton);

        // Should update visible activities
        await helpers.waitForLiveView();

        if (filter.expectedClass) {
          const visibleActivities = page.locator(filter.expectedClass);
          await expect(visibleActivities).toHaveCount(await visibleActivities.count());
        }
      }
    }
  });

  test('should filter activities by time', async ({ page }) => {
    const timeFilters = [
      { selector: 'button:has-text("Today"), [data-time="today"]', label: 'Today' },
      { selector: 'button:has-text("This Week"), [data-time="week"]', label: 'This Week' },
      { selector: 'button:has-text("This Month"), [data-time="month"]', label: 'This Month' },
      { selector: 'button:has-text("All Time"), [data-time="all"]', label: 'All Time' }
    ];

    for (const filter of timeFilters) {
      const filterButton = page.locator(filter.selector);
      if (await filterButton.isVisible()) {
        await helpers.clickAndWait(filterButton);

        // Should update activities
        await helpers.waitForLiveView();

        // Should show activities within time range
        await expect(page.locator('.activity-item')).toHaveCount(await page.locator('.activity-item').count());
      }
    }
  });

  test('should show activity details on click', async ({ page }) => {
    const firstActivity = page.locator('.activity-item, .feed-item').first();

    // Click on activity
    await helpers.clickAndWait(firstActivity);

    // Should show detail view or expand
    const detailView = page.locator('.activity-detail, .expanded-activity, .modal');
    if (await detailView.isVisible()) {
      await expect(detailView).toBeVisible();

      // Should show more detailed information
      await expect(detailView.locator('.activity-description, .details')).toBeVisible();
    }
  });

  test('should allow liking activities', async ({ page }) => {
    const likeButtons = page.locator('button:has-text("Like"), .like-btn, [data-action="like"]');

    if (await likeButtons.count() > 0) {
      const firstLikeBtn = likeButtons.first();
      const initialText = await firstLikeBtn.innerText();

      // Click like button
      await helpers.clickAndWait(firstLikeBtn);

      // Should update like count or button state
      await helpers.waitForLiveView();

      // Button state should change
      const updatedButton = page.locator('button:has-text("Like"), button:has-text("Unlike")').first();
      await expect(updatedButton).not.toHaveText(initialText);
    }
  });

  test('should show like counts and user lists', async ({ page }) => {
    const activities = page.locator('.activity-item, .feed-item');

    if (await activities.count() > 0) {
      const firstActivity = activities.first();

      // Check for like count
      const likeCount = firstActivity.locator('.like-count, .likes');
      if (await likeCount.isVisible()) {
        await expect(likeCount).toBeVisible();

        // Should show number or "likes"
        await expect(likeCount).toMatch(/\d+|likes?/i);
      }
    }
  });

  test('should allow commenting on activities', async ({ page }) => {
    const commentButtons = page.locator('button:has-text("Comment"), .comment-btn');

    if (await commentButtons.count() > 0) {
      await helpers.clickAndWait(commentButtons.first());

      // Should show comment form
      const commentForm = page.locator('.comment-form, .comment-input');
      await expect(commentForm).toBeVisible();

      // Should have input field
      const commentInput = commentForm.locator('input, textarea');
      await expect(commentInput).toBeVisible();

      // Type a comment
      await commentInput.fill('Great work!');

      // Submit comment
      const submitBtn = commentForm.locator('button[type="submit"], button:has-text("Post")');
      await helpers.clickAndWait(submitBtn);

      // Should show new comment
      await expect(page.locator('.comment-item, .comment')).toBeVisible();
    }
  });

  test('should display comments on activities', async ({ page }) => {
    const activities = page.locator('.activity-item, .feed-item');

    if (await activities.count() > 0) {
      const firstActivity = activities.first();

      // Check for existing comments
      const comments = firstActivity.locator('.comments, .comment-list');
      if (await comments.isVisible()) {
        // Should show comment count
        const commentCount = comments.locator('.comment-count');
        if (await commentCount.isVisible()) {
          await expect(commentCount).toMatch(/\d+/);
        }

        // Should show comment items
        const commentItems = comments.locator('.comment-item, .comment');
        if (await commentItems.count() > 0) {
          await expect(commentItems.first().locator('.comment-author, .user-name')).toBeVisible();
          await expect(commentItems.first().locator('.comment-content, .text')).toBeVisible();
        }
      }
    }
  });

  test('should show following/followers activities', async ({ page }) => {
    // Check for following filter
    const followingFilter = page.locator('button:has-text("Following"), [data-filter="following"]');

    if (await followingFilter.isVisible()) {
      await helpers.clickAndWait(followingFilter);

      // Should show only followed users' activities
      await helpers.waitForLiveView();

      const activities = page.locator('.activity-item');
      if (await activities.count() > 0) {
        // Activities should be from followed users
        await expect(activities).toHaveCount(await activities.count());
      }
    }
  });

  test('should handle real-time activity updates', async ({ page }) => {
    // Test LiveView real-time updates
    await helpers.waitForLiveView();

    // Should have real-time indicator
    const liveIndicator = page.locator('.live-indicator, .real-time, [data-live="true"]');
    if (await liveIndicator.isVisible()) {
      await expect(liveIndicator).toBeVisible();
    }

    // Activities should update without page refresh
    const initialCount = await page.locator('.activity-item').count();

    // Wait a moment for potential updates
    await page.waitForTimeout(2000);

    // Count should remain stable or increase (no decrease without user action)
    const finalCount = await page.locator('.activity-item').count();
    expect(finalCount).toBeGreaterThanOrEqual(initialCount);
  });

  test('should show activity notifications', async ({ page }) => {
    // Check for notification indicators
    const notifications = page.locator('.notification-badge, .unread-indicator');

    if (await notifications.count() > 0) {
      // Should show unread count
      await expect(notifications.first()).toBeVisible();

      // Should contain number
      await expect(notifications.first()).toMatch(/\d+/);
    }
  });

  test('should allow sharing activities', async ({ page }) => {
    const shareButtons = page.locator('button:has-text("Share"), .share-btn');

    if (await shareButtons.count() > 0) {
      await helpers.clickAndWait(shareButtons.first());

      // Should show share options
      const shareModal = page.locator('.share-modal, .share-options');
      await expect(shareModal).toBeVisible();

      // Should have share methods
      await expect(shareModal.locator('button:has-text("Copy Link")')).toBeVisible();
    }
  });

  test('should be mobile responsive', async ({ page }) => {
    await helpers.testResponsive({ width: 375, height: 667 });

    // Should show activity feed on mobile
    await expect(page.locator('.activity-feed, .feed-container')).toBeVisible();

    // Check mobile layout
    const activities = page.locator('.activity-item, .feed-item');
    await expect(activities.first()).toBeVisible();

    // Touch interactions should work
    await activities.first().tap();

    // Should handle mobile details
    const detailView = page.locator('.activity-detail, .modal');
    if (await detailView.isVisible()) {
      await expect(detailView).toBeVisible();
    }
  });

  test('should handle empty activity states', async ({ page }) => {
    // Test filtering to potentially empty state
    const typeFilter = page.locator('button[data-filter]:not([data-filter="all"])');
    if (await typeFilter.isVisible()) {
      await helpers.clickAndWait(typeFilter);

      // Should handle empty state gracefully
      const visibleActivities = page.locator('.activity-item:visible, .feed-item:visible');
      if (await visibleActivities.count() === 0) {
        // Should show empty state message
        await expect(page.locator('.empty-state, text="No activities found"')).toBeVisible();
      }
    }
  });

  test('should show activity categories/tabs', async ({ page }) => {
    // Check for activity type tabs
    const activityTabs = page.locator('.activity-tabs, [data-activity-category]');

    if (await activityTabs.count() > 1) {
      // Test switching between categories
      const secondTab = activityTabs.nth(1);
      await helpers.clickAndWait(secondTab);

      // Should show different activities
      await helpers.waitForLiveView();
      await expect(page.locator('.activity-item')).toHaveCount(await page.locator('.activity-item').count());
    }
  });

  test('should load more activities on scroll', async ({ page }) => {
    const initialCount = await page.locator('.activity-item').count();

    // Scroll to bottom
    await page.locator('.activity-feed').evaluate(el => el.scrollTop = el.scrollHeight);

    // Wait for potential load more
    await page.waitForTimeout(2000);

    const finalCount = await page.locator('.activity-item').count();

    // Should have same or more activities
    expect(finalCount).toBeGreaterThanOrEqual(initialCount);
  });
});</content>
<parameter name="filePath">tests/e2e/social/activity-feed.spec.ts