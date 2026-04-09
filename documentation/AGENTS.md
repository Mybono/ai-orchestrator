[README](../README.md) · [Architecture](ARCHITECTURE.md) · **Agents** · [Skills & Commands](SKILLS.md)

---

# Agents

Agents are markdown files in `agents/`. Each file defines the behavior of a subagent that Claude Code can spawn. The `/implement` command orchestrates agents automatically; agents can also be invoked on demand.

## [Planner](../agents/planner.md)

Analyzes a coding task, explores the codebase, and writes `.claude/context/task_context.md`. It never writes production code.

- **Triggered by**: `/implement`, always first, before any code is written
- **Claude model**: Sonnet (inherited from the calling session)
- **Ollama**: not used directly — planner writes the context that coder and reviewer consume

The planner checks for `.claude/context/project_overview.md` on every run. If it exists, the planner skips full codebase exploration and only verifies that previously recorded files still exist (fast path). Otherwise it detects the project language from indicator files, reads the matching standards file from `.claude/skills/`, explores the codebase with Glob and Grep, and reads every relevant file in full.

The output `task_context.md` contains: the task description, a step-by-step plan, exact function signatures, copy-pasted code patterns, anti-patterns to avoid, and full contents of every file that will be changed.

After writing `task_context.md`, the planner updates `.claude/context/project_overview.md` with any new architectural findings.

## [coder](../agents/coder.md)

Reads `task_context.md` and implements the changes by calling Ollama for code generation, then applies them with Edit and Write tools.

- **Triggered by**: `/implement`, after planner completes
- **Claude model**: haiku
- **Ollama role**: `coder` (default model: `qwen3-coder:30b-a3b-q4_K_M`)

The coder does not re-explore the codebase. All context comes from `task_context.md`. For non-trivial generation it calls:

```bash
bash ~/.claude/call_ollama.sh --role coder --prompt "$PROMPT"
```

After applying changes, it runs `python3 -m py_compile` (Python) or `tsc --noEmit` (TypeScript) per changed file, and writes a summary to `.claude/context/coder_output.md`.

## [reviewer](../agents/reviewer.md)

Reviews code diffs against project standards, runs a syntax check, and calls Ollama for logic and bug analysis. Returns `APPROVED` or `NEEDS CHANGES` with a list of issues.

- **Triggered by**: `/implement`, after coder and build check; one instance per changed file, run in parallel
- **Claude model**: haiku
- **Ollama role**: `reviewer` (default model: `qwen2.5-coder:7b`)

The reviewer reads the diff (`git diff HEAD -- <file>`), loads the language standards from `.claude/skills/`, checks reverse dependencies (callers of changed modules), runs a syntax check, and sends the diff to Ollama for analysis.

Output format:

```text
VERDICT: APPROVED | NEEDS CHANGES

FILES REVIEWED: <paths>

ISSUES (if any):
- [CRITICAL] <issue> — <fix>
- [WARNING]  <issue> — <fix>
- [STYLE]    <issue> — <fix>
```

CRITICAL issues block merging. WARNING issues should be fixed but are not blockers. STYLE issues are optional.

## [quick-coder](../agents/quick-coder.md)

Handles small, targeted changes using the lightest available model. Intended for single-function fixes, import updates, renames, and constant additions.

- **Triggered by**: user or agent request for a change under ~30 lines that does not require planning
- **Claude model**: haiku
- **Ollama role**: `commit` (qwen2.5-coder:7b)

If the task turns out to require more than one file or more than ~30 lines, quick-coder stops and recommends using `/implement` instead. Prompts must be short because the model has a 4096-token context window.

No review step follows quick-coder for trivial changes.

## [commit](../agents/commit.md)

Stages and commits all pending changes. Generates the commit message via Ollama.

- **Triggered by**: user says "commit", "make a commit", "save changes", or uses `/commit`
- **Claude model**: haiku
- **Ollama role**: `commit` (qwen2.5-coder:7b)

The agent never asks for confirmation. It runs `git status`, gets the diff, generates a conventional-commits message (prefix: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`), then stages and commits. It never commits `venv/`, `dist/`, `*.egg-info/`, `__pycache__/`, or `.env` files.

## [doc-writer](../agents/doc-writer.md)

Creates or updates documentation after code changes. Reads the git diff, calls Ollama to draft content, then applies changes to markdown files.

- **Triggered by**: user asks to write, create, or update documentation, README, or docs
- **Claude model**: Sonnet (inherited)
- **Ollama role**: `reviewer` (qwen2.5-coder:7b)

All content is derived from the git diff. The agent never invents API details or documents code that was not changed. It uses Edit for targeted updates to existing files and Write for new files.

## [test-agent](../agents/test-agent.md)

Writes tests for code that was just implemented, runs them, and performs one fix round if they fail.

- **Triggered by**: on demand, after the coder agent has written code
- **Claude model**: Sonnet (inherited)
- **Ollama role**: `coder` (qwen3-coder:30b-a3b-q4_K_M)

The agent reads `task_context.md` to understand what was built, detects the language and test framework from indicator files, reads existing test files to mirror their style, generates new tests via Ollama, writes them to the appropriate location, and runs them.

If tests fail, the agent sends the full error output back to Ollama for a fix and runs again. It stops after one fix round and reports any remaining failures.

Framework detection:

| Indicator | Language | Framework | Run command |
|-----------|----------|-----------|-------------|
| `tsconfig.json` | TypeScript | Jest or Vitest | `npx jest` / `npx vitest run` |
| `pubspec.yaml` | Flutter/Dart | flutter test | `flutter test` |
| `Package.swift` | Swift | XCTest | `swift test` |
| `CMakeLists.txt` | C++ | GoogleTest / Catch2 | `ctest` |
| `pyproject.toml` | Python | pytest | `python -m pytest -v` |
| `*.sh` | Bash | Shunit2 | `shunit2` |

## [debugger](../agents/debugger.md)

Analyzes errors, stack traces, and logs to find the fundamental cause of a failure. Proposes a hotfix and a systemic countermeasure.

- **Triggered by**: user sharing an error log, stack trace, or asking "why did this happen"
- **Claude model**: Sonnet (inherited)
- **Ollama role**: `debugger` (qwen2.5-coder:7b)

The agent ALWAYS loads `skills/root-cause-analysis/SKILL.md` before starting the analysis. It gathers the logs and relevant source code, conducts a systematic 5-Whys analysis, and outputs a structured Root Cause Analysis report.

## [architect](../agents/architect.md)

Evaluates designs, proposed refactors, and technology choices using fundamental truths instead of analogies.

- **Triggered by**: `/implement` (Phase 1), user asking "is this the right approach?", or refactor requests
- **Claude model**: Sonnet (inherited)
- **Ollama role**: `architect` (qwen2.5-coder:14b)

The agent ALWAYS loads `skills/first-principles/SKILL.md`. It identifies the core job to be done, challenges all current assumptions, identifies ground truths, and builds up the recommended solution from those fundamentals. It is the primary agent for "Phase 1: Planning".

### 🎓 Local Use & Mentorship (Onboarding)
Developers can use the Architect agent directly in their AI IDE (Cursor, VS Code + Copilot/Cline) or Claude Code to learn project standards and architectural patterns.

**How to invoke:**
1.  **Mention the Agent**: In your chat, point to `agents/architect.md` (using `@` or as context).
2.  **Ask for Guidance**: Provide the path to the project or folder you are working on.

**Example Prompts:**
- *"Read `agents/architect.md` and tell me: how do we correctly add a new endpoint in `src/routes/` according to our standards?"*
- *"Based on our architectural rules, is this the right way to handle database transactions in this module?"*
- *"I am new here. Can you explain the project structure of `src/` using the Architect's identity?"*

## [devops](../agents/devops.md)

Architects CI/CD pipelines, cloud infrastructure (AWS), and develops MCP servers.

- **Triggered by**: user asks for "CI/CD", "deploy", "AWS", "Docker", "Kubernetes", or "MCP server"
- **Claude model**: Sonnet (inherited)
- **Ollama role**: `devops` (qwen2.5-coder:7b)

The agent leverages specialized skills: `skills/ci-cd-pipelines/SKILL.md`, `skills/aws-cloud-patterns/SKILL.md`, and `skills/devops-automation/SKILL.md`. It is responsible for ensuring that all development is cloud-ready and properly automated.
