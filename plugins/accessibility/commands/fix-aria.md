Fix incorrect or missing ARIA attributes for accessibility compliance.

Load the following expertise before starting:

- [UI Test Agent](../../../agents/ui-tester.md)

## Process

1. Analyze target HTML/JSX/Vue templates for common accessibility issues:
   - Missing alt text on images.
   - Missing labels for form inputs.
   - Incorrect usage of ARIA roles.
   - Poor color contrast ratios.
   - Missing or non-semantic focus states.
2. Apply fixes following WCAG 2.1 (AA or AAA) standards.
3. Add appropriate `aria-label`, `aria-describedby`, and roles.
4. Verify using automated accessibility tools (Axe, Lighthouse).

## Rules

- Prioritize native semantic HTML elements over ARIA roles where possible.
- Ensure all interactive elements are keyboard-navigable.
- Labels must be descriptive and distinct.
