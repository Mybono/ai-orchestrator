[![CI](https://github.com/Mybono/ai-orchestrator/actions/workflows/ci.yml/badge.svg)](https://github.com/Mybono/ai-orchestrator/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**README** · [Architecture](documentation/ARCHITECTURE.md) · [Agents](documentation/AGENTS.md) · [Skills & Commands](documentation/SKILLS.md) · [Plugins](documentation/PLUGINS.md)

---

TypeScript + Bash orchestration that runs AI agents — Ollama for code generation, Claude for planning and triage — in parallel, in dependency order.

<p align="center">
  <img src="ai_orchestrator_pipeline.svg" alt="ai-orchestrator pipeline" width="680">
</p>

## How it works

`/implement` triggers a multi-step pipeline. Claude handles triage and planning; the TypeScript orchestrator runs Ollama agents in dependency order; Claude applies the generated output.

```text
Step 0   Triage      Claude reads graph.json (BFS depth=2), writes triage_ts.md
Step 1   Plan        Parallel Claude planners write task_context_<domain>.md
Step 1.5 Orchestrate npm start runs Ollama agents in dependency order,
                     writes ollama_output_<domain>.md
Step 2   Code        Parallel Claude coders apply ollama_output_<domain>.md,
                     write coder_output_<domain>.md
Step 2.5 Pre-review  Standards compliance check
Step 3   Build       npx tsc --noEmit
Step 4   Review      Fast review per file; deep review for flagged files
Step 5   Fix loop    Max 3 rounds, circuit breaker on repeat errors
Step 6   Finalize    git diff + track savings
```

`scripts/run_pipeline.sh` wraps steps 1–3 into a single non-interactive script. Pass a task description and it runs triage, parallel planning, and the TS orchestrator in sequence without any Claude interaction required.

Agents communicate through files in `.claude/context/`. Each step reads file paths from the previous step, not the full content.

## Source layout

```text
src/
  types/index.ts          AgentDomain, KNOWN_DOMAINS, Role, AgentTask,
                          AgentResult (done|skipped|failed|blocked), TriageResult
  agents/
    AgentRunner.ts        Wraps call_ollama.sh via spawn; 5 min timeout; 10 MB output limit
    TriageAgent.ts        BFS depth=2 on graph.json; writes triage_ts.md; CLI via import.meta.url
  core/
    DependencyGraph.ts    Kahn topological sort; duplicate domain detection
    Orchestrator.ts       Reads task_context_<domain>.md; circuit breaker for failed deps;
                          reviews ollama_output_<domain>.md after all domains complete
    BuildChecker.ts       Runs npx tsc --noEmit; returns pass/fail with stderr
    DiffCompressor.ts     Strips lock files, collapses blanks, truncates long hunks
    FileWriter.ts         Parses %%FILE…%%ENDFILE blocks from Ollama output; writes to disk
    TriageRouter.ts       Reads triage_ts.md and extracts the chosen TriageRoute
  cli/
    commit.ts             npm run ao-commit — calls local-commit.sh via spawn
    review.ts             npm run ao-review — runs reviewer agent on current diff
    stats.ts              npm run ao-stats  — prints token savings summary
    update.ts             npm run ao-update — pulls latest orchestrator version
  mcp/
    server.ts             MCP HTTP server (default port 3456); exposes get_stats,
                          triage_task, and run_ollama tools to Claude
  index.ts                CLI entry point
```

## Domain dependencies

| Domain | Depends on |
|--------|------------|
| `coder` | (none) |
| `unit-tester` | `coder` |
| `doc-writer` | `coder` |
| `devops` | `coder`, `unit-tester`, `doc-writer` |

Domains within the same dependency level run concurrently. If a domain fails, its dependents are marked `blocked` and skipped.

## Requirements

- Node.js 20+ with `tsx`
- [Claude Code](https://claude.ai/code) CLI
- [Ollama](https://ollama.com) installed and running
- `jq`
- Python 3 with `graphify` package (optional, for knowledge graph updates)

## Installation

```bash
git clone https://github.com/Mybono/ai-orchestrator ~/Projects/ai-orchestrator
cd ~/Projects/ai-orchestrator
./scripts/install.sh
```

Or with curl:

```bash
curl -sSL https://raw.githubusercontent.com/Mybono/ai-orchestrator/main/scripts/install.sh | bash
```

`install.sh` creates symlinks from `~/.claude/` into the repo. A `git pull` in the repo directory updates all tooling immediately.

## Configuration

Model routing is controlled by `llm-config.json` in the repo root:

```json
{
  "models": {
    "coder":        "qwen3:32b-q4_K_M",
    "reviewer":     "qwen3:32b-q4_K_M",
    "debugger":     "qwen3:32b-q4_K_M",
    "pre-reviewer": "qwen3:8b",
    "quick-coder":  "qwen3:8b",
    "devops":       "qwen3:8b",
    "triage":       "qwen3:8b",
    "commit":       "qwen2.5-coder:7b",
    "embedding":    "mxbai-embed-large"
  },
  "fallback": {
    "coder":        "claude-sonnet-4-6",
    "reviewer":     "claude-sonnet-4-6",
    "debugger":     "claude-sonnet-4-6",
    "pre-reviewer": "claude-haiku-4-5-20251001",
    "quick-coder":  "claude-haiku-4-5-20251001",
    "devops":       "claude-haiku-4-5-20251001",
    "commit":       "claude-haiku-4-5-20251001",
    "triage":       "claude-haiku-4-5-20251001",
    "embedding":    ""
  }
}
```

Each role has an Ollama primary model and a Claude fallback used when Ollama is unavailable. Changing a model name takes effect immediately — no restart needed. See [Architecture](documentation/ARCHITECTURE.md#model-configuration) for details.

## Development

```bash
npm run build                                    # compile TypeScript
npm run typecheck                                # tsc --noEmit, no output files
npm start "coder,unit-tester"                    # run TS orchestrator for given domains
npx tsx src/agents/TriageAgent.ts "<task>"       # run triage standalone

npm run ao-commit                                # generate commit message via Ollama and commit
npm run ao-review                                # review current diff with reviewer agent
npm run ao-stats                                 # print token savings (day/week/month)
npm run ao-update                                # pull latest orchestrator version
npm run ao-mcp                                   # start MCP server on port 3456

bash scripts/run_pipeline.sh "<task description>"  # run full pipeline autonomously
```

## License

MIT

---

**README** · [Architecture](documentation/ARCHITECTURE.md) · [Agents](documentation/AGENTS.md) · [Skills & Commands](documentation/SKILLS.md) · [Plugins](documentation/PLUGINS.md)
