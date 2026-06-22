# 002 — Goal decomposition (hierarchical task breakdown)

## Problem

`GoalQueue` is a flat FIFO list. A high-level goal like "add OAuth to the API" cannot be broken
into sub-goals with dependencies. The agent cannot plan multi-step work autonomously.

## Goal

The planner must be able to decompose a goal into ordered sub-goals and enqueue them.
Sub-goals are executed in dependency order; the parent goal completes when all children are done.

## Scope

- Add `parentId?: string` and `dependsOn?: string[]` to the `Goal` type
- Add `GoalQueue.pushMany(goals)` — atomic batch enqueue
- Add `GoalQueue.nextReady()` — returns a pending goal whose `dependsOn` are all `done`
  (replaces the current `nextPending()` in `AgentLoop`)
- Add `decompose` tool to `PlannerSession` / `ToolRunner`:
  `decompose_goal(subgoals: Array<{ description, domains?, dependsOn? }>)`
  — the planner calls this instead of `write_task_context` for complex tasks
- `AgentLoop` detects decomposed goals: parent stays `running` until all children are `done`

## Acceptance criteria

- Enqueue "add OAuth to the API" — planner decomposes into 4 sub-goals with correct dependency order
- Sub-goals execute in the right sequence; blocked sub-goals wait
- Parent goal transitions to `done` automatically when all children are `done`
- `--goals` output shows parent/child relationships

## Files likely touched

- `src/types/index.ts` — `parentId`, `dependsOn` on `Goal`
- `src/core/GoalQueue.ts` — `pushMany`, `nextReady`, `markChildDone`
- `src/core/ToolRunner.ts` — `decompose_goal` tool
- `src/core/AgentLoop.ts` — replace `nextPending` with `nextReady`, parent completion logic
