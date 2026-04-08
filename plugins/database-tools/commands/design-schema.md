Design a database schema based on the project's requirements, domain model, and performance needs.

Load the following expertise before starting:

- [Architect Agent](../../../agents/architect.md)
- [microservices-design](../../../skills/microservices-design/SKILL.md)

## Process

1. Identify entities, attributes, and relationships (1:1, 1:N, N:M).
2. Choose the appropriate database type (Relational, Document, Graph, Cache).
3. Design the schema:
   - For SQL: Define tables, primary/foreign keys, and indexes.
   - For NoSQL: Define collections, document structures, and sharding keys.
4. Normalize where appropriate (3NF), but denormalize if required for high read performance.
5. Define data types, constraints (NOT NULL, UNIQUE), and default values.

## Output

Present the schema design as SQL DDL scripts or a detailed document describing the data structure and relationships.

## Rules

- Follow the [Architect Agent](../../../agents/architect.md) standards.
- Always include indexes for fields used in common lookups.
- Avoid large BLOBs in relational tables; recommend object storage instead.
