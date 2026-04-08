Test application compatibility with screen readers.

Load the following expertise before starting:

- [UI Test Agent](../../../agents/ui-tester.md)

## Process

1. Explore the application UI using headless browser tools.
2. Simulate a screen reader's virtual cursor traversal.
3. Identify "dead zones" where focus is lost or elements are skipped.
4. Verify the reading order matches the visual order.
5. Check if dynamic content (modals, alerts) is announced via ARIA live regions.
6. Provide a report with compatibility scores and remediation suggestions.

## Rules

- Test against common patterns (Forms, Tables, Dialogs).
- Verify that every focusable element has a meaningful announcement.
- Check for "keyboard trapping" in modals.
