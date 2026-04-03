# TypeScript Code Quality Standards (Claude Code Skill)

## 🎯 Goal

Write clean, strongly-typed, maintainable, and scalable TypeScript code using modern best practices.

---

## 🧱 General Principles

* Prefer **type safety over flexibility**
* Avoid `any` at all costs
* Write **self-documenting code**
* Keep functions and modules **small and focused**
* Favor composition over inheritance
* Avoid premature optimization

---

## 🧼 Code Style

### Naming

* `camelCase` → variables & functions
* `PascalCase` → types, interfaces, classes
* `UPPER_CASE` → constants

### Formatting

* Max line length: **100 chars**
* Use consistent formatting (Prettier)
* Always use semicolons

---

## 🧠 Typing

* Always define explicit types for public APIs
* Prefer `type` over `interface` (unless extending)
* Use unions and literals instead of enums when possible

```ts
type Status = 'pending' | 'success' | 'error';
```markdown

* Use generics for reusable logic

```ts
function identity<T>(value: T): T {
  return value;
}
```markdown

---

## ❌ Avoid `any`

* Use:

  * `unknown` → safer alternative
  * proper typing or generics

```ts
function parse(data: unknown): string {
  if (typeof data === 'string') return data;
  throw new Error('Invalid data');
}
```markdown

---

## 📦 Project Structure

* Organize by **feature**, not by type

```markdown
src/
  features/
  shared/
  core/
```markdown

* Keep modules small and cohesive

---

## 🧩 Functions

* Max ~20–30 lines
* Single responsibility
* Avoid side effects where possible
* Use explicit return types

```ts
function calculateTotal(price: number, tax: number): number {
  return price * (1 + tax);
}
```markdown

---

## 🏗 Types & Models

* Prefer immutable data (`readonly`)
* Use utility types (`Partial`, `Pick`, `Omit`)

```ts
type User = {
  readonly id: number;
  name: string;
};
```markdown

---

## ⚠️ Error Handling

* Use `try/catch` only when needed
* Prefer returning `Result`-like structures

```ts
type Result<T> = { data: T } | { error: string };
```markdown

* Never ignore errors

---

## 🧪 Testing

* Use:

  * Jest / Vitest

* Write:

  * Unit tests for logic
  * Integration tests for flows

* Tests must be:

  * Deterministic
  * Independent

---

## 🧹 Clean Code Practices

* Avoid duplication (DRY)
* Remove dead code
* Avoid magic values → use constants
* Use meaningful names

---

## 🚀 Performance

* Avoid unnecessary re-renders (frontend)
* Use memoization when needed
* Avoid deep object cloning unless required

---

## 🔒 Async & Promises

* Always handle promises properly (`await` / `.catch`)
* Avoid unhandled promise rejections

```ts
async function fetchData(): Promise<void> {
  try {
    await apiCall();
  } catch (e) {
    handleError(e);
  }
}
```markdown

---

## 🧰 Tooling

Recommended tools:

* `typescript` (strict mode ON)
* `eslint`
* `prettier`
* `ts-node` / `tsx`

---

## 📚 Documentation

* Document public APIs
* Use JSDoc where needed

```ts
/**
 * Fetch user by ID
 */
function fetchUser(id: number): Promise<User>;
```markdown

---

## 🚫 Anti-Patterns

* Using `any`
* Massive files/modules
* Hidden side effects
* Deep nesting (>3 levels)
* Overuse of classes (prefer functions)

---

## ✅ Definition of Done

* Fully typed (no `any`)
* Clean and readable
* Covered by tests
* Linted and formatted
* No obvious runtime risks

---

## 🧭 Mindset

> "TypeScript is not JavaScript with types. It's a tool for correctness."

Use types to prevent bugs before they happen.
