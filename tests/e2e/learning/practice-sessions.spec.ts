import { test, expect } from '@playwright/test';
import { TestHelpers, PageObjects, PerformanceMonitor } from '../utils/test-helpers';

/**
 * Practice Session User Journey Tests
 *
 * Tests the complete practice session experience including:
 * - Session initialization
 * - Question rendering and answering
 * - Real-time feedback
 * - Progress tracking
 * - Session completion
 * - Results display
 */

test.describe('Practice Session Experience', () => {
  let helpers: TestHelpers;
  let pageObjects: PageObjects;
  let perfMonitor: PerformanceMonitor;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    pageObjects = new PageObjects(page);
    perfMonitor = new PerformanceMonitor(page);

    // Navigate to practice page
    await helpers.gotoAndWait('/practice');
  });

  test('should load practice page successfully', async ({ page }) => {
    await helpers.assertPageLoaded('Practice Session', [
      'h1:has-text("Practice Session")',
      'text=Subject: Math'
    ]);

    await helpers.assertNoErrors();
    await helpers.assertPerformance();
  });

  test('should start practice session with subject selection', async ({ page }) => {
    // Select subject and grade
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');

    // Start session
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Should show first question
    await expect(page.locator('h2')).toContainText('Question 1');
    await expect(page.locator('input[type="radio"]')).toBeVisible();
    await expect(page.locator('.progress-bar')).toBeVisible();
  });

  test('should handle multiple choice questions correctly', async ({ page }) => {
    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Answer first question
    await page.locator('input[type="radio"]').first().check();
    await helpers.clickAndWait('button:has-text("Submit Answer")');

    // Should show feedback
    await expect(page.locator('.feedback')).toBeVisible();

    // Should advance to next question or show results
    const nextButton = page.locator('button:has-text("Next Question")');
    const finishButton = page.locator('button:has-text("Finish Session")');

    await expect(nextButton.or(finishButton)).toBeVisible();
  });

  test('should track progress throughout session', async ({ page }) => {
    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Check initial progress
    await expect(page.locator('.progress-text')).toContainText('1 / 10');

    // Answer questions and check progress updates
    for (let i = 0; i < 3; i++) {
      await page.locator('input[type="radio"]').first().check();
      await helpers.clickAndWait('button:has-text("Submit Answer")');

      if (i < 2) {
        await helpers.clickAndWait('button:has-text("Next Question")');
        await expect(page.locator('.progress-text')).toContainText(`${i + 2} / 10`);
      }
    }
  });

  test('should handle timer functionality', async ({ page }) => {
    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Check timer is displayed
    await expect(page.locator('.timer')).toBeVisible();

    // Timer should count down
    const initialTime = await page.locator('.timer').textContent();
    expect(initialTime).toMatch(/\d+:\d+/); // MM:SS format

    // Wait a few seconds and check timer updates
    await page.waitForTimeout(3000);
    const updatedTime = await page.locator('.timer').textContent();
    expect(updatedTime).not.toBe(initialTime);
  });

  test('should handle pause and resume functionality', async ({ page }) => {
    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Pause session
    await helpers.clickAndWait('button:has-text("Pause")');

    // Should show pause overlay
    await expect(page.locator('.pause-overlay')).toBeVisible();

    // Timer should be paused
    const pausedTime = await page.locator('.timer').textContent();
    await page.waitForTimeout(2000);
    const stillPausedTime = await page.locator('.timer').textContent();
    expect(stillPausedTime).toBe(pausedTime);

    // Resume session
    await helpers.clickAndWait('button:has-text("Resume")');

    // Pause overlay should be hidden
    await expect(page.locator('.pause-overlay')).toBeHidden();

    // Timer should resume
    await page.waitForTimeout(2000);
    const resumedTime = await page.locator('.timer').textContent();
    expect(resumedTime).not.toBe(pausedTime);
  });

  test('should complete session and show results', async ({ page }) => {
    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Answer all questions quickly (for testing)
    for (let i = 0; i < 10; i++) {
      await page.locator('input[type="radio"]').first().check();
      await helpers.clickAndWait('button:has-text("Submit Answer")');

      if (i < 9) {
        await helpers.clickAndWait('button:has-text("Next Question")');
      }
    }

    // Should show completion screen
    await expect(page.locator('h2')).toContainText('Session Complete');
    await expect(page.locator('.score-display')).toBeVisible();
    await expect(page.locator('.time-spent')).toBeVisible();
  });

  test('should handle session interruption gracefully', async ({ page }) => {
    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Answer a few questions
    for (let i = 0; i < 3; i++) {
      await page.locator('input[type="radio"]').first().check();
      await helpers.clickAndWait('button:has-text("Submit Answer")');
      await helpers.clickAndWait('button:has-text("Next Question")');
    }

    // Refresh page (simulate interruption)
    await page.reload();
    await page.waitForLoadState('networkidle');

    // Should return to practice page (not crash)
    await expect(page.locator('h1')).toContainText('Practice Session');
  });

  test('should be mobile responsive', async ({ page }) => {
    await helpers.testResponsive({ width: 375, height: 667 });

    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Check mobile layout
    await expect(page.locator('.question-container')).toBeVisible();
    await expect(page.locator('input[type="radio"]')).toBeVisible();

    // Touch interactions should work
    await page.locator('input[type="radio"]').first().check();
    await helpers.clickAndWait('button:has-text("Submit Answer")');
  });

  test('should handle network interruptions', async ({ page }) => {
    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Simulate offline
    await page.context().setOffline(true);

    // Try to submit answer
    await page.locator('input[type="radio"]').first().check();
    await page.click('button:has-text("Submit Answer")');

    // Should handle gracefully (show error or retry)
    await page.waitForTimeout(2000);

    // Reconnect
    await page.context().setOffline(false);

    // Should recover
    await helpers.waitForLiveView();
    await expect(page.locator('.question-container')).toBeVisible();
  });

  test('should validate answer submission', async ({ page }) => {
    // Start session
    await page.locator('select[name="subject"]').selectOption('Math');
    await page.locator('select[name="grade"]').selectOption('9');
    await helpers.clickAndWait('button:has-text("Start Practice")');

    // Try to submit without selecting answer
    await helpers.clickAndWait('button:has-text("Submit Answer")');

    // Should show validation error
    await expect(page.locator('.error-message')).toContainText('Please select an answer');

    // Select answer and submit
    await page.locator('input[type="radio"]').first().check();
    await helpers.clickAndWait('button:has-text("Submit Answer")');

    // Should proceed without error
    await expect(page.locator('.feedback')).toBeVisible();
  });
});</content>
<parameter name="filePath">tests/e2e/learning/practice-sessions.spec.ts