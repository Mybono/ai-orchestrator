# Documentation Standards

## Language and Tone

- Write in **English only**
- No emojis
- Concise — every sentence earns its place; cut filler words
- Direct — prefer active voice over passive
- Factual — describe what things are and do, not how great they are

## Structure

### README.md (project root)

Required sections in order:

1. **One-line description** — what the project does (not how it works)
2. **Requirements** — language/runtime version, dependencies
3. **Installation** — minimal steps to get running
4. **Usage** — the single most common use case, with a code example
5. **Configuration** (if any) — environment variables or config file fields, in a table
6. **Development** — how to run tests, build, lint
7. **License** (one line)

Omit sections that do not apply. Do not add sections not listed above unless strongly justified.

### API / Module documentation

- Document **public** interfaces only; skip private helpers unless logic is non-obvious
- Each public function/class needs: what it does, parameters (name + type + purpose), return value, and one usage example if non-trivial
- Document error conditions and what the caller should do about them

### Inline code comments

- Comment the **why**, not the **what** — the code already shows what
- Use comments only where the logic is non-obvious or there is a known gotcha
- No commented-out code

## Formatting

- Use Markdown for all documentation files
- Headings: `#` for title, `##` for sections, `###` for subsections — no deeper
- Code blocks: always specify the language (` ```python `, ` ```bash `, etc.)
- Tables for structured data (config options, CLI flags, comparison)
- Lists for steps and enumerations — use numbered lists for ordered steps, bullets otherwise
- Keep lines under 100 characters where possible

## Anti-patterns — Do NOT do this

- DO NOT start with "Welcome to..." or "This is a..." — start with what the thing does
- DO NOT write "easily", "simply", "just", "straightforward" — show, don't tell
- DO NOT document implementation details that will change — document contracts and behavior
- DO NOT duplicate information that is already in code signatures or type definitions
- DO NOT add a "Contributing" section unless the project is open source and has a real process
- DO NOT use passive voice when active voice is shorter ("is returned by" → "returns")
- DO NOT add placeholder sections with "TODO: fill this in"
