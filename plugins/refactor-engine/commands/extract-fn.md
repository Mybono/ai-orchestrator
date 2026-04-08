Extract a block of code into a well-named, reusable function with proper typing.

Load the following expertise before starting:

- [Architect Agent](../../../agents/architect.md)
- [first-principles](../../../skills/first-principles/SKILL.md)

## Process

1. Identify a logical block of code within a large function that performs a single specific task.
2. Analyze all local variables used within that block to determine parameters and return values.
3. Choose a semantic, verb-noun name for the new function (e.g., `calculateTotalAmount`).
4. Re-write the block as a standalone function with clear type annotations.
5. Replace the original block with a call to the new function.
6. Verify the refactor doesn't change the component's behavior.

## Rules

- Follow the [Architect Agent](../../../agents/architect.md) patterns.
- Ensure the new function is pure if possible (no side effects).
- Add clear documentation to the new function.
- Do not exceed 3-4 parameters; use a configuration object if more are needed.
