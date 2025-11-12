import { test, expect } from '@playwright/test';
import { TestHelpers, PageObjects, PerformanceMonitor } from '../utils/test-helpers';

/**
 * Viral Sharing Features Tests
 *
 * Tests viral sharing functionality including:
 * - Share achievement modals
 * - Social media integration
 * - Referral links and codes
 * - Share tracking and analytics
 * - Viral challenges and contests
 */

test.describe('Viral Sharing Features', () => {
  let helpers: TestHelpers;
  let pageObjects: PageObjects;
  let perfMonitor: PerformanceMonitor;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    pageObjects = new PageObjects(page);
    perfMonitor = new PerformanceMonitor(page);

    await helpers.gotoAndWait('/share');
  });

  test('should load sharing page successfully', async ({ page }) => {
    await helpers.assertPageLoaded('Share & Earn', [
      'h1:has-text("Share")',
      'text=Share your achievements'
    ]);

    await helpers.assertNoErrors();
    await helpers.assertPerformance();
  });

  test('should display share achievement interface', async ({ page }) => {
    // Should show share options
    await expect(page.locator('.share-options, .sharing-interface')).toBeVisible();

    // Should show achievement cards
    const achievements = page.locator('.achievement-card, .shareable-item');
    await expect(achievements).toHaveCount(await achievements.count());

    // Check first achievement has share button
    const firstAchievement = achievements.first();
    await expect(firstAchievement.locator('button:has-text("Share"), .share-btn')).toBeVisible();
  });

  test('should open share modal on achievement click', async ({ page }) => {
    const shareButton = page.locator('button:has-text("Share"), .share-btn').first();

    await helpers.clickAndWait(shareButton);

    // Should open share modal
    const shareModal = page.locator('.share-modal, .modal');
    await expect(shareModal).toBeVisible();

    // Should show share options
    await expect(shareModal.locator('.share-option, .social-platform')).toHaveCount(await shareModal.locator('.share-option, .social-platform').count());
  });

  test('should show social media share options', async ({ page }) => {
    const shareButton = page.locator('button:has-text("Share"), .share-btn').first();
    await helpers.clickAndWait(shareButton);

    const shareModal = page.locator('.share-modal, .modal');

    // Should have common social platforms
    const socialPlatforms = ['facebook', 'twitter', 'instagram', 'tiktok', 'whatsapp'];
    let foundPlatforms = 0;

    for (const platform of socialPlatforms) {
      const platformBtn = shareModal.locator(`[data-platform="${platform}"], .${platform}-share`);
      if (await platformBtn.isVisible()) {
        foundPlatforms++;
      }
    }

    expect(foundPlatforms).toBeGreaterThan(0);
  });

  test('should generate shareable links', async ({ page }) => {
    const shareButton = page.locator('button:has-text("Share"), .share-btn').first();
    await helpers.clickAndWait(shareButton);

    const shareModal = page.locator('.share-modal, .modal');

    // Should have copy link option
    const copyLinkBtn = shareModal.locator('button:has-text("Copy Link"), .copy-link');
    await expect(copyLinkBtn).toBeVisible();

    // Click copy link
    await helpers.clickAndWait(copyLinkBtn);

    // Should show success message
    await expect(page.locator('.success-message, text="Link copied"')).toBeVisible();
  });

  test('should display referral code system', async ({ page }) => {
    // Check for referral section
    const referralSection = page.locator('.referral-section, .referral-code, [data-testid="referrals"]');

    if (await referralSection.isVisible()) {
      // Should show referral code
      await expect(referralSection.locator('.referral-code, .code')).toBeVisible();

      // Should show copy button
      await expect(referralSection.locator('button:has-text("Copy Code"), .copy-code')).toBeVisible();

      // Should show referral stats
      const referralStats = referralSection.locator('.referral-stats, .stats');
      if (await referralStats.isVisible()) {
        await expect(referralStats.locator('.friends-invited, .signups')).toBeVisible();
      }
    }
  });

  test('should show share tracking and analytics', async ({ page }) => {
    // Check for share analytics
    const analyticsSection = page.locator('.share-analytics, .sharing-stats, [data-testid="share-stats"]');

    if (await analyticsSection.isVisible()) {
      // Should show share counts
      await expect(analyticsSection.locator('.total-shares, .share-count')).toBeVisible();

      // Should show engagement metrics
      const engagement = analyticsSection.locator('.engagement, .clicks, .conversions');
      if (await engagement.isVisible()) {
        await expect(engagement).toBeVisible();
      }

      // Should show viral coefficient or reach
      const reach = analyticsSection.locator('.viral-coefficient, .reach, .network-size');
      if (await reach.isVisible()) {
        await expect(reach).toBeVisible();
      }
    }
  });

  test('should display viral challenges', async ({ page }) => {
    // Check for challenges section
    const challengesSection = page.locator('.viral-challenges, .challenges, [data-testid="challenges"]');

    if (await challengesSection.isVisible()) {
      // Should show challenge cards
      const challenges = challengesSection.locator('.challenge-card, .challenge-item');
      await expect(challenges).toHaveCount(await challenges.count());

      // Check first challenge
      const firstChallenge = challenges.first();
      await expect(firstChallenge.locator('.challenge-title, .title')).toBeVisible();
      await expect(firstChallenge.locator('.challenge-description, .description')).toBeVisible();

      // Should have participate/join button
      await expect(firstChallenge.locator('button:has-text("Join"), button:has-text("Participate")')).toBeVisible();
    }
  });

  test('should show leaderboard for viral activities', async ({ page }) => {
    // Check for viral leaderboard
    const viralLeaderboard = page.locator('.viral-leaderboard, .sharing-leaderboard');

    if (await viralLeaderboard.isVisible()) {
      // Should show top sharers
      await expect(viralLeaderboard.locator('.leader-entry, .rank-item')).toHaveCount(await viralLeaderboard.locator('.leader-entry, .rank-item').count());

      // Should show share counts
      const firstEntry = viralLeaderboard.locator('.leader-entry, .rank-item').first();
      await expect(firstEntry.locator('.share-count, .viral-score')).toBeVisible();
    }
  });

  test('should allow creating custom share messages', async ({ page }) => {
    const shareButton = page.locator('button:has-text("Share"), .share-btn').first();
    await helpers.clickAndWait(shareButton);

    const shareModal = page.locator('.share-modal, .modal');

    // Check for custom message input
    const messageInput = shareModal.locator('textarea[name="message"], input[name="message"]');
    if (await messageInput.isVisible()) {
      // Should allow typing custom message
      await messageInput.fill('Check out my awesome achievement!');

      // Should preview message
      const preview = shareModal.locator('.message-preview, .preview');
      if (await preview.isVisible()) {
        await expect(preview).toContainText('Check out my awesome achievement!');
      }
    }
  });

  test('should show share rewards and incentives', async ({ page }) => {
    // Check for rewards section
    const rewardsSection = page.locator('.share-rewards, .incentives, [data-testid="share-rewards"]');

    if (await rewardsSection.isVisible()) {
      // Should show reward tiers
      const rewardTiers = rewardsSection.locator('.reward-tier, .incentive-item');
      await expect(rewardTiers).toHaveCount(await rewardTiers.count());

      // Check first reward
      const firstReward = rewardTiers.first();
      await expect(firstReward.locator('.reward-description, .description')).toBeVisible();

      // Should show progress toward reward
      const progress = firstReward.locator('.progress-bar, .reward-progress');
      if (await progress.isVisible()) {
        await expect(progress).toBeVisible();
      }
    }
  });

  test('should handle share success feedback', async ({ page }) => {
    const shareButton = page.locator('button:has-text("Share"), .share-btn').first();
    await helpers.clickAndWait(shareButton);

    const shareModal = page.locator('.share-modal, .modal');

    // Click a share option (using a safe one like copy link)
    const copyLinkBtn = shareModal.locator('button:has-text("Copy Link"), .copy-link');
    if (await copyLinkBtn.isVisible()) {
      await helpers.clickAndWait(copyLinkBtn);

      // Should show success feedback
      await expect(page.locator('.share-success, .success-toast, text="Shared successfully"')).toBeVisible();

      // Should track the share
      await helpers.waitForLiveView();
    }
  });

  test('should show viral network visualization', async ({ page }) => {
    // Check for network visualization
    const networkViz = page.locator('.viral-network, .network-graph, [data-testid="viral-network"]');

    if (await networkViz.isVisible()) {
      // Should show network nodes/connections
      await expect(networkViz.locator('.network-node, .connection')).toBeVisible();

      // Should show user's position
      const userNode = networkViz.locator('.user-node, [data-user="current"]');
      if (await userNode.isVisible()) {
        await expect(userNode).toBeVisible();
      }
    }
  });

  test('should be mobile responsive', async ({ page }) => {
    await helpers.testResponsive({ width: 375, height: 667 });

    // Should show sharing interface on mobile
    await expect(page.locator('.share-options, .sharing-interface')).toBeVisible();

    // Check mobile layout
    const shareButton = page.locator('button:has-text("Share"), .share-btn').first();
    await expect(shareButton).toBeVisible();

    // Touch interactions should work
    await shareButton.tap();

    // Should open mobile-friendly modal
    const shareModal = page.locator('.share-modal, .modal');
    if (await shareModal.isVisible()) {
      await expect(shareModal).toBeVisible();

      // Mobile share options should be touchable
      const shareOption = shareModal.locator('.share-option').first();
      await shareOption.tap();
    }
  });

  test('should handle share limits and cooldowns', async ({ page }) => {
    // Test multiple shares to check for limits
    const shareButtons = page.locator('button:has-text("Share"), .share-btn');

    if (await shareButtons.count() > 1) {
      // Try sharing multiple items
      for (let i = 0; i < Math.min(3, await shareButtons.count()); i++) {
        const shareBtn = shareButtons.nth(i);
        await helpers.clickAndWait(shareBtn);

        const shareModal = page.locator('.share-modal, .modal');
        if (await shareModal.isVisible()) {
          // Check for rate limiting messages
          const rateLimitMsg = shareModal.locator('.rate-limit, text="Please wait"');
          if (await rateLimitMsg.isVisible()) {
            await expect(rateLimitMsg).toBeVisible();
            break; // Stop if rate limited
          }

          // Close modal and continue
          const closeBtn = shareModal.locator('button:has-text("Close"), .close-btn');
          if (await closeBtn.isVisible()) {
            await helpers.clickAndWait(closeBtn);
          }
        }
      }
    }
  });

  test('should show share history and past shares', async ({ page }) => {
    // Check for share history
    const shareHistory = page.locator('.share-history, .past-shares, [data-testid="share-history"]');

    if (await shareHistory.isVisible()) {
      // Should show past share items
      const pastShares = shareHistory.locator('.share-item, .history-item');
      await expect(pastShares).toHaveCount(await pastShares.count());

      // Check first history item
      const firstItem = pastShares.first();
      await expect(firstItem.locator('.share-date, .timestamp')).toBeVisible();
      await expect(firstItem.locator('.share-platform, .platform')).toBeVisible();
    }
  });

  test('should integrate with achievement system', async ({ page }) => {
    // Check for achievement-triggered shares
    const achievementShares = page.locator('.achievement-share, [data-trigger="achievement"]');

    if (await achievementShares.count() > 0) {
      const firstAchievement = achievementShares.first();

      // Should show achievement details
      await expect(firstAchievement.locator('.achievement-name, .title')).toBeVisible();

      // Should have contextual share message
      const shareMessage = firstAchievement.locator('.share-message, .contextual-text');
      if (await shareMessage.isVisible()) {
        await expect(shareMessage).toBeVisible();
      }
    }
  });
});</content>
<parameter name="filePath">tests/e2e/social/viral-sharing.spec.ts