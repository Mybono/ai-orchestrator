# AI Guide — Global

## Code Writing Workflow — Save Claude Tokens

**For any non-trivial coding task, always follow this pipeline:**

```markdown
┌─────────────────────────────────────────────────────────────────────────────┐
│  /implement                                                                 │
│                                                                             │
│                                       ┌─ reviewer (file A) ─┐              │
│  planner ──► coder ──► build/type ────┤─ reviewer (file B) ─├──► verdict  │
│                        check          └─ reviewer (file C) ─┘   fix loop  │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1 — planner      │ Claude Sonnet (inherit)  │ detects language, reads standarts,
                      │                          │ explores codebase, writes context file
Step 2 — coder        │ Claude Haiku             │ orchestrates; calls Ollama (role: coder)
Step 2.5 — build      │ Claude Haiku             │ tsc --noEmit (TS), etc.
Step 3 — reviewer ×N  │ Claude Haiku (parallel)  │ orchestrates; calls Ollama (role: reviewer)
```markdown

**LLM Configuration (`llm-config.json`):**

| Role | Responsibility | Default Model |
|------|----------------|---------------|
| `coder` | Main code generation | `qwen2.5-coder:14b...` |
| `reviewer` | Code review and documentation | `qwen2.5-coder:7b` |
| `commit` | Commit messages and minor fixes | `qwen2.5-coder:1.5b` |
| `embedding` | Semantic search and RAG | `nomic-embed-text` |

**Language standarts** (auto-detected by planner and reviewer):

- TypeScript → `.claude/skills/ts-code-standarts.md`
- Python → `.claude/skills/python-code-standarts.md`
- Flutter/Dart → `.claude/skills/fluter-code-standarts.md`
- Swift → `.claude/skills/swift-code-standarts.md`
- C++ → `.claude/skills/c-code-standarts.md`
- Documentation → `.claude/skills/doc-standarts.md`

## Commands

| Command | When |
|---------|------|
| `/implement` | Full plan → code → build → review pipeline |
| `/review` | Check current changes against language standarts |
| `/commit` | Stage and commit changes (uses local LLM) |
| `/stats [day\|week\|month]` | Show token savings summary (all time if no arg) |

**Agents available on demand** (not auto-run):

- `test-agent` — write and run tests (uses `coder` role)
- `doc-writer` — update documentation (uses `reviewer` role)

**Trigger rules** — BLOCKING REQUIREMENT: invoke the agent/skill BEFORE generating any other response:

- User says "commit", "сделай коммит", "закоммить" → run `commit` agent
- User says "implement", "напиши код", "добавь фичу" → run `implement` skill
- User asks to write, create, or update documentation → run `doc-writer` agent

**NEVER edit core orchestration scripts directly** — only use `doc-writer` for markdown. Use `coder` for `.sh` scripts.
