Run the full plan → code → review pipeline for a coding task.

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
| `full-pipeline` | Continue to Step 1 below. |
| `architect-first` | Spawn `architect` agent → wait for approval → continue to Step 1. |

For `full-pipeline` and `architect-first`: read `.claude/context/triage.md` and keep it in context for all subsequent steps.

### Step 1 — Plan

Spawn the `planner` agent with:
- The user's task description.
- The full content of `.claude/context/triage.md` — so the planner knows which domains, skills, and constraints apply.

The planner writes `.claude/context/task_context.md` with the full plan, relevant file contents, and domain-specific standards from triage.

Wait for it to complete before proceeding.

**Context budget** — per [context-manager](../../../agents/context-manager.md):

Load:
- Files directly related to the task and their immediate dependencies.
- Test files for modified code.
- Type definitions and interfaces referenced by the task.
- Relevant config files (`tsconfig.json`, `pyproject.toml`, `package.json`).

Never load:
- `node_modules/`, `vendor/`, `target/`, `dist/`, `build/`.
- Lock files (`package-lock.json`, `yarn.lock`, `Cargo.lock`, `poetry.lock`).
- Generated code, binary files, images, large data fixtures.

Budget: **40% critical** / **30% important** / **20% reference** / **10% reserve**.

### Step 1.5 — Pre-Review (Plan Approval)

Before coding starts, spawn the `reviewer` agent with **only** `.claude/context/task_context.md` (not code — it doesn't exist yet).

The reviewer checks:
- Is the approach architecturally sound?
- Does the plan respect the domain constraints from triage?
- Are there design-level security or performance issues?

**Verdict:**
- `APPROACH APPROVED` → proceed to Step 2.
- `APPROACH REJECTED` → return to planner with reviewer's objections. Planner rewrites the plan. Re-run Step 1.5 once. If still rejected, report to user and stop.

> Pre-review is cheap: it reads only the plan (~100–300 lines), not code. Catching a wrong approach here saves an entire fix loop.

### Step 2 — Code

Spawn the `coder` agent.
The coder reads `.claude/context/task_context.md` (which includes domain constraints from triage) and implements the changes using the local Ollama model.
It writes a summary to `.claude/context/coder_output.md`.
Wait for it to complete before proceeding.

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

**Tiered review:**

1. **Fast review** — spawn `quick-coder` agent per changed file (all in parallel). Checks: syntax, style, obvious bugs. Uses fastest local model.
2. **Deep review** — spawn `reviewer` agent only for files where fast review flagged issues OR if triage detected `security` / `api` / `complex` domains.

Each reviewer also receives the domain constraints from `.claude/context/triage.md` — so it knows which standards apply (e.g., OWASP rules for security domain, API design rules for api domain).

Overall verdict is **NEEDS CHANGES** if any reviewer returns NEEDS CHANGES.

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

1. Capture diff: `git diff`
2. Spawn `coder` with: reviewer issues + full diff + domain constraints from triage.
3. Re-run Step 2.5.
4. Re-run Step 3 (post-review).
5. Repeat at most **3 times**.

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
