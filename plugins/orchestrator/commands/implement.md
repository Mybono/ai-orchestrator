Run the full plan → code → review pipeline for a coding task.

## Context Handoff Protocol

**Rule**: The orchestrator never carries agent output in its own context. Between every step:

1. The completing agent writes a structured summary file to `.claude/context/`.
2. The next step receives only the **file path** in its prompt, not the content.
3. The next agent reads the file itself using its Read tool.

| Step | Agent writes | Next step reads |
|---|---|---|
| Triage | `triage.md` | Planner, Coder, Reviewer |
| Planner | `task_context.md` | Coder |
| Pre-review | `pre_review.md` | Orchestrator (verdict only) |
| Coder | `coder_output.md` | Reviewer, Fix loop |
| Reviewer (per file) | `review_<filename>.md` | Fix loop |
| Fix loop | `fix_loop.md` | Next fix iteration |

**Never** pass full file contents between steps via prompt. Pass paths.

## Pipeline

### Step 0 — Triage

Run [triage](./triage.md) first. It writes `.claude/context/triage.md` with:

- Complexity tier (nano / micro / standard / complex)
- Detected domains (api, security, docker, etc.)
- Route decision
- Skills, agents, and plugin references to load
- Domain-specific constraints for the coder

**Route decision:**

| Route | Action |
|---|---|
| `direct-edit` | Make the edit immediately. Stop here. |
| `quick-coder` | Spawn `quick-coder` only → build check. Stop here. |
| `plugin-route` | **Skip planner.** Use plugin file as plan → Step 2 (coder) → Step 2.5 (build) → Step 3 (review). |
| `full-pipeline` | Continue to Step 1 (planner) below. |
| `architect-first` | **You (Claude) perform architect analysis** → write `architect_review.md` → if `PROCEED` continue to Step 1. |

For `plugin-route`: read `## Plugin Plan` from `.claude/context/triage.md` to get the plugin command file path. Load that file as the task plan. Pass it directly to the `coder` agent along with `## Constraints` from triage. Skip Step 1 and Step 1.5 entirely — the plugin file already defines what to do and how.

For `full-pipeline` and `architect-first`: read `.claude/context/triage.md` and keep it in context for all subsequent steps.

### Step 1 — Plan

Spawn the **`planner` subagent** (Claude — not Ollama). Pass:

- The user's task description.
- The path `.claude/context/triage.md` — so the planner knows which domains, skills, and constraints apply.

The planner is a Claude subagent following `agents/planner.md`. It reads the codebase directly, writes `.claude/context/task_context.md` with the full plan, and updates `project_overview.md`.

Wait for it to complete. Then read only the path `.claude/context/task_context.md` — do not carry full plan content in orchestrator context.

### Step 1.5 — Pre-Review (Standards Compliance Check)

Before coding starts, spawn the agent with the **pre-reviewer** role. Pass two paths — the agent reads them itself:

- `.claude/context/task_context.md`
- `.claude/context/triage.md` (to get the domain standards that apply)

**Role:** The pre-reviewer is NOT an architectural validator — Claude already made the architectural decisions. Its job is a mechanical checklist: does the plan comply with the domain-specific standards loaded by triage?

Read only `## Plan`, `## Exact Signatures`, `## Anti-patterns`, and `## Files to Change` from `task_context.md`. Read `## Domain Standards` and `## Constraints` from `triage.md`.

> [!TIP]
> Pre-reviewer uses `qwen2.5-coder:7b` (role: `pre-reviewer` in `llm-config.json`). This is a checklist task — verify the plan follows the rules, not whether the rules themselves are right.

Check against the domain standards from triage. Examples by domain:

- **docker**: HEALTHCHECK present? no root user? multi-stage build intact? correct interval/timeout syntax?
- **security**: no hardcoded secrets in plan? auth checks mentioned? input validation noted?
- **api**: HTTP verbs correct? versioning in path? error response format defined?
- **ci_cd**: environment variables injected, not hardcoded? rollback step present?
- **testing**: edge cases covered? mocks scoped correctly?

For each standard in the loaded skill file — mark as `✓ compliant` or `✗ violated: <reason>`.

**Output:** Write `.claude/context/pre_review.md`:

```markdown
## Verdict
COMPLIANT | NON-COMPLIANT

## Checklist
- ✓ <standard met>
- ✗ <standard violated: specific reason>

## Required Fixes
- <what Claude's plan must add or change before coder runs, or "none">
```

Orchestrator reads only `## Verdict` line from this file to decide next step. Do not carry full pre-review output in context.

**Verdict:**

- `APPROACH APPROVED` → proceed to Step 2.
- `APPROACH REJECTED` → return to planner with path to `pre_review.md`. Planner reads `## Issues` and rewrites the plan. Re-run Step 1.5 once. If still rejected, report to user and stop.

> Pre-review is cheap: it reads only the plan (~100–300 lines), not code. Catching a wrong approach here saves an entire fix loop.

### Step 2 — Code

Spawn the `coder` agent. Pass only these paths — the agent reads them itself:

- `.claude/context/task_context.md`
- `.claude/context/triage.md` (for domain constraints)

Do not pass file contents. The coder writes `.claude/context/coder_output.md` when done.

After coder completes, read only `## Changed Files` and `## Verdict` from `coder_output.md`. Do not carry the full coder output in context.

### Step 2.5 — Build / Type check

Detect the project type and run the appropriate check:

**TypeScript** (if `tsconfig.json` exists):

```bash
npx tsc --noEmit
```

Fallback: `npm run build` or `npm run typecheck`.

**Python** (if `pyproject.toml` or `setup.py` exists):

```bash
python -m mypy <changed_files> --ignore-missing-imports
```

Fallback: `python -m py_compile <file>` per changed file. Do NOT run pytest here.

**Other projects**: skip this step.

If build/type check **fails** — classify per [error-coordinator](../../../agents/error-coordinator.md):

- **Transient** (flaky env, missing dep): retry once, then fix loop.
- **Permanent** (type error, syntax error): fix loop immediately.

Do NOT proceed to reviewer until build passes.

### Step 3 — Post-Review (parallel if multiple files)

Read `## Changed Files` from `.claude/context/coder_output.md` to get the list of files to review.

**Tiered review:**

1. **Fast review** — spawn `quick-coder` agent per changed file (all in parallel). Pass only:
   - The file path to review
   - Path to `.claude/context/triage.md` (for domain constraints)
   Each fast reviewer writes `.claude/context/review_fast_<filename>.md`.

2. **Deep review** — spawn `reviewer` agent only for files where fast review wrote `## Verdict: NEEDS CHANGES` OR if triage detected `security` / `api` / `complex` domains. Pass only:
   - The file path to review
   - Path to `.claude/context/review_fast_<filename>.md`
   - Path to `.claude/context/triage.md`
   Each deep reviewer writes `.claude/context/review_deep_<filename>.md`.

After all reviewers complete, read only `## Verdict` line from each review file. Do not carry reviewer output in context.

Overall verdict is **NEEDS CHANGES** if any `review_deep_*.md` contains `Verdict: NEEDS CHANGES`.

> Post-review is now cheaper: the approach was pre-approved in Step 1.5, so reviewer focuses only on implementation correctness — not architecture.

### Step 4 — Fix loop (if needed)

Apply [error-coordinator](../../../agents/error-coordinator.md) recovery:

| Error type | Strategy |
|---|---|
| Syntax / type error (permanent) | Fix immediately |
| Build tool failure (transient) | Retry once, then fix loop |
| Reviewer logic issue (degraded) | Fix loop with full diff context |
| Same error 2 rounds in a row | Escalate to user — stop |

**Fix loop steps:**

1. Collect problem files: read `## Verdict` from every `review_deep_*.md`. List only files with `NEEDS CHANGES` — write to `.claude/context/fix_loop.md` under `## Problem Files`.
2. Collect issues: read `## Issues` from those same files → append to `fix_loop.md` under `## Issues`.
3. Capture diff for problem files only: `git diff HEAD -- <problem_file_1> <problem_file_2> ...` → append to `fix_loop.md` under `## Diff`.
4. Spawn `coder` with only paths: `fix_loop.md` + `triage.md`. Coder reads both itself.
5. After coder completes, read `## Changed Files` from `coder_output.md`. If any file appears there that was **not** in `## Problem Files`, add it to the review queue for Step 6.
6. Re-run Step 2.5.
7. Re-run Step 3 (post-review) — **only for files in `## Problem Files` plus any unexpected files from step 5**.
8. Repeat at most **3 times**.

**Circuit breaker**: same error in 2 consecutive rounds → stop immediately, report to user.

### Step 5 — Finalize

1. Collect changed files: `git diff --name-only HEAD`
2. Track savings:

   ```bash
   bash ~/.claude/track_savings.sh --task "<task description>" --files "<changed files>"
   ```

   Best-effort — skip silently if not found.

## When to skip the full pipeline

Triage handles this via `direct-edit` and `quick-coder` routes. Do not second-guess triage output.

## Output to user

- List every file changed.
- Show pre-review verdict (approach) and post-review verdict (implementation).
- List remaining issues after fix loop if any, so user can decide next steps.
