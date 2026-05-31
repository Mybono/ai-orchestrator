## Minimalist UI — Design Principles

A minimalist UI removes everything that doesn't serve a function. Every element must earn its place.

### Core Rules

1. **One focal point per screen** — one primary action, one primary message. If the eye doesn't know where to go first, the layout is wrong.
2. **Whitespace is structure** — padding and margins communicate hierarchy. More space = more importance.
3. **Limit the palette** — 2 functional colors + 1 accent maximum. Neutral base (grays), one brand color, one action color.
4. **Typography does the work** — size, weight, and spacing carry hierarchy. No decorative fonts in data-heavy interfaces.
5. **Hide until needed** — secondary actions live in menus, drawers, or tooltips. The default view shows only the current task.

### What to Remove

- Borders around containers that whitespace already separates
- Icon + label when the label alone is clear
- Placeholder text that repeats the label
- Hover effects that don't indicate interactivity
- Animations longer than 200ms on functional transitions

### What to Keep

- Clear affordance on every interactive element (cursor, focus ring, hover state)
- Error states — never silent failures
- Loading states — never unexplained delays
- Empty states — explain what goes here and how to fill it

### Measurements (sensible defaults)

- Base spacing unit: 4px (use multiples: 8, 16, 24, 32, 48, 64)
- Body text: 14–16px, line-height 1.5
- Headings: weight 600–700, no decorative flourishes
- Border-radius: 4–8px for interactive elements, 0 for data tables

### Anti-Patterns

- DO NOT add elements "just in case" — add them when they solve a real problem
- DO NOT use color to decorate — use it to communicate state or action
- DO NOT animate layout shifts — fade or scale only non-layout properties
- DO NOT show every feature on the landing screen — progressive disclosure
