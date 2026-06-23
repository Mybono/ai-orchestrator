# 003 — Persistent memory and self-learning

## Problem

Every goal starts from zero. The agent does not remember:

- Which patterns caused reviewer failures in the past
- Project-specific constraints discovered during previous tasks
- Which LLM candidates were slow or unreliable

Each `project_overview.md` update is manual (planner writes it) and only captures structure,
not learned behavior rules.

## Goal

After each completed or failed goal, the agent updates a persistent memory store with:

- What worked / what the reviewer rejected and why
- New constraints discovered (e.g. "never mock the DB in this project")
- LLM candidate performance metrics

On the next goal, the planner reads this memory before planning.

## Scope

- Create `src/core/AgentMemory.ts` — reads/writes `.claude/agent-memory.json`
- Structure: `{ rules: string[], constraints: string[], candidateStats: Record<string, LatencyStats> }`
- `AgentMemory.record(goalId, outcome)` — called by `AgentLoop` after each goal
- `AgentMemory.summarize()` — returns a short text block injected into the planner prompt
- Reviewer failures are parsed from `review_output_*.md` and extracted as rules
- Add `memory_write(rule: string)` tool to `ToolRunner` so the planner can persist a discovery mid-session

## Acceptance criteria

- After a reviewer rejects a goal for using `any`, the memory stores: "never use `any` — always `unknown`"
- The next goal's planner prompt includes this rule under `## Learned Rules`
- `--goals` output includes a `[memory: N rules]` line

## Files likely touched

- `src/core/AgentMemory.ts` — new file
- `src/core/AgentLoop.ts` — call `AgentMemory.record()` after each goal
- `src/core/ToolRunner.ts` — add `memory_write` tool
- `src/core/PlannerSession.ts` — inject `AgentMemory.summarize()` into user message
