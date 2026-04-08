# Enterprise TypeScript Patterns

> Load when: user asks about project structure, migration, barrel exports, security, or large-scale TS patterns.

## Project Structure (feature-based)

```text
src/
├── features/
│   ├── users/
│   │   ├── index.ts           # public API (barrel export)
│   │   ├── user.types.ts
│   │   ├── user.schema.ts     # Zod schemas
│   │   ├── user.service.ts
│   │   ├── user.repository.ts
│   │   └── __tests__/
│   └── auth/
│       ├── index.ts
│       └── ...
├── shared/
│   ├── types/
│   │   ├── result.ts
│   │   └── pagination.ts
│   ├── errors/
│   │   └── app-error.ts
│   └── utils/
│       └── validation.ts
└── config/
    └── env.ts    # Zod-validated env vars
```

## Barrel Exports

```typescript
// features/users/index.ts — export only public API
export type { User, CreateUserDto } from "./user.types";
export { UserSchema } from "./user.schema";
export { UserService } from "./user.service";
// DON'T export: repository, internal helpers

// Consumers use clean import
import { User, UserService } from "@features/users";
```

## JS → TS Migration Strategy

**Phase 1: TypeScript alongside JS (no breakage)**

```json
{
  "compilerOptions": {
    "allowJs": true,
    "checkJs": false,
    "strict": false,
    "noImplicitAny": false
  }
}
```

**Phase 2: Rename files one at a time**

```bash
mv src/utils/helpers.js src/utils/helpers.ts
# Fix type errors, run tests
# Repeat per file
```

**Phase 3: Enable strictness incrementally**

```json
// Start here
{ "noImplicitAny": true }

// Then
{ "strictNullChecks": true }

// Then full strict
{ "strict": true }

// Finally (optional but recommended)
{ "noUncheckedIndexedAccess": true, "exactOptionalPropertyTypes": true }
```

**JSDoc for gradual typing (before renaming)**

```javascript
/**
 * @param {string} id
 * @returns {Promise<import('./user.types').User | null>}
 */
async function findUser(id) { ... }
```

## Security Patterns

### Never expose internal fields

```typescript
interface InternalUser {
  id: string;
  name: string;
  email: string;
  passwordHash: string;  // never send this
  internalNotes: string; // never send this
}

// Pick only safe fields for API response
type PublicUser = Pick<InternalUser, "id" | "name" | "email">;

function toPublicUser(user: InternalUser): PublicUser {
  return { id: user.id, name: user.name, email: user.email };
}
```

### Type-safe env vars

```typescript
import { z } from "zod";

const EnvSchema = z.object({
  NODE_ENV:     z.enum(["development", "production", "test"]),
  PORT:         z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  JWT_SECRET:   z.string().min(32),
});

export const env = EnvSchema.parse(process.env);
// Crash on startup with clear message if vars are missing/invalid
// env.PORT is number, not string | undefined
```

### Sanitize inputs (with Zod transforms)

```typescript
import { z } from "zod";
import DOMPurify from "isomorphic-dompurify";

const SafeStringSchema = z.string().transform(val => DOMPurify.sanitize(val.trim()));

const SafeIdentifierSchema = z.string().regex(
  /^[a-zA-Z_][a-zA-Z0-9_]*$/,
  "Invalid identifier — alphanumeric + underscore only"
);
```

## Pagination Types

```typescript
interface PaginationParams {
  page: number;
  pageSize: number;
}

interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

function paginate<T>(items: T[], params: PaginationParams): PaginatedResult<T> {
  const { page, pageSize } = params;
  const start = (page - 1) * pageSize;
  return {
    items: items.slice(start, start + pageSize),
    total: items.length,
    page,
    pageSize,
    totalPages: Math.ceil(items.length / pageSize),
  };
}
```

## CommonJS → ESM

```json
// package.json
{ "type": "module" }
```

```typescript
// Before (CJS)
const { fn } = require("./utils");
module.exports = { router };

// After (ESM) — note .js extension even for .ts files
import { fn } from "./utils.js";
export { router };
```
