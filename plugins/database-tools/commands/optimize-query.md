Analyze and optimize a slow SQL query for better performance.

Load the following expertise before starting:

- [performance-optimization](../../../skills/performance-optimization/SKILL.md)
- [API Test Agent](../../../agents/api-tester.md)

## Process

1. Capture the query and its execution plan (using `/explain-plan`).
2. Implement optimizations:
   - Rewrite subqueries as joins or CTEs.
   - Add/modify indexes suggested by the analysis.
   - Eliminate unnecessary column selection (`SELECT *`).
   - Use window functions where appropriate for complex aggregations.
   - Recommend partitioning for extremely large tables.
3. Compare performance before and after the fix.

## Rules

- Follow the [performance-optimization](../../../skills/performance-optimization/SKILL.md) standards.
- Ensure the optimization doesn't change the query's result set.
- Prioritize non-destructive changes (e.g., adding an index) over invasive schema changes.
