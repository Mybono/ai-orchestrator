Generate and interpret a SQL query execution plan to identify bottlenecks.

Load the following expertise before starting:

- [performance-optimization](../../../skills/performance-optimization/SKILL.md)
- [API Test Agent](../../../agents/api-tester.md)

## Process

1. Analyze the target SQL query and the associated table schema.
2. Run `EXPLAIN ANALYZE` (or equivalent for the target DB) to get the execution plan.
3. Identify performance killers:
   - Full Table Scans (Seq Scan).
   - Inefficient joins (Nested Loops on large sets).
   - High disk I/O or temporary file usage.
   - Missing or unused indexes.
4. Translate the plan into plain language for the developer.

## Rules

- Always consider the index types (B-tree, GIN, etc.) based on the column data and query.
- Factor in the volume of data in the target environment.
- Propose specific index changes or query rewrites based on the plan.
