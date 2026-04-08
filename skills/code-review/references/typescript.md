# TypeScript/JavaScript Code Review Guide

> A TypeScript code review guide covering the type system, generics, conditional types, strict mode, async/await patterns, and other core topics.

## Table of Contents

- [Type Safety Basics](#type-safety-basics)
- [Generic Patterns](#generic-patterns)
- [Advanced Types](#advanced-types)
- [Strict Mode Configuration](#strict-mode-configuration)
- [Async Handling](#async-handling)
- [Immutability](#immutability)
- [ESLint Rules](#eslint-rules)
- [Review Checklist](#review-checklist)

---

## Type Safety Basics

### Avoid using any

```typescript
// ❌ Using any defeats type safety
function processData(data: any) {
  return data.value;  // No type checking — may crash at runtime
}

// ✅ Use proper types
interface DataPayload {
  value: string;
}
function processData(data: DataPayload) {
  return data.value;
}

// ✅ Use unknown + type guard for truly unknown types
function processUnknown(data: unknown) {
  if (typeof data === 'object' && data !== null && 'value' in data) {
    return (data as { value: string }).value;
  }
  throw new Error('Invalid data');
}
```

### Type Narrowing

```typescript
// ❌ Unsafe type assertion
function getLength(value: string | string[]) {
  return (value as string[]).length;  // Will error if value is a string
}

// ✅ Use type guards
function getLength(value: string | string[]): number {
  if (Array.isArray(value)) {
    return value.length;
  }
  return value.length;
}

// ✅ Use the in operator
interface Dog { bark(): void }
interface Cat { meow(): void }

function speak(animal: Dog | Cat) {
  if ('bark' in animal) {
    animal.bark();
  } else {
    animal.meow();
  }
}
```

### Literal Types and as const

```typescript
// ❌ Type is too broad
const config = {
  endpoint: '/api',
  method: 'GET'  // Type is string
};

// ✅ Use as const to get literal types
const config = {
  endpoint: '/api',
  method: 'GET'
} as const;  // method type is 'GET'

// ✅ Used with function parameters
function request(method: 'GET' | 'POST', url: string) { ... }
request(config.method, config.endpoint);  // Correct!
```

---

## Generic Patterns

### Basic Generics

```typescript
// ❌ Duplicated code
function getFirstString(arr: string[]): string | undefined {
  return arr[0];
}
function getFirstNumber(arr: number[]): number | undefined {
  return arr[0];
}

// ✅ Use generics
function getFirst<T>(arr: T[]): T | undefined {
  return arr[0];
}
```

### Generic Constraints

```typescript
// ❌ Generic without constraint — cannot access properties
function getProperty<T>(obj: T, key: string) {
  return obj[key];  // Error: cannot index
}

// ✅ Use keyof constraint
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

const user = { name: 'Alice', age: 30 };
getProperty(user, 'name');  // Return type is string
getProperty(user, 'age');   // Return type is number
getProperty(user, 'foo');   // Error: 'foo' is not in keyof User
```

### Generic Default Values

```typescript
// ✅ Provide sensible default types
interface ApiResponse<T = unknown> {
  data: T;
  status: number;
  message: string;
}

// Generic parameter can be omitted
const response: ApiResponse = { data: null, status: 200, message: 'OK' };
// Or specified explicitly
const userResponse: ApiResponse<User> = { ... };
```

### Common Generic Utility Types

```typescript
// ✅ Make good use of built-in utility types
interface User {
  id: number;
  name: string;
  email: string;
}

type PartialUser = Partial<User>;         // All properties optional
type RequiredUser = Required<User>;       // All properties required
type ReadonlyUser = Readonly<User>;       // All properties readonly
type UserKeys = keyof User;               // 'id' | 'name' | 'email'
type NameOnly = Pick<User, 'name'>;       // { name: string }
type WithoutId = Omit<User, 'id'>;        // { name: string; email: string }
type UserRecord = Record<string, User>;   // { [key: string]: User }
```

---

## Advanced Types

### Conditional Types

```typescript
// ✅ Return different types based on input type
type IsString<T> = T extends string ? true : false;

type A = IsString<string>;  // true
type B = IsString<number>;  // false

// ✅ Extract array element type
type ElementType<T> = T extends (infer U)[] ? U : never;

type Elem = ElementType<string[]>;  // string

// ✅ Extract function return type (built-in ReturnType)
type MyReturnType<T> = T extends (...args: any[]) => infer R ? R : never;
```

### Mapped Types

```typescript
// ✅ Transform all properties of an object type
type Nullable<T> = {
  [K in keyof T]: T[K] | null;
};

interface User {
  name: string;
  age: number;
}

type NullableUser = Nullable<User>;
// { name: string | null; age: number | null }

// ✅ Add a prefix
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

type UserGetters = Getters<User>;
// { getName: () => string; getAge: () => number }
```

### Template Literal Types

```typescript
// ✅ Type-safe event names
type EventName = 'click' | 'focus' | 'blur';
type HandlerName = `on${Capitalize<EventName>}`;
// 'onClick' | 'onFocus' | 'onBlur'

// ✅ API route types
type ApiRoute = `/api/${string}`;
const route: ApiRoute = '/api/users';  // OK
const badRoute: ApiRoute = '/users';   // Error
```

### Discriminated Unions

```typescript
// ✅ Use a discriminant property for type safety
type Result<T, E> =
  | { success: true; data: T }
  | { success: false; error: E };

function handleResult(result: Result<User, Error>) {
  if (result.success) {
    console.log(result.data.name);  // TypeScript knows data exists
  } else {
    console.log(result.error.message);  // TypeScript knows error exists
  }
}

// ✅ Redux Action pattern
type Action =
  | { type: 'INCREMENT'; payload: number }
  | { type: 'DECREMENT'; payload: number }
  | { type: 'RESET' };

function reducer(state: number, action: Action): number {
  switch (action.type) {
    case 'INCREMENT':
      return state + action.payload;  // payload type is known
    case 'DECREMENT':
      return state - action.payload;
    case 'RESET':
      return 0;  // No payload here
  }
}
```

---

## Strict Mode Configuration

### Recommended tsconfig.json

```json
{
  "compilerOptions": {
    // ✅ Required strict options
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "useUnknownInCatchVariables": true,

    // ✅ Additional recommended options
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "exactOptionalPropertyTypes": true,
    "noPropertyAccessFromIndexSignature": true
  }
}
```

### Impact of noUncheckedIndexedAccess

```typescript
// tsconfig: "noUncheckedIndexedAccess": true

const arr = [1, 2, 3];
const first = arr[0];  // Type is number | undefined

// ❌ Using directly may error
console.log(first.toFixed(2));  // Error: may be undefined

// ✅ Check first
if (first !== undefined) {
  console.log(first.toFixed(2));
}

// ✅ Or use non-null assertion (when you are certain)
console.log(arr[0]!.toFixed(2));
```

---

## Async Handling

### Promise Error Handling

```typescript
// ❌ Not handling async errors
async function fetchUser(id: string) {
  const response = await fetch(`/api/users/${id}`);
  return response.json();  // Network errors are not handled
}

// ✅ Handle errors properly
async function fetchUser(id: string): Promise<User> {
  try {
    const response = await fetch(`/api/users/${id}`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to fetch user: ${error.message}`);
    }
    throw error;
  }
}
```

### Promise.all vs Promise.allSettled

```typescript
// ❌ Promise.all fails entirely if one rejects
async function fetchAllUsers(ids: string[]) {
  const users = await Promise.all(ids.map(fetchUser));
  return users;  // One failure causes all to fail
}

// ✅ Promise.allSettled gives all results
async function fetchAllUsers(ids: string[]) {
  const results = await Promise.allSettled(ids.map(fetchUser));

  const users: User[] = [];
  const errors: Error[] = [];

  for (const result of results) {
    if (result.status === 'fulfilled') {
      users.push(result.value);
    } else {
      errors.push(result.reason);
    }
  }

  return { users, errors };
}
```

### Race Condition Handling

```typescript
// ❌ Race condition: an older request may overwrite a newer one
function useSearch() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);

  useEffect(() => {
    fetch(`/api/search?q=${query}`)
      .then(r => r.json())
      .then(setResults);  // An older request may return after a newer one!
  }, [query]);
}

// ✅ Use AbortController
function useSearch() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);

  useEffect(() => {
    const controller = new AbortController();

    fetch(`/api/search?q=${query}`, { signal: controller.signal })
      .then(r => r.json())
      .then(setResults)
      .catch(e => {
        if (e.name !== 'AbortError') throw e;
      });

    return () => controller.abort();
  }, [query]);
}
```

---

## Immutability

### Readonly and ReadonlyArray

```typescript
// ❌ Mutable parameter may be accidentally modified
function processUsers(users: User[]) {
  users.sort((a, b) => a.name.localeCompare(b.name));  // Mutates the original array!
  return users;
}

// ✅ Use readonly to prevent mutation
function processUsers(users: readonly User[]): User[] {
  return [...users].sort((a, b) => a.name.localeCompare(b.name));
}

// ✅ Deep readonly
type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K];
};
```

### Invariant Function Parameters

```typescript
// ✅ Use as const and readonly to protect data
function createConfig<T extends readonly string[]>(routes: T) {
  return routes;
}

const routes = createConfig(['home', 'about', 'contact'] as const);
// Type is readonly ['home', 'about', 'contact']
```

---

## ESLint Rules

### Recommended @typescript-eslint Rules

```javascript
// .eslintrc.js
module.exports = {
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:@typescript-eslint/recommended-requiring-type-checking',
    'plugin:@typescript-eslint/strict'
  ],
  rules: {
    // ✅ Type safety
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/no-unsafe-assignment': 'error',
    '@typescript-eslint/no-unsafe-member-access': 'error',
    '@typescript-eslint/no-unsafe-call': 'error',
    '@typescript-eslint/no-unsafe-return': 'error',

    // ✅ Best practices
    '@typescript-eslint/explicit-function-return-type': 'warn',
    '@typescript-eslint/no-floating-promises': 'error',
    '@typescript-eslint/await-thenable': 'error',
    '@typescript-eslint/no-misused-promises': 'error',

    // ✅ Code style
    '@typescript-eslint/consistent-type-imports': 'error',
    '@typescript-eslint/prefer-nullish-coalescing': 'error',
    '@typescript-eslint/prefer-optional-chain': 'error'
  }
};
```

### Common ESLint Error Fixes

```typescript
// ❌ no-floating-promises: Promises must be handled
async function save() { ... }
save();  // Error: unhandled Promise

// ✅ Handle explicitly
await save();
// or
save().catch(console.error);
// or explicitly ignore
void save();

// ❌ no-misused-promises: Promises cannot be used in non-async positions
const items = [1, 2, 3];
items.forEach(async (item) => {  // Error!
  await processItem(item);
});

// ✅ Use for...of
for (const item of items) {
  await processItem(item);
}
// or Promise.all
await Promise.all(items.map(processItem));
```

---

## Review Checklist

### Type System

- [ ] No use of `any` (use `unknown` + type guard instead)
- [ ] Interfaces and type definitions are complete and meaningfully named
- [ ] Generics are used to improve code reusability
- [ ] Union types have correct type narrowing
- [ ] Utility types are used appropriately (Partial, Pick, Omit, etc.)

### Generics

- [ ] Generics have appropriate constraints (extends)
- [ ] Generic parameters have sensible default values
- [ ] Avoid over-generalization (KISS principle)

### Strict Mode

- [ ] tsconfig.json has strict: true enabled
- [ ] noUncheckedIndexedAccess is enabled
- [ ] No use of @ts-ignore (use @ts-expect-error instead)

### Async Code

- [ ] async functions have error handling
- [ ] Promise rejections are handled correctly
- [ ] No floating promises (unhandled Promises)
- [ ] Concurrent requests use Promise.all or Promise.allSettled
- [ ] Race conditions are handled with AbortController

### Immutability

- [ ] Function parameters are not mutated directly
- [ ] Spread operator is used to create new objects/arrays
- [ ] readonly modifier is considered where appropriate

### ESLint

- [ ] @typescript-eslint/recommended is used
- [ ] No ESLint warnings or errors
- [ ] consistent-type-imports is used
