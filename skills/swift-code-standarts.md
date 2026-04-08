# Swift Code Quality standarts (Claude Code Skill)

## 🎯 Goal

Write clean, safe, readable, and maintainable Swift code following modern best practices (Swift 5+).

---

## 🧱 General Principles

* Prefer **readability over cleverness**
* Follow **Swift API Design Guidelines**
* Use **value types (`struct`) by default**
* Keep code **simple and expressive**
* Avoid premature optimization
* Minimize shared mutable state
* Favor immutability (`let` over `var`)

---

## 🧼 Code Style

### Naming

* `camelCase` → variables & functions
* `PascalCase` → types (structs, classes, enums)
* Use clear, descriptive names (avoid abbreviations)

### Formatting

* Max line length: **100–120 chars**
* Indentation: **4 spaces**
* Always use braces `{}` clearly
* One responsibility per line when possible

---

## 🧠 Types & Safety

* Prefer **strong typing**
* Use `let` by default
* Avoid force unwrapping (`!`)
* Use:

  * `Optional` (`?`)
  * `guard let` / `if let`
  * `Result` for operations that can fail

```swift
func findUser(id: Int) -> User? {
    ...
}
```

---

## 📦 Imports & Modules

* Import only what you need
* Keep modules small and cohesive
* Avoid circular dependencies

---

## 🧩 Functions

* Max ~20–30 lines
* Single responsibility
* Prefer clear parameter labels

```swift
func calculateTotal(price: Double, tax: Double) -> Double {
    return price * (1 + tax)
}
```

---

## 🏗 Types (Structs / Classes)

* Prefer `struct` over `class`
* Use `class` only when:

  * Reference semantics required
  * Inheritance needed

```swift
struct User {
    let id: Int
    let name: String
}
```

---

## ⚠️ Error Handling

* Use `throws` for fallible functions
* Handle errors explicitly with `do-catch`
* Avoid silent failures

```swift
func fetchUser() throws -> User {
    ...
}
```

---

## 🧪 Testing

* Use `XCTest`
* Write tests for business logic
* Keep tests:

  * Independent
  * Deterministic
  * Easy to read

---

## 🧹 Clean Code Practices

* Avoid duplication (DRY)
* Remove dead code
* Avoid magic numbers
* Use extensions to organize logic

---

## 🚀 Performance

* Avoid unnecessary copying
* Use lazy properties where appropriate
* Measure before optimizing

---

## 🔒 Memory Management

* Understand **ARC (Automatic Reference Counting)**
* Avoid retain cycles:

  * Use `[weak self]` / `[unowned self]` in closures

```swift
someAsyncCall { [weak self] in
    self?.handle()
}
```

---

## 🧰 Tooling

Recommended tools:

* `swiftformat` → formatting
* `swiftlint` → linting
* Xcode Analyzer → static analysis

---

## 📚 Documentation

* Use `///` for public APIs
* Write concise, meaningful comments

```swift
/// Fetch user by ID
/// - Parameter id: Unique identifier
/// - Returns: User or nil
func fetchUser(id: Int) -> User?
```

---

## 🚫 Anti-Patterns

* Force unwrap (`!`)
* Massive view controllers (MVC abuse)
* Deep nesting
* Overuse of globals/singletons
* Hidden side effects

---

## ✅ Definition of Done

* Code is readable and clean
* No crashes due to optionals
* Proper memory handling (no retain cycles)
* Covered by tests
* Linted and formatted

---

## 🧭 Mindset

> "Clarity is more important than brevity."

Write code that is easy to understand and safe by default.
