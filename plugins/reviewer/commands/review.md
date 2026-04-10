Review the current code changes against the project coding standarts.

1. Detect project language from indicator files (`tsconfig.json` → TS, `pubspec.yaml` → Flutter, `Package.swift` → Swift, `CMakeLists.txt` → C++, `pyproject.toml` → Python). Read the matching standarts from `.claude/skills/<lang>-code-standarts.md`.
2. Run `git diff HEAD` to see what changed (or review the file/selection the user is pointing at)
3. Check every change against each rule in the standarts

## Output format

Write results to `.claude/context/review_<filename>.md` (replace `/` with `_` in filename). Always write this file — even if no violations.

```markdown
## Verdict
APPROVED | NEEDS CHANGES

## Issues
- `<path>:<line>` [<Rule section>] <short description> — Fix: <concrete fix>

## Notes
- <optional low-priority observations, or "none">
```

For console output (visible to user), print a one-line summary only:

- `✅ <filename> — APPROVED`
- `❌ <filename> — NEEDS CHANGES (N issues)`

Be concise. Only flag real violations — not style preferences or theoretical issues.
