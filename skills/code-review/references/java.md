# Java Code Review Guide

Java review focus areas: Java 17/21 new features, Spring Boot 3 best practices, concurrent programming (virtual threads), JPA performance optimization, and code maintainability.

## Table of Contents

- [Modern Java Features (17/21+)](#modern-java-features-1721)
- [Stream API & Optional](#stream-api--optional)
- [Spring Boot Best Practices](#spring-boot-best-practices)
- [JPA & Database Performance](#jpa--database-performance)
- [Concurrency & Virtual Threads](#concurrency--virtual-threads)
- [Lombok Usage Guidelines](#lombok-usage-guidelines)
- [Exception Handling](#exception-handling)
- [Testing Guidelines](#testing-guidelines)
- [Review Checklist](#review-checklist)

---

## Modern Java Features (17/21+)

### Record Classes

```java
// ❌ Traditional POJO/DTO: lots of boilerplate
public class UserDto {
    private final String name;
    private final int age;

    public UserDto(String name, int age) {
        this.name = name;
        this.age = age;
    }
    // getters, equals, hashCode, toString...
}

// ✅ Use Record: concise, immutable, semantically clear
public record UserDto(String name, int age) {
    // Compact constructor for validation
    public UserDto {
        if (age < 0) throw new IllegalArgumentException("Age cannot be negative");
    }
}
```

### Switch Expressions and Pattern Matching

```java
// ❌ Traditional switch: easy to forget break, verbose and error-prone
String type = "";
switch (obj) {
    case Integer i: // Java 16+
        type = String.format("int %d", i);
        break;
    case String s:
        type = String.format("string %s", s);
        break;
    default:
        type = "unknown";
}

// ✅ Switch expression: no fall-through risk, return value is enforced
String type = switch (obj) {
    case Integer i -> "int %d".formatted(i);
    case String s  -> "string %s".formatted(s);
    case null      -> "null value"; // Java 21 handles null
    default        -> "unknown";
};
```

### Text Blocks

```java
// ❌ Concatenating SQL/JSON strings
String json = "{\n" +
              "  \"name\": \"Alice\",\n" +
              "  \"age\": 20\n" +
              "}";

// ✅ Use text blocks: what-you-see-is-what-you-get
String json = """
    {
      "name": "Alice",
      "age": 20
    }
    """;
```

---

## Stream API & Optional

### Avoid Overusing Streams

```java
// ❌ Simple loops don't need Stream (performance overhead + worse readability)
items.stream().forEach(item -> {
    process(item);
});

// ✅ Use for-each for simple cases
for (var item : items) {
    process(item);
}

// ❌ Excessively complex stream chains
List<Dto> result = list.stream()
    .filter(...)
    .map(...)
    .peek(...)
    .sorted(...)
    .collect(...); // Hard to debug

// ✅ Break into meaningful steps
var filtered = list.stream().filter(...).toList();
// ...
```

### Correct Optional Usage

```java
// ❌ Using Optional as a parameter or field (serialization issues, increases call complexity)
public void process(Optional<String> name) { ... }
public class User {
    private Optional<String> email; // Not recommended
}

// ✅ Optional should only be used as a return value
public Optional<User> findUser(String id) { ... }

// ❌ Using Optional but still calling isPresent() + get()
Optional<User> userOpt = findUser(id);
if (userOpt.isPresent()) {
    return userOpt.get().getName();
} else {
    return "Unknown";
}

// ✅ Use the functional API
return findUser(id)
    .map(User::getName)
    .orElse("Unknown");
```

---

## Spring Boot Best Practices

### Dependency Injection (DI)

```java
// ❌ Field injection (@Autowired)
// Drawbacks: hard to test (requires reflection injection), hides too many dependencies, poor immutability
@Service
public class UserService {
    @Autowired
    private UserRepository userRepo;
}

// ✅ Constructor injection
// Benefits: dependencies are explicit, easy to unit test (mock), fields can be final
@Service
public class UserService {
    private final UserRepository userRepo;

    public UserService(UserRepository userRepo) {
        this.userRepo = userRepo;
    }
}
// 💡 Tip: combine with Lombok @RequiredArgsConstructor to reduce boilerplate, but watch out for circular dependencies
```

### Configuration Management

```java
// ❌ Hard-coded configuration values
@Service
public class PaymentService {
    private String apiKey = "sk_live_12345";
}

// ❌ Scattering @Value annotations throughout the code
@Value("${app.payment.api-key}")
private String apiKey;

// ✅ Use @ConfigurationProperties for type-safe configuration
@ConfigurationProperties(prefix = "app.payment")
public record PaymentProperties(String apiKey, int timeout, String url) {}
```

---

## JPA & Database Performance

### N+1 Query Problem

```java
// ❌ FetchType.EAGER or lazy loading triggered inside a loop
// Entity definition
@Entity
public class User {
    @OneToMany(fetch = FetchType.EAGER) // Dangerous!
    private List<Order> orders;
}

// Business code
List<User> users = userRepo.findAll(); // 1 SQL query
for (User user : users) {
    // If LAZY, this triggers N additional SQL queries
    System.out.println(user.getOrders().size());
}

// ✅ Use @EntityGraph or JOIN FETCH
@Query("SELECT u FROM User u JOIN FETCH u.orders")
List<User> findAllWithOrders();
```

### Transaction Management

```java
// ❌ Opening transactions in the Controller layer (database connection held too long)
// ❌ @Transactional on private methods (AOP proxy does not intercept them)
@Transactional
private void saveInternal() { ... }

// ✅ Apply @Transactional to public methods in the Service layer
// ✅ Explicitly mark read operations with readOnly = true (performance optimization)
@Service
public class UserService {
    @Transactional(readOnly = true)
    public User getUser(Long id) { ... }

    @Transactional
    public void createUser(UserDto dto) { ... }
}
```

### Entity Design

```java
// ❌ Using Lombok @Data on Entities
// @Data generates equals/hashCode covering all fields, which may trigger lazy loading
// and cause performance issues or exceptions
@Entity
@Data
public class User { ... }

// ✅ Use only @Getter and @Setter
// ✅ Implement custom equals/hashCode (typically based on the ID)
@Entity
@Getter
@Setter
public class User {
    @Id
    private Long id;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof User)) return false;
        return id != null && id.equals(((User) o).id);
    }

    @Override
    public int hashCode() {
        return getClass().hashCode();
    }
}
```

---

## Concurrency & Virtual Threads

### Virtual Threads (Java 21+)

```java
// ❌ Traditional thread pools for large numbers of I/O-blocking tasks (resource exhaustion)
ExecutorService executor = Executors.newFixedThreadPool(100);

// ✅ Use virtual threads for I/O-intensive tasks (high throughput)
// Spring Boot 3.2+ enable with: spring.threads.virtual.enabled=true
ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

// With virtual threads, blocking operations (DB queries, HTTP requests) consume almost no OS thread resources
```

### Thread Safety

```java
// ❌ SimpleDateFormat is not thread-safe
private static final SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");

// ✅ Use DateTimeFormatter (Java 8+)
private static final DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy-MM-dd");

// ❌ HashMap can cause infinite loops or data loss in multi-threaded environments
// ✅ Use ConcurrentHashMap
Map<String, String> cache = new ConcurrentHashMap<>();
```

---

## Lombok Usage Guidelines

```java
// ❌ Overusing @Builder makes required fields impossible to enforce
@Builder
public class Order {
    private String id; // Required
    private String note; // Optional
}
// Caller may omit id: Order.builder().note("hi").build();

// ✅ For critical business objects, prefer manually writing Builder or constructors
// to enforce invariants, or use validation inside the build() method (Lombok @Builder.Default, etc.)
```

---

## Exception Handling

### Global Exception Handling

```java
// ❌ try-catch scattered everywhere, swallowing exceptions or only printing stack traces
try {
    userService.create(user);
} catch (Exception e) {
    e.printStackTrace(); // Should not be used in production
    // return null; // Swallows the exception — callers have no idea what happened
}

// ✅ Custom exceptions + @ControllerAdvice (Spring Boot 3 ProblemDetail)
public class UserNotFoundException extends RuntimeException { ... }

@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(UserNotFoundException.class)
    public ProblemDetail handleNotFound(UserNotFoundException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }
}
```

---

## Testing Guidelines

### Unit Tests vs Integration Tests

```java
// ❌ Unit tests that depend on a real database or external services
@SpringBootTest // Starts the full context, slow
public class UserServiceTest { ... }

// ✅ Unit tests using Mockito
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    @Mock UserRepository repo;
    @InjectMocks UserService service;

    @Test
    void shouldCreateUser() { ... }
}

// ✅ Integration tests using Testcontainers
@Testcontainers
@SpringBootTest
class UserRepositoryTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    // ...
}
```

---

## Review Checklist

### Basics & Standards
- [ ] Modern Java 17/21 features used (switch expressions, records, text blocks)
- [ ] Deprecated classes avoided (`Date`, `Calendar`, `SimpleDateFormat`)
- [ ] Stream API or Collections methods preferred for collection operations
- [ ] `Optional` used only as a return value, not in fields or parameters

### Spring Boot
- [ ] Constructor injection used instead of `@Autowired` field injection
- [ ] Configuration properties use `@ConfigurationProperties`
- [ ] Controllers have a single responsibility; business logic is in the Service layer
- [ ] Global exception handling uses `@ControllerAdvice` / `ProblemDetail`

### Database & Transactions
- [ ] Read operations are marked `@Transactional(readOnly = true)`
- [ ] N+1 queries checked (EAGER fetch or calls inside loops)
- [ ] Entity classes do not use `@Data`; `equals`/`hashCode` are correctly implemented
- [ ] Database indexes cover query conditions

### Concurrency & Performance
- [ ] Virtual threads considered for I/O-intensive tasks
- [ ] Thread-safe classes used correctly (`ConcurrentHashMap` vs `HashMap`)
- [ ] Lock granularity is appropriate; I/O operations avoided inside locks

### Maintainability
- [ ] Key business logic has sufficient unit tests
- [ ] Logging is appropriate (use Slf4j, avoid `System.out`)
- [ ] Magic values extracted into constants or enums
