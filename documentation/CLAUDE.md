# AI Guide — Project-specific reference

This file is read by Claude Code when working in this repo. It covers the orchestration pipeline, LLM roles, slash commands, and trigger rules. General principles (humanizer, doc standards, zero deps, English only) live in `~/.claude/CLAUDE.md` and are not repeated here.

## Coding workflow

For any non-trivial coding task, follow this pipeline:

```text
/implement

                                   ┌─ reviewer (file A) ─┐
planner ──► coder ──► build/type ──┤─ reviewer (file B) ─├──► verdict / fix loop
                      check        └─ reviewer (file C) ─┘
```

| Step | Runner | LLM role | What it does |
|------|--------|----------|--------------|
| 1 — planner | Claude Sonnet (inherit) | — | Detects language, reads standards, explores codebase, writes context file |
| 2 — coder | Claude Haiku | `coder` | Orchestrates; calls Ollama |
| 2.5 — build | Claude Haiku | — | `tsc --noEmit` (TS) or equivalent |
| 3 — reviewer ×N | Claude Haiku (parallel) | `reviewer` | Orchestrates; calls Ollama |

## LLM roles

Roles are defined in `llm-config.json` at the project root or in `~/.claude/llm-config.json`.

| Role | Default model | Responsibility |
|------|--------------|----------------|
| `coder` | `hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS` | Main code generation |
| `reviewer` | `qwen2.5-coder:7b` | Code review and documentation |
| `commit` | `qwen2.5-coder:7b` | Commit messages and minor fixes |
| `debugger` | `qwen2.5-coder:7b` | Root Cause Analysis and bug fixing |
| `architect` | `hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS` | Architectural design & RCA |
| `devops` | `qwen2.5-coder:7b` | CI/CD, Infrastructure & MCP |
| `embedding` | `nomic-embed-text` | Semantic search and RAG |

## Language standards

The planner and reviewer auto-detect the language from the changed files and load the matching standard:

| Language | Standard file |
|----------|---------------|
| TypeScript | [skills/ts-code-standarts.md](../skills/ts-code-standarts.md) |
| Python | [skills/python-code-standarts.md](../skills/python-code-standarts.md) |
| Flutter/Dart | [skills/flutter-code-standarts.md](../skills/flutter-code-standarts.md) |
| Swift | [skills/swift-code-standarts.md](../skills/swift-code-standarts.md) |
| C++ | [skills/c-code-standarts.md](../skills/c-code-standarts.md) |
| Bash/Shell | [skills/bash-code-standarts.md](../skills/bash-code-standarts.md) |
| Documentation | [skills/doc-standarts.md](../skills/doc-standarts.md) |
| Code Review | [skills/code-review/SKILL.md](../skills/code-review/SKILL.md) |
| Root Cause Analysis | [skills/root-cause-analysis/SKILL.md](../skills/root-cause-analysis/SKILL.md) |
| First Principles | [skills/first-principles/SKILL.md](../skills/first-principles/SKILL.md) |
| DevOps / CI-CD | [skills/devops-automation/SKILL.md](../skills/devops-automation/SKILL.md) |
| AWS Cloud | [skills/aws-cloud-patterns/SKILL.md](../skills/aws-cloud-patterns/SKILL.md) |
| MCP | [skills/mcp-development/SKILL.md](../skills/mcp-development/SKILL.md) |
| Advanced Git | [skills/git-advanced/SKILL.md](../skills/git-advanced/SKILL.md) |
| Kubernetes Ops | [skills/kubernetes-operations/SKILL.md](../skills/kubernetes-operations/SKILL.md) |
| Microservices | [skills/microservices-design/SKILL.md](../skills/microservices-design/SKILL.md) |
| WebSockets / Real-time | [skills/websocket-realtime/SKILL.md](../skills/websocket-realtime/SKILL.md) |

## Commands

| Command | When to use |
|---------|-------------|
| `/implement` | Full plan → code → build → review pipeline |
| `/review` | Check current changes against language standards |
| `/commit` | Stage and commit changes using the local LLM |
| `/stats [day\|week\|month]` | Token savings summary (all time if no argument) |

## Agents available on demand

These are not triggered automatically. Call them explicitly when needed.

- `test-agent` — write and run tests (uses the `coder` role)
- `doc-writer` — update documentation (uses the `reviewer` role)
- `debugger` — systematic root cause analysis (uses the `debugger` role)
- `architect` — architectural review and first principles (uses the `architect` role)
- `devops` — CI/CD, AWS and MCP development (uses the `devops` role)

## Trigger rules

BLOCKING REQUIREMENT: invoke the matching agent or skill before generating any other response.

- User says "commit" or "make a commit" → run the `commit` agent
- User says "open pr", "create a pull request", or "open a pull request" → run the `commit` agent
- User says "implement", "напиши код", or "добавь фичу" → run the `architect` agent for planning, then the `implement` skill
- User asks to write, create, or update documentation → run the `doc-writer` agent
- User asks "could we do this better?", "is this the right approach?", or needs a refactor → run the `architect` agent
- User shares an error log, stack trace, or asks "why did this happen" → run the `debugger` agent
- User asks to "setup CI/CD", "deploy to AWS/cloud", or "write MCP server" → run the `devops` agent
- User asks about "microservices", "event-driven", "saga pattern", or "k8s/helm" → run the `architect` or `devops` agent
- User says "websocket", "socket.io", or "real-time" → run the `architect` agent

## Core constraints

- NEVER edit core orchestration scripts directly — use the `coder` agent for `.sh` files.
- NEVER use `doc-writer` for shell scripts or `coder` for markdown files.
- NEVER add Python dependencies to the core logic.
- ALWAYS use `jq` for JSON processing.
