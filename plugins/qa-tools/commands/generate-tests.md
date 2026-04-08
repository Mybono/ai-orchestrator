Generate exhaustive unit tests by identifying edge cases and required mocks.

Load the following expertise before starting:

- [Unit Test Agent](../../../agents/unit-tester.md)
- [detected language standards](../../../skills/)

## Process

1. Analyze the target code block to identify:
   - Inputs and their possible ranges.
   - External dependencies that need mocking.
   - Core logic and branching paths.
2. Draft a test suite structure:
   - Happy path scenarios.
   - Boundary condition scenarios (empty, null, max/min).
   - Error handling scenarios (exceptions, timeouts).
3. Generate the test code using the project's preferred framework (Jest, Pytest, etc.).
4. Verify the tests by running them against the implementation.

## Rules

- Use the Page Object Model (POM) if the tests involve UI.
- Ensure all mocks are strictly isolated.
- Naming must be descriptive: `test_<entity>_<action>_<expected_result>`.
