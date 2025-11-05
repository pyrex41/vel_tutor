# Vel Tutor E2E Test Suite

End-to-end tests for Vel Tutor using Playwright.

## Setup

1. Install dependencies:
   ```bash
   pnpm install
   ```

2. Install Playwright browsers:
   ```bash
   pnpm dlx playwright@latest install
   ```

## Running Tests

### Local Development
```bash
# Run all tests headlessly
pnpm test:e2e

# Run tests with browser UI (for debugging)
pnpm test:e2e:ui

# Debug specific test
pnpm test:e2e:debug

# View test report
pnpm test:e2e:report
```

### Prerequisites
- Phoenix server running on `http://localhost:4000`
- Test database seeded (automatic via global setup)

## Test Structure

- `tests/e2e/auth.spec.ts` - Authentication flows
- `tests/e2e/dashboard.spec.ts` - Dashboard and navigation
- `tests/e2e/interactions.spec.ts` - UI interactions and forms
- `tests/e2e/global-setup.ts` - Test data seeding

## Configuration

- `playwright.config.ts` - Test configuration
- Uses Chrome browser with 1280x720 viewport
- Automatic server startup and test data seeding
- Parallel execution with 3 workers

## Data Test IDs

Tests expect the following data attributes on elements:
- `data-testid="email-input"`
- `data-testid="password-input"`
- `data-testid="login-button"`
- `data-testid="error-message"`
- `data-testid="user-menu"`
- `data-testid="logout-button"`
- `data-testid="dashboard-header"`
- `data-testid="activity-feed"`
- `data-testid="activity-item"`
- `data-testid="profile-link"`
- `data-testid="profile-form"`
- `data-testid="name-input"`
- `data-testid="save-profile-button"`
- `data-testid="success-toast"`
- `data-testid="create-challenge-button"`
- `data-testid="challenge-modal"`
- `data-testid="modal-close-button"`
- `data-testid="challenge-title-input"`
- `data-testid="challenge-description-input"`
- `data-testid="submit-challenge-button"`
- `data-testid="title-error"`
- `data-testid="error-toast"`

## CI Integration

For GitHub Actions, add:

```yaml
- name: Install Playwright
  run: pnpm dlx playwright@latest install --with-deps
- name: Run E2E tests
  run: pnpm test:e2e
```

## Troubleshooting

1. **Server not starting**: Ensure Phoenix is not already running on port 4000
2. **Database errors**: Check test database configuration in `config/test.exs`
3. **Element not found**: Add `data-testid` attributes to HTML elements
4. **Flaky tests**: Increase timeouts or add explicit waits