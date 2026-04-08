---
name: mastering-typescript
description: >
  Write, review, debug, and improve TypeScript code across any context: React SPAs,
  Node.js tooling, CLI scripts, automation, monorepos, and API backends.
  Use this skill whenever the user asks about TypeScript types, generics, tsconfig,
  type errors, Zod validation, type narrowing, mapped/conditional types, path aliases,
  project references, JS-to-TS migration, or typed React components and hooks.
  Also trigger when the user pastes a TypeScript error they don't understand, or asks
  how to type something specific
---

# Mastering TypeScript

> TypeScript 5.x · Node.js 22 LTS · React 19 · strict mode first

---

## Step 0: Understand the context first

Before writing or reviewing TypeScript, identify:

1. **Environment** — browser SPA, Node.js CLI/tooling, monorepo, CI script?
2. **Entry point** — Vite, tsc, ts-node, tsx, esbuild?
3. **Strict mode?** — If not, enable it. Explain why if they push back.
4. **Framework** — React, NestJS, plain Node, none?
5. **Existing tsconfig?** — Ask or check before proposing settings.

If the user pastes a tsc error, diagnose it first — skip the interview.

---

## The tsconfig Foundation

### Strict baseline (works everywhere)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
```

**What `strict: true` enables:** `strictNullChecks`, `noImplicitAny`, `strictFunctionTypes`, `strictBindCallApply`, `strictPropertyInitialization`, `useUnknownInCatchVariables`.

### Monorepo / path aliases

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"],
      "@shared/*": ["src/shared/*"],
      "@features/*": ["src/features/*"]
    }
  }
}
```

⚠️ Path aliases in tsconfig are type-only. Runtime resolution requires Vite's `resolve.alias`, webpack's `alias`, or `tsconfig-paths` for Node.

### Project references (monorepo)

```json
// Root tsconfig.json
{
  "references": [
    { "path": "./packages/shared" },
    { "path": "./packages/sdk" },
    { "path": "./packages/e2e" }
  ]
}
 
// packages/sdk/tsconfig.json
{
  "compilerOptions": {
    "composite": true,
    "declarationMap": true
  },
  "references": [{ "path": "../shared" }]
}
```

Use `tsc --build` instead of `tsc` in monorepos.

---

## Type System Quick Reference

### Primitives and literals

```typescript
const name: string = "Alice";
const port: number = 3000;
const active: boolean = true;
 
// Literal types — prefer over enums
type Status = "pending" | "approved" | "rejected";
type Direction = "north" | "south" | "east" | "west";
```

### Union and intersection

```typescript
// Union: one of several types
type StringOrNumber = string | number;
 
// Discriminated union — TypeScript narrows automatically
type Result<T> =
  | { success: true; data: T }
  | { success: false; error: string };
 
function handle<T>(r: Result<T>): T | null {
  if (r.success) return r.data;   // TypeScript knows: data exists
  console.error(r.error);         // TypeScript knows: error exists
  return null;
}
 
// Intersection: must satisfy all
type Admin = User & { permissions: string[] };
```

### The `satisfies` operator (TS 4.9+)

```typescript
// Problem with `as`: loses specific type
const config = { port: 3000, host: "localhost" } as Record<string, unknown>;
config.port.toFixed(2);  // Error: unknown
 
// `satisfies`: validates shape, preserves inference
const config = {
  port: 3000,
  host: "localhost"
} satisfies Record<string, string | number>;
 
config.port.toFixed(2);  // OK — TypeScript knows it's number
config.host.toUpperCase(); // OK — TypeScript knows it's string
```

### Type guards

```typescript
// typeof
function format(val: string | number): string {
  if (typeof val === "string") return val.toUpperCase();
  return val.toFixed(2);
}
 
// instanceof
function handleError(e: unknown): string {
  if (e instanceof Error) return e.message;
  return String(e);
}
 
// Custom type guard
interface User  { kind: "user";  name: string }
interface Admin { kind: "admin"; permissions: string[] }
 
function isAdmin(p: User | Admin): p is Admin {
  return p.kind === "admin";
}
 
// Assertion function (throws on failure)
function assertDefined<T>(val: T | null | undefined, msg: string): asserts val is T {
  if (val == null) throw new Error(msg);
}
```

### unknown vs any

```typescript
// any: opt out of type checking entirely — avoid
function parse(data: any) {
  data.whatever.you.want();  // no error, no safety
}
 
// unknown: forces you to narrow before use — prefer
function parse(data: unknown) {
  if (typeof data === "object" && data !== null && "name" in data) {
    console.log((data as { name: string }).name);
  }
}
```

---

## Generics

### Basic patterns

```typescript
// Generic function
function first<T>(items: T[]): T | undefined {
  return items[0];
}
 
// Constrained generic
function getLength<T extends { length: number }>(item: T): number {
  return item.length;
}
 
// Multiple type parameters
function zip<A, B>(as: A[], bs: B[]): [A, B][] {
  return as.map((a, i) => [a, bs[i]]);
}
 
// Generic with default
type ApiResponse<T = unknown> = {
  data: T;
  status: number;
  timestamp: Date;
};
```

### Utility types reference

| Type | Purpose | Example |
|------|---------|---------|
| `Partial<T>` | All props optional | `Partial<User>` |
| `Required<T>` | All props required | `Required<Config>` |
| `Readonly<T>` | Immutable | `Readonly<State>` |
| `Pick<T, K>` | Select keys | `Pick<User, "id" \| "name">` |
| `Omit<T, K>` | Remove keys | `Omit<User, "passwordHash">` |
| `Record<K, V>` | Typed object | `Record<string, number>` |
| `ReturnType<F>` | Function return type | `ReturnType<typeof fn>` |
| `Parameters<F>` | Function params tuple | `Parameters<typeof fn>` |
| `Awaited<T>` | Unwrap Promise | `Awaited<Promise<User>>` |
| `NonNullable<T>` | Remove null/undefined | `NonNullable<string \| null>` |

---

## Advanced Types

### Conditional types

```typescript
// Basic
type IsArray<T> = T extends unknown[] ? true : false;
 
// Infer inside conditional
type UnwrapPromise<T> = T extends Promise<infer R> ? R : T;
type ArrayElement<T> = T extends (infer E)[] ? E : never;
 
// Distribute over union
type ToArray<T> = T extends unknown ? T[] : never;
type Result = ToArray<string | number>; // string[] | number[]
```

### Mapped types

```typescript
// Basic mapped type
type Nullable<T> = { [K in keyof T]: T[K] | null };
 
// With key remapping
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K]
};
 
// Filter keys by value type
type StringKeys<T> = {
  [K in keyof T]: T[K] extends string ? K : never
}[keyof T];
```

### Template literal types

```typescript
type EventName<T extends string> = `on${Capitalize<T>}`;
type ClickEvent = EventName<"click">;  // "onClick"
 
type CSSProperty = `${string}-${string}`;
type Endpoint = `/api/${string}`;
```

### Branded types (validation at the type level)

```typescript
declare const _brand: unique symbol;
type Brand<T, B> = T & { readonly [_brand]: B };
 
type UserId = Brand<string, "UserId">;
type Email  = Brand<string, "Email">;
 
function createUserId(id: string): UserId {
  if (!id.match(/^user_/)) throw new Error("Invalid user ID");
  return id as UserId;
}
 
// Prevents mixing up plain strings with validated values
function getUser(id: UserId): Promise<User> { ... }
 
getUser("user_123");                 // Error: string not assignable to UserId
getUser(createUserId("user_123"));   // OK
```

---

## Error Handling

### Result pattern (no exceptions)

```typescript
type Ok<T>  = { success: true;  data: T };
type Err<E> = { success: false; error: E };
type Result<T, E = Error> = Ok<T> | Err<E>;
 
const ok  = <T>(data: T): Ok<T>   => ({ success: true, data });
const err = <E>(error: E): Err<E> => ({ success: false, error });
 
// Usage
async function fetchUser(id: string): Promise<Result<User>> {
  try {
    const user = await db.users.findById(id);
    if (!user) return err(new Error(`User ${id} not found`));
    return ok(user);
  } catch (e) {
    return err(e instanceof Error ? e : new Error(String(e)));
  }
}
 
const result = await fetchUser("123");
if (result.success) {
  console.log(result.data.name);
} else {
  console.error(result.error.message);
}
```

### Typed error classes

```typescript
abstract class AppError extends Error {
  abstract readonly code: string;
  abstract readonly statusCode: number;
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}
 
class NotFoundError extends AppError {
  readonly code = "NOT_FOUND";
  readonly statusCode = 404;
  constructor(resource: string, id: string) {
    super(`${resource} ${id} not found`);
  }
}
 
class ValidationError extends AppError {
  readonly code = "VALIDATION_ERROR";
  readonly statusCode = 400;
  constructor(message: string, public readonly fields: Record<string, string[]>) {
    super(message);
  }
}
 
// Type guard
function isAppError(e: unknown): e is AppError {
  return e instanceof AppError;
}
```

---

## Validation with Zod

```typescript
import { z } from "zod";
 
const UserSchema = z.object({
  id:    z.string().uuid(),
  name:  z.string().min(1).max(100),
  email: z.string().email(),
  role:  z.enum(["user", "admin"]),
});
 
type User = z.infer<typeof UserSchema>;  // TS type derived from schema
 
// Safe parse (doesn't throw)
const result = UserSchema.safeParse(rawData);
if (result.success) {
  console.log(result.data.email); // typed as string
} else {
  console.error(result.error.issues);
}
 
// Derive DTO schemas from base
const CreateUserSchema = UserSchema.omit({ id: true });
const UpdateUserSchema = UserSchema.partial().omit({ id: true });
 
type CreateUserDto = z.infer<typeof CreateUserSchema>;
type UpdateUserDto = z.infer<typeof UpdateUserSchema>;
 
// Type-safe env validation
const EnvSchema = z.object({
  NODE_ENV:     z.enum(["development", "production", "test"]),
  PORT:         z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  API_KEY:      z.string().min(32),
});
 
export const env = EnvSchema.parse(process.env); // throws on startup if invalid
```

---

## Debugging tsc Errors

### Common errors and fixes

**TS2322 — Type not assignable**

```typescript
// Error: Type 'string | undefined' is not assignable to type 'string'
function greet(name: string | undefined) {
  const upper = name.toUpperCase(); // Error
 
  // Fix 1: narrowing
  if (name !== undefined) {
    const upper = name.toUpperCase(); // OK
  }
 
  // Fix 2: nullish coalescing
  const upper = (name ?? "stranger").toUpperCase(); // OK
 
  // Fix 3: non-null assertion (only if you're sure)
  const upper = name!.toUpperCase(); // risky
}
```

**TS2345 — Argument type mismatch**

```typescript
// Usually means a union type wasn't narrowed
function process(val: string | number) {
  takesString(val);  // Error: number not assignable to string
 
  // Fix: narrow first
  if (typeof val === "string") takesString(val); // OK
}
```

**TS2339 — Property does not exist**

```typescript
// Error: Property 'foo' does not exist on type '{}'
const obj = {};
obj.foo = "bar";  // Error
 
// Fix: type the object properly
const obj: { foo?: string } = {};
obj.foo = "bar"; // OK
```

**TS7006 — Parameter implicitly has 'any' type**

```typescript
// Error in strict mode
const nums = [1, 2, 3];
nums.map(n => n * 2);  // OK, inferred
nums.forEach(n => { }); // OK if body is enough
 
// Explicit when TypeScript can't infer
function transform(fn: (x: number) => number) { ... }
```

**TS2769 — No overload matches**
Usually means you called a generic function with mismatched types.
Check each argument type individually against the function signature.

**TS2532 — Object is possibly undefined (with `noUncheckedIndexedAccess`)**

```typescript
const arr = [1, 2, 3];
const first = arr[0];         // number | undefined (with noUncheckedIndexedAccess)
const val = first.toFixed(2); // Error
 
// Fix
const val = arr[0]?.toFixed(2);  // string | undefined
// OR
if (first !== undefined) { ... }
```

---

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| `any` everywhere | No type safety | Use `unknown` + narrow |
| `as SomeType` without guard | Hides real errors | Use type guards or `satisfies` |
| `enum` for string unions | Generates runtime JS | Use `"a" \| "b" \| "c"` literals |
| `!` non-null assertion | Runtime crash if wrong | Narrow with `if` instead |
| Not validating API/JSON data | Runtime type mismatch | Use Zod at boundaries |
| `interface` for everything | Can't use mapped types | Use `type` for aliases & mapped types |
| `Object.keys()` returns `string[]` | Loses key types | Use `(Object.keys(obj) as (keyof typeof obj)[])` |

---

## Reference Files

Load on demand — don't preload all:

- `references/react.md` — Typed components, hooks (useState/useReducer/useRef), events, Context, Zustand, Redux Toolkit
- `references/toolchain.md` — ESLint 9 flat config, Vitest setup, Prettier, pnpm workspaces
- `references/enterprise.md` — Project structure, barrel exports, migration JS→TS, security patterns, branded types
