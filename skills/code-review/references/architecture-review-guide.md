# Architecture Review Guide

An architectural design review guide to help assess whether code architecture is sound and design is appropriate.

## SOLID Principles Checklist

### S - Single Responsibility Principle (SRP)

**Key review points:**
- Does this class/module have only one reason to change?
- Do all methods in the class serve the same purpose?
- If you had to describe this class to a non-technical person, could you do it in one sentence?

**Signals to look for in code review:**
```
⚠️ Class name contains generic words like "And", "Manager", "Handler", or "Processor"
⚠️ A class exceeds 200–300 lines of code
⚠️ The class has more than 5–7 public methods
⚠️ Different methods operate on completely different data
```

**Review questions:**
- "What is this class responsible for? Can it be split?"
- "If requirement X changes, which methods need to change? What about requirement Y?"

### O - Open/Closed Principle (OCP)

**Key review points:**
- Does adding a new feature require modifying existing code?
- Can new behavior be added through extension (inheritance, composition)?
- Are there large chains of if/else or switch statements handling different types?

**Signals to look for in code review:**
```
⚠️ switch/if-else chains handling different types
⚠️ Adding new functionality requires modifying core classes
⚠️ Type checks (instanceof, typeof) scattered throughout the code
```

**Review questions:**
- "If a new X type needs to be added, which files need to change?"
- "Will this switch statement grow as new types are added?"

### L - Liskov Substitution Principle (LSP)

**Key review points:**
- Can a subclass fully substitute its parent class?
- Does the subclass change the expected behavior of parent class methods?
- Does the subclass throw exceptions not declared by the parent?

**Signals to look for in code review:**
```
⚠️ Explicit type casting
⚠️ Subclass methods throw NotImplementedException
⚠️ Subclass methods have empty bodies or just return
⚠️ Code using the base class needs to check the concrete type
```

**Review questions:**
- "If the subclass replaces the parent class, does the calling code need to change?"
- "Does this method's behavior in the subclass fulfill the parent class contract?"

### I - Interface Segregation Principle (ISP)

**Key review points:**
- Are interfaces small and focused enough?
- Are implementing classes forced to implement methods they don't need?
- Do clients depend on methods they don't use?

**Signals to look for in code review:**
```
⚠️ Interface has more than 5–7 methods
⚠️ Implementing classes have empty methods or throw NotImplementedException
⚠️ Interface names are too broad (IManager, IService)
⚠️ Different clients only use a subset of the interface's methods
```

**Review questions:**
- "Are all methods in this interface used by every implementing class?"
- "Can this large interface be split into smaller, specialized interfaces?"

### D - Dependency Inversion Principle (DIP)

**Key review points:**
- Do high-level modules depend on abstractions rather than concrete implementations?
- Is dependency injection used instead of directly instantiating objects?
- Are abstractions defined by high-level modules rather than low-level ones?

**Signals to look for in code review:**
```
⚠️ High-level modules directly instantiate concrete classes from low-level modules
⚠️ Importing concrete implementation classes instead of interfaces/abstractions
⚠️ Configuration and connection strings hardcoded in business logic
⚠️ Difficult to write unit tests for a class
```

**Review questions:**
- "Can the dependencies of this class be replaced with mocks during testing?"
- "If the database/API implementation changes, how many places need to be modified?"

---

## Identifying Architecture Anti-Patterns

### Critical Anti-Patterns

| Anti-Pattern | Signals | Impact |
|-------------|---------|--------|
| **Big Ball of Mud** | No clear module boundaries; any code can call any other code | Hard to understand, modify, and test |
| **God Object** | A single class has too many responsibilities, knows too much, does too much | High coupling, hard to reuse and test |
| **Spaghetti Code** | Chaotic control flow, goto or deep nesting, hard to trace execution | Hard to understand and maintain |
| **Lava Flow** | Ancient code nobody dares touch, lacks documentation and tests | Accumulating technical debt |

### Design Anti-Patterns

| Anti-Pattern | Signals | Recommendation |
|-------------|---------|---------------|
| **Golden Hammer** | Using the same technology/pattern for every problem | Choose the right solution for each problem |
| **Overengineering (Gas Factory)** | Solving simple problems with complex solutions, overusing design patterns | Apply the YAGNI principle: start simple, add complexity only when needed |
| **Boat Anchor** | Unused code written for "maybe needed someday" | Delete unused code; write it when actually needed |
| **Copy-Paste Programming** | Same logic appearing in multiple places | Extract into a shared method or module |

### Review Questions

```markdown
🔴 [blocking] "This class has 2000 lines of code — recommend splitting it into multiple focused classes"
🟡 [important] "This logic is duplicated in 3 places — consider extracting it into a shared method?"
💡 [suggestion] "This switch statement could be replaced with the Strategy pattern for easier extensibility"
```

---

## Coupling and Cohesion Assessment

### Types of Coupling (best to worst)

| Type | Description | Example |
|------|-------------|---------|
| **Message Coupling** ✅ | Data passed via parameters | `calculate(price, quantity)` |
| **Data Coupling** ✅ | Sharing simple data structures | `processOrder(orderDTO)` |
| **Stamp Coupling** ⚠️ | Sharing complex data structures but using only part | Passing an entire User object but only using name |
| **Control Coupling** ⚠️ | Passing control flags that influence behavior | `process(data, isAdmin=true)` |
| **Common Coupling** ❌ | Sharing global variables | Multiple modules reading/writing the same global state |
| **Content Coupling** ❌ | Directly accessing another module's internals | Directly manipulating another class's private properties |

### Types of Cohesion (best to worst)

| Type | Description | Quality |
|------|-------------|---------|
| **Functional Cohesion** | All elements accomplish a single task | ✅ Best |
| **Sequential Cohesion** | Output of one step is input for the next | ✅ Good |
| **Communicational Cohesion** | Operate on the same data | ⚠️ Acceptable |
| **Temporal Cohesion** | Tasks executed at the same time | ⚠️ Poor |
| **Logical Cohesion** | Logically related but functionally different | ❌ Bad |
| **Coincidental Cohesion** | No apparent relationship | ❌ Worst |

### Reference Metrics

```yaml
Coupling metrics:
  CBO (Coupling Between Objects):
    Good: < 5
    Warning: 5-10
    Danger: > 10

  Ce (Efferent Coupling):
    Description: How many external classes this depends on
    Good: < 7

  Ca (Afferent Coupling):
    Description: How many classes depend on this
    High value means: Changes have wide impact; keep it stable

Cohesion metrics:
  LCOM4 (Lack of Cohesion in Methods):
    1: Single responsibility ✅
    2-3: May need splitting ⚠️
    >3: Should be split ❌
```

### Review Questions

- "How many other modules does this module depend on? Can that number be reduced?"
- "How many other places will be affected when this class is changed?"
- "Do all methods in this class operate on the same data?"

---

## Layered Architecture Review

### Clean Architecture Layer Check

```
┌─────────────────────────────────────┐
│         Frameworks & Drivers        │ ← Outermost: Web, DB, UI
├─────────────────────────────────────┤
│         Interface Adapters          │ ← Controllers, Gateways, Presenters
├─────────────────────────────────────┤
│          Application Layer          │ ← Use Cases, Application Services
├─────────────────────────────────────┤
│            Domain Layer             │ ← Entities, Domain Services
└─────────────────────────────────────┘
          ↑ Dependencies only point inward ↑
```

### Dependency Rule Check

**Core rule: Source code dependencies can only point toward inner layers**

```typescript
// ❌ Violates dependency rule: Domain layer depends on Infrastructure
// domain/User.ts
import { MySQLConnection } from '../infrastructure/database';

// ✅ Correct: Domain layer defines interface, Infrastructure implements it
// domain/UserRepository.ts (interface)
interface UserRepository {
  findById(id: string): Promise<User>;
}

// infrastructure/MySQLUserRepository.ts (implementation)
class MySQLUserRepository implements UserRepository {
  findById(id: string): Promise<User> { /* ... */ }
}
```

### Review Checklist

**Layer boundary checks:**
- [ ] Does the Domain layer have external dependencies (database, HTTP, file system)?
- [ ] Does the Application layer directly access the database or call external APIs?
- [ ] Does the Controller contain business logic?
- [ ] Are there cross-layer calls (UI calling Repository directly)?

**Separation of concerns checks:**
- [ ] Is business logic separated from presentation logic?
- [ ] Is data access encapsulated in a dedicated layer?
- [ ] Is configuration and environment-specific code centrally managed?

### Review Questions

```markdown
🔴 [blocking] "Domain entity directly imports a database connection — violates the dependency rule"
🟡 [important] "Controller contains business calculation logic — recommend moving it to the Service layer"
💡 [suggestion] "Consider using dependency injection to decouple these components"
```

---

## Design Pattern Usage Assessment

### When to Use Design Patterns

| Pattern | Suitable scenarios | Unsuitable scenarios |
|---------|-------------------|---------------------|
| **Factory** | Need to create different types of objects; type determined at runtime | Only one type, or type is fixed |
| **Strategy** | Algorithm needs to switch at runtime; multiple interchangeable behaviors | Only one algorithm, or algorithm never changes |
| **Observer** | One-to-many dependency; state changes need to notify multiple objects | Simple direct calls are sufficient |
| **Singleton** | A globally unique instance is truly required, e.g., configuration management | Objects that can be passed via dependency injection |
| **Decorator** | Need to dynamically add responsibilities; avoid inheritance explosion | Responsibilities are fixed and don't need dynamic composition |

### Overengineering Warning Signals

```
⚠️ Patternitis (pattern overuse) signals:

1. A simple if/else replaced by Strategy + Factory + Registry
2. Interfaces with only one implementation
3. Abstraction layers added for "might be needed someday"
4. Line count increases dramatically due to pattern application
5. New team members take a long time to understand the code structure
```

### Review Principles

```markdown
✅ Correct pattern use:
- Solves a real extensibility problem
- Makes the code easier to understand and test
- Adding new features becomes simpler

❌ Overusing patterns:
- Using a pattern for the sake of using a pattern
- Adds unnecessary complexity
- Violates the YAGNI principle
```

### Review Questions

- "What specific problem does this pattern solve?"
- "What would be wrong with the code if this pattern were not used?"
- "Does the value this abstraction layer provides outweigh its complexity?"

---

## Scalability Assessment

### Extensibility Checklist

**Feature extensibility:**
- [ ] Does adding new functionality require modifying core code?
- [ ] Are extension points provided (hooks, plugins, events)?
- [ ] Is configuration externalized (config files, environment variables)?

**Data extensibility:**
- [ ] Does the data model support adding new fields?
- [ ] Has data volume growth been considered?
- [ ] Do queries have appropriate indexes?

**Load scalability:**
- [ ] Can the system scale horizontally (adding more instances)?
- [ ] Are there stateful dependencies (sessions, local cache)?
- [ ] Does the database connection use a connection pool?

### Extension Point Design Check

```typescript
// ✅ Good extensible design: using events/hooks
class OrderService {
  private hooks: OrderHooks;

  async createOrder(order: Order) {
    await this.hooks.beforeCreate?.(order);
    const result = await this.save(order);
    await this.hooks.afterCreate?.(result);
    return result;
  }
}

// ❌ Poor extensible design: all behavior is hardcoded
class OrderService {
  async createOrder(order: Order) {
    await this.sendEmail(order);        // Hardcoded
    await this.updateInventory(order);  // Hardcoded
    await this.notifyWarehouse(order);  // Hardcoded
    return await this.save(order);
  }
}
```

### Review Questions

```markdown
💡 [suggestion] "If a new payment method needs to be supported in the future, is this design easy to extend?"
🟡 [important] "The logic here is hardcoded — consider using configuration or the Strategy pattern?"
📚 [learning] "An event-driven architecture would make this feature easier to extend"
```

---

## Code Structure Best Practices

### Directory Organization

**Organized by feature/domain (recommended):**
```
src/
├── user/
│   ├── User.ts           (entity)
│   ├── UserService.ts    (service)
│   ├── UserRepository.ts (data access)
│   └── UserController.ts (API)
├── order/
│   ├── Order.ts
│   ├── OrderService.ts
│   └── ...
└── shared/
    ├── utils/
    └── types/
```

**Organized by technical layer (not recommended):**
```
src/
├── controllers/     ← Different domains mixed together
│   ├── UserController.ts
│   └── OrderController.ts
├── services/
├── repositories/
└── models/
```

### Naming Convention Check

| Type | Convention | Example |
|------|-----------|---------|
| Class name | PascalCase, noun | `UserService`, `OrderRepository` |
| Method name | camelCase, verb | `createUser`, `findOrderById` |
| Interface name | I prefix or no prefix | `IUserService` or `UserService` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Private property | Underscore prefix or none | `_cache` or `#cache` |

### File Size Guidelines

```yaml
Recommended limits:
  Single file: < 300 lines
  Single function: < 50 lines
  Single class: < 200 lines
  Function parameters: < 4
  Nesting depth: < 4 levels

When limits are exceeded:
  - Consider splitting into smaller units
  - Use composition over inheritance
  - Extract helper functions or classes
```

### Review Questions

```markdown
🟢 [nit] "This 500-line file could be split by responsibility"
🟡 [important] "Recommend organizing the directory structure by feature domain rather than technical layer"
💡 [suggestion] "The function name `process` is unclear — consider renaming it to `calculateOrderTotal`?"
```

---

## Quick Reference Checklist

### Architecture Review 5-Minute Checklist

```markdown
□ Are dependencies pointing in the correct direction? (outer layers depend on inner layers)
□ Are there any circular dependencies?
□ Is core business logic decoupled from frameworks/UI/databases?
□ Are SOLID principles followed?
□ Are there any obvious anti-patterns?
```

### Red Flags (must address)

```markdown
🔴 God Object — single class exceeds 1000 lines
🔴 Circular dependency — A → B → C → A
🔴 Domain layer contains framework dependencies
🔴 Hardcoded configuration and secrets
🔴 External service calls without interfaces
```

### Yellow Flags (recommended to address)

```markdown
🟡 Coupling Between Objects (CBO) > 10
🟡 Method has more than 5 parameters
🟡 Nesting depth exceeds 4 levels
🟡 Duplicated code block > 10 lines
🟡 Interface with only one implementation
```

---

## Recommended Tools

| Tool | Purpose | Language Support |
|------|---------|-----------------|
| **SonarQube** | Code quality, coupling analysis | Multi-language |
| **NDepend** | Dependency analysis, architecture rules | .NET |
| **JDepend** | Package dependency analysis | Java |
| **Madge** | Module dependency graph | JavaScript/TypeScript |
| **ESLint** | Code standards, complexity checks | JavaScript/TypeScript |
| **CodeScene** | Technical debt, hotspot analysis | Multi-language |

---

## References

- [Clean Architecture - Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SOLID Principles in Code Review - JetBrains](https://blog.jetbrains.com/upsource/2015/08/31/what-to-look-for-in-a-code-review-solid-principles-2/)
- [Software Architecture Anti-Patterns](https://medium.com/@christophnissle/anti-patterns-in-software-architecture-3c8970c9c4f5)
- [Coupling and Cohesion in System Design](https://www.geeksforgeeks.org/system-design/coupling-and-cohesion-in-system-design/)
- [Design Patterns - Refactoring Guru](https://refactoring.guru/design-patterns)
