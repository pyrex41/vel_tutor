import { test, expect } from '@playwright/test';

/**
 * Comprehensive Page Coverage Tests
 *
 * Tests for all working pages in the Vel Tutor application.
 * Authentication is handled automatically by DevAuthPlug in development.
 */

test.describe('Page Coverage - Core Learning Features', () => {
  test('should load homepage successfully', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/');
    await expect(page.locator('main h1').filter({ hasText: 'Vel Tutor' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Get Started' })).toBeVisible();
  });

  test('should load practice page successfully', async ({ page }) => {
    await page.goto('/practice');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/practice');
    await expect(page.locator('h1').filter({ hasText: 'Practice Session' })).toBeVisible();
    await expect(page.getByText('Subject: Math')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Submit Answer' })).toBeVisible();
  });

  test('should load badges page successfully', async ({ page }) => {
    await page.goto('/badges');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/badges');
    await expect(page.locator('h1').filter({ hasText: 'Badges & Achievements' })).toBeVisible();
    await expect(page.getByText('Completion Rate')).toBeVisible();
    await expect(page.getByRole('button', { name: 'All Badges' })).toBeVisible();
  });

  test('should load flashcards page successfully', async ({ page }) => {
    await page.goto('/flashcards');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/flashcards');
    await expect(page.locator('h1').filter({ hasText: 'Flashcard Study' })).toBeVisible();
    await expect(page.getByText('Select a deck or generate one with AI')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Generate AI Deck' })).toBeVisible();
  });

  test('should load diagnostic page successfully', async ({ page }) => {
    await page.goto('/diagnostic');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/diagnostic');
    await expect(page.locator('h1').filter({ hasText: 'Diagnostic Assessment' })).toBeVisible();
    await expect(page.getByText('Select Subject')).toBeVisible();
    await expect(page.getByRole('button', { name: 'M math' })).toBeVisible();
  });

  test('should load leaderboard page successfully', async ({ page }) => {
    await page.goto('/leaderboard');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/leaderboard');
    await expect(page.locator('h1').filter({ hasText: 'Leaderboard' })).toBeVisible();
    await expect(page.getByText('Compete with others and track your progress')).toBeVisible();
    await expect(page.getByRole('combobox').filter({ hasText: 'Global' })).toBeVisible();
  });
});

test.describe('Page Coverage - Social & Collaborative Features', () => {
  test('should load activity feed page successfully', async ({ page }) => {
    await page.goto('/activity');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/activity');
    await expect(page.locator('h1').filter({ hasText: 'Activity Feed' })).toBeVisible();
    await expect(page.getByText('No activities yet.')).toBeVisible();
  });

  test('should load rewards page successfully', async ({ page }) => {
    await page.goto('/rewards');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/rewards');
    await expect(page.locator('h1').filter({ hasText: 'Rewards Store' })).toBeVisible();
    await expect(page.getByText('Your XP Balance')).toBeVisible();
    await expect(page.getByRole('button', { name: 'All Rewards' })).toBeVisible();
  });

  test('should load study page successfully', async ({ page }) => {
    await page.goto('/study');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/study');
    await expect(page.locator('h1').filter({ hasText: 'Study Together' })).toBeVisible();
    await expect(page.getByText('Join or create collaborative study sessions')).toBeVisible();
    await expect(page.getByRole('link', { name: 'Create new study session' })).toBeVisible();
  });

  test('should load presence page successfully', async ({ page }) => {
    await page.goto('/presence');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/presence');
    await expect(page.getByText('Global Online Students')).toBeVisible();
  });

  test('should load transcripts page successfully', async ({ page }) => {
    await page.goto('/transcripts');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/transcripts');
    await expect(page.locator('h1').filter({ hasText: 'My Transcripts' })).toBeVisible();
    await expect(page.getByText('Review and manage your conversation transcripts')).toBeVisible();
  });

  test('should load progress reels page successfully', async ({ page }) => {
    await page.goto('/reels');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/reels');
    await expect(page.locator('h1').filter({ hasText: 'My Progress Reels' })).toBeVisible();
    await expect(page.getByText('Celebrate your achievements and milestones')).toBeVisible();
  });

  test('should load prep packs page successfully', async ({ page }) => {
    await page.goto('/prep-packs');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/prep-packs');
    await expect(page.locator('h1').filter({ hasText: 'My Prep Packs' })).toBeVisible();
    await expect(page.getByText('Access your personalized study materials')).toBeVisible();
  });
});

test.describe('Page Coverage - Dashboard & Analytics', () => {
  test('should load performance dashboard successfully', async ({ page }) => {
    await page.goto('/dashboard/performance');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/dashboard/performance');
    await expect(page.locator('h1').filter({ hasText: 'Provider Performance Dashboard' })).toBeVisible();
    await expect(page.getByText('Monitor AI provider performance metrics')).toBeVisible();
  });

  test('should load cost dashboard successfully', async ({ page }) => {
    await page.goto('/dashboard/costs');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveURL('/dashboard/costs');
    await expect(page.locator('h1').filter({ hasText: 'Cost Tracking & Budget Dashboard' })).toBeVisible();
    await expect(page.getByText('Monitor AI costs, track budget usage')).toBeVisible();
  });
});

test.describe('Page Coverage - Navigation & UX', () => {
  test('should navigate between pages using header links', async ({ page }) => {
    // Start at home
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveURL('/');

    // Navigate to practice via header link (use the header navigation link)
    await page.locator('header a[href="/practice"]').click();
    await expect(page).toHaveURL('/practice');

    // Navigate to leaderboard via header link
    await page.locator('header a[href="/leaderboard"]').click();
    await expect(page).toHaveURL('/leaderboard');

    // Navigate to badges via header link
    await page.locator('header a[href="/badges"]').click();
    await expect(page).toHaveURL('/badges');

    // Navigate back to home
    await page.locator('header a[href="/"]').first().click();
    await expect(page).toHaveURL('/');
  });

  test('should load all pages successfully', async ({ page }) => {
    const pages = [
      '/',
      '/practice',
      '/badges',
      '/flashcards',
      '/diagnostic',
      '/leaderboard',
      '/activity',
      '/rewards',
      '/study',
      '/presence',
      '/transcripts',
      '/reels',
      '/prep-packs',
      '/dashboard/performance',
      '/dashboard/costs'
    ];

    for (const pageUrl of pages) {
      await page.goto(pageUrl);
      await page.waitForLoadState('networkidle');
      await expect(page).toHaveURL(pageUrl);

      // Verify page has loaded by checking for body content
      const bodyText = await page.textContent('body');
      expect(bodyText?.length).toBeGreaterThan(0);
    }
  });

  test('should display consistent branding across all pages', async ({ page }) => {
    const pages = [
      '/',
      '/practice',
      '/badges',
      '/flashcards',
      '/diagnostic',
      '/leaderboard',
      '/activity',
      '/rewards',
      '/study',
      '/presence',
      '/transcripts',
      '/reels',
      '/prep-packs'
    ];

    for (const pageUrl of pages) {
      await page.goto(pageUrl);
      await page.waitForLoadState('networkidle');

      // Check for consistent branding elements
      await expect(page.getByRole('link', { name: 'Vel Tutor' })).toBeVisible();
      await expect(page.getByText('v0.1.0')).toBeVisible();

      // Check for navigation links in header
      await expect(page.locator('header a[href="/practice"]')).toBeVisible();
      await expect(page.locator('header a[href="/leaderboard"]')).toBeVisible();
      await expect(page.locator('header a[href="/badges"]')).toBeVisible();
    }
  });
});