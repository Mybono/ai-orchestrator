
# Skills and Commands

[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · **Skills & Commands**

## Skills

Skills are markdown files in `skills/` (symlinked to `~/.claude/skills/`). Each file defines coding standards for one language. Agents load the relevant skill file before generating or reviewing code.

Language detection happens by checking indicator files in the project root:

| Skill file | Language | Indicator file |
|------------|----------|----------------|
| [ts-code-standarts.md](../skills/ts-code-standarts.md) | TypeScript | `tsconfig.json` |
| [python-code-standarts.md](../skills/python-code-standarts.md) | Python | `pyproject.toml` or `requirements.txt` |
| [flutter-code-standarts.md](../skills/flutter-code-standarts.md) | Flutter/Dart | `pubspec.yaml` |
| [swift-code-standarts.md](../skills/swift-code-standarts.md) | Swift | `Package.swift` or `*.xcodeproj` |
| [c-code-standarts.md](../skills/c-code-standarts.md) | C++ | `CMakeLists.txt` or `*.cpp` files |
| [doc-standarts.md](../skills/doc-standarts.md) | Documentation | always available |
| [humanizer.md](../skills/humanizer.md) | Writing style — removes AI patterns | always available |

The planner reads the skill file once during Phase 1 and embeds the most relevant rules into `task_context.md`. The reviewer reads it directly before each review.

If no indicator file is found, the `/standards` command lists all available skill files and asks the user to choose one.

## Commands

Commands are markdown files in `commands/` (symlinked to `~/.claude/commands/`). Each file describes the behavior of a slash command in Claude Code. Type `/commandname` to invoke a command.

| Command | File | What it does |
|---------|------|--------------|
| `/implement` | `implement.md` | Runs the full planner → coder → build check → reviewer pipeline |
| `/review` | `review.md` | Reviews current changes against the detected project language standards |
| `/commit` | `commit.md` | Stages changes and generates a commit message via Ollama |
| `/stats [day\|week\|month]` | `stats.md` | Shows token savings summary; calls `~/.claude/stats.sh` |
| `/debug` | `debug.md` | Reads an error, traces the data flow, states root cause, proposes a minimal fix |
| `/standards` | `standards.md` | Detects project language and displays the matching coding standards |

### /implement

Runs the complete pipeline for a coding task. Spawns planner, then coder, then runs a build/type check, then spawns one reviewer per changed file in parallel. Repeats the coder + reviewer loop up to 3 times on NEEDS CHANGES. Calls `track_savings.sh` after a successful run.

Skip this command for one-liner changes (rename, single import fix) — make the edit directly.

### /review

Gets `git diff HEAD`, loads the language standards for the detected project, and checks every changed line against each rule. Reports violations in this format:

```text
[Rule section] short description
File: <path>:<line>
Issue: <what is wrong>
Fix: <concrete fix>
```

Reports nothing if no violations are found.

### /stats

Calls `~/.claude/stats.sh` with an optional period argument and displays the token savings table.

```bash
/stats day    # current calendar day
/stats week   # last 7 days
/stats month  # last 30 days
/stats        # all-time totals
```

### /debug

Reads the provided error or stack trace, locates the relevant source code, traces the data flow from inputs to the failure point, and outputs:

```text
Root cause: <one sentence>

File: <path>:<line>
Problem: <what is wrong>
Fix: <concrete change>
```

No speculation — output is based only on what the code and error clearly show.

### /standards

Detects the project language from indicator files in the current working directory and displays the full contents of the matching skill file. Used to inspect the rules that planner and reviewer apply to this project.

[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · **Skills & Commands**
