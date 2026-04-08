Analyze test failure outputs to identify root causes and patterns.

Load the following expertise before starting:

- [QA Orchestrator](../../../agents/qa-orchestrator.md)
- [Root Cause Analysis](../../../skills/root-cause-analysis/SKILL.md)

## Process

1. Parse the test logs or CI/CD output for error messages and stack traces.
2. Group related failures to identify a common systemic cause.
3. Trace the data flow to the point of failure using the codebase.
4. Perform a 5-Whys analysis to reach the fundamental cause.
5. Rank suggested fixes by impact and effort.

## Rules

- Never suggest a fix without identifying the clear root cause.
- Differentiate between flaky tests (environment/timing) and regression bugs (logic).
- If multiple layers are failing, fix the deepest layer first.
