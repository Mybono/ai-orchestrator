# AI Guide — Global

## Code Writing Workflow — Save Claude Tokens

**For any non-trivial coding task, always follow this pipeline:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  /implement                                                                 │
│                                                                             │
│                                       ┌─ reviewer (file A) ─┐              │
│  planner ──► coder ──► build/type ────┤─ reviewer (file B) ─├──► verdict  │
│                        check          └─ reviewer (file C) ─┘   fix loop  │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1 — planner      │ Claude Sonnet (inherit)  │ detects language, reads standards,
                      │                          │ explores codebase, writes context file
Step 2 — coder        │ Claude Haiku             │ orchestrates; Ollama qwen2.5-coder:14b generates
Step 2.5 — build      │ Claude Haiku             │ tsc --noEmit (TS) / mypy (Python) / etc.
Step 3 — reviewer ×N  │ Claude Haiku (parallel)  │ orchestrates; Ollama qwen2.5-coder:7b reviews
```

**Installed Ollama models:**

| Model | Role |
|-------|------|
| `qwen2.5-coder:14b-instruct-q4_K_M` | coder, test-agent — main code generation |
| `qwen2.5-coder:7b` | reviewer — code review against standards |
| `qwen2.5-coder:1.5b` | quick-coder, commit — trivial fixes, commit messages |
| `qwen3:8b` | planner fallback, doc-writer — documentation generation |
| `nomic-embed-text` | semantic code search |

**Language standards** (auto-detected by planner and reviewer):
- TypeScript → `.claude/skills/ts-code-standarts.md`
- Python → `.claude/skills/python-code-standarts.md`
- Flutter/Dart → `.claude/skills/fluter-code-standarts.md`
- Swift → `.claude/skills/swift-code-standarts.md`
- C++ → `.claude/skills/c-code-standarts.md`
- Documentation → `.claude/skills/doc-standarts.md`

**When to skip the full pipeline** (implement directly):
- Single-line fixes
- Import updates
- Renaming a variable

## Commands

| Command | When |
|---------|------|
| `/implement` | Full plan → code → build → review pipeline |
| `/review` | Check current changes against language standards |
| `/debug` | Analyze any error or stack trace |
| `/commit` | Stage and commit changes |

**Agents available on demand** (not auto-run):
- `test-agent` — write and run tests for implemented code (spawn manually when needed)

**Trigger rules** — BLOCKING REQUIREMENT: invoke the agent/skill BEFORE generating any other response:
- User says "commit", "сделай коммит", "закоммить" → run `commit` agent
- User says "implement", "напиши код", "добавь фичу" → run `implement` skill
- User asks to write, create, or update documentation / docs / README / ридми / документацию → run `doc-writer` agent

**NEVER edit README.md or docs/ files directly** — always use the `doc-writer` agent. A hook will block direct edits anyway.
