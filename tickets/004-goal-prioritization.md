# 004 — Goal prioritization and scheduling

## Problem

Goals are processed strictly FIFO. There is no concept of urgency, deadlines, or blocking relationships
between independent goals. A low-priority background task can block a critical bugfix for hours.

## Goal

Goals have a priority score and optional deadline. `AgentLoop` always picks the highest-priority
ready goal. The user can change priority at any time without re-enqueuing.

## Scope

- Add `priority: number` (default `50`, range `0–100`) and `deadline?: string` (ISO 8601) to `Goal`
- `GoalQueue.nextReady()` — returns the highest-priority pending goal whose dependencies are met
  (ties broken by `createdAt`, earlier wins)
- CLI: `--goal "..." --priority 90` and `--reprioritize <id> <score>`
- `--goals` output sorts by priority descending and shows deadline if set
- Deadline enforcement: if `deadline` is past when the goal is claimed, log a warning in the result

## Acceptance criteria

- Enqueue two goals with priorities 30 and 80 — the daemon picks priority 80 first
- `--reprioritize <id> 95` moves a goal to the front of the queue without re-enqueuing
- `--goals` output is sorted by priority

## Files likely touched

- `src/types/index.ts` — `priority`, `deadline` on `Goal`
- `src/core/GoalQueue.ts` — `nextReady` priority sort, `reprioritize(id, score)`
- `src/index.ts` — `--priority` flag on `--goal`, new `--reprioritize` command
