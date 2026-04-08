Generate an OpenAPI 3.1 specification from the existing codebase or API design.

Load the following expertise before starting:

- [api-design-patterns](../../../skills/api-design-patterns/SKILL.md)
- [Architect Agent](../../../agents/architect.md)

## Process

1. Discover existing API routes and handlers:
   - Search for routing patterns in the codebase (Express, FastAPI, etc.).
2. Extract schema information:
   - Parse DTOs, interfaces, or models.
   - Map field types to OpenAPI types.
3. Build the OpenAPI specification:
   - Set title, version, and server URLs.
   - Define paths, parameters, request bodies, and responses.
   - Create reusable schemas in `components`.
4. Validate the specification:
   - Ensure all references ($ref) resolve.
5. Generate examples:
   - Include realistic data for schemas.

## Output

Write the specification to `openapi.yaml`. If an existing file exists, present a diff and ask before overwriting.

## Rules

- Use OpenAPI 3.1.0 for full JSON Schema compatibility.
- Ensure every endpoint has a summary, description, and at least one response.
- Use semantic operation IDs (e.g., `listUsers`, `createOrder`).
