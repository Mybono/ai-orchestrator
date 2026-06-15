# Knowledge Index

_Update this file when you add a new repo or discover a cross-project dependency._
_Planner reads this file at the start of every task if it exists._

---

## Projects

| Repo | Path | Purpose | Branch |
|---|---|---|---|
| ai-orchestrator | ~/Projects/ai-orchestrator | Claude Code multi-agent orchestration framework | main |

_Add rows for every repo this codebase interacts with._

---

## Cross-Repo Dependencies

_List any shared libraries, shared config, or runtime dependencies between repos._

| From | To | Type | Notes |
|---|---|---|---|
| — | — | — | _none yet_ |

---

## Architectural Decisions

_Record decisions that span multiple repos or that are non-obvious from the code._

| Date | Decision | Reason | Affected Repos |
|---|---|---|---|
| 2026-05-31 | Ollama-first, Claude fallback | Minimize API spend; local models handle codegen | ai-orchestrator |
| 2026-05-31 | File-path handoff between agents | Prevent context explosion in multi-step pipelines | ai-orchestrator |

---

## Known Constraints

- Never mock Ollama in tests — all agent tests require a live local model
- README.md is managed by doc-writer agent only (enforced by PreToolUse hook)
- llm-config.json models can be changed at runtime — no restart needed

---

## Learning Data

`knowledge/outcomes.jsonl` is an append-only JSON Lines file. Each line records the outcome of one completed pipeline run.

### Record format

Each line contains a JSON object with these fields:

    {
      "date": "2026-06-15T14:32:00",
      "task_type": "coder",
      "task": "add retry logic to run_pipeline.sh",
      "reviewer_issues": [
        "missing error handling for empty response",
        "variable not quoted in bash"
      ],
      "verdict": "APPROVED"
    }

| Field | Type | Description |
|---|---|---|
| `date` | ISO 8601 string | When the run completed |
| `task_type` | string | Domain: `coder`, `doc-writer`, `unit-tester`, `devops`, etc. |
| `task` | string | One-sentence description of the task |
| `reviewer_issues` | string array | Every issue the reviewer raised, verbatim. Empty array if none. |
| `verdict` | string | Final pipeline verdict: `APPROVED` or `NEEDS CHANGES` |

### Adding a record

Use `scripts/capture-outcome.sh` after each pipeline run:

    bash scripts/capture-outcome.sh \
      --task-type "coder" \
      --task "add retry logic to run_pipeline.sh" \
      --issues "missing error handling" "variable not quoted" \
      --verdict "APPROVED"

The script appends one JSON line to `knowledge/outcomes.jsonl`. Do not edit the file by hand — the append-only format keeps history intact for learning queries.

### How `/learn` uses this file

The `/learn` command reads `outcomes.jsonl`, counts `reviewer_issues` by `task_type`, finds the top 3 recurring issues per domain, and proposes targeted edits to the relevant `agents/*.md` or `skills/*.md` files. Run `/learn` after 10 or more pipeline runs to give the system enough data to spot real patterns.

---

## How to Update

Run the update script to refresh the index:

    bash scripts/update-knowledge.sh

Or edit this file manually. The planner reads it once per session — stale info causes wrong assumptions.
