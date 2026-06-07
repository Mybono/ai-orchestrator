# Architecture

[README](../README.md) · **Architecture** · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · [Cluster](CLUSTER.md)

## Pipeline

The `/implement` command runs a multi-layer smart pipeline:

```text
+-----------------------------------------------------------------+
|  Layer 0 - TRIAGE                                               |
|  Detects complexity + domain -> chooses route                   |
|                                                                 |
|  nano -> direct edit                                            |
|  micro -> quick-coder -> build check                            |
|  standard (single domain) -> plugin-route                       |
|  standard (multi-domain)  -> full-pipeline                      |
|  complex -> architect-first -> full-pipeline                    |
+-----------------------------------------------------------------+
                            |
          +-----------------+-----------------+
          | plugin-route                      | full-pipeline / architect-first
          |                                   |
          v                                   v
+---------------------+       +-------------------------------+
|  Plugin file        |       |  architect-first (if routed)  |
|  used as plan       |       |  architect <-> planner debate |
|  (planner skipped)  |       |  up to 2 rounds               |
+---------------------+       |  -> architect_decision.md     |
          |                   +-------------------------------+
          |                                   |
          |                   +-------------------------------+
          |                   |  Layer 1 - PLAN               |
          |                   |  Claude (orchestrator)        |
          |                   |  -> task_context.md           |
          |                   |  (+ domain constraints)       |
          |                   |                               |
          |                   |  pre-reviewer (Ollama)        |
          |                   |  -> approves approach         |
          |                   +-------------------------------+
          |                                   |
          +-----------------+-----------------+
                            |
          +-----------------v-----------------+
          |  Layer 2 - CODE                   |
          |  coder (Ollama) -> build check    |
          +-----------------------------------+
                            |
          +-----------------v-----------------+
          |  Layer 3 - GATE                   |
          |  fast reviewer per file (parallel)|
          |  -> deep reviewer (if issues found|
          |    or security/api domain)        |
          +-----------------------------------+
                            |
          +-----------------v-----------------+
          |  Layer 4 - FIX LOOP               |
          |  error-coordinator manages retries|
          |  max 3 rounds + circuit breaker   |
          +-----------------------------------+
                            |
          +-----------------v-----------------+
          |  Layer 5 - FINALIZE               |
          |  track_savings + performance-mon  |
          +-----------------------------------+
```

### Layer details

Agents communicate exclusively through files in `.claude/context/`. The orchestrator passes only **file paths** between steps — never full content.

| Layer | Stage | Agent | Reads | Writes |
|---|---|---|---|---|
| 0 | Triage | Claude + TriageAgent (TS) | task description, `graph.json` | `triage_ts.md` |
| 0.5 | Tension Loop | architect + planner (Claude) | task description, prior round output | `architect_decision.md` |
| 1 | Plan | Claude (orchestrator) | `triage_ts.md`, `architect_decision.md` (if present) | `task_context_<domain>.md` |
| 1.5 | TS Orchestrator | Ollama (per domain) | `task_context_<domain>.md` | `ollama_output_<domain>.md` |
| 1 | Pre-review | reviewer (Ollama) | `task_context_<domain>.md` | `pre_review.md` |
| 2 | Code | Claude coder | `ollama_output_<domain>.md` | `coder_output_<domain>.md` |
| 2 | Build check | — | changed files | — |
| 3 | Fast review | quick-coder (Ollama) | changed file, `triage_ts.md` | `review_fast_<file>.md` |
| 3 | Deep review | reviewer (Ollama) | changed file, `review_fast_<file>.md` | `review_deep_<file>.md` |
| 4 | Fix loop | coder (Ollama) | `fix_loop.md` | `coder_output_<domain>.md` |
| 5 | Finalize | — | `coder_output_<domain>.md` | — |

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

### Triage routes

| Route | Triggers | What happens |
|---|---|---|
| `direct-edit` | nano task (typo fix, single-line change) | Claude edits directly; no agents invoked |
| `quick-coder` | micro task (single file, clear scope) | coder (Ollama) → build check |
| `plugin-route` | single domain, task matches one plugin exactly | plugin command file used as plan; planner skipped |
| `full-pipeline` | multi-domain or composite task | planner → coder → build check → reviewer |
| `architect-first` | complexity=complex OR keywords: refactor, redesign, new module, architecture, migrate, extract, split, rewrite | architect ⇄ planner debate (max 2 rounds) → `architect_decision.md` → full-pipeline |

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

## TypeScript orchestrator

The TypeScript orchestrator runs at step 1.5 in the `/implement` flow, between the Claude planners and the Claude coders. It handles multi-domain tasks: reads the context files written by the planners, runs Ollama agents in dependency order, and writes the generated code output for Claude to apply.

### Invocation

```bash
npm start "coder,unit-tester,doc-writer"
```

Valid domain names come from `KNOWN_DOMAINS` in `src/types/index.ts`. Any domain not in that list is silently dropped before execution starts.

### Domain dependencies

| Domain | Depends on |
|--------|------------|
| `coder` | (none) |
| `unit-tester` | `coder` |
| `doc-writer` | `coder` |
| `devops` | `coder`, `unit-tester`, `doc-writer` |

Domains at the same dependency level run concurrently via `Promise.all`. The order across levels follows Kahn's topological sort (`DependencyGraph.ts`).

### Circuit breaker

If a domain fails, all dependents are set to `status: blocked` and never run. The failed domain is added to an internal `failedDomains` set; each subsequent task checks that set before executing.

`AgentResult.status` values:

| Status | Meaning |
|--------|---------|
| `done` | Ollama call succeeded; output written to `ollama_output_<domain>.md` |
| `skipped` | No context file found for this domain |
| `failed` | Ollama call returned a non-zero exit code or timed out |
| `blocked` | A dependency failed; this domain was never attempted |

### Source layout

```text
src/
  types/index.ts        AgentDomain, KNOWN_DOMAINS, Role, AgentTask,
                        AgentResult, RunResult, TriageResult, TriageRoute
  agents/
    AgentRunner.ts      Wraps call_ollama.sh via spawn; 5 min timeout;
                        10 MB stdout+stderr limit; validates promptFile before spawn
    TriageAgent.ts      BFS depth=2 on graph.json; writes triage_ts.md;
                        route detection via ARCHITECT_FIRST_KEYWORDS;
                        CLI entry via import.meta.url
  core/
    DependencyGraph.ts  Kahn topological sort; throws on duplicate domains or cycles
    Orchestrator.ts     Reads task_context_<domain>.md; runs agents level by level;
                        reviews ollama_output_<domain>.md after all domains complete;
                        mkdirSync for contextDir in constructor
  index.ts              CLI entry: npm start "coder,unit-tester,doc-writer"
```

### Review step

After all domains complete, `Orchestrator.review()` runs the `reviewer` role against each `ollama_output_<domain>.md` file concurrently. It reviews the generated code, not the plan file. Domains with status other than `done` are skipped.

### Autonomous pipeline script

`scripts/run_pipeline.sh` wraps the full coding pipeline into a single non-interactive shell script. It accepts one argument — the task description — and runs triage, planning, and the TS orchestrator in sequence.

```bash
bash scripts/run_pipeline.sh "add retry logic to AgentRunner"
```

Internal flow:

1. **Triage** — calls `triage-agent.sh`, reads the resulting `triage_ts.md` to extract domains and route.
2. **Route check** — exits immediately (code 0) if the route is `direct-edit`, `quick-coder`, or `plugin-route`.
3. **Plan** — runs `plan_task.sh` in parallel for each domain, waits for all planners, then verifies `task_context_<domain>.md` was written.
4. **Orchestrate** — calls `ts-orchestrator.sh "$DOMAINS"` and maps its exit code: `0` = success, `2` = build failed, `3` = review failed.

**`scripts/plan_task.sh`** generates `task_context_<domain>.md` for one domain. It assembles context from the knowledge graph wiki, project overview, architecture docs, language standards, and relevant source files, then sends the combined prompt to a free LLM API (configurable via `free_api_url` in `llm-config.json`). Falls back to Claude when the free API is unavailable. Arguments:

| Flag | Required | Description |
|---|---|---|
| `--task` | yes | Task description |
| `--domain` | no | Domain name (default: `coder`) |
| `--triage` | no | Path to `triage_ts.md` for additional context |
| `--project` | no | Project root (default: `$PWD`) |

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
| `triage_ts.md` | TriageAgent (TS, Layer 0) | planners, coders, reviewers | Detected domains, reasoning, route, graphify context used |
| `architect_decision.md` | architect (Layer 0.5, Tension Loop) | planner (Layer 1) | Design decision, trade-offs, and PROCEED/BLOCKED verdict |
| `task_context_<domain>.md` | Claude planner (Layer 1) | TS Orchestrator, Claude coder | Full plan per domain: signatures, patterns, domain standards |
| `task_context.md` | Claude planner (fallback) | TS Orchestrator | Used when a domain-specific file is not present |
| `ollama_output_<domain>.md` | TS Orchestrator (Layer 1.5) | Claude coder (Layer 2) | Ollama-generated code output for each domain |
| `coder_output_<domain>.md` | Claude coder (Layer 2) | — | Summary of applied changes per domain |
| `project_overview.md` | planner | planner | Cached project map; speeds up future planner runs |

---

## Cluster mode

The orchestrator supports three inference backends selected automatically based on whether `exo-config.json` is present in the project root.

| Condition | Backend | Behavior |
|---|---|---|
| File absent | `AgentRunner` | Local Ollama at `localhost:11434` |
| `combined: false` | `DistributedRunner` | Routes each role to the first cluster node that claims it |
| `combined: true` | `ExoRunner` | Sends requests to an Exo gateway; model is split across machines |

`DistributedRunner` reads `exo-config.json`, iterates `nodes[]`, and picks the first node whose `roles` map contains the requested role. When no node matches, it falls back to `localhost:11434` with the model from `llm-config.json`. The role passed to `DistributedRunner` is the domain name (e.g., `coder`, `unit-tester`), not a fixed string — this allows different nodes to serve different domains.

`ExoRunner` wraps the Exo OpenAI-compatible API (`POST /v1/chat/completions` on port 52415 by default) and handles model layer distribution internally.

See [Cluster Mode](CLUSTER.md) for configuration reference and setup instructions.

---

[README](../README.md) · **Architecture** · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · [Cluster](CLUSTER.md)
