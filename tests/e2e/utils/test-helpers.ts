import { Page, expect } from '@playwright/test';

/**
 * Enhanced test utilities for Vel Tutor E2E tests
 * Provides common actions, assertions, and data helpers
 */

export class TestHelpers {
  constructor(private page: Page) {}

  /**
   * Navigate to a page and wait for it to be fully loaded
   */
  async gotoAndWait(url: string) {
    await this.page.goto(url);
    await this.page.waitForLoadState('networkidle');
  }

  /**
   * Wait for LiveView to be ready (no pending updates)
   */
  async waitForLiveView() {
    await this.page.waitForFunction(() => {
      // Check if LiveView is connected and no pending updates
      return !document.querySelector('[data-phx-loading]');
    });
  }

  /**
   * Fill form field with validation
   */
  async fillFormField(selector: string, value: string) {
    await this.page.fill(selector, value);
    await expect(this.page.locator(selector)).toHaveValue(value);
  }

  /**
   * Click button and wait for navigation or LiveView update
   */
  async clickAndWait(selector: string, options?: { waitFor?: 'navigation' | 'liveview' }) {
    const waitFor = options?.waitFor || 'liveview';

    if (waitFor === 'navigation') {
      await Promise.all([
        this.page.waitForLoadState('networkidle'),
        this.page.click(selector)
      ]);
    } else {
      await this.page.click(selector);
      await this.waitForLiveView();
    }
  }

  /**
   * Assert page title and content
   */
  async assertPageLoaded(title: string, contentSelectors: string[] = []) {
    await expect(this.page).toHaveTitle(/Vel Tutor/);
    if (title) {
      await expect(this.page.locator('h1').first()).toContainText(title);
    }
    for (const selector of contentSelectors) {
      await expect(this.page.locator(selector)).toBeVisible();
    }
  }

  /**
   * Handle common error states
   */
  async assertNoErrors() {
    // Check for console errors
    const errors: string[] = [];
    this.page.on('pageerror', error => errors.push(error.message));

    // Check for visible error messages
    const errorElements = this.page.locator('[data-testid="error-message"], .error, .alert-error');
    await expect(errorElements).toHaveCount(0);

    expect(errors.length).toBe(0);
  }

  /**
   * Test responsive behavior
   */
  async testResponsive(viewport: { width: number; height: number }) {
    await this.page.setViewportSize(viewport);
    // Basic responsive checks
    await expect(this.page.locator('body')).toBeVisible();
  }

  /**
   * Performance assertions
   */
  async assertPerformance(maxLoadTime: number = 3000) {
    const navigationTiming = await this.page.evaluate(() => {
      const timing = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      return {
        loadTime: timing.loadEventEnd - timing.fetchStart,
        domContentLoaded: timing.domContentLoadedEventEnd - timing.fetchStart
      };
    });

    expect(navigationTiming.loadTime).toBeLessThan(maxLoadTime);
    expect(navigationTiming.domContentLoaded).toBeLessThan(2000);
  }

  /**
   * Accessibility basic checks
   */
  async assertBasicAccessibility() {
    // Check for alt text on images
    const imagesWithoutAlt = await this.page.locator('img:not([alt])');
    await expect(imagesWithoutAlt).toHaveCount(0);

    // Check for form labels
    const inputsWithoutLabels = await this.page.locator('input:not([aria-label]):not([aria-labelledby])');
    // Allow some flexibility for complex forms
    await expect(inputsWithoutLabels).toHaveCount(0);

    // Check for heading hierarchy
    const h1Elements = await this.page.locator('h1').count();
    expect(h1Elements).toBeGreaterThan(0);
  }
}

/**
 * Test data factory for creating test scenarios
 */
export class TestDataFactory {
  static generateUserData(overrides: Partial<any> = {}) {
    return {
      email: `test-${Date.now()}@example.com`,
      name: 'Test User',
      sessionToken: `token_${Date.now()}`,
      ...overrides
    };
  }

  static generatePracticeSessionData(overrides: Partial<any> = {}) {
    return {
      subject: 'Math',
      grade: '9',
      questionCount: 10,
      timeLimit: 30,
      ...overrides
    };
  }

  static generateDiagnosticData(overrides: Partial<any> = {}) {
    return {
      subject: 'Science',
      grade: '10',
      questions: [
        { type: 'multiple_choice', difficulty: 1 },
        { type: 'true_false', difficulty: 2 },
        { type: 'open_ended', difficulty: 3 }
      ],
      ...overrides
    };
  }
}

/**
 * Page object for common UI elements
 */
export class PageObjects {
  constructor(private page: Page) {}

  // Navigation
  get header() { return this.page.locator('header'); }
  get navLinks() { return this.page.locator('header a'); }
  get userMenu() { return this.page.locator('[data-testid="user-menu"]'); }

  // Common buttons
  get submitButton() { return this.page.locator('button[type="submit"]'); }
  get cancelButton() { return this.page.locator('button').filter({ hasText: 'Cancel' }); }

  // Loading states
  get loadingSpinner() { return this.page.locator('[data-phx-loading]'); }

  // Error states
  get errorMessage() { return this.page.locator('[data-testid="error-message"]'); }
  get successMessage() { return this.page.locator('[data-testid="success-message"]'); }

  // Modal helpers
  async closeModal() {
    await this.page.locator('[data-testid="modal-close-button"]').click();
  }

  async confirmDialog() {
    await this.page.locator('button').filter({ hasText: 'Confirm' }).click();
  }
}

/**
 * Performance monitoring utilities
 */
export class PerformanceMonitor {
  constructor(private page: Page) {}

  async measureAction(action: () => Promise<void>, label: string) {
    const startTime = Date.now();
    await action();
    const endTime = Date.now();
    const duration = endTime - startTime;

    console.log(`${label} took ${duration}ms`);
    expect(duration).toBeLessThan(1000); // 1 second max for actions

    return duration;
  }

  async measurePageLoad(url: string) {
    const startTime = Date.now();
    await this.page.goto(url);
    await this.page.waitForLoadState('networkidle');
    const endTime = Date.now();

    return endTime - startTime;
  }
}</content>
<parameter name="filePath">tests/e2e/utils/test-helpers.ts