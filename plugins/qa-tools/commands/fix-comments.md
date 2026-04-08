Automate the application of PR review fixes based on comments.

Load the following expertise before starting:

- [QA Orchestrator](../../../agents/qa-orchestrator.md)
- [Reviewer Agent](../../../agents/reviewer.md)

## Process

1. Fetch PR details and comments (via `gh pr view` or reading shared context).
2. Parse comments to identify specific requested changes.
3. Map comments to relevant files in the codebase.
4. Implement the requested fixes one by one.
5. Verify changes by running relevant tests.
6. Commit the fixes with a clear message referencing the comments.

## Rules

- Do not apply a fix if it contradicts existing project standards (refer to `skills/`).
- If a comment is unclear, ask the user for clarification before editing code.
- Always run the full test suite for changed files before considering the fix complete.
