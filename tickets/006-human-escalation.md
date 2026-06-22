# 006 — Human escalation

## Problem

When the agent is blocked — missing context, ambiguous requirements, repeated reviewer failures —
it marks the goal `failed` and stops. There is no way for it to surface a specific question
to a human and resume when answered.

## Goal

The agent can pause a goal with a question. A human answers via Slack / Telegram / CLI.
The goal resumes from where it paused, with the answer injected into context.

## Scope

- Add `status: 'waiting'` and `blockedReason?: string` and `humanAnswer?: string` to `Goal`
- Add `escalate_to_human(question: string)` tool to `ToolRunner`
  — sets goal to `waiting`, sends the question via active bot client (Slack/Telegram)
  — `AgentLoop` skips `waiting` goals in the main loop
- Add `GoalQueue.answer(id, answer)` — sets `humanAnswer`, transitions back to `pending`
- Wire answer intake:
  - CLI: `tsx src/index.ts --answer <goal-id> "the answer"`
  - Slack/Telegram: bot routes messages that match `answer <id> ...` to `GoalQueue.answer()`
- When goal resumes, planner prompt includes `## Human Answer\n<answer>` section

## Acceptance criteria

- Planner calls `escalate_to_human("which DB schema should I use: A or B?")`
- Goal transitions to `waiting`; question appears in Slack
- User replies `/answer <id> use schema A` in Slack
- Goal transitions back to `pending` and daemon picks it up with the answer in context
- `--goals` shows `[WAITING]` status with the blocked reason

## Files likely touched

- `src/types/index.ts` — `waiting` status, `blockedReason`, `humanAnswer` on `Goal`
- `src/core/GoalQueue.ts` — `answer(id, text)`, `nextReady` skips `waiting`
- `src/core/ToolRunner.ts` — `escalate_to_human` tool
- `src/core/AgentLoop.ts` — skip `waiting` goals
- `src/integrations/TelegramClient.ts` / `SlackClient.ts` — route answer commands
- `src/index.ts` — `--answer <id> "text"` CLI command
