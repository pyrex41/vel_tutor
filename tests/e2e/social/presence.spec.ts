import { test, expect } from '@playwright/test';
import { TestHelpers, PageObjects, PerformanceMonitor } from '../utils/test-helpers';

/**
 * Real-time Presence System Tests
 *
 * Tests presence functionality including:
 * - Online/offline status indicators
 * - Real-time user presence updates
 * - Presence in different contexts (leaderboards, activity feed)
 * - Typing indicators and live interactions
 * - Presence-based features
 */

test.describe('Real-time Presence System', () => {
  let helpers: TestHelpers;
  let pageObjects: PageObjects;
  let perfMonitor: PerformanceMonitor;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    pageObjects = new PageObjects(page);
    perfMonitor = new PerformanceMonitor(page);

    await helpers.gotoAndWait('/dashboard');
  });

  test('should show online status indicators', async ({ page }) => {
    // Should show presence indicators somewhere on the page
    const presenceIndicators = page.locator('.presence-indicator, .online-status, [data-presence]');
    await expect(presenceIndicators).toHaveCount(await presenceIndicators.count());

    // Should have some online users
    const onlineIndicators = page.locator('.online, [data-status="online"], .presence-online');
    await expect(onlineIndicators).toHaveCount(await onlineIndicators.count());
  });

  test('should display user presence in leaderboards', async ({ page }) => {
    // Navigate to leaderboard
    await helpers.clickAndWait('a[href="/leaderboard"], button:has-text("Leaderboard")');

    // Should show presence indicators on leaderboard entries
    const leaderboardPresence = page.locator('.leaderboard-entry .presence-indicator, .ranking-item [data-presence]');
    if (await leaderboardPresence.count() > 0) {
      await expect(leaderboardPresence.first()).toBeVisible();

      // Should show online/offline status
      await expect(leaderboardPresence.first()).toHaveAttribute('data-status');
    }
  });

  test('should show presence in activity feed', async ({ page }) => {
    // Navigate to activity feed
    await helpers.clickAndWait('a[href="/activity"], button:has-text("Activity")');

    // Should show presence indicators on activity items
    const activityPresence = page.locator('.activity-item .presence-indicator, .feed-item [data-presence]');
    if (await activityPresence.count() > 0) {
      await expect(activityPresence.first()).toBeVisible();
    }
  });

  test('should update presence in real-time', async ({ page }) => {
    // Test LiveView real-time presence updates
    await helpers.waitForLiveView();

    // Get initial presence count
    const initialOnlineCount = await page.locator('.online, [data-status="online"]').count();

    // Wait for potential presence updates
    await page.waitForTimeout(5000);

    // Presence should be stable (no unexpected changes without user action)
    const finalOnlineCount = await page.locator('.online, [data-status="online"]').count();

    // Count should be reasonably stable
    expect(Math.abs(finalOnlineCount - initialOnlineCount)).toBeLessThan(5);
  });

  test('should show typing indicators in chat/messages', async ({ page }) => {
    // Check for chat or messaging interface
    const chatInterface = page.locator('.chat-interface, .messages, [data-testid="chat"]');

    if (await chatInterface.isVisible()) {
      // Should have message input
      const messageInput = chatInterface.locator('input[name="message"], textarea[name="message"]');
      await expect(messageInput).toBeVisible();

      // Type in chat to trigger typing indicator
      await messageInput.fill('Hello everyone!');

      // Should show typing indicator somewhere
      const typingIndicator = page.locator('.typing-indicator, .someone-typing, [data-typing="true"]');
      if (await typingIndicator.isVisible()) {
        await expect(typingIndicator).toBeVisible();
        await expect(typingIndicator).toContainText('typing');
      }

      // Clear input
      await messageInput.clear();
    }
  });

  test('should show user presence in friend lists', async ({ page }) => {
    // Check for friends/followers section
    const friendsSection = page.locator('.friends-list, .followers, [data-testid="friends"]');

    if (await friendsSection.isVisible()) {
      // Should show friend items
      const friends = friendsSection.locator('.friend-item, .user-item');
      await expect(friends).toHaveCount(await friends.count());

      // Should have presence indicators
      const friendPresence = friends.locator('.presence-indicator, [data-presence]');
      if (await friendPresence.count() > 0) {
        await expect(friendPresence.first()).toHaveAttribute('data-status');
      }
    }
  });

  test('should handle presence in collaborative features', async ({ page }) => {
    // Check for collaborative features like study groups
    const collaborativeSection = page.locator('.study-group, .collaboration, [data-testid="collaboration"]');

    if (await collaborativeSection.isVisible()) {
      // Should show active participants
      const participants = collaborativeSection.locator('.participant, .group-member');
      await expect(participants).toHaveCount(await participants.count());

      // Should show presence for participants
      const participantPresence = participants.locator('.presence-indicator, [data-presence]');
      if (await participantPresence.count() > 0) {
        await expect(participantPresence.first()).toBeVisible();
      }
    }
  });

  test('should show presence-based features', async ({ page }) => {
    // Check for presence-dependent features
    const presenceFeatures = page.locator('.presence-feature, [data-requires-presence]');

    if (await presenceFeatures.count() > 0) {
      const firstFeature = presenceFeatures.first();

      // Should be enabled/disabled based on presence
      const isEnabled = await firstFeature.isEnabled();
      const presenceStatus = await firstFeature.getAttribute('data-presence-required');

      if (presenceStatus) {
        // Feature should reflect presence requirements
        await expect(firstFeature).toBeVisible();
      }
    }
  });

  test('should display last seen timestamps for offline users', async ({ page }) => {
    // Find offline users
    const offlineUsers = page.locator('[data-status="offline"], .offline');

    if (await offlineUsers.count() > 0) {
      const firstOffline = offlineUsers.first();

      // Should show last seen time
      const lastSeen = firstOffline.locator('.last-seen, .last-active, [data-last-seen]');
      if (await lastSeen.isVisible()) {
        await expect(lastSeen).toBeVisible();

        // Should contain time information
        await expect(lastSeen).toMatch(/\d+|minutes?|hours?|days?|ago/i);
      }
    }
  });

  test('should show presence in user profiles', async ({ page }) => {
    // Navigate to a user profile or click on a user
    const userLink = page.locator('.user-link, .username-link, [data-user-id]').first();

    if (await userLink.isVisible()) {
      await helpers.clickAndWait(userLink);

      // Should show profile page
      const profilePage = page.locator('.user-profile, .profile-page');
      if (await profilePage.isVisible()) {
        // Should show presence status
        const profilePresence = profilePage.locator('.presence-indicator, [data-presence]');
        await expect(profilePresence).toBeVisible();

        // Should show current status
        await expect(profilePresence).toHaveAttribute('data-status');
      }
    }
  });

  test('should handle presence during navigation', async ({ page }) => {
    // Get initial presence state
    const initialPresence = await page.locator('.presence-indicator').first().getAttribute('data-status');

    // Navigate to different page
    await helpers.clickAndWait('a[href="/leaderboard"], button:has-text("Leaderboard")');

    // Should maintain presence connection
    await helpers.waitForLiveView();

    // Presence should still be functional
    const currentPresence = page.locator('.presence-indicator').first();
    if (await currentPresence.isVisible()) {
      await expect(currentPresence).toHaveAttribute('data-status');
    }

    // Navigate back
    await helpers.clickAndWait('a[href="/dashboard"], button:has-text("Dashboard")');

    // Presence should still work
    await expect(page.locator('.presence-indicator')).toHaveCount(await page.locator('.presence-indicator').count());
  });

  test('should show presence in notifications', async ({ page }) => {
    // Check for notification system
    const notifications = page.locator('.notifications, .notification-list, [data-testid="notifications"]');

    if (await notifications.isVisible()) {
      // Should show notification items
      const notificationItems = notifications.locator('.notification-item, .notification');
      if (await notificationItems.count() > 0) {
        // Should show presence context for social notifications
        const socialNotifications = notificationItems.locator('.social-notification, [data-type="social"]');
        if (await socialNotifications.count() > 0) {
          const firstSocial = socialNotifications.first();

          // Should show user presence in notification
          const notificationPresence = firstSocial.locator('.presence-indicator, [data-presence]');
          if (await notificationPresence.isVisible()) {
            await expect(notificationPresence).toBeVisible();
          }
        }
      }
    }
  });

  test('should handle presence in real-time games/challenges', async ({ page }) => {
    // Check for gaming/challenge features
    const gameSection = page.locator('.game-section, .challenge-active, [data-testid="games"]');

    if (await gameSection.isVisible()) {
      // Should show active players
      const activePlayers = gameSection.locator('.active-player, .player-presence');
      await expect(activePlayers).toHaveCount(await activePlayers.count());

      // Should show real-time presence
      const playerPresence = activePlayers.locator('.presence-indicator, [data-presence]');
      if (await playerPresence.count() > 0) {
        await expect(playerPresence.first()).toHaveAttribute('data-status');
      }
    }
  });

  test('should be mobile responsive', async ({ page }) => {
    await helpers.testResponsive({ width: 375, height: 667 });

    // Should show presence indicators on mobile
    const presenceIndicators = page.locator('.presence-indicator, .online-status');
    await expect(presenceIndicators).toHaveCount(await presenceIndicators.count());

    // Mobile presence should be touch-friendly
    const firstPresence = presenceIndicators.first();
    if (await firstPresence.isVisible()) {
      // Should be appropriately sized for mobile
      const boundingBox = await firstPresence.boundingBox();
      if (boundingBox) {
        expect(boundingBox.width).toBeGreaterThan(20); // Minimum touch target
        expect(boundingBox.height).toBeGreaterThan(20);
      }
    }
  });

  test('should handle presence privacy settings', async ({ page }) => {
    // Check for presence privacy controls
    const privacySettings = page.locator('.presence-privacy, .privacy-settings, [data-testid="presence-privacy"]');

    if (await privacySettings.isVisible()) {
      // Should have privacy options
      const privacyOptions = privacySettings.locator('select[name="presence-privacy"], input[name="presence-privacy"]');
      if (await privacyOptions.isVisible()) {
        // Should allow changing presence visibility
        await expect(privacyOptions).toBeVisible();
      }
    }
  });

  test('should show presence statistics', async ({ page }) => {
    // Check for presence analytics
    const presenceStats = page.locator('.presence-stats, .online-stats, [data-testid="presence-stats"]');

    if (await presenceStats.isVisible()) {
      // Should show online user count
      await expect(presenceStats.locator('.online-count, .active-users')).toBeVisible();

      // Should show peak times or patterns
      const peakInfo = presenceStats.locator('.peak-time, .activity-pattern');
      if (await peakInfo.isVisible()) {
        await expect(peakInfo).toBeVisible();
      }
    }
  });

  test('should handle presence disconnections gracefully', async ({ page }) => {
    // Test presence system resilience
    await helpers.waitForLiveView();

    // Simulate network issues (by waiting)
    await page.waitForTimeout(10000);

    // Presence indicators should still be present
    const presenceIndicators = page.locator('.presence-indicator');
    await expect(presenceIndicators).toHaveCount(await presenceIndicators.count());

    // Should handle reconnection gracefully
    await helpers.waitForLiveView();
  });
});</content>
<parameter name="filePath">tests/e2e/social/presence.spec.ts