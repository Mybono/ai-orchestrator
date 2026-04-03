Review the current code changes against the project coding standards.

1. Detect project language from indicator files (`tsconfig.json` → TS, `pubspec.yaml` → Flutter, `Package.swift` → Swift, `CMakeLists.txt` → C++, `pyproject.toml` → Python). Read the matching standards from `.claude/skills/<lang>-code-standarts.md`.
2. Run `git diff HEAD` to see what changed (or review the file/selection the user is pointing at)
3. Check every change against each rule in the standards

## Output format

For each violation:
```
❌ [Rule section] <short description>
   File: <path>:<line>
   Issue: <what's wrong>
   Fix: <concrete fix>
```

If no violations:
```
✅ No violations found. Code follows project standards.
```

Be concise. Only flag real violations — not style preferences or theoretical issues.
