# 007 — Outcome evaluator

## Problem

A goal is marked `done` as soon as the reviewer returns `APPROVED`. But the reviewer reads code
statically — it cannot know if the feature actually works, if tests pass, or if existing behavior
regressed. Goals can be formally closed with broken code.

## Goal

After the reviewer approves, a dedicated `evaluator` step runs the test suite and checks real
behavior. Only a green evaluator marks the goal `done`. A red evaluator triggers another fix round
or escalation.

## Scope

- Create `src/core/Evaluator.ts`
  - `evaluate(changedFiles, projectRoot)` — runs the test command for the project type
    (auto-detected: `npm test`, `npx vitest`, `pytest`, `go test ./...`, `cargo test`)
  - Returns `{ passed: boolean; output: string; failureCount: number }`
- `AgentLoop.processGoal()` — call `Evaluator.evaluate()` after reviewer approves
- On failure: append test output to task_context as `## Evaluator Failures`, run one more coder round
- On second failure: escalate to human (if ticket 006 is implemented) or mark `failed` with full output
- Store evaluator output in the goal's `result` field alongside reviewer summary

## Acceptance criteria

- Coder introduces a bug that breaks an existing test
- Reviewer approves (static analysis passes)
- Evaluator catches the failure, triggers a fix round
- After fix, tests pass and goal is marked `done`
- `--goals` output includes `[tests: 42 passed]` in the result line

## Files likely touched

- `src/core/Evaluator.ts` — new file
- `src/core/AgentLoop.ts` — call evaluator after reviewer, feed failures back
- `src/types/index.ts` — `evaluatorResult` on `Goal`
