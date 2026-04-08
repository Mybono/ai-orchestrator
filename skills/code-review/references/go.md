# Go Code Review Guide

Code review checklist based on the official Go guidelines, Effective Go, and community best practices.

## Quick Review Checklist

### Required Checks

- [ ] Errors are handled correctly (not ignored, include context)
- [ ] Goroutines have an exit mechanism (prevent leaks)
- [ ] Context is properly propagated and cancelled
- [ ] Receiver type choice is appropriate (value/pointer)
- [ ] Code is formatted with `gofmt`

### Frequent Issues

- [ ] Loop variable capture (Go < 1.22)
- [ ] nil checks are complete
- [ ] Maps are initialized before use
- [ ] defer inside loops
- [ ] Variable shadowing

---

## 1. Error Handling

### 1.1 Never Ignore Errors

```go
// ❌ Wrong: ignoring the error
result, _ := SomeFunction()

// ✅ Correct: handle the error
result, err := SomeFunction()
if err != nil {
    return fmt.Errorf("some function failed: %w", err)
}
```

### 1.2 Error Wrapping and Context

```go
// ❌ Wrong: losing context
if err != nil {
    return err
}

// ❌ Wrong: using %v loses the error chain
if err != nil {
    return fmt.Errorf("failed: %v", err)
}

// ✅ Correct: use %w to preserve the error chain
if err != nil {
    return fmt.Errorf("failed to process user %d: %w", userID, err)
}
```

### 1.3 Use errors.Is and errors.As

```go
// ❌ Wrong: direct comparison (cannot handle wrapped errors)
if err == sql.ErrNoRows {
    // ...
}

// ✅ Correct: use errors.Is (supports error chains)
if errors.Is(err, sql.ErrNoRows) {
    return nil, ErrNotFound
}

// ✅ Correct: use errors.As to extract a specific type
var pathErr *os.PathError
if errors.As(err, &pathErr) {
    log.Printf("path error: %s", pathErr.Path)
}
```

### 1.4 Custom Error Types

```go
// ✅ Recommended: define sentinel errors
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
)

// ✅ Recommended: custom error with context
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation error on %s: %s", e.Field, e.Message)
}
```

### 1.5 Handle Errors Only Once

```go
// ❌ Wrong: both logging and returning (duplicate handling)
if err != nil {
    log.Printf("error: %v", err)
    return err
}

// ✅ Correct: only return, let the caller decide
if err != nil {
    return fmt.Errorf("operation failed: %w", err)
}

// ✅ Or: only log and handle (don't return)
if err != nil {
    log.Printf("non-critical error: %v", err)
    // continue with fallback logic
}
```

---

## 2. Concurrency and Goroutines

### 2.1 Avoid Goroutine Leaks

```go
// ❌ Wrong: goroutine can never exit
func bad() {
    ch := make(chan int)
    go func() {
        val := <-ch // blocks forever, no one sends
        fmt.Println(val)
    }()
    // function returns, goroutine leaks
}

// ✅ Correct: use context or done channel
func good(ctx context.Context) {
    ch := make(chan int)
    go func() {
        select {
        case val := <-ch:
            fmt.Println(val)
        case <-ctx.Done():
            return // graceful exit
        }
    }()
}
```

### 2.2 Channel Usage Guidelines

```go
// ❌ Wrong: sending to nil channel (blocks forever)
var ch chan int
ch <- 1 // blocks forever

// ❌ Wrong: sending to a closed channel (panic)
close(ch)
ch <- 1 // panic!

// ✅ Correct: sender closes the channel
func producer(ch chan<- int) {
    defer close(ch) // sender is responsible for closing
    for i := 0; i < 10; i++ {
        ch <- i
    }
}

// ✅ Correct: receiver detects close
for val := range ch {
    process(val)
}
// or
val, ok := <-ch
if !ok {
    // channel is closed
}
```

### 2.3 Using sync.WaitGroup

```go
// ❌ Wrong: Add inside the goroutine
var wg sync.WaitGroup
for i := 0; i < 10; i++ {
    go func() {
        wg.Add(1) // race condition!
        defer wg.Done()
        work()
    }()
}
wg.Wait()

// ✅ Correct: Add before starting the goroutine
var wg sync.WaitGroup
for i := 0; i < 10; i++ {
    wg.Add(1)
    go func() {
        defer wg.Done()
        work()
    }()
}
wg.Wait()
```

### 2.4 Avoid Capturing Loop Variables (Go < 1.22)

```go
// ❌ Wrong (Go < 1.22): capturing the loop variable
for _, item := range items {
    go func() {
        process(item) // all goroutines may use the same item
    }()
}

// ✅ Correct: pass as argument
for _, item := range items {
    go func(it Item) {
        process(it)
    }(item)
}

// ✅ Go 1.22+: default behavior is fixed, each iteration creates a new variable
```

### 2.5 Worker Pool Pattern

```go
// ✅ Recommended: limit concurrency
func processWithWorkerPool(ctx context.Context, items []Item, workers int) error {
    jobs := make(chan Item, len(items))
    results := make(chan error, len(items))

    // start workers
    for w := 0; w < workers; w++ {
        go func() {
            for item := range jobs {
                results <- process(item)
            }
        }()
    }

    // send jobs
    for _, item := range items {
        jobs <- item
    }
    close(jobs)

    // collect results
    for range items {
        if err := <-results; err != nil {
            return err
        }
    }
    return nil
}
```

---

## 3. Context Usage

### 3.1 Context as First Parameter

```go
// ❌ Wrong: context is not the first parameter
func Process(data []byte, ctx context.Context) error

// ❌ Wrong: context stored in a struct
type Service struct {
    ctx context.Context // don't do this!
}

// ✅ Correct: context as first parameter, named ctx
func Process(ctx context.Context, data []byte) error
```

### 3.2 Propagate, Don't Create New Root Contexts

```go
// ❌ Wrong: creating a new root context in the call chain
func middleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        ctx := context.Background() // loses the request context!
        process(ctx)
        next.ServeHTTP(w, r)
    })
}

// ✅ Correct: obtain and propagate from the request
func middleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        ctx := r.Context()
        ctx = context.WithValue(ctx, key, value)
        process(ctx)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

### 3.3 Always Call the Cancel Function

```go
// ❌ Wrong: cancel not called
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
// missing cancel() call, potential resource leak

// ✅ Correct: use defer to ensure it is called
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
defer cancel() // call even on timeout
```

### 3.4 Respond to Context Cancellation

```go
// ✅ Recommended: check context during long-running operations
func LongRunningTask(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err() // returns context.Canceled or context.DeadlineExceeded
        default:
            // do a small chunk of work
            if err := doChunk(); err != nil {
                return err
            }
        }
    }
}
```

### 3.5 Distinguish Cancellation Reasons

```go
// ✅ Distinguish cancellation reasons via ctx.Err()
if err := ctx.Err(); err != nil {
    switch {
    case errors.Is(err, context.Canceled):
        log.Println("operation was canceled")
    case errors.Is(err, context.DeadlineExceeded):
        log.Println("operation timed out")
    }
    return err
}
```

---

## 4. Interface Design

### 4.1 Accept Interfaces, Return Structs

```go
// ❌ Not recommended: accept concrete type
func SaveUser(db *sql.DB, user User) error

// ✅ Recommended: accept interface (decoupled, testable)
type UserStore interface {
    Save(ctx context.Context, user User) error
}

func SaveUser(store UserStore, user User) error

// ❌ Not recommended: return interface
func NewUserService() UserServiceInterface

// ✅ Recommended: return concrete type
func NewUserService(store UserStore) *UserService
```

### 4.2 Define Interfaces at the Consumer

```go
// ❌ Not recommended: defining the interface in the implementation package
// package database
type Database interface {
    Query(ctx context.Context, query string) ([]Row, error)
    // ... 20 methods
}

// ✅ Recommended: define the minimal interface needed in the consumer package
// package userservice
type UserQuerier interface {
    QueryUsers(ctx context.Context, filter Filter) ([]User, error)
}
```

### 4.3 Keep Interfaces Small and Focused

```go
// ❌ Not recommended: large, all-purpose interface
type Repository interface {
    GetUser(id int) (*User, error)
    CreateUser(u *User) error
    UpdateUser(u *User) error
    DeleteUser(id int) error
    GetOrder(id int) (*Order, error)
    CreateOrder(o *Order) error
    // ... more methods
}

// ✅ Recommended: small, focused interfaces
type UserReader interface {
    GetUser(ctx context.Context, id int) (*User, error)
}

type UserWriter interface {
    CreateUser(ctx context.Context, u *User) error
    UpdateUser(ctx context.Context, u *User) error
}

// composed interface
type UserRepository interface {
    UserReader
    UserWriter
}
```

### 4.4 Avoid Overusing Empty Interfaces

```go
// ❌ Not recommended: excessive use of interface{}
func Process(data interface{}) interface{}

// ✅ Recommended: use generics (Go 1.18+)
func Process[T any](data T) T

// ✅ Recommended: define a concrete interface
type Processor interface {
    Process() Result
}
```

---

## 5. Receiver Type Selection

### 5.1 When to Use Pointer Receivers

```go
// ✅ When the receiver needs to be modified
func (u *User) SetName(name string) {
    u.Name = name
}

// ✅ When the receiver contains sync primitives like sync.Mutex
type SafeCounter struct {
    mu    sync.Mutex
    count int
}

func (c *SafeCounter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// ✅ When the receiver is a large struct (avoid copy overhead)
type LargeStruct struct {
    Data [1024]byte
    // ...
}

func (l *LargeStruct) Process() { /* ... */ }
```

### 5.2 When to Use Value Receivers

```go
// ✅ Receiver is a small, immutable struct
type Point struct {
    X, Y float64
}

func (p Point) Distance(other Point) float64 {
    return math.Sqrt(math.Pow(p.X-other.X, 2) + math.Pow(p.Y-other.Y, 2))
}

// ✅ Receiver is an alias for a basic type
type Counter int

func (c Counter) String() string {
    return fmt.Sprintf("%d", c)
}

// ✅ Receiver is a map, func, or chan (already reference types)
type StringSet map[string]struct{}

func (s StringSet) Contains(key string) bool {
    _, ok := s[key]
    return ok
}
```

### 5.3 Consistency Principle

```go
// ❌ Not recommended: mixing receiver types
func (u User) GetName() string   // value receiver
func (u *User) SetName(n string) // pointer receiver

// ✅ Recommended: if any method needs a pointer receiver, use pointer for all
func (u *User) GetName() string { return u.Name }
func (u *User) SetName(n string) { u.Name = n }
```

---

## 6. Performance Optimization

### 6.1 Pre-allocate Slices

```go
// ❌ Not recommended: dynamic growth
var result []int
for i := 0; i < 10000; i++ {
    result = append(result, i) // multiple allocations and copies
}

// ✅ Recommended: pre-allocate with known size
result := make([]int, 0, 10000)
for i := 0; i < 10000; i++ {
    result = append(result, i)
}

// ✅ Or initialize directly
result := make([]int, 10000)
for i := 0; i < 10000; i++ {
    result[i] = i
}
```

### 6.2 Avoid Unnecessary Heap Allocations

```go
// ❌ May escape to heap
func NewUser() *User {
    return &User{} // escapes to heap
}

// ✅ Consider returning by value (if applicable)
func NewUser() User {
    return User{} // may be stack-allocated
}

// Check escape analysis
// go build -gcflags '-m -m' ./...
```

### 6.3 Use sync.Pool to Reuse Objects

```go
// ✅ Recommended: use sync.Pool for objects created and destroyed frequently
var bufferPool = sync.Pool{
    New: func() interface{} {
        return new(bytes.Buffer)
    },
}

func ProcessData(data []byte) string {
    buf := bufferPool.Get().(*bytes.Buffer)
    defer func() {
        buf.Reset()
        bufferPool.Put(buf)
    }()

    buf.Write(data)
    return buf.String()
}
```

### 6.4 String Concatenation Optimization

```go
// ❌ Not recommended: using + in a loop
var result string
for _, s := range strings {
    result += s // creates a new string each time
}

// ✅ Recommended: use strings.Builder
var builder strings.Builder
for _, s := range strings {
    builder.WriteString(s)
}
result := builder.String()

// ✅ Or use strings.Join
result := strings.Join(strings, "")
```

### 6.5 Avoid interface{} Conversion Overhead

```go
// ❌ Using interface{} in hot paths
func process(data interface{}) {
    switch v := data.(type) { // type assertion has overhead
    case int:
        // ...
    }
}

// ✅ Use generics or concrete types in hot paths
func process[T int | int64 | float64](data T) {
    // type determined at compile time, no runtime overhead
}
```

---

## 7. Testing

### 7.1 Table-Driven Tests

```go
// ✅ Recommended: table-driven tests
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive numbers", 1, 2, 3},
        {"with zero", 0, 5, 5},
        {"negative numbers", -1, -2, -3},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Add(tt.a, tt.b)
            if result != tt.expected {
                t.Errorf("Add(%d, %d) = %d; want %d",
                    tt.a, tt.b, result, tt.expected)
            }
        })
    }
}
```

### 7.2 Parallel Tests

```go
// ✅ Recommended: run independent test cases in parallel
func TestParallel(t *testing.T) {
    tests := []struct {
        name  string
        input string
    }{
        {"test1", "input1"},
        {"test2", "input2"},
    }

    for _, tt := range tests {
        tt := tt // required copy for Go < 1.22
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // mark as parallelizable
            result := Process(tt.input)
            // assertions...
        })
    }
}
```

### 7.3 Using Interfaces for Mocking

```go
// ✅ Define interfaces to enable testing
type EmailSender interface {
    Send(to, subject, body string) error
}

// Production implementation
type SMTPSender struct { /* ... */ }

// Test mock
type MockEmailSender struct {
    SendFunc func(to, subject, body string) error
}

func (m *MockEmailSender) Send(to, subject, body string) error {
    return m.SendFunc(to, subject, body)
}

func TestUserRegistration(t *testing.T) {
    mock := &MockEmailSender{
        SendFunc: func(to, subject, body string) error {
            if to != "test@example.com" {
                t.Errorf("unexpected recipient: %s", to)
            }
            return nil
        },
    }

    service := NewUserService(mock)
    // test...
}
```

### 7.4 Test Helper Functions

```go
// ✅ Use t.Helper() to mark helper functions
func assertEqual(t *testing.T, got, want interface{}) {
    t.Helper() // error reports show the caller's location
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}

// ✅ Use t.Cleanup() to clean up resources
func TestWithTempFile(t *testing.T) {
    f, err := os.CreateTemp("", "test")
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() {
        os.Remove(f.Name())
    })
    // test...
}
```

---

## 8. Common Pitfalls

### 8.1 Nil Slice vs Empty Slice

```go
var nilSlice []int     // nil, len=0, cap=0
emptySlice := []int{}  // not nil, len=0, cap=0
made := make([]int, 0) // not nil, len=0, cap=0

// ✅ JSON encoding difference
json.Marshal(nilSlice)   // null
json.Marshal(emptySlice) // []

// ✅ Recommended: explicitly initialize when an empty array in JSON is required
if slice == nil {
    slice = []int{}
}
```

### 8.2 Map Initialization

```go
// ❌ Wrong: uninitialized map
var m map[string]int
m["key"] = 1 // panic: assignment to entry in nil map

// ✅ Correct: initialize with make
m := make(map[string]int)
m["key"] = 1

// ✅ Or use a literal
m := map[string]int{}
```

### 8.3 Defer Inside Loops

```go
// ❌ Potential issue: defer executes when the function returns
func processFiles(files []string) error {
    for _, file := range files {
        f, err := os.Open(file)
        if err != nil {
            return err
        }
        defer f.Close() // all files closed only when function returns!
        // process...
    }
    return nil
}

// ✅ Correct: use a closure or extract a function
func processFiles(files []string) error {
    for _, file := range files {
        if err := processFile(file); err != nil {
            return err
        }
    }
    return nil
}

func processFile(file string) error {
    f, err := os.Open(file)
    if err != nil {
        return err
    }
    defer f.Close()
    // process...
    return nil
}
```

### 8.4 Slice Underlying Array Sharing

```go
// ❌ Potential issue: slices share the underlying array
original := []int{1, 2, 3, 4, 5}
slice := original[1:3] // [2, 3]
slice[0] = 100         // modifies original!
// original becomes [1, 100, 3, 4, 5]

// ✅ Correct: explicitly copy when an independent copy is needed
slice := make([]int, 2)
copy(slice, original[1:3])
slice[0] = 100 // does not affect original
```

### 8.5 String Substring Memory Leak

```go
// ❌ Potential issue: substring holds reference to the entire underlying array
func getPrefix(s string) string {
    return s[:10] // still references the underlying array of the entire s
}

// ✅ Correct: create an independent copy (Go 1.18+)
func getPrefix(s string) string {
    return strings.Clone(s[:10])
}

// ✅ Before Go 1.18
func getPrefix(s string) string {
    return string([]byte(s[:10]))
}
```

### 8.6 Interface Nil Trap

```go
// ❌ Trap: nil check on an interface
type MyError struct{}
func (e *MyError) Error() string { return "error" }

func returnsError() error {
    var e *MyError = nil
    return e // the returned error is NOT nil!
}

func main() {
    err := returnsError()
    if err != nil { // true! interface{type: *MyError, value: nil}
        fmt.Println("error:", err)
    }
}

// ✅ Correct: explicitly return nil
func returnsError() error {
    var e *MyError = nil
    if e == nil {
        return nil // explicitly return nil
    }
    return e
}
```

### 8.7 Time Comparison

```go
// ❌ Not recommended: direct == comparison of time.Time
if t1 == t2 { // may fail due to monotonic clock differences
    // ...
}

// ✅ Recommended: use the Equal method
if t1.Equal(t2) {
    // ...
}

// ✅ Compare time ranges
if t1.Before(t2) || t1.After(t2) {
    // ...
}
```

---

## 9. Code Organization

### 9.1 Package Naming

```go
// ❌ Not recommended
package common   // too generic
package utils    // too generic
package helpers  // too generic
package models   // grouped by type

// ✅ Recommended: name by functionality
package user     // user-related functionality
package order    // order-related functionality
package postgres // PostgreSQL implementation
```

### 9.2 Avoid Circular Dependencies

```go
// ❌ Circular dependency
// package a imports package b
// package b imports package a

// ✅ Solution 1: extract shared types into a separate package
// package types (shared types)
// package a imports types
// package b imports types

// ✅ Solution 2: use interfaces to decouple
// package a defines the interface
// package b implements the interface
```

### 9.3 Exported Identifier Conventions

```go
// ✅ Only export what is necessary
type UserService struct {
    db *sql.DB // private
}

func (s *UserService) GetUser(id int) (*User, error) // public
func (s *UserService) validate(u *User) error         // private

// ✅ Use internal packages to restrict access
// internal/database/... can only be imported by code in the same project
```

---

## 10. Tools and Checks

### 10.1 Required Tools

```bash
# Formatting (required)
gofmt -w .
goimports -w .

# Static analysis
go vet ./...

# Race detection
go test -race ./...

# Escape analysis
go build -gcflags '-m -m' ./...
```

### 10.2 Recommended Linters

```bash
# golangci-lint (integrates multiple linters)
golangci-lint run

# Common checks
# - errcheck: detect unhandled errors
# - gosec: security checks
# - ineffassign: ineffectual assignments
# - staticcheck: static analysis
# - unused: unused code
```

### 10.3 Benchmark Tests

```go
// ✅ Performance benchmark
func BenchmarkProcess(b *testing.B) {
    data := prepareData()
    b.ResetTimer() // reset the timer

    for i := 0; i < b.N; i++ {
        Process(data)
    }
}

// Run benchmarks
// go test -bench=. -benchmem ./...
```

---

## References

- [Effective Go](https://go.dev/doc/effective_go)
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Go Common Mistakes](https://go.dev/wiki/CommonMistakes)
- [100 Go Mistakes](https://100go.co/)
- [Go Proverbs](https://go-proverbs.github.io/)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)
