Analyze the error or unexpected behavior and find the root cause.

Provide the error/stack trace if not already in context.

## Process

1. **Read the error carefully** — note the exact message, file, line number
2. **Check `CHANGELOG.md`** — see if recent changes are related to the failure area
3. **Find the source** — locate the relevant code
4. **Trace the data flow** — follow inputs → transformations → failure point
5. **State the root cause** — one clear sentence: "X fails because Y"
6. **Propose a fix** — minimal, targeted change

## Output format

```
Root cause: <one sentence>

File: <path>:<line>
Problem: <what's wrong>
Fix: <concrete change>
```

If multiple causes:
```
Root cause 1: ...
Root cause 2: ...
```

Be direct. No speculation — only what the code/error clearly shows.
