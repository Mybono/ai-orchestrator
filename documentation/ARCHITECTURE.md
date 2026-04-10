# Architecture

[README](../README.md) · **Architecture** · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md)

## Pipeline

The `/implement` command runs a multi-layer smart pipeline:

```text
┌──────────────────────────────────────────────────────────────┐
│  Layer 0 — TRIAGE                                            │
│  Detects complexity + domain → chooses route                 │
│                                                              │
│  nano → direct edit                                          │
│  micro → quick-coder → build check                          │
│  standard (single domain) → plugin-route                     │
│  standard (multi-domain)  → full-pipeline                    │
│  complex → architect-first → full-pipeline                   │
└──────────────────────────────────────────────────────────────┘
                            │
          ┌─────────────────┴──────────────────┐
          │ plugin-route                        │ full-pipeline
          │                                     │
          ▼                                     ▼
┌─────────────────────┐         ┌──────────────────────────────┐
│  Plugin file        │         │  Layer 1 — PLAN               │
│  used as plan       │         │  planner (Ollama)             │
│  (planner skipped)  │         │  → task_context.md            │
└─────────────────────┘         │  (+ domain constraints)       │
          │                     │                               │
          │                     │  pre-reviewer (Ollama)        │
          │                     │  → approves approach          │
          │                     └──────────────────────────────┘
          │                                     │
          └─────────────────┬──────────────────┘
                            │
          ┌─────────────────▼──────────────────┐
          │  Layer 2 — CODE                     │
          │  coder (Ollama) → build check       │
          └─────────────────────────────────────┘
                            │
          ┌─────────────────▼──────────────────┐
          │  Layer 3 — GATE                     │
          │  fast reviewer per file (parallel)  │
          │  → deep reviewer (if issues found   │
          │    or security/api domain)           │
          └─────────────────────────────────────┘
                            │
          ┌─────────────────▼──────────────────┐
          │  Layer 4 — FIX LOOP                 │
          │  error-coordinator manages retries  │
          │  max 3 rounds + circuit breaker     │
          └─────────────────────────────────────┘
                            │
          ┌─────────────────▼──────────────────┐
          │  Layer 5 — FINALIZE                 │
          │  track_savings + performance-monitor│
          └─────────────────────────────────────┘
```

### Layer details

Agents communicate exclusively through files in `.claude/context/`. The orchestrator passes only **file paths** between steps — never full content.

| Layer | Stage | Agent | Reads | Writes |
|---|---|---|---|---|
| 0 | Triage | Claude | task description | `triage.md` |
| 1 | Plan | planner (Ollama) | `triage.md` | `task_context.md` |
| 1 | Pre-review | reviewer (Ollama) | `task_context.md` | `pre_review.md` |
| 2 | Code | coder (Ollama) | `task_context.md`, `triage.md` | `coder_output.md` |
| 2 | Build check | — | changed files | — |
| 3 | Fast review | quick-coder (Ollama) | changed file, `triage.md` | `review_fast_<file>.md` |
| 3 | Deep review | reviewer (Ollama) | changed file, `review_fast_<file>.md`, `triage.md` | `review_deep_<file>.md` |
| 4 | Fix loop | coder (Ollama) | `fix_loop.md`, `triage.md` | `coder_output.md` |
| 5 | Finalize | — | `coder_output.md` | — |

**Context handoff rule**: orchestrator reads only the `## Verdict` line from each output file. Full content stays on disk, out of the orchestrator context.

### Triage domains and routing

Triage scans the task description for domain keywords and loads the matching plugin, skills, and agents into `task_context.md` automatically:

| Domain | Keywords (sample) | Plugin | Agents |
|---|---|---|---|
| `api` | api, endpoint, REST, GraphQL, OpenAPI | api-architect | architect, api-tester |
| `docker` | docker, dockerfile, container | docker-helper | devops |
| `ci_cd` | CI/CD, k8s, kubernetes, deploy | k8s-helper | devops |
| `release` | release, version bump, semver, publish | release-manager | devops |
| `security` | security, auth, JWT, OWASP, injection | security-guidance | security-auditor, reviewer |
| `database` | schema, SQL, migration, ERD | database-tools | architect |
| `testing` | test, unit test, e2e, playwright | qa-tools | unit-tester, test-agent, qa-orchestrator |
| `accessibility` | aria, a11y, WCAG, screen reader | accessibility | ui-tester |
| `bug` | bug, crash, stack trace, error, fix | debugger | debugger |
| `refactor` | refactor, simplify, extract, complexity | refactor-engine | architect |
| `python` | python, pep, mypy, pydantic | python-expert | — |
| `ai_llm` | prompt, LLM, RAG, embedding, vector | ai-engineering | — |
| `docs` | readme, docs, changelog | documentation | doc-writer |
| `performance` | slow, optimize, cache, latency | database-tools | architect |

### Plugin-route vs Full-pipeline

| | plugin-route | full-pipeline |
|---|---|---|
| When | Single domain, task intent matches one plugin exactly | Multi-domain or composite task |
| Plan | Plugin command file used directly as plan | planner agent writes `task_context.md` |
| Pre-review | Skipped (plugin defines the approach) | Runs before coding |
| Code | coder (Ollama) | coder (Ollama) |
| Review | fast + deep reviewer (Ollama) | fast + deep reviewer (Ollama) |
| Token cost | Lower (planner skipped) | Standard |

---

## call_ollama.sh

`scripts/call_ollama.sh` is the single interface every agent uses to reach a local Ollama model. It is symlinked to `~/.claude/call_ollama.sh` during installation.

### Interface

```bash
bash ~/.claude/call_ollama.sh \
  --role <role> \
  --prompt "<text>" \
  [--context-file <path>] \
  [--model <override>]
```

### How it works

1. Walks up from `$PWD` to find the nearest `llm-config.json`. Project-level config wins over `~/.claude/llm-config.json`.
2. Resolves the Ollama model name for the given role using `jq`.
3. Writes the prompt and optional context file to temp files, then builds the JSON payload with `jq`.
4. Sends `POST http://localhost:11434/api/chat` and extracts `.message.content` from the response.
5. Calls `track_savings.sh` in best-effort mode to record estimated token usage.

---

## Model Configuration

`llm-config.json` in the repo root is the single source of truth for model routing.

```json
{
  "models": {
    "coder":        "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "planner":      "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "architect":    "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "reviewer":     "qwen2.5-coder:7b",
    "pre-reviewer": "qwen2.5-coder:7b",
    "quick-coder":  "qwen2.5-coder:7b",
    "commit":       "qwen2.5-coder:7b",
    "triage":       "llama3.1:8b",
    "embedding":    "mxbai-embed-large"
  }
}
```

---

## Symlinks

`scripts/install.sh` creates symlinks from `~/.claude/` into the cloned repo using `ln -sfn`. After installation, a `git pull` in the repo directory instantly updates all global tooling.

Items symlinked into `~/.claude/`:

- `documentation/CLAUDE.md`
- `documentation/ai_rules.md`
- `agents/`
- `commands/`
- `skills/`
- `scripts/call_ollama.sh`
- `scripts/local-commit.sh`
- `scripts/open-pr.sh`
- `scripts/track_savings.sh`
- `scripts/stats.sh`
- `llm-config.json`

---

## Context Files

Agents share state through files in `.claude/context/`:

| File | Written by | Read by | Purpose |
|---|---|---|---|
| `triage.md` | triage (Layer 0) | planner, coder, reviewer | Complexity tier, domain, route, skills, agents, constraints |
| `task_context.md` | planner | coder, reviewer | Full plan: signatures, patterns, file contents, domain standards |
| `coder_output.md` | coder | — | Summary of what was implemented |
| `project_overview.md` | planner | planner | Cached project map; speeds up future planner runs |

---

[README](../README.md) · **Architecture** · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md)
