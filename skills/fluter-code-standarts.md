# Flutter (Dart) Code Quality Standards (Claude Code Skill)

## 🎯 Goal

Write clean, scalable, and maintainable Flutter applications using modern Dart best practices.

---

## 🧱 General Principles

* Prefer **readability over cleverness**
* Follow **Flutter & Dart style guide**
* Keep widgets **small and reusable**
* Separate **UI, logic, and data layers**
* Avoid premature optimization
* Favor composition over inheritance

---

## 🧼 Code Style

### Naming

* `camelCase` → variables & functions
* `PascalCase` → classes & widgets
* `lowercase_with_underscores.dart` → file names

### Formatting

* Max line length: **100 chars**
* Use `dart format`
* Keep widget tree readable (split into smaller widgets)

---

## 🧠 Types & Safety

* Always use **strong typing**
* Avoid `dynamic` unless absolutely necessary
* Prefer `final` over `var`

```dart
final String name = 'John';
```

---

## 📦 Project Structure

Recommended structure:

```
lib/
  core/
  features/
    feature_name/
      data/
      domain/
      presentation/
```

* Use **feature-based architecture**
* Keep layers independent

---

## 🧩 Widgets

* Keep widgets small (**<100 lines** ideally)
* Extract reusable components
* Prefer **StatelessWidget** when possible

```dart
class UserCard extends StatelessWidget {
  final String name;

  const UserCard({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Text(name);
  }
}
```

---

## 🔁 State Management

* Choose one approach and stay consistent:

  * Provider
  * Riverpod (preferred for scalability)
  * Bloc / Cubit (for complex apps)

* Avoid business logic inside UI

---

## ⚠️ Error Handling

* Handle async errors properly (`try/catch`)
* Avoid silent failures
* Show meaningful UI states (loading, error, empty)

```dart
try {
  final data = await api.fetch();
} catch (e) {
  handleError(e);
}
```

---

## 🧪 Testing

* Write:

  * Unit tests (logic)
  * Widget tests (UI)
  * Integration tests (flows)

* Keep tests isolated and deterministic

---

## 🧹 Clean Code Practices

* Avoid duplication (DRY)
* Remove dead widgets/code
* Avoid deeply nested widget trees
* Use meaningful names

---

## 🚀 Performance

* Use `const` constructors where possible
* Avoid unnecessary rebuilds
* Use `ListView.builder` for large lists
* Use `Keys` when needed

---

## 🔒 Async & Concurrency

* Always `await` async calls
* Avoid unhandled Futures
* Use `FutureBuilder` / `StreamBuilder` correctly

---

## 🧰 Tooling

Recommended tools:

* `flutter analyze`
* `dart format`
* `flutter test`
* `build_runner` (for codegen)

---

## 📚 Documentation

* Document public classes and methods
* Use clear comments for complex UI logic

```dart
/// Fetch user data from API
Future<User> fetchUser();
```

---

## 🚫 Anti-Patterns

* Massive widgets (>300 lines)
* Business logic in UI
* Overuse of `setState`
* Deep widget nesting
* Using `dynamic` everywhere

---

## ✅ Definition of Done

* Code is readable and modular
* Widgets are reusable
* No unnecessary rebuilds
* Covered by tests
* Linted and formatted

---

## 🧭 Mindset

> "UI should be declarative, predictable, and easy to reason about."

Build apps that scale in both codebase and team size.
