## Frontend Design — Standards

### 1. Component Architecture

- **Atomic Design**: atoms (basic elements) → molecules (composites) → organisms (complex layouts)
- **Single Responsibility**: each component handles one distinct function or UI pattern
- **Props Interface**: name props interfaces `ComponentNameProps` (e.g., `ButtonProps`)
- **Co-located Styles**: style files live next to components (`Button.tsx` + `Button.module.css`)

### 2. CSS Methodology

- **BEM Naming**: `.block__element--modifier` (e.g., `.card__title--highlight`)
- **Custom Properties**: define all design tokens as CSS vars: `--color-primary`, `--spacing-md`
- **Mobile-First**: media queries start with `@media (min-width: ...)`
- **No Magic Numbers**: replace hardcoded values with tokens (`margin: var(--spacing-md)`)

### 3. State Management

- **Local State First**: use component state for isolated logic; lift only when shared by ≥2 components
- **Avoid Prop Drilling**: use context or store for shared state — no props beyond 2 levels deep
- **Derive, Don't Duplicate**: compute values from existing state instead of maintaining copies

### 4. Performance

- **Lazy Load**: use `React.lazy` / `Suspense` for routes and heavy components
- **Memoize**: `React.memo` / `useMemo` for expensive computations
- **No Layout Thrash**: batch DOM reads/writes; use `useEffect` for side effects
- **Images**: always set `width` + `height`; use `srcset` for responsive images

### 5. Accessibility (a11y)

- All interactive elements must be keyboard-reachable (tab order, focus ring)
- Prefer semantic HTML over ARIA (`button` not `div[onclick]`)
- Color contrast ≥ 4.5:1 (WCAG AA)
- Every `<img>` must have a descriptive `alt` attribute

### 6. Anti-Patterns

- DO NOT use inline styles for layout — use CSS modules or tokens
- DO NOT use `div`/`span` for interactive elements — use `button`, `a`, `input`
- DO NOT hardcode colors or spacing — always reference CSS custom properties
- DO NOT skip `key` props in lists — each item needs a stable, unique key
