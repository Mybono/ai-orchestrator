# Rust Code Review Guide

> Rust code review guide. The compiler catches memory safety issues, but reviewers need to focus on problems the compiler cannot detect — business logic, API design, performance, cancellation safety, and maintainability.

## Table of Contents

- [Ownership and Borrowing](#ownership-and-borrowing)
- [Unsafe Code Review](#unsafe-code-review-most-critical)
- [Async Code](#async-code)
- [Cancellation Safety](#cancellation-safety)
- [spawn vs await](#spawn-vs-await)
- [Error Handling](#error-handling)
- [Performance](#performance)
- [Trait Design](#trait-design)
- [Review Checklist](#rust-review-checklist)

---

## Ownership and Borrowing

### Avoid Unnecessary clone()

```rust
// ❌ clone() is "Rust's duct tape" — used to work around the borrow checker
fn bad_process(data: &Data) -> Result<()> {
    let owned = data.clone();  // why is this clone needed?
    expensive_operation(owned)
}

// ✅ Ask during review: is the clone necessary? Can a borrow be used instead?
fn good_process(data: &Data) -> Result<()> {
    expensive_operation(data)  // pass a reference
}

// ✅ If a clone is truly needed, add a comment explaining why
fn justified_clone(data: &Data) -> Result<()> {
    // Clone needed: data will be moved to spawned task
    let owned = data.clone();
    tokio::spawn(async move {
        process(owned).await
    });
    Ok(())
}
```

### Using Arc<Mutex<T>>

```rust
// ❌ Arc<Mutex<T>> can hide unnecessary shared state
struct BadService {
    cache: Arc<Mutex<HashMap<String, Data>>>,  // is sharing really needed?
}

// ✅ Consider whether sharing is needed, or if the design can avoid it
struct GoodService {
    cache: HashMap<String, Data>,  // single owner
}

// ✅ If concurrent access is truly needed, consider a better data structure
use dashmap::DashMap;

struct ConcurrentService {
    cache: DashMap<String, Data>,  // more fine-grained locking
}
```

### Cow (Copy-on-Write) Pattern

```rust
use std::borrow::Cow;

// ❌ Always allocates a new string
fn bad_process_name(name: &str) -> String {
    if name.is_empty() {
        "Unknown".to_string()  // allocates
    } else {
        name.to_string()  // unnecessary allocation
    }
}

// ✅ Use Cow to avoid unnecessary allocations
fn good_process_name(name: &str) -> Cow<'_, str> {
    if name.is_empty() {
        Cow::Borrowed("Unknown")  // static string, no allocation
    } else {
        Cow::Borrowed(name)  // borrows the original data
    }
}

// ✅ Only allocate when modification is needed
fn normalize_name(name: &str) -> Cow<'_, str> {
    if name.chars().any(|c| c.is_uppercase()) {
        Cow::Owned(name.to_lowercase())  // needs modification, allocates
    } else {
        Cow::Borrowed(name)  // no modification needed, borrows
    }
}
```

---

## Unsafe Code Review (Most Critical!)

### Basic Requirements

```rust
// ❌ unsafe without safety documentation — this is a red flag
unsafe fn bad_transmute<T, U>(t: T) -> U {
    std::mem::transmute(t)
}

// ✅ Every unsafe must explain: why is it safe? what invariants must hold?
/// Transmutes `T` to `U`.
///
/// # Safety
///
/// - `T` and `U` must have the same size and alignment
/// - `T` must be a valid bit pattern for `U`
/// - The caller ensures no references to `t` exist after this call
unsafe fn documented_transmute<T, U>(t: T) -> U {
    // SAFETY: Caller guarantees size/alignment match and bit validity
    std::mem::transmute(t)
}
```

### Unsafe Block Comments

```rust
// ❌ unsafe block with no explanation
fn bad_get_unchecked(slice: &[u8], index: usize) -> u8 {
    unsafe { *slice.get_unchecked(index) }
}

// ✅ Every unsafe block must have a SAFETY comment
fn good_get_unchecked(slice: &[u8], index: usize) -> u8 {
    debug_assert!(index < slice.len(), "index out of bounds");
    // SAFETY: We verified index < slice.len() via debug_assert.
    // In release builds, callers must ensure valid index.
    unsafe { *slice.get_unchecked(index) }
}

// ✅ Wrap unsafe to provide a safe API
pub fn checked_get(slice: &[u8], index: usize) -> Option<u8> {
    if index < slice.len() {
        // SAFETY: bounds check performed above
        Some(unsafe { *slice.get_unchecked(index) })
    } else {
        None
    }
}
```

### Common unsafe Patterns

```rust
// ✅ FFI boundary
extern "C" {
    fn external_function(ptr: *const u8, len: usize) -> i32;
}

pub fn safe_wrapper(data: &[u8]) -> Result<i32, Error> {
    // SAFETY: data.as_ptr() is valid for data.len() bytes,
    // and external_function only reads from the buffer.
    let result = unsafe {
        external_function(data.as_ptr(), data.len())
    };
    if result < 0 {
        Err(Error::from_code(result))
    } else {
        Ok(result)
    }
}

// ✅ unsafe on performance-critical paths
pub fn fast_copy(src: &[u8], dst: &mut [u8]) {
    assert_eq!(src.len(), dst.len(), "slices must be equal length");
    // SAFETY: src and dst are valid slices of equal length,
    // and dst is mutable so no aliasing.
    unsafe {
        std::ptr::copy_nonoverlapping(
            src.as_ptr(),
            dst.as_mut_ptr(),
            src.len()
        );
    }
}
```

---

## Async Code

### Avoid Blocking Operations

```rust
// ❌ Blocking inside an async context — starves other tasks
async fn bad_async() {
    let data = std::fs::read_to_string("file.txt").unwrap();  // blocks!
    std::thread::sleep(Duration::from_secs(1));  // blocks!
}

// ✅ Use async APIs
async fn good_async() -> Result<String> {
    let data = tokio::fs::read_to_string("file.txt").await?;
    tokio::time::sleep(Duration::from_secs(1)).await;
    Ok(data)
}

// ✅ If blocking is unavoidable, use spawn_blocking
async fn with_blocking() -> Result<Data> {
    let result = tokio::task::spawn_blocking(|| {
        // blocking operations are safe here
        expensive_cpu_computation()
    }).await?;
    Ok(result)
}
```

### Mutex and .await

```rust
// ❌ Holding std::sync::Mutex across .await — may deadlock
async fn bad_lock(mutex: &std::sync::Mutex<Data>) {
    let guard = mutex.lock().unwrap();
    async_operation().await;  // holding lock while waiting!
    process(&guard);
}

// ✅ Option 1: minimize lock scope
async fn good_lock_scoped(mutex: &std::sync::Mutex<Data>) {
    let data = {
        let guard = mutex.lock().unwrap();
        guard.clone()  // release the lock immediately
    };
    async_operation().await;
    process(&data);
}

// ✅ Option 2: use tokio::sync::Mutex (can be held across await)
async fn good_lock_tokio(mutex: &tokio::sync::Mutex<Data>) {
    let guard = mutex.lock().await;
    async_operation().await;  // OK: tokio Mutex is designed for cross-await use
    process(&guard);
}

// 💡 Selection guide:
// - std::sync::Mutex: low contention, short critical sections, no cross-await
// - tokio::sync::Mutex: needs cross-await, high contention scenarios
```

### Async Trait Methods

```rust
// ❌ Pitfall of async trait methods (older versions)
#[async_trait]
trait BadRepository {
    async fn find(&self, id: i64) -> Option<Entity>;  // implicit Box
}

// ✅ Rust 1.75+: native async trait methods
trait Repository {
    async fn find(&self, id: i64) -> Option<Entity>;

    // Return a concrete Future type to avoid allocation
    fn find_many(&self, ids: &[i64]) -> impl Future<Output = Vec<Entity>> + Send;
}

// ✅ For cases that require dyn
trait DynRepository: Send + Sync {
    fn find(&self, id: i64) -> Pin<Box<dyn Future<Output = Option<Entity>> + Send + '_>>;
}
```

---

## Cancellation Safety

### What is Cancellation Safety

```rust
// When a Future is dropped at an .await point, what state is it in?
// Cancellation-safe Future: can be safely cancelled at any await point
// Non-cancellation-safe Future: cancellation may cause data loss or inconsistent state

// ❌ Example of a non-cancellation-safe future
async fn cancel_unsafe(conn: &mut Connection) -> Result<()> {
    let data = receive_data().await;  // if cancelled here...
    conn.send_ack().await;  // ...the ack is never sent, data may be lost
    Ok(())
}

// ✅ Cancellation-safe version
async fn cancel_safe(conn: &mut Connection) -> Result<()> {
    // use a transaction or atomic operation to ensure consistency
    let transaction = conn.begin_transaction().await?;
    let data = receive_data().await;
    transaction.commit_with_ack(data).await?;  // atomic operation
    Ok(())
}
```

### Cancellation Safety in select

```rust
use tokio::select;

// ❌ Using a non-cancellation-safe Future in select!
async fn bad_select(stream: &mut TcpStream) {
    let mut buffer = vec![0u8; 1024];
    loop {
        select! {
            // if timeout completes first, read is cancelled
            // partially read data may be lost!
            result = stream.read(&mut buffer) => {
                handle_data(&buffer[..result?]);
            }
            _ = tokio::time::sleep(Duration::from_secs(5)) => {
                println!("Timeout");
            }
        }
    }
}

// ✅ Use a cancellation-safe API
async fn good_select(stream: &mut TcpStream) {
    let mut buffer = vec![0u8; 1024];
    loop {
        select! {
            // tokio::io::AsyncReadExt::read is cancellation-safe
            // on cancellation, unread data remains in the stream
            result = stream.read(&mut buffer) => {
                match result {
                    Ok(0) => break,  // EOF
                    Ok(n) => handle_data(&buffer[..n]),
                    Err(e) => return Err(e),
                }
            }
            _ = tokio::time::sleep(Duration::from_secs(5)) => {
                println!("Timeout, retrying...");
            }
        }
    }
}

// ✅ Use tokio::pin! to ensure Futures can be safely reused
async fn pinned_select() {
    let sleep = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(sleep);

    loop {
        select! {
            _ = &mut sleep => {
                println!("Timer elapsed");
                break;
            }
            data = receive_data() => {
                process(data).await;
                // sleep continues counting down, not reset
            }
        }
    }
}
```

### Documenting Cancellation Safety

```rust
/// Reads a complete message from the stream.
///
/// # Cancel Safety
///
/// This method is **not** cancel safe. If cancelled while reading,
/// partial data may be lost and the stream state becomes undefined.
/// Use `read_message_cancel_safe` if cancellation is expected.
async fn read_message(stream: &mut TcpStream) -> Result<Message> {
    let len = stream.read_u32().await?;
    let mut buffer = vec![0u8; len as usize];
    stream.read_exact(&mut buffer).await?;
    Ok(Message::from_bytes(&buffer))
}

/// Reads a message with cancel safety.
///
/// # Cancel Safety
///
/// This method is cancel safe. If cancelled, any partial data
/// is preserved in the internal buffer for the next call.
async fn read_message_cancel_safe(reader: &mut BufferedReader) -> Result<Message> {
    reader.read_message_buffered().await
}
```

---

## spawn vs await

### When to Use spawn

```rust
// ❌ Unnecessary spawn — adds overhead, loses structured concurrency
async fn bad_unnecessary_spawn() {
    let handle = tokio::spawn(async {
        simple_operation().await
    });
    handle.await.unwrap();  // why not just await directly?
}

// ✅ Directly await simple operations
async fn good_direct_await() {
    simple_operation().await;
}

// ✅ spawn for truly parallel execution
async fn good_parallel_spawn() {
    let task1 = tokio::spawn(fetch_from_service_a());
    let task2 = tokio::spawn(fetch_from_service_b());

    // both requests execute in parallel
    let (result1, result2) = tokio::try_join!(task1, task2)?;
}

// ✅ spawn for background tasks (fire-and-forget)
async fn good_background_spawn() {
    // start a background task without waiting for it
    tokio::spawn(async {
        cleanup_old_sessions().await;
        log_metrics().await;
    });

    // continue with other work
    handle_request().await;
}
```

### The 'static Requirement for spawn

```rust
// ❌ Futures passed to spawn must be 'static
async fn bad_spawn_borrow(data: &Data) {
    tokio::spawn(async {
        process(data).await;  // Error: `data` is not 'static
    });
}

// ✅ Option 1: clone the data
async fn good_spawn_clone(data: &Data) {
    let owned = data.clone();
    tokio::spawn(async move {
        process(&owned).await;
    });
}

// ✅ Option 2: share via Arc
async fn good_spawn_arc(data: Arc<Data>) {
    let data = Arc::clone(&data);
    tokio::spawn(async move {
        process(&data).await;
    });
}

// ✅ Option 3: use scoped tasks (tokio-scoped or async-scoped)
async fn good_scoped_spawn(data: &Data) {
    // assuming the async-scoped crate
    async_scoped::scope(|s| async {
        s.spawn(async {
            process(data).await;  // can borrow
        });
    }).await;
}
```

### JoinHandle Error Handling

```rust
// ❌ Ignoring spawn errors
async fn bad_ignore_spawn_error() {
    let handle = tokio::spawn(async {
        risky_operation().await
    });
    let _ = handle.await;  // panics and errors are ignored
}

// ✅ Handle JoinHandle results correctly
async fn good_handle_spawn_error() -> Result<()> {
    let handle = tokio::spawn(async {
        risky_operation().await
    });

    match handle.await {
        Ok(Ok(result)) => {
            // task completed successfully
            process_result(result);
            Ok(())
        }
        Ok(Err(e)) => {
            // error inside the task
            Err(e.into())
        }
        Err(join_err) => {
            // task panicked or was cancelled
            if join_err.is_panic() {
                error!("Task panicked: {:?}", join_err);
            }
            Err(anyhow!("Task failed: {}", join_err))
        }
    }
}
```

### Structured Concurrency vs spawn

```rust
// ✅ Prefer join! (structured concurrency)
async fn structured_concurrency() -> Result<(A, B, C)> {
    // all tasks are within the same scope
    // if any one fails, the others are cancelled
    tokio::try_join!(
        fetch_a(),
        fetch_b(),
        fetch_c()
    )
}

// ✅ Consider task lifetime when using spawn
struct TaskManager {
    handles: Vec<JoinHandle<()>>,
}

impl TaskManager {
    async fn shutdown(self) {
        // graceful shutdown: wait for all tasks to complete
        for handle in self.handles {
            if let Err(e) = handle.await {
                error!("Task failed during shutdown: {}", e);
            }
        }
    }

    async fn abort_all(self) {
        // forced shutdown: cancel all tasks
        for handle in self.handles {
            handle.abort();
        }
    }
}
```

---

## Error Handling

### Library vs Application Error Types

```rust
// ❌ Using anyhow in library code — callers cannot match on the error
pub fn parse_config(s: &str) -> anyhow::Result<Config> { ... }

// ✅ Use thiserror in libraries, anyhow in applications
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("invalid syntax at line {line}: {message}")]
    Syntax { line: usize, message: String },
    #[error("missing required field: {0}")]
    MissingField(String),
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

pub fn parse_config(s: &str) -> Result<Config, ConfigError> { ... }
```

### Preserving Error Context

```rust
// ❌ Swallowing error context
fn bad_error() -> Result<()> {
    operation().map_err(|_| anyhow!("failed"))?;  // original error is lost
    Ok(())
}

// ✅ Use context to preserve the error chain
fn good_error() -> Result<()> {
    operation().context("failed to perform operation")?;
    Ok(())
}

// ✅ Use with_context for lazy evaluation
fn good_error_lazy() -> Result<()> {
    operation()
        .with_context(|| format!("failed to process file: {}", filename))?;
    Ok(())
}
```

### Error Type Design

```rust
// ✅ Use #[source] to preserve the error chain
#[derive(Debug, thiserror::Error)]
pub enum ServiceError {
    #[error("database error")]
    Database(#[source] sqlx::Error),

    #[error("network error: {message}")]
    Network {
        message: String,
        #[source]
        source: reqwest::Error,
    },

    #[error("validation failed: {0}")]
    Validation(String),
}

// ✅ Implement From for common conversions
impl From<sqlx::Error> for ServiceError {
    fn from(err: sqlx::Error) -> Self {
        ServiceError::Database(err)
    }
}
```

---

## Performance

### Avoid Unnecessary collect()

```rust
// ❌ Unnecessary collect — intermediate allocation
fn bad_sum(items: &[i32]) -> i32 {
    items.iter()
        .filter(|x| **x > 0)
        .collect::<Vec<_>>()  // unnecessary!
        .iter()
        .sum()
}

// ✅ Lazy iteration
fn good_sum(items: &[i32]) -> i32 {
    items.iter().filter(|x| **x > 0).copied().sum()
}
```

### String Concatenation

```rust
// ❌ String concatenation in a loop reallocates every time
fn bad_concat(items: &[&str]) -> String {
    let mut s = String::new();
    for item in items {
        s = s + item;  // reallocates every time!
    }
    s
}

// ✅ Pre-allocate or use join
fn good_concat(items: &[&str]) -> String {
    items.join("")
}

// ✅ Pre-allocate with with_capacity
fn good_concat_capacity(items: &[&str]) -> String {
    let total_len: usize = items.iter().map(|s| s.len()).sum();
    let mut result = String::with_capacity(total_len);
    for item in items {
        result.push_str(item);
    }
    result
}

// ✅ Use the write! macro
use std::fmt::Write;

fn good_concat_write(items: &[&str]) -> String {
    let mut result = String::new();
    for item in items {
        write!(result, "{}", item).unwrap();
    }
    result
}
```

### Avoid Unnecessary Allocations

```rust
// ❌ Unnecessary Vec allocation
fn bad_check_any(items: &[Item]) -> bool {
    let filtered: Vec<_> = items.iter()
        .filter(|i| i.is_valid())
        .collect();
    !filtered.is_empty()
}

// ✅ Use iterator methods
fn good_check_any(items: &[Item]) -> bool {
    items.iter().any(|i| i.is_valid())
}

// ❌ String::from for static strings
fn bad_static() -> String {
    String::from("error message")  // runtime allocation
}

// ✅ Return &'static str
fn good_static() -> &'static str {
    "error message"  // no allocation
}
```

---

## Trait Design

### Avoid Over-Abstraction

```rust
// ❌ Over-abstraction — this is not Java, not everything needs an Interface
trait Processor { fn process(&self); }
trait Handler { fn handle(&self); }
trait Manager { fn manage(&self); }  // too many traits

// ✅ Only create a trait when polymorphism is needed
// Concrete types are usually simpler and faster
struct DataProcessor {
    config: Config,
}

impl DataProcessor {
    fn process(&self, data: &Data) -> Result<Output> {
        // direct implementation
    }
}
```

### Trait Objects vs Generics

```rust
// ❌ Unnecessary trait object (dynamic dispatch)
fn bad_process(handler: &dyn Handler) {
    handler.handle();  // vtable call
}

// ✅ Use generics (static dispatch, inlinable)
fn good_process<H: Handler>(handler: &H) {
    handler.handle();  // may be inlined
}

// ✅ Trait objects are appropriate for heterogeneous collections
fn store_handlers(handlers: Vec<Box<dyn Handler>>) {
    // need to store handlers of different types
}

// ✅ Use impl Trait return types
fn create_handler() -> impl Handler {
    ConcreteHandler::new()
}
```

---

## Rust Review Checklist

### Issues the Compiler Cannot Catch

**Business Logic Correctness**

- [ ] Boundary conditions are handled correctly
- [ ] State machine transitions are complete
- [ ] Race conditions in concurrent scenarios

**API Design**

- [ ] Public APIs are hard to misuse
- [ ] Type signatures clearly express intent
- [ ] Error type granularity is appropriate

### Ownership and Borrowing

- [ ] clone() is intentional and documented with a reason
- [ ] Arc<Mutex<T>> is truly necessary for shared state
- [ ] RefCell usage is justified
- [ ] Lifetimes are not overly complex
- [ ] Consider using Cow to avoid unnecessary allocations

### Unsafe Code (Most Important)

- [ ] Every unsafe block has a SAFETY comment
- [ ] unsafe fn has a # Safety documentation section
- [ ] Explains why it is safe, not just what it does
- [ ] Lists the invariants that must be maintained
- [ ] unsafe boundary is as small as possible
- [ ] A safe alternative was considered

### Async / Concurrency

- [ ] No blocking calls inside async (std::fs, thread::sleep)
- [ ] std::sync locks are not held across .await
- [ ] Spawned tasks satisfy 'static
- [ ] Lock acquisition order is consistent
- [ ] Channel buffer sizes are appropriate

### Cancellation Safety

- [ ] Futures inside select! are cancellation-safe
- [ ] Cancellation safety of async functions is documented
- [ ] Cancellation does not cause data loss or inconsistent state
- [ ] tokio::pin! is used correctly for Futures that need to be reused

### spawn vs await

- [ ] spawn is only used when true parallelism is needed
- [ ] Simple operations are awaited directly, not spawned
- [ ] JoinHandle results are handled correctly
- [ ] Task lifetime and shutdown strategy are considered
- [ ] join!/try_join! is preferred for structured concurrency

### Error Handling

- [ ] Libraries: thiserror for structured errors
- [ ] Applications: anyhow + context
- [ ] No unwrap/expect in production code
- [ ] Error messages are helpful for debugging
- [ ] must_use return values are handled
- [ ] #[source] is used to preserve the error chain

### Performance

- [ ] Avoid unnecessary collect()
- [ ] Large data is passed by reference
- [ ] Strings use with_capacity or write!
- [ ] impl Trait vs Box<dyn Trait> choice is appropriate
- [ ] Hot paths avoid allocations
- [ ] Consider using Cow to reduce cloning

### Code Quality

- [ ] cargo clippy has zero warnings
- [ ] cargo fmt is applied
- [ ] Documentation comments are complete
- [ ] Tests cover edge cases
- [ ] Public APIs have documentation examples
