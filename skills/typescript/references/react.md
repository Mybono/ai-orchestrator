# React + TypeScript Reference

> Load when: user asks about typed React components, hooks, events, context, or state management.

## Component Patterns

### Basic functional component

```typescript
interface ButtonProps {
  label: string;
  onClick: () => void;
  variant?: "primary" | "secondary";
  disabled?: boolean;
}

function Button({ label, onClick, variant = "primary", disabled }: ButtonProps) {
  return (
    <button className={`btn-${variant}`} onClick={onClick} disabled={disabled}>
      {label}
    </button>
  );
}
```

### Component with children

```typescript
interface CardProps {
  title: string;
  children: React.ReactNode;
  className?: string;
}

function Card({ title, children, className }: CardProps) {
  return (
    <div className={className}>
      <h2>{title}</h2>
      {children}
    </div>
  );
}
```

### Generic component

```typescript
interface ListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  keyExtractor: (item: T) => string;
  emptyMessage?: string;
}

function List<T>({ items, renderItem, keyExtractor, emptyMessage = "No items" }: ListProps<T>) {
  if (items.length === 0) return <p>{emptyMessage}</p>;
  return (
    <ul>
      {items.map((item, i) => (
        <li key={keyExtractor(item)}>{renderItem(item, i)}</li>
      ))}
    </ul>
  );
}
```

### Polymorphic component (render as any element)

```typescript
type PolymorphicProps<T extends React.ElementType> = {
  as?: T;
  children: React.ReactNode;
} & Omit<React.ComponentPropsWithoutRef<T>, "as" | "children">;

function Box<T extends React.ElementType = "div">({
  as,
  children,
  ...props
}: PolymorphicProps<T>) {
  const Component = as ?? "div";
  return <Component {...props}>{children}</Component>;
}

// Usage
<Box>Default div</Box>
<Box as="section" aria-label="main">Section</Box>
<Box as="a" href="/home">Link</Box>
```

---

## Hooks

### useState

```typescript
// Type inferred from initial value
const [count, setCount] = useState(0);              // number
const [name, setName] = useState("");               // string

// Explicit type for complex/nullable initial state
const [user, setUser] = useState<User | null>(null);

// Union literal type
type Status = "idle" | "loading" | "success" | "error";
const [status, setStatus] = useState<Status>("idle");
```

### useRef

```typescript
// DOM element — initial value must be null
const inputRef = useRef<HTMLInputElement>(null);
inputRef.current?.focus(); // safe access

// Mutable value (not a DOM element)
const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

useEffect(() => {
  timerRef.current = setTimeout(() => {}, 1000);
  return () => {
    if (timerRef.current) clearTimeout(timerRef.current);
  };
}, []);
```

### useReducer

```typescript
interface State {
  count: number;
  step: number;
}

type Action =
  | { type: "increment" }
  | { type: "decrement" }
  | { type: "setStep"; payload: number }
  | { type: "reset" };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case "increment": return { ...state, count: state.count + state.step };
    case "decrement": return { ...state, count: state.count - state.step };
    case "setStep":   return { ...state, step: action.payload };
    case "reset":     return { count: 0, step: 1 };
  }
}

const [state, dispatch] = useReducer(reducer, { count: 0, step: 1 });
dispatch({ type: "setStep", payload: 5 });
```

### Custom hook: async data fetching

```typescript
interface UseAsyncResult<T> {
  data: T | null;
  loading: boolean;
  error: Error | null;
  refetch: () => void;
}

function useAsync<T>(
  asyncFn: () => Promise<T>,
  deps: React.DependencyList = []
): UseAsyncResult<T> {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const execute = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await asyncFn());
    } catch (e) {
      setError(e instanceof Error ? e : new Error(String(e)));
    } finally {
      setLoading(false);
    }
  }, deps);

  useEffect(() => { execute(); }, [execute]);

  return { data, loading, error, refetch: execute };
}
```

---

## Event Handling

```typescript
// Click
const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => { ... };

// Input change
const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
  const { name, value, type, checked } = e.target;
  const val = type === "checkbox" ? checked : value;
};

// Form submit
const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
  e.preventDefault();
  const data = new FormData(e.currentTarget);
};

// Keyboard
const handleKey = (e: React.KeyboardEvent<HTMLInputElement>) => {
  if (e.key === "Enter") { ... }
};
```

---

## Context API

```typescript
interface ThemeContextType {
  theme: "light" | "dark";
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const toggleTheme = useCallback(
    () => setTheme(t => t === "light" ? "dark" : "light"),
    []
  );
  const value = useMemo(() => ({ theme, toggleTheme }), [theme, toggleTheme]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

// Hook that throws if used outside provider
function useTheme(): ThemeContextType {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within ThemeProvider");
  return ctx;
}
```

### Generic context factory

```typescript
function createTypedContext<T>(displayName: string) {
  const Ctx = React.createContext<T | undefined>(undefined);
  Ctx.displayName = displayName;

  function useCtx(): T {
    const val = React.useContext(Ctx);
    if (val === undefined)
      throw new Error(`use${displayName} must be used within ${displayName}Provider`);
    return val;
  }

  return [Ctx.Provider, useCtx] as const;
}

// Usage
const [AuthProvider, useAuth] = createTypedContext<AuthContextType>("Auth");
```

---

## State Management

### Zustand

```typescript
import { create } from "zustand";

interface AuthStore {
  user: User | null;
  token: string | null;
  login: (email: string, pass: string) => Promise<void>;
  logout: () => void;
}

const useAuthStore = create<AuthStore>()((set) => ({
  user: null,
  token: null,
  login: async (email, pass) => {
    const { user, token } = await api.login(email, pass);
    set({ user, token });
  },
  logout: () => set({ user: null, token: null }),
}));

// Selector (re-renders only when user changes)
const user = useAuthStore(s => s.user);
```

### Redux Toolkit

```typescript
import { createSlice, PayloadAction, configureStore } from "@reduxjs/toolkit";
import { useDispatch, useSelector, TypedUseSelectorHook } from "react-redux";

const slice = createSlice({
  name: "todos",
  initialState: { items: [] as Todo[] },
  reducers: {
    add: (state, action: PayloadAction<string>) => {
      state.items.push({ id: crypto.randomUUID(), text: action.payload, done: false });
    },
    toggle: (state, action: PayloadAction<string>) => {
      const t = state.items.find(t => t.id === action.payload);
      if (t) t.done = !t.done;
    },
  },
});

const store = configureStore({ reducer: { todos: slice.reducer } });

type RootState = ReturnType<typeof store.getState>;
type AppDispatch = typeof store.dispatch;

export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;
export const useAppDispatch = () => useDispatch<AppDispatch>();
```
