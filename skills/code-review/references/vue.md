# Vue 3 Code Review Guide

> Vue 3 Composition API code review guide covering the reactivity system, Props/Emits, Watchers, Composables, Vue 3.5 new features, and other core topics.

## Table of Contents

- [Reactivity System](#reactivity-system)
- [Props & Emits](#props--emits)
- [Vue 3.5 New Features](#vue-35-new-features)
- [Watchers](#watchers)
- [Template Best Practices](#template-best-practices)
- [Composables](#composables)
- [Performance Optimization](#performance-optimization)
- [Review Checklist](#review-checklist)

---

## Reactivity System

### Choosing Between ref and reactive

```vue
<!-- ✅ Use ref for primitives -->
<script setup lang="ts">
const count = ref(0)
const name = ref('Vue')

// ref requires .value to access
count.value++
</script>

<!-- ✅ Use reactive for objects/arrays (optional) -->
<script setup lang="ts">
const state = reactive({
  user: null,
  loading: false,
  error: null
})

// reactive is accessed directly
state.loading = true
</script>

<!-- 💡 Modern best practice: use ref for everything, stay consistent -->
<script setup lang="ts">
const user = ref<User | null>(null)
const loading = ref(false)
const error = ref<Error | null>(null)
</script>
```

### Destructuring Reactive Objects

```vue
<!-- ❌ Destructuring reactive loses reactivity -->
<script setup lang="ts">
const state = reactive({ count: 0, name: 'Vue' })
const { count, name } = state  // Reactivity lost!
</script>

<!-- ✅ Use toRefs to preserve reactivity -->
<script setup lang="ts">
const state = reactive({ count: 0, name: 'Vue' })
const { count, name } = toRefs(state)  // Reactivity preserved
// Or just use ref directly
const count = ref(0)
const name = ref('Vue')
</script>
```

### Side Effects in computed

```vue
<!-- ❌ Side effects inside computed -->
<script setup lang="ts">
const fullName = computed(() => {
  console.log('Computing...')  // Side effect!
  otherRef.value = 'changed'   // Mutating other state!
  return `${firstName.value} ${lastName.value}`
})
</script>

<!-- ✅ computed should only be used for derived state -->
<script setup lang="ts">
const fullName = computed(() => {
  return `${firstName.value} ${lastName.value}`
})
// Side effects belong in watch or event handlers
watch(fullName, (name) => {
  console.log('Name changed:', name)
})
</script>
```

### shallowRef Optimization

```vue
<!-- ❌ Using ref on large objects causes deep conversion -->
<script setup lang="ts">
const largeData = ref(hugeNestedObject)  // Deep reactive, high performance cost
</script>

<!-- ✅ Use shallowRef to avoid deep conversion -->
<script setup lang="ts">
const largeData = shallowRef(hugeNestedObject)

// Only whole-value replacement triggers updates
function updateData(newData) {
  largeData.value = newData  // ✅ Triggers update
}

// ❌ Mutating nested properties does NOT trigger updates
// largeData.value.nested.prop = 'new'

// Use triggerRef to manually trigger when needed
import { triggerRef } from 'vue'
largeData.value.nested.prop = 'new'
triggerRef(largeData)
</script>
```

---

## Props & Emits

### Mutating Props Directly

```vue
<!-- ❌ Mutating props directly -->
<script setup lang="ts">
const props = defineProps<{ user: User }>()
props.user.name = 'New Name'  // Never mutate props directly!
</script>

<!-- ✅ Use emit to notify the parent of updates -->
<script setup lang="ts">
const props = defineProps<{ user: User }>()
const emit = defineEmits<{
  update: [name: string]
}>()
const updateName = (name: string) => emit('update', name)
</script>
```

### defineProps Type Declarations

```vue
<!-- ❌ defineProps without type declarations -->
<script setup lang="ts">
const props = defineProps(['title', 'count'])  // No type checking
</script>

<!-- ✅ Use type declarations + withDefaults -->
<script setup lang="ts">
interface Props {
  title: string
  count?: number
  items?: string[]
}
const props = withDefaults(defineProps<Props>(), {
  count: 0,
  items: () => []  // Object/array defaults require factory functions
})
</script>
```

### Type-Safe defineEmits

```vue
<!-- ❌ defineEmits without types -->
<script setup lang="ts">
const emit = defineEmits(['update', 'delete'])  // No type checking
emit('update', someValue)  // Argument types are unsafe
</script>

<!-- ✅ Full type definitions -->
<script setup lang="ts">
const emit = defineEmits<{
  update: [id: number, value: string]
  delete: [id: number]
  'custom-event': [payload: CustomPayload]
}>()

// Now fully type-checked
emit('update', 1, 'new value')  // ✅
emit('update', 'wrong')  // ❌ TypeScript error
</script>
```

---

## Vue 3.5 New Features

### Reactive Props Destructure (3.5+)

```vue
<!-- Before Vue 3.5: destructuring loses reactivity -->
<script setup lang="ts">
const props = defineProps<{ count: number }>()
// Must use props.count or toRefs
</script>

<!-- ✅ Vue 3.5+: destructuring preserves reactivity -->
<script setup lang="ts">
const { count, name = 'default' } = defineProps<{
  count: number
  name?: string
}>()

// count and name stay reactive automatically!
// Can be used directly in templates and watch
watch(() => count, (newCount) => {
  console.log('Count changed:', newCount)
})
</script>

<!-- ✅ Using with default values -->
<script setup lang="ts">
const {
  title,
  count = 0,
  items = () => []  // Function as default value (for objects/arrays)
} = defineProps<{
  title: string
  count?: number
  items?: () => string[]
}>()
</script>
```

### defineModel (3.4+)

```vue
<!-- ❌ Traditional v-model implementation: verbose -->
<script setup lang="ts">
const props = defineProps<{ modelValue: string }>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

// Requires computed for two-way binding
const value = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})
</script>

<!-- ✅ defineModel: concise v-model implementation -->
<script setup lang="ts">
// Automatically handles props and emit
const model = defineModel<string>()

// Use directly
model.value = 'new value'  // Emits automatically
</script>
<template>
  <input v-model="model" />
</template>

<!-- ✅ Named v-model -->
<script setup lang="ts">
// Implementation for v-model:title
const title = defineModel<string>('title')

// With default value and options
const count = defineModel<number>('count', {
  default: 0,
  required: false
})
</script>

<!-- ✅ Multiple v-models -->
<script setup lang="ts">
const firstName = defineModel<string>('firstName')
const lastName = defineModel<string>('lastName')
</script>
<template>
  <!-- Parent usage: <MyInput v-model:first-name="first" v-model:last-name="last" /> -->
</template>

<!-- ✅ v-model modifiers -->
<script setup lang="ts">
const [model, modifiers] = defineModel<string>()

// Check modifier
if (modifiers.capitalize) {
  // Handle .capitalize modifier
}
</script>
```

### useTemplateRef (3.5+)

```vue
<!-- Traditional approach: ref attribute must match variable name -->
<script setup lang="ts">
const inputRef = ref<HTMLInputElement | null>(null)
</script>
<template>
  <input ref="inputRef" />
</template>

<!-- ✅ useTemplateRef: clearer template refs -->
<script setup lang="ts">
import { useTemplateRef } from 'vue'

const input = useTemplateRef<HTMLInputElement>('my-input')

onMounted(() => {
  input.value?.focus()
})
</script>
<template>
  <input ref="my-input" />
</template>

<!-- ✅ Dynamic ref -->
<script setup lang="ts">
const refKey = ref('input-a')
const dynamicInput = useTemplateRef<HTMLInputElement>(refKey)
</script>
```

### useId (3.5+)

```vue
<!-- ❌ Manually generated IDs may collide -->
<script setup lang="ts">
const id = `input-${Math.random()}`  // Inconsistent in SSR!
</script>

<!-- ✅ useId: SSR-safe unique IDs -->
<script setup lang="ts">
import { useId } from 'vue'

const id = useId()  // e.g. 'v-0'
</script>
<template>
  <label :for="id">Name</label>
  <input :id="id" />
</template>

<!-- ✅ Usage in form components -->
<script setup lang="ts">
const inputId = useId()
const errorId = useId()
</script>
<template>
  <label :for="inputId">Email</label>
  <input
    :id="inputId"
    :aria-describedby="errorId"
  />
  <span :id="errorId" class="error">{{ error }}</span>
</template>
```

### onWatcherCleanup (3.5+)

```vue
<!-- Traditional approach: cleanup via third argument -->
<script setup lang="ts">
watch(source, async (value, oldValue, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())
  // ...
})
</script>

<!-- ✅ onWatcherCleanup: more flexible cleanup -->
<script setup lang="ts">
import { onWatcherCleanup } from 'vue'

watch(source, async (value) => {
  const controller = new AbortController()
  onWatcherCleanup(() => controller.abort())

  // Can be called anywhere, not just at the top of the callback
  if (someCondition) {
    const anotherResource = createResource()
    onWatcherCleanup(() => anotherResource.dispose())
  }

  await fetchData(value, controller.signal)
})
</script>
```

### Deferred Teleport (3.5+)

```vue
<!-- ❌ Teleport target must exist at mount time -->
<template>
  <Teleport to="#modal-container">
    <!-- Errors if #modal-container does not exist -->
  </Teleport>
</template>

<!-- ✅ defer attribute delays mounting -->
<template>
  <Teleport to="#modal-container" defer>
    <!-- Waits for the target element to exist before mounting -->
    <Modal />
  </Teleport>
</template>
```

---

## Watchers

### watch vs watchEffect

```vue
<script setup lang="ts">
// ✅ watch: explicit dependencies, lazy execution
watch(
  () => props.userId,
  async (userId) => {
    user.value = await fetchUser(userId)
  }
)

// ✅ watchEffect: automatic dependency tracking, immediate execution
watchEffect(async () => {
  // Automatically tracks props.userId
  user.value = await fetchUser(props.userId)
})

// 💡 Selection guide:
// - Need the old value? Use watch
// - Need lazy execution? Use watch
// - Complex dependencies? Use watchEffect
</script>
```

### Watcher Cleanup Functions

```vue
<!-- ❌ watch without cleanup, potential memory leak -->
<script setup lang="ts">
watch(searchQuery, async (query) => {
  const controller = new AbortController()
  const data = await fetch(`/api/search?q=${query}`, {
    signal: controller.signal
  })
  results.value = await data.json()
  // If query changes rapidly, old requests are never cancelled!
})
</script>

<!-- ✅ Use onCleanup to clean up side effects -->
<script setup lang="ts">
watch(searchQuery, async (query, _, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())  // Cancel previous request

  try {
    const data = await fetch(`/api/search?q=${query}`, {
      signal: controller.signal
    })
    results.value = await data.json()
  } catch (e) {
    if (e.name !== 'AbortError') throw e
  }
})
</script>
```

### Watcher Options

```vue
<script setup lang="ts">
// ✅ immediate: run once immediately
watch(
  userId,
  async (id) => {
    user.value = await fetchUser(id)
  },
  { immediate: true }
)

// ✅ deep: deep watching (high performance cost, use carefully)
watch(
  state,
  (newState) => {
    console.log('State changed deeply')
  },
  { deep: true }
)

// ✅ flush: 'post': run after DOM update
watch(
  source,
  () => {
    // Can safely access the updated DOM
    // nextTick is no longer needed
  },
  { flush: 'post' }
)

// ✅ once: true (Vue 3.4+): run only once
watch(
  source,
  (value) => {
    console.log('Runs only once:', value)
  },
  { once: true }
)
</script>
```

### Watching Multiple Sources

```vue
<script setup lang="ts">
// ✅ Watch multiple refs
watch(
  [firstName, lastName],
  ([newFirst, newLast], [oldFirst, oldLast]) => {
    console.log(`Name changed from ${oldFirst} ${oldLast} to ${newFirst} ${newLast}`)
  }
)

// ✅ Watch specific properties of a reactive object
watch(
  () => [state.count, state.name],
  ([count, name]) => {
    console.log(`count: ${count}, name: ${name}`)
  }
)
</script>
```

---

## Template Best Practices

### v-for Keys

```vue
<!-- ❌ Using index as key in v-for -->
<template>
  <li v-for="(item, index) in items" :key="index">
    {{ item.name }}
  </li>
</template>

<!-- ✅ Use a unique identifier as key -->
<template>
  <li v-for="item in items" :key="item.id">
    {{ item.name }}
  </li>
</template>

<!-- ✅ Composite key (when no unique ID is available) -->
<template>
  <li v-for="(item, index) in items" :key="`${item.name}-${item.type}-${index}`">
    {{ item.name }}
  </li>
</template>
```

### v-if and v-for Priority

```vue
<!-- ❌ Using v-if and v-for together on the same element -->
<template>
  <li v-for="user in users" v-if="user.active" :key="user.id">
    {{ user.name }}
  </li>
</template>

<!-- ✅ Use computed to filter -->
<script setup lang="ts">
const activeUsers = computed(() =>
  users.value.filter(user => user.active)
)
</script>
<template>
  <li v-for="user in activeUsers" :key="user.id">
    {{ user.name }}
  </li>
</template>

<!-- ✅ Or wrap with template -->
<template>
  <template v-for="user in users" :key="user.id">
    <li v-if="user.active">
      {{ user.name }}
    </li>
  </template>
</template>
```

### Event Handling

```vue
<!-- ❌ Inline complex logic -->
<template>
  <button @click="items = items.filter(i => i.id !== item.id); count--">
    Delete
  </button>
</template>

<!-- ✅ Use methods -->
<script setup lang="ts">
const deleteItem = (id: number) => {
  items.value = items.value.filter(i => i.id !== id)
  count.value--
}
</script>
<template>
  <button @click="deleteItem(item.id)">Delete</button>
</template>

<!-- ✅ Event modifiers -->
<template>
  <!-- Prevent default behavior -->
  <form @submit.prevent="handleSubmit">...</form>

  <!-- Stop propagation -->
  <button @click.stop="handleClick">...</button>

  <!-- Run only once -->
  <button @click.once="handleOnce">...</button>

  <!-- Keyboard modifiers -->
  <input @keyup.enter="submit" @keyup.esc="cancel" />
</template>
```

---

## Composables

### Composable Design Principles

```typescript
// ✅ Good composable design
export function useCounter(initialValue = 0) {
  const count = ref(initialValue)

  const increment = () => count.value++
  const decrement = () => count.value--
  const reset = () => count.value = initialValue

  // Return reactive refs and methods
  return {
    count: readonly(count),  // Readonly to prevent external mutation
    increment,
    decrement,
    reset
  }
}

// ❌ Do not return .value
export function useBadCounter() {
  const count = ref(0)
  return {
    count: count.value  // ❌ Reactivity lost!
  }
}
```

### Passing Props to Composables

```vue
<!-- ❌ Passing a prop value to a composable loses reactivity -->
<script setup lang="ts">
const props = defineProps<{ userId: string }>()
const { user } = useUser(props.userId)  // Reactivity lost!
</script>

<!-- ✅ Use toRef or computed to preserve reactivity -->
<script setup lang="ts">
const props = defineProps<{ userId: string }>()
const userIdRef = toRef(props, 'userId')
const { user } = useUser(userIdRef)  // Reactivity preserved
// Or use computed
const { user } = useUser(computed(() => props.userId))

// ✅ Vue 3.5+: use destructured props directly
const { userId } = defineProps<{ userId: string }>()
const { user } = useUser(() => userId)  // Getter function
</script>
```

### Async Composable

```typescript
// ✅ Async composable pattern
export function useFetch<T>(url: MaybeRefOrGetter<string>) {
  const data = ref<T | null>(null)
  const error = ref<Error | null>(null)
  const loading = ref(false)

  const execute = async () => {
    loading.value = true
    error.value = null

    try {
      const response = await fetch(toValue(url))
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      data.value = await response.json()
    } catch (e) {
      error.value = e as Error
    } finally {
      loading.value = false
    }
  }

  // Automatically re-fetch when the URL is reactive
  watchEffect(() => {
    toValue(url)  // Track dependency
    execute()
  })

  return {
    data: readonly(data),
    error: readonly(error),
    loading: readonly(loading),
    refetch: execute
  }
}

// Usage
const { data, loading, error, refetch } = useFetch<User[]>('/api/users')
```

### Lifecycle and Cleanup

```typescript
// ✅ Correctly handling lifecycle inside a composable
export function useEventListener(
  target: MaybeRefOrGetter<EventTarget>,
  event: string,
  handler: EventListener
) {
  // Add after component mounts
  onMounted(() => {
    toValue(target).addEventListener(event, handler)
  })

  // Remove when component unmounts
  onUnmounted(() => {
    toValue(target).removeEventListener(event, handler)
  })
}

// ✅ Use effectScope to manage side effects
export function useFeature() {
  const scope = effectScope()

  scope.run(() => {
    // All reactive effects are scoped here
    const state = ref(0)
    watch(state, () => { /* ... */ })
    watchEffect(() => { /* ... */ })
  })

  // Clean up all effects
  onUnmounted(() => scope.stop())

  return { /* ... */ }
}
```

---

## Performance Optimization

### v-memo

```vue
<!-- ✅ v-memo: cache subtrees to avoid re-rendering -->
<template>
  <div v-for="item in list" :key="item.id" v-memo="[item.id === selected]">
    <!-- Only re-renders when item.id === selected changes -->
    <ExpensiveComponent :item="item" :selected="item.id === selected" />
  </div>
</template>

<!-- ✅ Used together with v-for -->
<template>
  <div
    v-for="item in list"
    :key="item.id"
    v-memo="[item.name, item.status]"
  >
    <!-- Only re-renders when name or status changes -->
  </div>
</template>
```

### defineAsyncComponent

```vue
<script setup lang="ts">
import { defineAsyncComponent } from 'vue'

// ✅ Lazy-load a component
const HeavyChart = defineAsyncComponent(() =>
  import('./components/HeavyChart.vue')
)

// ✅ With loading and error states
const AsyncModal = defineAsyncComponent({
  loader: () => import('./components/Modal.vue'),
  loadingComponent: LoadingSpinner,
  errorComponent: ErrorDisplay,
  delay: 200,  // Delay showing the loading state (avoids flickering)
  timeout: 3000  // Timeout duration
})
</script>
```

### KeepAlive

```vue
<template>
  <!-- ✅ Cache dynamic components -->
  <KeepAlive>
    <component :is="currentTab" />
  </KeepAlive>

  <!-- ✅ Specify which components to cache -->
  <KeepAlive include="TabA,TabB">
    <component :is="currentTab" />
  </KeepAlive>

  <!-- ✅ Limit the number of cached instances -->
  <KeepAlive :max="10">
    <component :is="currentTab" />
  </KeepAlive>
</template>

<script setup lang="ts">
// KeepAlive lifecycle hooks
onActivated(() => {
  // Component activated (restored from cache)
  refreshData()
})

onDeactivated(() => {
  // Component deactivated (entered cache)
  pauseTimers()
})
</script>
```

### Virtual Lists

```vue
<!-- ✅ Use virtual scrolling for large lists -->
<script setup lang="ts">
import { useVirtualList } from '@vueuse/core'

const { list, containerProps, wrapperProps } = useVirtualList(
  items,
  { itemHeight: 50 }
)
</script>
<template>
  <div v-bind="containerProps" style="height: 400px; overflow: auto">
    <div v-bind="wrapperProps">
      <div v-for="item in list" :key="item.data.id" style="height: 50px">
        {{ item.data.name }}
      </div>
    </div>
  </div>
</template>
```

---

## Review Checklist

### Reactivity System

- [ ] `ref` used for primitives, `reactive` for objects (or `ref` for everything consistently)
- [ ] No bare destructuring of `reactive` objects (or `toRefs` used)
- [ ] Reactivity is preserved when passing props to composables
- [ ] `shallowRef`/`shallowReactive` used to optimize large objects
- [ ] No side effects inside `computed`

### Props & Emits

- [ ] `defineProps` uses TypeScript type declarations
- [ ] Complex default values use `withDefaults` + factory functions
- [ ] `defineEmits` has complete type definitions
- [ ] Props are never mutated directly
- [ ] Consider `defineModel` to simplify v-model (Vue 3.4+)

### Vue 3.5 New Features (where applicable)

- [ ] Reactive Props Destructure used to simplify prop access
- [ ] `useTemplateRef` used instead of the `ref` attribute approach
- [ ] `useId` used to generate SSR-safe IDs in forms
- [ ] `onWatcherCleanup` used for complex cleanup logic

### Watchers

- [ ] `watch`/`watchEffect` have appropriate cleanup functions
- [ ] Async watches handle race conditions
- [ ] `flush: 'post'` used for watchers that access the DOM
- [ ] Avoid overusing watchers (prefer `computed`)
- [ ] Consider `once: true` for one-time listeners

### Template

- [ ] `v-for` uses unique and stable keys
- [ ] `v-if` and `v-for` are not on the same element
- [ ] Event handlers use methods rather than inline complex logic
- [ ] Large lists use virtual scrolling

### Composables

- [ ] Related logic extracted into composables
- [ ] Composables return reactive refs (not `.value`)
- [ ] Pure functions are not wrapped into composables unnecessarily
- [ ] Side effects are cleaned up when the component unmounts
- [ ] `effectScope` used to manage complex side effects

### Performance

- [ ] Large components are split into smaller ones
- [ ] `defineAsyncComponent` used for lazy loading
- [ ] Avoid unnecessary reactive conversions
- [ ] `v-memo` used for expensive list rendering
- [ ] `KeepAlive` used to cache dynamic components
