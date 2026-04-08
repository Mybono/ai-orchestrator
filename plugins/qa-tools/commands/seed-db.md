Generate mock data and seed the database for specific test scenarios.

Load the following expertise before starting:

- [API Test Agent](../../../agents/api-tester.md)

## Process

1. Analyze the required test state (entities and relations).
2. Generate mock data (JSON, SQL, or Faker-based) that respects constraints.
3. Validate the data against the project's schema or DTOs.
4. Execute the seed script or manually insert data into the test environment.
5. Verify that the database is populated with the expected state.

## Rules

- Always ensure transactional integrity during seeding.
- Never use real PII (Personally Identifiable Information) in mock data.
- Respect foreign key constraints and required field mandates.
