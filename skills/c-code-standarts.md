# C++ Code Quality standarts (Claude Code Skill)

## 🎯 Goal

Write clean, safe, efficient, and maintainable modern C++ (C++17/20+) code following industry best practices.

---

## 🧱 General Principles

* Prefer **readability over cleverness**
* Follow **RAII (Resource Acquisition Is Initialization)**
* Use **modern C++ (C++17/20+)**, avoid legacy patterns
* Keep functions and classes **small and focused**
* Minimize global state
* Follow **SOLID principles** where applicable
* Avoid premature optimization

---

## 🧼 Code Style

### Naming

* `snake_case` → variables & functions
* `PascalCase` → classes & structs
* `kUpperCase` → constants
* `m_member_variable` → class members (optional but consistent)

### Formatting

* Max line length: **100 chars**
* Indentation: **4 spaces**
* Always use braces `{}` even for single-line statements
* Keep consistent spacing and alignment

---

## 🧠 Types & Safety

* Prefer **strong typing**
* Avoid raw pointers unless necessary
* Use:

  * `std::unique_ptr` → ownership
  * `std::shared_ptr` → shared ownership (only when needed)
  * `std::optional` → nullable values
  * `std::variant` → type-safe unions

```cpp
std::optional<int> find_user_id(const std::string& name);
```

* Prefer `const` correctness everywhere
* Use `enum class` instead of plain enums

---

## 📦 Includes & Dependencies

* Include only what you use
* Prefer forward declarations where possible
* Avoid including heavy headers in headers

```cpp
// Good
#include <string>

// Avoid
#include <bits/stdc++.h>
```

---

## 🧩 Functions

* Max ~20–30 lines
* Single responsibility
* Avoid side effects where possible
* Pass large objects by `const&`

```cpp
int calculate_total(int price, int tax) {
    return price + tax;
}
```

---

## 🏗 Classes

* Follow **Rule of 0/3/5**
* Prefer composition over inheritance
* Keep interfaces small and clean

```cpp
class User {
public:
    User(int id, std::string name)
        : id_(id), name_(std::move(name)) {}

    int id() const { return id_; }

private:
    int id_;
    std::string name_;
};
```

---

## ⚠️ Error Handling

* Prefer:

  * Exceptions for exceptional cases
  * `std::optional` / `std::expected` for expected failures

* Never ignore errors silently

```cpp
try {
    process();
} catch (const std::exception& e) {
    log_error(e.what());
}
```

---

## 🧪 Testing

* Write tests for all business logic

* Use frameworks like:

  * GoogleTest
  * Catch2

* Keep tests:

  * Small
  * Independent
  * Deterministic

---

## 🧹 Clean Code Practices

* Avoid duplication (DRY)
* Remove dead code
* Avoid magic numbers → use constants
* Use meaningful names
* Limit nesting (max 2–3 levels)

---

## 🚀 Performance

* Prefer:

  * Move semantics (`std::move`)
  * `emplace_back` over `push_back`
  * `reserve()` for containers

* Avoid unnecessary copies

* Measure before optimizing

---

## 🔒 Memory Management

* Never leak memory
* Prefer RAII wrappers
* Avoid manual `new` / `delete`

```cpp
auto ptr = std::make_unique<MyClass>();
```

---

## 🧰 Tooling

Recommended tools:

* `clang-format` → formatting
* `clang-tidy` → linting
* `cppcheck` → static analysis
* `valgrind` / `asan` → memory checks

---

## 📚 Documentation

* Use clear comments for complex logic
* Prefer self-documenting code
* Document public APIs

```cpp
/// Fetch user by ID
/// @param user_id Unique identifier
/// @return User object or null
std::optional<User> fetch_user(int user_id);
```

---

## 🚫 Anti-Patterns

* Raw owning pointers
* God classes
* Deep inheritance hierarchies
* Hidden side effects
* Overuse of macros
* Global mutable state

---

## ✅ Definition of Done

* Code is readable and clean
* No memory leaks
* Proper ownership model
* Covered by tests
* Linted and formatted
* No undefined behavior

---

## 🧭 Mindset

> "C++ gives you power. Use it responsibly."

Write code that is safe, predictable, and easy to maintain.
