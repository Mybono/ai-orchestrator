Show the coding standards for this project. Use these rules when writing, reviewing, or modifying any code in this repo.

---

Detect the project language from indicator files in the current working directory:

- `tsconfig.json` → TypeScript → read `.claude/skills/ts-code-standarts.md`
- `pubspec.yaml` → Flutter/Dart → read `.claude/skills/fluter-code-standarts.md`
- `Package.swift` or `*.xcodeproj` → Swift → read `.claude/skills/swift-code-standarts.md`
- `CMakeLists.txt` or `*.cpp` files → C++ → read `.claude/skills/c-code-standarts.md`
- `pyproject.toml` or `requirements.txt` → Python → read `.claude/skills/python-code-standarts.md`

Read the matching standards file and display its contents.

If no indicator file is found, list all available standards files and ask the user to pick one.
