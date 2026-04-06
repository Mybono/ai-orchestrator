# Project Overview

_Last updated: 2026-04-05 by planner after task: add token savings tracking scripts and /stats slash command_

## Language(s)
- Shell (Bash): `install.sh`, `call_ollama.sh`, `local-commit.sh`, `analyze_project.sh` — pure Bash + `jq` for orchestration — standarts: inferred from existing scripts (no dedicated standarts file)
- Markdown: all agent, command, and skill files — the "code" of the system

This is a **zero-dependency, Unix-native tooling repository**. All logic is handled via Bash, `jq`, and `curl` to interact with Ollama. No Python runtime is required for core operations.

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Global instructions injected into every Claude Code session — defines the pipeline, trigger rules, and available Ollama models |
| `scripts/install.sh` | Installer: creates symlinks in `~/.claude/`, generates `settings.json` from template, adds shell aliases, optionally pulls Ollama models |
| `agents/planner.md` | Authoritative source of project context — explores codebase, writes `.claude/context/task_context.md` and maintains `project_overview.md` |
| `agents/coder.md` | Coding agent — reads context, generates code via `call_ollama.sh` (role: coder), applies changes |
| `agents/reviewer.md` | Review agent — diffs changed files, invokes `call_ollama.sh` (role: reviewer), reports verdict |
| `agents/quick-coder.md` | Fast fix agent — uses `qwen2.5-coder:1.5b` via `call_ollama.sh` (role: commit) |
| `agents/commit.md` | Commit agent — generates commit message via `call_ollama.sh` (role: commit), stages and commits |
| `agents/doc-writer.md` | Documentation agent — reads git diff, drafts docs via `call_ollama.sh` (role: reviewer) |
| `agents/test-agent.md` | Test agent — generates and runs tests via `call_ollama.sh` (role: coder) |
| `scripts/call_ollama.sh` | Central LLM interface — handles prompt construction, context attachment, and raw API calls via `curl` |
| `scripts/local-commit.sh` | Local commit helper — stages changes, generates commit message via Ollama, prompts for confirmation |
| `scripts/open-pr.sh` | PR creation helper — generates PR title/body via Ollama, optionally creates via `gh` CLI |
| `scripts/analyze_project.sh` | Project analyzer — multi-agent script that provides change discovery (delta reports) for the planner |
| `scripts/track_savings.sh` | Token savings logger — reads context/output file sizes, estimates tokens and USD saved, appends to `~/.claude/token_stats.json` |
| `scripts/stats.sh` | Savings summary printer — reads `~/.claude/token_stats.json`, filters by period (day/week/month/all), prints formatted summary |
| `commands/implement.md` | `/implement` slash command — orchestrates the full planner → coder → build check → reviewer → fix loop → savings tracking pipeline |
| `commands/review.md` | `/review` slash command — detects language, reads standarts, diffs HEAD, reports violations |
| `commands/standards.md` | `/standarts` slash command — detects language and prints the matching standarts file |
| `commands/stats.md` | `/stats` slash command — runs `stats.sh` with optional period arg (day/week/month) |
| `skills/ts-code-standarts.md` | TypeScript coding standarts (indicator: `tsconfig.json`) |
| `skills/python-code-standarts.md` | Python coding standarts (indicator: `pyproject.toml` or `requirements.txt`) |
| `skills/fluter-code-standarts.md` | Flutter/Dart coding standarts (indicator: `pubspec.yaml`) |
| `skills/swift-code-standarts.md` | Swift coding standarts (indicator: `Package.swift` or `*.xcodeproj`) |
| `skills/c-code-standarts.md` | C++ coding standarts (indicator: `CMakeLists.txt` or `*.cpp`) |
| `skills/doc-standarts.md` | Documentation writing standarts (used by doc-writer agent) |
| `llm-config.json` | Centralized model role configuration — symlinked to `~/.claude/llm-config.json` |
| `.claude/settings.json.template` | Template for `settings.json` — contains `PreToolUse` hook that blocks direct edits to `README.md` and `docs/` files; uses `__HOME__` placeholder replaced by `install.sh` |

## Architecture & Conventions

- All agents are Markdown files in `agents/` with a YAML front-matter block (`name`, `description`, `model`, `tools`)
- All slash commands are Markdown files in `commands/` with no front-matter — they describe steps to orchestrate agents
- Language standarts are in `skills/` and are named `<lang>-code-standarts.md` (note: "standarts" not "standards" — intentional spelling in filenames)
- Context files produced during a task go to `.claude/context/` — specifically `task_context.md`, `coder_output.md`, and `project_overview.md`
- The full pipeline is: planner writes context → coder generates code → build/type check → reviewer(s) in parallel → fix loop (max 3 rounds) → track_savings.sh
- **Zero Python dependency**: All agents call `scripts/call_ollama.sh` directly, which uses `curl` and `jq` for API interaction
- `install.sh` uses symlinks, not file copies — a `git pull` updates everything without reinstall
- New scripts must be added to both `SYMLINK_TARGETS` array and a `chmod +x` block in `scripts/install.sh`
- Bash scripts use `#!/usr/bin/env bash`; standalone scripts add `set -euo pipefail`
- Arg parsing pattern: `while [[ "$#" -gt 0 ]]; do case $1 in --flag) VAR="$2"; shift ;; esac; shift; done`
- All JSON manipulation uses `jq` — never sed/awk for JSON; `$HOME` not `~` for home dir references
- `settings.json.template` uses `__HOME__` as a placeholder; `install.sh` substitutes it with `$HOME` via `sed`
- The planner agent checks for `project_overview.md` first (Phase 0 fast path) and skips full exploration if it exists
- Token stats are persisted at `~/.claude/token_stats.json` with schema `{"runs": [...]}`

## Do Not Touch

- `README.md`: managed exclusively by the `doc-writer` agent — a `PreToolUse` hook in `settings.json` will block direct edits
- `docs/` (any path matching `/docs/`): same hook protection as README.md
- `.claude/settings.json`: generated by `install.sh` from the template — do not edit directly on each machine
- `skills/*-code-standarts.md` filenames: the "standarts" typo is load-bearing — all agents reference these exact filenames; renaming breaks detection

## Known Constraints

- Never mock Ollama in tests: the system relies on real local model responses
- The `debug.md` agent file does not exist in `agents/` — it exists only as `commands/debug.md`
- `quick-coder` uses `qwen2.5-coder:1.5b` with a hard 4096-token context limit — never use it for multi-file changes or new classes
- The fix loop in `/implement` is capped at 3 rounds — after that, unresolved issues are reported to the user
- `doc-writer` uses `think=False` when calling `qwen3:8b` — do not remove this flag
- `track_savings.sh` Step 5 in `/implement` is best-effort — skip silently if script not found (not yet installed)
- Float arithmetic in bash scripts must use `jq -n` — bash `$(( ))` handles integers only
