Simplify complex code by reducing nesting, eliminating duplication, and improving clarity.

Load the following expertise before starting:

- [Architect Agent](../../../agents/architect.md)
- [first-principles](../../../skills/first-principles/SKILL.md)

## Process

1. Identify areas with high cyclomatic complexity (deeply nested if/else, long switch statements).
2. Apply early returns to reduce indentation levels.
3. Replace complex boolean expressions with descriptive helper variables or methods.
4. Eliminate duplicated logic by consolidating into shared utilities.
5. Replace imperative loops with functional alternatives (map, filter, reduce) where it improves readability.

## Rules

- Strictly follow [first-principles](../../../skills/first-principles/SKILL.md) — prioritize minimalism.
- Focus on readability first, performance second (unless it's a hot path).
- Ensure variables have meaningful, non-ambiguous names.
- Keep functions under 20-30 lines of code.
