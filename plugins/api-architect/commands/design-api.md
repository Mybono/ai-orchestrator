Design a RESTful or GraphQL API based on the project's domain model and requirements.

Load the following expertise before starting:

- [api-design-patterns](../../../skills/api-design-patterns/SKILL.md)
- [Architect Agent](../../../agents/architect.md)

## Process

1. Analyze the existing codebase to understand the domain:
   - Identify entities, relationships, and current API surface.
2. Design the resource hierarchy:
   - Map entities to plural noun URLs.
   - Use standard REST methods properly.
3. Define request/response shapes:
   - Use consistent envelopes.
   - Define error formats and status codes.
4. Design security:
   - Specify authentication (JWT/OAuth2) and permission models.
5. Plan for versioning:
   - Recommend URL prefix versioning.

## Output

Present the API design as a structured table of endpoints with methods, descriptions, request/response shapes, and example curl commands.

## Rules

- Follow the [api-design-patterns](../../../skills/api-design-patterns/SKILL.md) skill strictly.
- Never expose internal database IDs or implementation details.
- Use standard HTTP status codes (201, 204, 400, 401, 404, 500).
