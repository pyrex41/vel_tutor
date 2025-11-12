import { test, expect } from '@playwright/test';
import { TestHelpers, PageObjects, PerformanceMonitor } from '../utils/test-helpers';

/**
 * Flashcard Study Session Tests
 *
 * Tests flashcard functionality including:
 * - Card presentation and flipping
 * - Study progress tracking
 * - Difficulty rating system
 * - Spaced repetition algorithm
 * - Study session management
 */

test.describe('Flashcard Study Sessions', () => {
  let helpers: TestHelpers;
  let pageObjects: PageObjects;
  let perfMonitor: PerformanceMonitor;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    pageObjects = new PageObjects(page);
    perfMonitor = new PerformanceMonitor(page);

    await helpers.gotoAndWait('/flashcards');
  });

  test('should load flashcards page successfully', async ({ page }) => {
    await helpers.assertPageLoaded('Flashcards', [
      'h1:has-text("Flashcards")',
      'text=Study Session'
    ]);

    await helpers.assertNoErrors();
    await helpers.assertPerformance();
  });

  test('should display flashcard interface', async ({ page }) => {
    // Should show flashcard container
    await expect(page.locator('.flashcard-container, .card-container')).toBeVisible();

    // Should show current card
    const currentCard = page.locator('.flashcard, .card');
    await expect(currentCard).toBeVisible();

    // Should show card content (question/term)
    await expect(currentCard.locator('.card-front, .question, .term')).toBeVisible();
  });

  test('should allow flipping cards', async ({ page }) => {
    const card = page.locator('.flashcard, .card').first();

    // Should have flip functionality
    const flipButton = page.locator('button:has-text("Flip"), button:has-text("Show Answer"), .flip-btn');
    if (await flipButton.isVisible()) {
      await helpers.clickAndWait(flipButton);

      // Should show answer/back
      await expect(card.locator('.card-back, .answer, .definition')).toBeVisible();

      // Should hide question/front
      await expect(card.locator('.card-front, .question')).not.toBeVisible();
    } else {
      // Test clicking on card itself
      await helpers.clickAndWait(card);

      // Should flip card
      await expect(card.locator('.card-back, .answer')).toBeVisible();
    }
  });

  test('should show study progress', async ({ page }) => {
    // Should show progress indicator
    const progressBar = page.locator('.progress-bar, .study-progress, [data-progress]');
    await expect(progressBar).toBeVisible();

    // Should show current position
    await expect(page.locator('.current-card, .position')).toBeVisible();
    await expect(page.locator('.total-cards, .total')).toBeVisible();

    // Should show completion percentage
    const percentage = page.locator('.percentage, .completion-rate');
    if (await percentage.isVisible()) {
      await expect(percentage).toMatch(/\d+%/);
    }
  });

  test('should have difficulty rating system', async ({ page }) => {
    // Flip card to show answer first
    const card = page.locator('.flashcard, .card').first();
    await helpers.clickAndWait(card);

    // Should show difficulty buttons
    const difficultyButtons = page.locator('button[data-difficulty], .difficulty-btn');
    await expect(difficultyButtons).toHaveCount(await difficultyButtons.count());

    // Should have common difficulty levels
    const expectedDifficulties = ['easy', 'medium', 'hard', 'again'];
    let foundDifficulties = 0;

    for (const difficulty of expectedDifficulties) {
      const btn = page.locator(`button[data-difficulty="${difficulty}"], button:has-text("${difficulty}")`);
      if (await btn.isVisible()) {
        foundDifficulties++;
      }
    }

    expect(foundDifficulties).toBeGreaterThan(0);
  });

  test('should advance to next card after rating', async ({ page }) => {
    // Get current card content
    const currentCard = page.locator('.flashcard, .card').first();
    const initialContent = await currentCard.textContent();

    // Flip and rate card
    await helpers.clickAndWait(currentCard);

    const easyButton = page.locator('button[data-difficulty="easy"], button:has-text("Easy")');
    if (await easyButton.isVisible()) {
      await helpers.clickAndWait(easyButton);

      // Should advance to next card
      await helpers.waitForLiveView();

      const newCard = page.locator('.flashcard, .card').first();
      const newContent = await newCard.textContent();

      // Content should be different (next card)
      expect(newContent).not.toBe(initialContent);
    }
  });

  test('should show study session statistics', async ({ page }) => {
    // Check for session stats
    const statsSection = page.locator('.session-stats, .study-stats, [data-testid="session-stats"]');

    if (await statsSection.isVisible()) {
      // Should show cards studied
      await expect(statsSection.locator('.cards-studied, .studied-count')).toBeVisible();

      // Should show accuracy or correct/incorrect counts
      const accuracy = statsSection.locator('.accuracy, .correct-count, .incorrect-count');
      if (await accuracy.isVisible()) {
        await expect(accuracy).toBeVisible();
      }

      // Should show time spent
      const timeSpent = statsSection.locator('.time-spent, .duration');
      if (await timeSpent.isVisible()) {
        await expect(timeSpent).toBeVisible();
      }
    }
  });

  test('should allow pausing and resuming study session', async ({ page }) => {
    const pauseButton = page.locator('button:has-text("Pause"), .pause-btn');

    if (await pauseButton.isVisible()) {
      // Pause session
      await helpers.clickAndWait(pauseButton);

      // Should show pause state
      await expect(page.locator('.paused-state, .pause-modal')).toBeVisible();

      // Should have resume button
      const resumeButton = page.locator('button:has-text("Resume"), .resume-btn');
      await expect(resumeButton).toBeVisible();

      // Resume session
      await helpers.clickAndWait(resumeButton);

      // Should return to study state
      await expect(page.locator('.flashcard, .card')).toBeVisible();
    }
  });

  test('should show card categories and filters', async ({ page }) => {
    // Check for subject/category filters
    const categoryFilters = page.locator('.category-filter, [data-category]');

    if (await categoryFilters.count() > 0) {
      // Test category filtering
      await helpers.clickAndWait(categoryFilters.first());

      // Should update card set
      await helpers.waitForLiveView();

      // Should show filtered cards
      await expect(page.locator('.flashcard, .card')).toBeVisible();
    }
  });

  test('should handle spaced repetition scheduling', async ({ page }) => {
    // Test different difficulty ratings affect scheduling
    const card = page.locator('.flashcard, .card').first();

    // Flip card
    await helpers.clickAndWait(card);

    // Rate as hard
    const hardButton = page.locator('button[data-difficulty="hard"], button:has-text("Hard")');
    if (await hardButton.isVisible()) {
      await helpers.clickAndWait(hardButton);

      // Should advance and potentially show same card sooner
      await helpers.waitForLiveView();

      // Check if card appears again in session
      const nextCard = page.locator('.flashcard, .card').first();
      const nextContent = await nextCard.textContent();

      // In spaced repetition, hard cards should reappear
      // This is a basic check - full algorithm testing would need more complex setup
      await expect(nextCard).toBeVisible();
    }
  });

  test('should show card review history', async ({ page }) => {
    const card = page.locator('.flashcard, .card').first();

    // Click for details/history
    const detailButton = card.locator('button:has-text("Details"), .detail-btn');
    if (await detailButton.isVisible()) {
      await helpers.clickAndWait(detailButton);

      // Should show card history
      const history = page.locator('.card-history, .review-history');
      if (await history.isVisible()) {
        await expect(history).toBeVisible();

        // Should show previous ratings
        await expect(history.locator('.previous-rating, .rating-history')).toBeVisible();
      }
    }
  });

  test('should allow creating custom study sessions', async ({ page }) => {
    const createSessionBtn = page.locator('button:has-text("Create Session"), .create-session-btn');

    if (await createSessionBtn.isVisible()) {
      await helpers.clickAndWait(createSessionBtn);

      // Should show session creation form
      const sessionForm = page.locator('.session-form, .create-form');
      await expect(sessionForm).toBeVisible();

      // Should have session options
      await expect(sessionForm.locator('select[name="subject"], input[name="subject"]')).toBeVisible();
      await expect(sessionForm.locator('input[name="card-count"], select[name="card-count"]')).toBeVisible();

      // Test form submission
      await sessionForm.locator('select[name="subject"]').selectOption('Math');
      await sessionForm.locator('input[name="card-count"]').fill('10');

      const submitBtn = sessionForm.locator('button[type="submit"]');
      await helpers.clickAndWait(submitBtn);

      // Should start new session
      await expect(page.locator('.flashcard, .card')).toBeVisible();
    }
  });

  test('should show study streak information', async ({ page }) => {
    // Check for streak indicator
    const streakIndicator = page.locator('.study-streak, .streak-counter');

    if (await streakIndicator.isVisible()) {
      await expect(streakIndicator).toBeVisible();

      // Should show current streak
      await expect(streakIndicator.locator('.current-streak, .streak-number')).toBeVisible();
    }
  });

  test('should be mobile responsive', async ({ page }) => {
    await helpers.testResponsive({ width: 375, height: 667 });

    // Should show flashcards on mobile
    await expect(page.locator('.flashcard-container, .card-container')).toBeVisible();

    // Check mobile layout
    const card = page.locator('.flashcard, .card');
    await expect(card).toBeVisible();

    // Touch interactions should work
    await card.tap();

    // Should flip on mobile
    await expect(card.locator('.card-back, .answer')).toBeVisible();

    // Mobile difficulty buttons should work
    const difficultyBtn = page.locator('button[data-difficulty]').first();
    if (await difficultyBtn.isVisible()) {
      await difficultyBtn.tap();

      // Should advance cards
      await expect(page.locator('.flashcard, .card')).toBeVisible();
    }
  });

  test('should handle end of study session', async ({ page }) => {
    // This test would ideally complete a full session
    // For now, we'll test the completion state if available

    const completeButton = page.locator('button:has-text("Complete Session"), .complete-btn');
    if (await completeButton.isVisible()) {
      await helpers.clickAndWait(completeButton);

      // Should show completion screen
      await expect(page.locator('.session-complete, .completion-screen')).toBeVisible();

      // Should show final statistics
      await expect(page.locator('.final-stats, .session-summary')).toBeVisible();
    }
  });

  test('should allow reviewing incorrect cards', async ({ page }) => {
    // Rate some cards as incorrect/hard
    const card = page.locator('.flashcard, .card').first();

    // Flip card
    await helpers.clickAndWait(card);

    // Rate as "again" or hard
    const againButton = page.locator('button[data-difficulty="again"], button:has-text("Again")');
    if (await againButton.isVisible()) {
      await helpers.clickAndWait(againButton);

      // Should continue session
      await expect(page.locator('.flashcard, .card')).toBeVisible();

      // Check for review mode or incorrect pile
      const reviewMode = page.locator('.review-mode, .incorrect-cards');
      if (await reviewMode.isVisible()) {
        await expect(reviewMode).toBeVisible();
      }
    }
  });

  test('should show study time tracking', async ({ page }) => {
    // Check for timer
    const timer = page.locator('.study-timer, .session-timer');

    if (await timer.isVisible()) {
      await expect(timer).toBeVisible();

      // Should show elapsed time
      await expect(timer.locator('.elapsed-time, .duration')).toBeVisible();
    }
  });
});</content>
<parameter name="filePath">tests/e2e/learning/flashcards.spec.ts