Вот переведенная версия вашего файла на английский язык в формате Markdown. Вы можете скопировать этот текст и сохранить его как файл `.md`.

---

# Common Bugs Checklist

Language-specific bugs and issues to watch for during code review.

## Universal Issues

### Logic Errors
- [ ] Off-by-one errors in loops and array access
- [ ] Incorrect boolean logic (De Morgan's law violations)
- [ ] Missing null/undefined checks
- [ ] Race conditions in concurrent code
- [ ] Incorrect comparison operators (`==` vs `===`, `=` vs `==`)
- [ ] Integer overflow/underflow
- [ ] Floating point comparison issues

### Resource Management
- [ ] Memory leaks (unclosed connections, listeners)
- [ ] File handles not closed
- [ ] Database connections not released
- [ ] Event listeners not removed
- [ ] Timers/intervals not cleared

### Error Handling
- [ ] Swallowed exceptions (empty catch blocks)
- [ ] Generic exception handling hiding specific errors
- [ ] Missing error propagation
- [ ] Incorrect error types thrown
- [ ] Missing `finally`/cleanup blocks

---

## TypeScript/JavaScript

### Type Issues
```typescript
// ❌ Using any defeats type safety
function process(data: any) { return data.value; }

// ✅ Use proper types
interface Data { value: string; }
function process(data: Data) { return data.value; }
```

### Async/Await Pitfalls
```typescript
// ❌ Missing await
async function fetch() {
  const data = fetchData();  // Missing await!
  return data.json();
}

// ❌ Unhandled promise rejection
async function risky() {
  const result = await fetchData();  // No try-catch
  return result;
}

// ✅ Proper error handling
async function safe() {
  try {
    const result = await fetchData();
    return result;
  } catch (error) {
    console.error('Fetch failed:', error);
    throw error;
  }
}
```

### React Specific

#### Hooks Rules Violations
```tsx
// ❌ Calling Hooks conditionally — violates the Rules of Hooks
function BadComponent({ show }) {
  if (show) {
    const [value, setValue] = useState(0);  // Error!
  }
  return <div>...</div>;
}

// ✅ Hooks must be called unconditionally at the top level
function GoodComponent({ show }) {
  const [value, setValue] = useState(0);
  if (!show) return null;
  return <div>{value}</div>;
}

// ❌ Calling Hooks inside a loop
function BadLoop({ items }) {
  items.forEach(item => {
    const [selected, setSelected] = useState(false);  // Error!
  });
}

// ✅ Lift state up or use a different data structure
function GoodLoop({ items }) {
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  return items.map(item => (
    <Item key={item.id} selected={selectedIds.has(item.id)} />
  ));
}
```

#### Common useEffect Mistakes
```tsx
// ❌ Incomplete dependency array — stale closure
function StaleClosureExample({ userId, onSuccess }) {
  const [data, setData] = useState(null);
  useEffect(() => {
    fetchData(userId).then(result => {
      setData(result);
      onSuccess(result);  // onSuccess may be stale!
    });
  }, [userId]);  // Missing onSuccess dependency
}

// ✅ Complete dependency array
useEffect(() => {
  fetchData(userId).then(result => {
    setData(result);
    onSuccess(result);
  });
}, [userId, onSuccess]);

// ❌ Infinite loop — updating a dependency inside the effect
function InfiniteLoop() {
  const [count, setCount] = useState(0);
  useEffect(() => {
    setCount(count + 1);  // Triggers re-render, which triggers the effect again
  }, [count]);  // Infinite loop!
}

// ❌ Missing cleanup function — memory leak
function MemoryLeak({ userId }) {
  const [user, setUser] = useState(null);
  useEffect(() => {
    fetchUser(userId).then(setUser);  // setUser is still called after the component unmounts
  }, [userId]);
}

// ✅ Correct cleanup
function NoLeak({ userId }) {
  const [user, setUser] = useState(null);
  useEffect(() => {
    let cancelled = false;
    fetchUser(userId).then(data => {
      if (!cancelled) setUser(data);
    });
    return () => { cancelled = true; };
  }, [userId]);
}

// ❌ useEffect used for derived state (anti-pattern)
function BadDerived({ items }) {
  const [total, setTotal] = useState(0);
  useEffect(() => {
    setTotal(items.reduce((a, b) => a + b.price, 0));
  }, [items]);  // Unnecessary effect + extra render
}

// ✅ Compute directly or use useMemo
function GoodDerived({ items }) {
  const total = useMemo(
    () => items.reduce((a, b) => a + b.price, 0),
    [items]
  );
}

// ❌ useEffect used for event responses
function BadEvent() {
  const [query, setQuery] = useState('');
  useEffect(() => {
    if (query) logSearch(query);  // Should be in an event handler
  }, [query]);
}

// ✅ Side effects belong in event handlers
function GoodEvent() {
  const handleSearch = (q: string) => {
    setQuery(q);
    logSearch(q);
  };
}
```

#### useMemo / useCallback Misuse
```tsx
// ❌ Over-optimization — constants don't need memo
function OverOptimized() {
  const config = useMemo(() => ({ api: '/v1' }), []);  // Pointless
  const noop = useCallback(() => {}, []);  // Pointless
}

// ❌ useMemo with empty deps (can hide bugs)
function EmptyDeps({ user }) {
  const greeting = useMemo(() => `Hello ${user.name}`, []);
  // greeting won't update when user changes!
}

// ❌ useCallback with a dependency that always changes
function UselessCallback({ data }) {
  const process = useCallback(() => {
    return data.map(transform);
  }, [data]);  // Completely useless if data is a new reference every render
}

// ❌ useMemo/useCallback without React.memo on the child
function Parent() {
  const data = useMemo(() => compute(), []);
  const handler = useCallback(() => {}, []);
  return <Child data={data} onClick={handler} />;
  // Child is not wrapped in React.memo, so these optimizations are meaningless
}

// ✅ Correct optimization combination
const MemoChild = React.memo(function Child({ data, onClick }) {
  return <button onClick={onClick}>{data}</button>;
});

function Parent() {
  const data = useMemo(() => expensiveCompute(), [dep]);
  const handler = useCallback(() => {}, []);
  return <MemoChild data={data} onClick={handler} />;
}
```

#### Component Design Issues
```tsx
// ❌ Defining components inside other components
function Parent() {
  // Creates a new Child function on every render, causing full remounts
  const Child = () => <div>child</div>;
  return <Child />;
}

// ✅ Define components outside
const Child = () => <div>child</div>;
function Parent() {
  return <Child />;
}

// ❌ Props are always new references — breaks memo
function BadProps() {
  return (
    <MemoComponent
      style={{ color: 'red' }}      // New object on every render
      onClick={() => handle()}       // New function on every render
      items={data.filter(x => x)}    // New array on every render
    />
  );
}

// ❌ Mutating props directly
function MutateProps({ user }) {
  user.name = 'Changed';  // Never do this!
  return <div>{user.name}</div>;
}
```

#### Server Component Mistakes (React 19+)
```tsx
// ❌ Using client-side APIs in a Server Component
// app/page.tsx (Server Component by default)
export default function Page() {
  const [count, setCount] = useState(0);  // Error!
  useEffect(() => {}, []);  // Error!
  return <button onClick={() => {}}>Click</button>;  // Error!
}

// ✅ Move interactive logic to a Client Component
// app/counter.tsx
'use client';
export function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}

// app/page.tsx
import { Counter } from './counter';
export default async function Page() {
  const data = await fetchData();  // Server Components can await directly
  return <Counter initialCount={data.count} />;
}

// ❌ Marking a parent with 'use client' turns the entire subtree into client components
// layout.tsx
'use client';  // Bad idea! All child components become client components
export default function Layout({ children }) { ... }
```

#### Common Testing Mistakes
```tsx
// ❌ Using container queries
const { container } = render(<Component />);
const button = container.querySelector('button');  // Not recommended

// ✅ Use screen and semantic queries
render(<Component />);
const button = screen.getByRole('button', { name: /submit/i });

// ❌ Using fireEvent
fireEvent.click(button);

// ✅ Use userEvent
await userEvent.click(button);

// ❌ Testing implementation details
expect(component.state.isOpen).toBe(true);

// ✅ Test behavior
expect(screen.getByRole('dialog')).toBeVisible();

// ❌ Awaiting a synchronous query
await screen.getByText('Hello');  // getBy is synchronous

// ✅ Use findBy for async
await screen.findByText('Hello');  // findBy waits
```

### React Common Mistakes Checklist
- [ ] Hooks called outside the top level (in conditions/loops)
- [ ] Incomplete `useEffect` dependency arrays
- [ ] Missing `useEffect` cleanup functions
- [ ] `useEffect` used for derived state calculation
- [ ] `useMemo`/`useCallback` overused
- [ ] `useMemo`/`useCallback` not paired with `React.memo`
- [ ] Child components defined inside parent components
- [ ] Props are new object/function references (when passed to memo components)
- [ ] Props mutated directly
- [ ] Lists missing keys or using index as key
- [ ] Server Components using client-side APIs
- [ ] 'use client' placed on a parent, causing the entire tree to become client-side
- [ ] Tests using container queries instead of screen
- [ ] Tests checking implementation details instead of behavior

### React 19 Actions & Forms Errors

```tsx
// === useActionState Mistakes ===

// ❌ Calling setState directly inside an Action instead of returning state
const [state, action] = useActionState(async (prev, formData) => {
  setSomeState(newValue);  // Wrong! Should return new state
}, initialState);

// ✅ Return the new state
const [state, action] = useActionState(async (prev, formData) => {
  const result = await submitForm(formData);
  return { ...prev, data: result };  // Return new state
}, initialState);

// ❌ Forgetting to handle isPending
const [state, action] = useActionState(submitAction, null);
return <button>Submit</button>;  // User can click multiple times

// ✅ Use isPending to disable the button
const [state, action, isPending] = useActionState(submitAction, null);
return <button disabled={isPending}>Submit</button>;

// === useFormStatus Mistakes ===

// ❌ Calling useFormStatus at the same level as the form
function Form() {
  const { pending } = useFormStatus();  // Always undefined!
  return <form><button disabled={pending}>Submit</button></form>;
}

// ✅ Call it inside a child component
function SubmitButton() {
  const { pending } = useFormStatus();
  return <button disabled={pending}>Submit</button>;
}
function Form() {
  return <form><SubmitButton /></form>;
}

// === useOptimistic Mistakes ===

// ❌ Using it for critical business operations
function PaymentButton() {
  const [optimisticPaid, setPaid] = useOptimistic(false);
  const handlePay = async () => {
    setPaid(true);  // Dangerous: shows "paid" even if it fails
    await processPayment();
  };
}

// ❌ Not handling the UI state after a rollback
const [optimisticLikes, addLike] = useOptimistic(likes);
// UI rolls back on failure, but users may be confused why the like disappeared

// ✅ Provide failure feedback
const handleLike = async () => {
  addLike(1);
  try {
    await likePost();
  } catch {
    toast.error('Like failed, please try again');  // Notify the user
  }
};
```

### React 19 Forms Checklist
- [ ] `useActionState` returns new state instead of `setState`
- [ ] `useActionState` correctly uses `isPending` to disable submission
- [ ] `useFormStatus` is called within a form child component
- [ ] `useOptimistic` is not used for critical business logic (payments, deletions, etc.)
- [ ] `useOptimistic` provides user feedback on failure
- [ ] Server Action correctly marked with `'use server'`

### Suspense & Streaming Errors

```tsx
// === Suspense Boundary Mistakes ===

// ❌ One Suspense for the whole page — slow content blocks fast content
function BadPage() {
  return (
    <Suspense fallback={<FullPageLoader />}>
      <FastHeader />      {/* Fast */}
      <SlowMainContent /> {/* Slow — blocks the entire page */}
      <FastFooter />      {/* Fast */}
    </Suspense>
  );
}

// ✅ Independent boundaries, no blocking each other
function GoodPage() {
  return (
    <>
      <FastHeader />
      <Suspense fallback={<ContentSkeleton />}>
        <SlowMainContent />
      </Suspense>
      <FastFooter />
    </>
  );
}

// ❌ No Error Boundary
function NoErrorHandling() {
  return (
    <Suspense fallback={<Loading />}>
      <DataFetcher />  {/* An error causes a blank screen */}
    </Suspense>
  );
}

// ✅ Error Boundary + Suspense
function WithErrorHandling() {
  return (
    <ErrorBoundary fallback={<ErrorFallback />}>
      <Suspense fallback={<Loading />}>
        <DataFetcher />
      </Suspense>
    </ErrorBoundary>
  );
}

// === use() Hook Mistakes ===

// ❌ Creating a Promise inside a component (new Promise on every render)
function BadUse() {
  const data = use(fetchData());  // Creates a new Promise on every render!
  return <div>{data}</div>;
}

// ✅ Create in the parent and pass as props
function Parent() {
  const dataPromise = useMemo(() => fetchData(), []);
  return <Child dataPromise={dataPromise} />;
}
function Child({ dataPromise }) {
  const data = use(dataPromise);
  return <div>{data}</div>;
}

// === Next.js Streaming Mistakes ===

// ❌ Awaiting slow data in layout.tsx — blocks all child pages
// app/layout.tsx
export default async function Layout({ children }) {
  const config = await fetchSlowConfig();  // Blocks the entire app!
  return <ConfigProvider value={config}>{children}</ConfigProvider>;
}

// ✅ Move slow data to page-level or use Suspense
// app/layout.tsx
export default function Layout({ children }) {
  return (
    <Suspense fallback={<ConfigSkeleton />}>
      <ConfigProvider>{children}</ConfigProvider>
    </Suspense>
  );
}
```

### Suspense Checklist
- [ ] Slow content has its own Suspense boundary
- [ ] Each Suspense has a corresponding Error Boundary
- [ ] `fallback` is a meaningful skeleton screen (not just a plain spinner)
- [ ] Promises passed to `use()` are not created during render
- [ ] Slow data is not awaited in layout files
- [ ] Nesting depth does not exceed 3 levels

### TanStack Query Errors

```tsx
// === Query Configuration Mistakes ===

// ❌ queryKey does not include query parameters
function BadQuery({ userId, filters }) {
  const { data } = useQuery({
    queryKey: ['users'],  // Missing userId and filters!
    queryFn: () => fetchUsers(userId, filters),
  });
  // Data won't update when userId or filters change
}

// ✅ queryKey includes all parameters that affect data
function GoodQuery({ userId, filters }) {
  const { data } = useQuery({
    queryKey: ['users', userId, filters],
    queryFn: () => fetchUsers(userId, filters),
  });
}

// ❌ staleTime: 0 causes excessive requests
const { data } = useQuery({
  queryKey: ['data'],
  queryFn: fetchData,
  // Default staleTime: 0, refetches on every mount/window focus
});

// ✅ Set a reasonable staleTime
const { data } = useQuery({
  queryKey: ['data'],
  queryFn: fetchData,
  staleTime: 5 * 60 * 1000,  // Won't auto-refetch within 5 minutes
});

// === useSuspenseQuery Mistakes ===

// ❌ useSuspenseQuery + enabled (not supported)
const { data } = useSuspenseQuery({
  queryKey: ['user', userId],
  queryFn: () => fetchUser(userId),
  enabled: !!userId,  // Wrong! useSuspenseQuery does not support enabled
});

// ✅ Conditional rendering implementation
function UserQuery({ userId }) {
  const { data } = useSuspenseQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
  });
  return <UserProfile user={data} />;
}

function Parent({ userId }) {
  if (!userId) return <SelectUser />;
  return (
    <Suspense fallback={<UserSkeleton />}>
      <UserQuery userId={userId} />
    </Suspense>
  );
}

// === Mutation Mistakes ===

// ❌ Not invalidating queries after a mutation succeeds
const mutation = useMutation({
  mutationFn: updateUser,
  // Forgot to invalidate — UI shows stale data
});

// ✅ Invalidate related queries on success
const mutation = useMutation({
  mutationFn: updateUser,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['users'] });
  },
});

// ❌ Optimistic update without rollback handling
const mutation = useMutation({
  mutationFn: updateTodo,
  onMutate: async (newTodo) => {
    queryClient.setQueryData(['todos'], (old) => [...old, newTodo]);
    // Old data not saved — cannot roll back on failure!
  },
});

// ✅ Full optimistic update
const mutation = useMutation({
  mutationFn: updateTodo,
  onMutate: async (newTodo) => {
    await queryClient.cancelQueries({ queryKey: ['todos'] });
    const previous = queryClient.getQueryData(['todos']);
    queryClient.setQueryData(['todos'], (old) => [...old, newTodo]);
    return { previous };
  },
  onError: (err, newTodo, context) => {
    queryClient.setQueryData(['todos'], context.previous);
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['todos'] });
  },
});

// === v5 Migration Mistakes ===

// ❌ Using deprecated API
const { data, isLoading } = useQuery(['key'], fetchFn);  // v4 syntax

// ✅ v5 single-object argument
const { data, isPending } = useQuery({
  queryKey: ['key'],
  queryFn: fetchFn,
});

// ❌ Confusing isPending and isLoading
if (isLoading) return <Spinner />;
// In v5: isLoading = isPending && isFetching

// ✅ Choose based on intent
if (isPending) return <Spinner />;  // No cached data
// or
if (isFetching) return <Refreshing />;  // Background refresh in progress
```

### TanStack Query Checklist
- [ ] `queryKey` contains all parameters that affect data
- [ ] Reasonable `staleTime` set (not the default 0)
- [ ] `useSuspenseQuery` does not use `enabled`
- [ ] Invalidate related queries after a Mutation success
- [ ] Optimistic update has full rollback logic
- [ ] v5 uses single-object parameter syntax
- [ ] Understand `isPending` vs `isLoading` vs `isFetching`

### TypeScript/JavaScript Common Mistakes
- [ ] `==` instead of `===`
- [ ] Modifying array/object during iteration
- [ ] `this` context lost in callbacks
- [ ] Missing `key` prop in lists
- [ ] Closure capturing loop variable
- [ ] `parseInt` without radix parameter

---

## Vue 3

### Reactivity Loss
```vue
<script setup>
const state = reactive({ count: 0 })
const { count } = state  // count is NOT reactive!
</script>

<script setup>
const state = reactive({ count: 0 })
const { count } = toRefs(state)  // count.value is reactive
</script>
```

### Props Reactivity Transfer
```vue
<script setup>
const props = defineProps<{ id: string }>()
const { data } = useFetch(props.id)  // id won't refetch when it changes!
</script>

<script setup>
const props = defineProps<{ id: string }>()
const { data } = useFetch(() => props.id)  // getter maintains reactivity
// or
const { data } = useFetch(toRef(props, 'id'))
</script>
```

### Watch Cleanup
```vue
<script setup>
watch(id, async (newId) => {
  const data = await fetchData(newId)
  result.value = data  // old request might overwrite new result!
})
</script>

<script setup>
watch(id, async (newId, _, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())

  const data = await fetchData(newId, controller.signal)
  result.value = data
})
</script>
```

### Computed Side Effects
```vue
<script setup>
const total = computed(() => {
  sideEffect.value++  // Side effect! Executes on every access
  return items.value.reduce((a, b) => a + b, 0)
})
</script>

<script setup>
const total = computed(() => {
  return items.value.reduce((a, b) => a + b, 0)
})
// Put side effects in watch
watch(total, () => { sideEffect.value++ })
</script>
```

### Template Common Errors
```vue
<template>
  <div v-for="item in items" v-if="item.visible" :key="item.id">
    {{ item.name }}
  </div>
</template>

<template>
  <template v-for="item in items" :key="item.id">
    <div v-if="item.visible">{{ item.name }}</div>
  </template>
</template>
```

### Common Mistakes
- [ ] Destructuring `reactive` object loses reactivity
- [ ] Props lose reactivity when passed to composables
- [ ] `watch` async callback without cleanup function
- [ ] Side effects produced inside `computed`
- [ ] Using index as `key` for `v-for` (when list can be reordered)
- [ ] `v-if` and `v-for` on the same element
- [ ] `defineProps` used without TypeScript type declarations
- [ ] `withDefaults` object defaults not using a factory function
- [ ] Modifying props directly (instead of using `emit`)
- [ ] `watchEffect` dependencies are unclear, leading to over-triggering

---

## Python

### Mutable Default Arguments
```python
# ❌ Bug: List shared across all calls
def add_item(item, items=[]):
    items.append(item)
    return items

# ✅ Correct
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items
```

### Exception Handling
```python
# ❌ Catching everything, including KeyboardInterrupt
try:
    risky_operation()
except:
    pass

# ✅ Catch specific exceptions
try:
    risky_operation()
except ValueError as e:
    logger.error(f"Invalid value: {e}")
    raise
```

### Class Attributes
```python
# ❌ Shared mutable class attribute
class User:
    permissions = []  # Shared across all instances!

# ✅ Initialize in __init__
class User:
    def __init__(self):
        self.permissions = []
```

### Common Mistakes
- [ ] Using `is` instead of `==` for value comparison
- [ ] Forgetting `self` parameter in methods
- [ ] Modifying list while iterating
- [ ] String concatenation in loops (use `join`)
- [ ] Not closing files (use `with` statement)

---

## Rust

### Ownership and Borrowing

```rust
// ❌ Use after move
let s = String::from("hello");
let s2 = s;
println!("{}", s);  // Error: s was moved

// ✅ Clone if needed (but consider if clone is necessary)
let s = String::from("hello");
let s2 = s.clone();
println!("{}", s);  // OK

// ❌ Using clone() to bypass the borrow checker (anti-pattern)
fn process(data: &Data) {
    let owned = data.clone();  // Unnecessary clone
    do_something(owned);
}

// ✅ Correct use of borrowing
fn process(data: &Data) {
    do_something(data);  // Pass reference
}

// ❌ Storing borrows in structs (usually a bad idea)
struct Parser<'a> {
    input: &'a str,  // Lifecycle complication
    position: usize,
}

// ✅ Use owned data
struct Parser {
    input: String,  // Owns data, simplifies lifecycle
    position: usize,
}

// ❌ Modifying collection while iterating
let mut vec = vec![1, 2, 3];
for item in &vec {
    vec.push(*item);  // Error: cannot borrow as mutable
}

// ✅ Collect into a new collection
let vec = vec![1, 2, 3];
let new_vec: Vec<_> = vec.iter().map(|x| x * 2).collect();
```

### Unsafe Code Review

```rust
// ❌ unsafe without safety comment
unsafe {
    ptr::write(dest, value);
}

// ✅ Must have SAFETY comment explaining invariants
// SAFETY: dest pointer is obtained from Vec::as_mut_ptr(), ensuring:
// 1. Pointer is valid and aligned
// 2. Target memory is not borrowed by other references
// 3. Write does not exceed allocated capacity
unsafe {
    ptr::write(dest, value);
}

// ❌ unsafe fn without # Safety documentation
pub unsafe fn from_raw_parts(ptr: *mut T, len: usize) -> Self { ... }

// ✅ Must document the safety contract
/// Creates a new instance from raw parts.
///
/// # Safety
///
/// - `ptr` must have been allocated via `GlobalAlloc`
/// - `len` must be less than or equal to the allocated capacity
/// - The caller must ensure no other references to the memory exist
pub unsafe fn from_raw_parts(ptr: *mut T, len: usize) -> Self { ... }

// ❌ Cross-module unsafe invariants
mod a {
    pub fn set_flag() { FLAG = true; }  // Safe code affecting unsafe
}
mod b {
    pub unsafe fn do_thing() {
        if FLAG { /* assumes FLAG means something */ }
    }
}

// ✅ Encapsulate unsafe boundaries in a single module
mod safe_wrapper {
    // All unsafe logic within one module
    // Provide safe API externally
}
```

### Async/Concurrency

```rust
// ❌ Blocking in async context
async fn bad_fetch(url: &str) -> Result<String> {
    let resp = reqwest::blocking::get(url)?;  // Blocks the entire runtime!
    Ok(resp.text()?)
}

// ✅ Use async version
async fn good_fetch(url: &str) -> Result<String> {
    let resp = reqwest::get(url).await?;
    Ok(resp.text().await?)
}

// ❌ Holding Mutex across .await
async fn bad_lock(mutex: &Mutex<Data>) {
    let guard = mutex.lock().unwrap();
    some_async_op().await;  // Holding lock across await!
    drop(guard);
}

// ✅ Shorten lock duration
async fn good_lock(mutex: &Mutex<Data>) {
    let data = {
        let guard = mutex.lock().unwrap();
        guard.clone()  // Release lock immediately after getting data
    };
    some_async_op().await;
    // Process data
}

// ❌ Using std::sync::Mutex in async functions
async fn bad_async_mutex(mutex: &std::sync::Mutex<Data>) {
    let _guard = mutex.lock().unwrap();  // Potential deadlock
    tokio::time::sleep(Duration::from_secs(1)).await;
}

// ✅ Use tokio::sync::Mutex (if must cross await)
async fn good_async_mutex(mutex: &tokio::sync::Mutex<Data>) {
    let _guard = mutex.lock().await;
    tokio::time::sleep(Duration::from_secs(1)).await;
}

// ❌ Forgetting that Futures are lazy
fn bad_spawn() {
    let future = async_operation();  // Not executed!
    // future is dropped, nothing happened
}

// ✅ Must await or spawn
async fn good_spawn() {
    async_operation().await;  // Execute
    // or
    tokio::spawn(async_operation());  // Background execution
}

// ❌ spawn task missing 'static
async fn bad_spawn_lifetime(data: &str) {
    tokio::spawn(async {
        println!("{}", data);  // Error: data is not 'static
    });
}

// ✅ Use move or Arc
async fn good_spawn_lifetime(data: String) {
    tokio::spawn(async move {
        println!("{}", data);  // OK: owns data
    });
}
```

### Error Handling

```rust
// ❌ Using unwrap/expect in production code
fn bad_parse(input: &str) -> i32 {
    input.parse().unwrap()  // panic!
}

// ✅ Properly propagate errors
fn good_parse(input: &str) -> Result<i32, ParseIntError> {
    input.parse()
}

// ❌ Swallowing error info
fn bad_error_handling() -> Result<()> {
    match operation() {
        Ok(v) => Ok(v),
        Err(_) => Err(anyhow!("operation failed"))  // Lost original error
    }
}

// ✅ Use context to add info
fn good_error_handling() -> Result<()> {
    operation().context("failed to perform operation")?;
    Ok(())
}

// ❌ Library code using anyhow (should use thiserror)
// lib.rs
pub fn parse_config(path: &str) -> anyhow::Result<Config> {
    // Caller cannot distinguish error types
}

// ✅ Library code using thiserror to define error types
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("failed to read config file: {0}")]
    Io(#[from] std::io::Error),
    #[error("invalid config format: {0}")]
    Parse(#[from] serde_json::Error),
}

pub fn parse_config(path: &str) -> Result<Config, ConfigError> {
    // Caller can match different errors
}

// ❌ Ignoring must_use return value
fn bad_ignore_result() {
    some_fallible_operation();  // Warning: unused Result
}

// ✅ Explicitly handle or mark as ignored
fn good_handle_result() {
    let _ = some_fallible_operation();  // Explicit ignore
    // or
    some_fallible_operation().ok();  // Convert to Option
}
```

### Performance Pitfalls

```rust
// ❌ Unnecessary collect
fn bad_process(items: &[i32]) -> i32 {
    items.iter()
        .filter(|x| **x > 0)
        .collect::<Vec<_>>()  // Unnecessary allocation
        .iter()
        .sum()
}

// ✅ Lazy iteration
fn good_process(items: &[i32]) -> i32 {
    items.iter()
        .filter(|x| **x > 0)
        .sum()
}

// ❌ Repeated allocation in loop
fn bad_loop() -> String {
    let mut result = String::new();
    for i in 0..1000 {
        result = result + &i.to_string();  // Re-allocates every iteration!
    }
    result
}

// ✅ Pre-allocate or use push_str
fn good_loop() -> String {
    let mut result = String::with_capacity(4000);  // Pre-allocate
    for i in 0..1000 {
        write!(result, "{}", i).unwrap();  // Append in-place
    }
    result
}

// ❌ Overusing clone
fn bad_clone(data: &HashMap<String, Vec<u8>>) -> Vec<u8> {
    data.get("key").cloned().unwrap_or_default()
}

// ✅ Return reference or use Cow
fn good_ref(data: &HashMap<String, Vec<u8>>) -> &[u8] {
    data.get("key").map(|v| v.as_slice()).unwrap_or(&[])
}

// ❌ Passing large structs by value
fn bad_pass(data: LargeStruct) { ... }  // Copies entire struct

// ✅ Pass by reference
fn good_pass(data: &LargeStruct) { ... }

// ❌ Box<dyn Trait> for small known types
fn bad_trait_object() -> Box<dyn Iterator<Item = i32>> {
    Box::new(vec![1, 2, 3].into_iter())
}

// ✅ Use impl Trait
fn good_impl_trait() -> impl Iterator<Item = i32> {
    vec![1, 2, 3].into_iter()
}

// ❌ retain is slower than filter+collect in some scenarios
vec.retain(|x| x.is_valid());  // O(n) but high constant factor

// ✅ If in-place modification isn't required, consider filter
let vec: Vec<_> = vec.into_iter().filter(|x| x.is_valid()).collect();
```

### Lifecycles and References

```rust
// ❌ Returning reference to local variable
fn bad_return_ref() -> &str {
    let s = String::from("hello");
    &s  // Error: s will be dropped
}

// ✅ Return owned data or static reference
fn good_return_owned() -> String {
    String::from("hello")
}

// ❌ Over-generalized lifecycle
fn bad_lifetime<'a, 'b>(x: &'a str, y: &'b str) -> &'a str {
    x  // 'b is unused
}

// ✅ Simplified lifecycle
fn good_lifetime(x: &str, _y: &str) -> &str {
    x  // Compiler infers automatically
}

// ❌ Struct holding multiple related references with independent lifecycles
struct Bad<'a, 'b> {
    name: &'a str,
    data: &'b [u8],  // Usually should be the same lifecycle
}

// ✅ Related data uses the same lifecycle
struct Good<'a> {
    name: &'a str,
    data: &'a [u8],
}
```

### Rust Review Checklist

**Ownership and Borrowing**
- [ ] `clone()` is intentional, not to bypass the borrow checker
- [ ] Avoid storing borrows in structs (unless necessary)
- [ ] `Rc`/`Arc` used reasonably, no hidden unnecessary shared state
- [ ] No unnecessary `RefCell` (runtime check vs compile time)

**Unsafe Code**
- [ ] Every `unsafe` block has a `SAFETY` comment
- [ ] `unsafe fn` has `# Safety` documentation
- [ ] Safety invariants are clearly recorded
- [ ] `unsafe` boundaries are as small as possible

**Async/Concurrency**
- [ ] No blocking in async context
- [ ] No `std::sync` locks held across `.await`
- [ ] Spawned tasks satisfy `'static` constraint
- [ ] Futures are correctly `await`ed or `spawn`ed
- [ ] Lock order is consistent (avoid deadlock)

**Error Handling**
- [ ] Library code uses `thiserror`, app code uses `anyhow`
- [ ] Errors have sufficient context info
- [ ] No `unwrap`/`expect` in production code
- [ ] `must_use` return values are correctly handled

**Performance**
- [ ] Avoid unnecessary `collect()`
- [ ] Pass large data structures by reference
- [ ] String concatenation uses `String::with_capacity` or `write!`
- [ ] `impl Trait` preferred over `Box<dyn Trait>` (when possible)

**Type System**
- [ ] Use newtype pattern to increase type safety
- [ ] Exhaustive enum matching (no `_` wildcard hiding new variants)
- [ ] Lifecycles simplified as much as possible

---

## SQL

### Injection Vulnerabilities
```sql
-- ❌ String concatenation (SQL injection risk)
query = "SELECT * FROM users WHERE id = " + user_id

-- ✅ Parameterized queries
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))
```

### Performance Issues
- [ ] Missing indexes on filtered/joined columns
- [ ] `SELECT *` instead of specific columns
- [ ] N+1 query patterns
- [ ] Missing `LIMIT` on large tables
- [ ] Inefficient subqueries vs `JOIN`s

### Common Mistakes
- [ ] Not handling `NULL` comparisons correctly
- [ ] Missing transactions for related operations
- [ ] Incorrect `JOIN` types
- [ ] Case sensitivity issues
- [ ] Date/timezone handling errors

---

## API Design

### REST Issues
- [ ] Inconsistent resource naming
- [ ] Wrong HTTP methods (`POST` for idempotent operations)
- [ ] Missing pagination for list endpoints
- [ ] Incorrect status codes
- [ ] Missing rate limiting

### Data Validation
- [ ] Missing input validation
- [ ] Incorrect data type validation
- [ ] Missing length/range checks
- [ ] Not sanitizing user input
- [ ] Trusting client-side validation

---

## Testing

### Test Quality Issues
- [ ] Testing implementation details instead of behavior
- [ ] Missing edge case tests
- [ ] Flaky tests (non-deterministic)
- [ ] Tests with external dependencies
- [ ] Missing negative tests (error cases)
- [ ] Overly complex test setup