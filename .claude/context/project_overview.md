# Project Overview

_Last updated: 2026-04-16 by planner after task: fix 3 bugs — Ollama output written to disk, buildTasks() fallback for missing context files, implement.md parallel planning + Step 2 apply output_

## Language(s)
- Shell (Bash): `install.sh`, `call_ollama.sh`, `local-commit.sh`, `analyze_project.sh` — pure Bash + `jq` for orchestration — standarts: inferred from existing scripts (no dedicated standarts file)
- Markdown: all agent, command, and skill files — the "code" of the system
- TypeScript: `tsconfig.json`, `src/**/*.ts` — standarts: `skills/ts-code-standarts.md`

This is a **zero-dependency, Unix-native tooling repository**. All logic is handled via Bash, `jq`, and `curl` to interact with Ollama. A TypeScript orchestrator layer (`src/`) handles parallel execution.

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Global instructions injected into every Claude Code session — defines the pipeline, trigger rules, and available Ollama models |
| `scripts/install.sh` | Installer: creates symlinks in `~/.claude/`, generates `settings.json` from template, adds shell aliases, installs git hooks including post-commit graphify-update |
| `scripts/graphify-update.sh` | Post-commit hook script: checks for graphify install and graph.json, runs `python3 -m graphify --update` on changed files; silent if graphify not present |
| `agents/planner.md` | Authoritative source of project context — explores codebase, writes `.claude/context/task_context.md` and maintains `project_overview.md` |
| `agents/coder.md` | Coding agent — reads context, generates code via `call_ollama.sh` (role: coder), applies changes |
| `agents/reviewer.md` | Review agent — diffs changed files, invokes `call_ollama.sh` (role: reviewer), reports verdict |
| `agents/quick-coder.md` | Fast fix agent — uses `qwen2.5-coder:7b` via `call_ollama.sh` (role: quick-coder) |
| `agents/commit.md` | Commit agent — generates commit message via `call_ollama.sh` (role: commit), stages and commits |
| `agents/doc-writer.md` | Documentation agent — reads git diff, drafts docs via `call_ollama.sh` (role: reviewer) |
| `agents/test-agent.md` | Test agent — generates and runs tests via `call_ollama.sh` (role: coder) |
| `agents/architect.md` | Architect agent — system design, refactoring guidance, and long-term technical planning |
| `agents/api-tester.md` | API test agent — contract testing, schema validation, and integration flow coverage |
| `agents/debugger.md` | Debugger agent — root cause analysis via 5-Whys, proposes minimal permanent fixes |
| `agents/devops.md` | DevOps agent — CI/CD pipelines, cloud infrastructure (AWS/K8s), and MCP tooling |
| `agents/qa-orchestrator.md` | QA orchestrator — coordinates test agents, analyzes CI failures, automates PR comment fixes |
| `agents/ui-tester.md` | UI test agent — end-to-end journeys and visual regression via Playwright and Appium |
| `agents/unit-tester.md` | Unit test agent — logic isolation, edge case detection, and dependency mocking |
| `agents/triage-ts.md` | LLM instruction for `triage` role — defines `## Domains` / `## Reasoning` output format consumed by `TriageAgent.parseResponse()` |
| `scripts/call_ollama.sh` | Central LLM interface — handles prompt construction, context attachment, raw API calls via `curl`, and auto-tracks every call via `track_savings.sh` |
| `scripts/local-commit.sh` | Local commit helper — stages changes, generates commit message via Ollama, prompts for confirmation |
| `scripts/open-pr.sh` | PR creation helper — generates PR title/body via Ollama, optionally creates via `gh` CLI |
| `scripts/analyze_project.sh` | Project analyzer — multi-agent script that provides change discovery (delta reports) for the planner |
| `scripts/track_savings.sh` | Token savings logger — accepts either context/output file paths OR direct `--input-tokens`/`--output-tokens` counts; estimates USD saved; appends to `~/.claude/token_stats.json` |
| `scripts/stats.sh` | Savings summary printer — reads `~/.claude/token_stats.json`, filters by period (day/week/month/all), prints formatted summary |
| `commands/implement.md` | `/implement` slash command — orchestrates the full planner → coder → build check → reviewer → fix loop → savings tracking pipeline |
| `commands/review.md` | `/review` slash command — detects language, reads standarts, diffs HEAD, reports violations |
| `commands/standards.md` | `/standarts` slash command — detects language and prints the matching standarts file |
| `commands/stats.md` | `/stats` slash command — runs `stats.sh` with optional period arg (day/week/month) |
| `skills/ts-code-standarts.md` | TypeScript coding standarts (indicator: `tsconfig.json`) |
| `skills/python-code-standarts.md` | Python coding standarts (indicator: `pyproject.toml` or `requirements.txt`) |
| `skills/flutter-code-standarts.md` | Flutter/Dart coding standarts (indicator: `pubspec.yaml`) |
| `skills/swift-code-standarts.md` | Swift coding standarts (indicator: `Package.swift` or `*.xcodeproj`) |
| `skills/c-code-standarts.md` | C++ coding standarts (indicator: `CMakeLists.txt` or `*.cpp`) |
| `skills/doc-standarts.md` | Documentation writing standarts (used by doc-writer agent) |
| `skills/bash/SKILL.md` | Trigger-based bash scripting skill — covers CI scripts, DevOps automation, and `.sh` file tasks |
| `skills/python/SKILL.md` | Trigger-based Python skill — covers CLI tools, APIs, async code, and packaging |
| `skills/typescript/SKILL.md` | Trigger-based TypeScript skill — covers types, generics, tsconfig, and typed React |
| `skills/code-review/SKILL.md` | Trigger-based code review skill — covers PR reviews, quality standards, and security audits |
| `plugins/accessibility/` | Accessibility plugin — ARIA fixes and screen reader test commands |
| `plugins/ai-engineering/` | AI engineering plugin — prompt analysis and optimization commands |
| `plugins/api-architect/` | API architect plugin — API design and OpenAPI spec generation |
| `plugins/committer/` | Committer plugin — local AI commit and push-to-remote commands |
| `plugins/database-tools/` | Database tools plugin — schema design, ERD generation, and query optimization |
| `plugins/debugger/` | Debugger plugin — wraps the debugger agent as a slash command |
| `plugins/docker-helper/` | Docker helper plugin — image builds and Dockerfile optimization |
| `plugins/documentation/` | Documentation plugin — README generation command |
| `plugins/k8s-helper/` | Kubernetes helper plugin — pod debugging and manifest generation |
| `plugins/orchestrator/` | Orchestrator plugin — `/implement` and `/stats` pipeline commands |
| `plugins/python-expert/` | Python expert plugin — idiomatic refactoring and type hint commands |
| `plugins/qa-tools/` | QA tools plugin — test generation, failure analysis, DB seeding, and Slack notification |
| `plugins/refactor-engine/` | Refactor engine plugin — function extraction and code simplification |
| `plugins/release-manager/` | Release manager plugin — version bump, changelog update, and release commands |
| `plugins/reviewer/` | Reviewer plugin — code review and language standards commands |
| `plugins/security-guidance/` | Security guidance plugin — vulnerability fixes and security audit commands |
| `llm-config.json` | Centralized model role configuration — symlinked to `~/.claude/llm-config.json`; includes `"triage": "llama3.1:8b"` role |
| `.claude/settings.json.template` | Template for `settings.json` — contains `PreToolUse` hook that blocks direct edits to `README.md` and `docs/` files; uses `__HOME__` placeholder replaced by `install.sh` |
| `src/types/index.ts` | All TypeScript domain types: `AgentDomain`, `AgentTask`, `AgentResult`, `RunResult`, `OrchestratorConfig`, `LlmConfig`, `TriageResult` |
| `src/core/DependencyGraph.ts` | DAG class with Kahn's topological sort — `getLevels()` returns `AgentTask[][]` for parallel execution |
| `src/agents/AgentRunner.ts` | Wraps `~/.claude/call_ollama.sh` via `child_process.spawn` — returns `RunResult` discriminated union |
| `src/agents/TriageAgent.ts` | LLM-powered triage — scans project structure, does BFS traversal on `graphify-out/graph.json` (NetworkX node-link format, depth=2), calls triage role, parses response into `TriageResult` |
| `src/core/Orchestrator.ts` | Pure execution engine — accepts pre-written domain list, reads `task_context_<domain>.md` files (falls back to `task_context.md` with warning), executes by levels, writes `ollama_output_<domain>.md` after each Ollama call, then reviews |
| `src/index.ts` | CLI entry point — parses `process.argv[2]` as comma-separated `AgentDomain` list, validates, runs `Orchestrator.run(domains)` |
| `tsconfig.json` | TypeScript strict ESM config — target ES2022, module NodeNext, `noUncheckedIndexedAccess: true`, `exactOptionalPropertyTypes: true` |
| `plugins/orchestrator/commands/implement.md` | `/implement` pipeline — Steps 0–6: triage → parallel planning per domain (Step 1) → multi-domain TS Orchestrator (Step 1.5) → apply Ollama output via Claude coders (Step 2) → pre-review (Step 2.5) → code → build → post-review → fix loop → finalize |

## Architecture & Conventions

- Plugins live in `plugins/` — each plugin is a directory with a `commands/` subdirectory containing Markdown slash commands; each command defines trigger keywords and delegates to a paired agent
- All agents are Markdown files in `agents/` with a YAML front-matter block (`name`, `description`, `tools`) — no `model` field; models are defined exclusively in `llm-config.json`
- All slash commands are Markdown files in `commands/` with no front-matter — they describe steps to orchestrate agents
- Language standarts are in `skills/` and are named `<lang>-code-standarts.md` (note: "standarts" not "standards" — intentional spelling in filenames)
- Context files produced during a task go to `.claude/context/`: `triage.md`, `triage_ts.md` (TriageAgent output), `task_context_<domain>.md` (per-domain plans, fallback `task_context.md`), `ollama_output_<domain>.md` (Ollama output written by TS Orchestrator), `pre_review.md`, `coder_output.md`, `coder_output_<domain>.md`, `review_fast_<file>.md`, `review_deep_<file>.md`, `fix_loop.md`, `project_overview.md`
- **Context Handoff Protocol**: orchestrator passes only file paths between steps — never full content; each agent reads its input files directly and writes its own structured output file
- **Pipeline separation**: Claude planner subagents write `task_context_<domain>.md` (one per domain, in parallel); TS Orchestrator reads those files, executes Ollama calls, writes `ollama_output_<domain>.md`; Claude coder subagents read `ollama_output_<domain>.md` and apply changes to disk — no file writes in TypeScript except the output files
- The full pipeline is: triage (TriageAgent → Ollama) → Claude plans per domain → multi-domain TS Orchestrator (`npm start "d1,d2"`) OR single-domain coder → pre-review → build check → tiered review → fix loop (max 3 rounds) → track_savings.sh
- **TypeScript orchestrator layer** (`src/`): ESM modules (`"type": "module"`), all imports use `.js` extensions, strict mode + `noUncheckedIndexedAccess` + `exactOptionalPropertyTypes`. Shell bridge is `~/.claude/call_ollama.sh` via `child_process.spawn`. No new heavy dependencies — only `typescript` + `tsx` + `@types/node` as devDeps.
- **TriageAgent graph traversal**: reads `graphify-out/graph.json` (NetworkX node-link format), matches seed nodes by label keywords, runs BFS depth=2, formats "Affected nodes: X\nConnected to:\n- Y (via relation)" output truncated to 1500 chars
- **DOMAIN_DEPENDENCIES** constant lives in `Orchestrator.ts` (not PlannerAgent — that file no longer exists)
- **Zero Python dependency**: All agents call `scripts/call_ollama.sh` directly, which uses `curl` and `jq` for API interaction
- `install.sh` uses symlinks, not file copies — a `git pull` updates everything without reinstall
- New scripts must be added to both `SYMLINK_TARGETS` array and a `chmod +x` block in `scripts/install.sh`
- Bash scripts use `#!/usr/bin/env bash`; standalone scripts add `set -euo pipefail`
- Arg parsing pattern: `while [[ "$#" -gt 0 ]]; do case $1 in --flag) VAR="$2"; shift ;; esac; shift; done`
- All JSON manipulation uses `jq` — never sed/awk for JSON; `$HOME` not `~` for home dir references
- `settings.json.template` uses `__HOME__` as a placeholder; `install.sh` substitutes it with `$HOME` via `sed`
- Planner (Phase 0): reads `project_overview.md` first, runs `git status --short` + `git diff --name-only HEAD~1 HEAD` to mark stale files, re-reads [STALE] files fully in Phase 1
- Token stats are persisted at `~/.claude/token_stats.json` with schema `{"runs": [...]}`
- `track_savings.sh` supports two modes: (1) file-size mode using `--context-file`/`--output-file`, (2) direct mode using `--input-tokens`/`--output-tokens`; mode is auto-detected by whether both direct flags are present
- `call_ollama.sh` auto-tracks every LLM call via `track_savings.sh` (best-effort, silent on failure)

## Do Not Touch

- `README.md`: managed exclusively by the `doc-writer` agent — a `PreToolUse` hook in `settings.json` will block direct edits
- `docs/` (any path matching `/docs/`): same hook protection as README.md
- `.claude/settings.json`: generated by `install.sh` from the template — do not edit directly on each machine
- `skills/*-code-standarts.md` filenames: the "standarts" typo is load-bearing — all agents reference these exact filenames; renaming breaks detection
- `src/agents/PlannerAgent.ts`: **deleted** — do not recreate; planning is done by Claude subagents writing context files, not by TypeScript

## Known Constraints

- Never mock Ollama in tests: the system relies on real local model responses
- The `debug.md` agent file does not exist in `agents/` — it exists only as `commands/debug.md`
- `quick-coder` uses `qwen2.5-coder:7b` — never use it for multi-file changes or new classes
- The fix loop in `/implement` is capped at 3 rounds — after that, unresolved issues are reported to the user
- `track_savings.sh` Step 6 in `/implement` is best-effort — skip silently if script not found (not yet installed)
- Float arithmetic in bash scripts must use `jq -n` — bash `$(( ))` handles integers only
- `call_ollama.sh` and `track_savings.sh` do NOT use `set -euo pipefail` — do not add it; callers depend on lenient error handling
- `call_claude.sh` does NOT exist — the only shell LLM bridge is `~/.claude/call_ollama.sh`
- TypeScript `src/` files must use `.js` import extensions even for `.ts` source — required by NodeNext ESM module resolution
- `noUncheckedIndexedAccess: true` in tsconfig means array access returns `T | undefined` — guard all index access with `if (x === undefined) continue`
- `exactOptionalPropertyTypes: true` in tsconfig means optional fields typed `string?` cannot be assigned `undefined` — always type optional fields as `string | undefined` explicitly
- `graphify-out/` may not exist — all graphify code guards with `existsSync` before reading
- `TriageResult.graphifyContext` must be typed `string | undefined` (not `string?`) due to `exactOptionalPropertyTypes`
- `Orchestrator.run()` now takes `AgentDomain[]`, not a task string — callers (index.ts, implement.md) must parse domains before calling
- `readdirSync` is no longer imported in `TriageAgent.ts` — the BFS implementation reads only `graph.json` directly
