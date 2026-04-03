Run the full plan → code → review pipeline for a coding task.

## Pipeline

### Step 1 — Plan
Spawn the `planner` agent with the user's task description.
The planner will write `.claude/context/task_context.md` with the full plan and all relevant file contents.
Wait for it to complete before proceeding.

### Step 2 — Code
Spawn the `coder` agent.
The coder reads `.claude/context/task_context.md` and implements the changes using the local Ollama model.
It writes a summary to `.claude/context/coder_output.md`.
Wait for it to complete before proceeding.

### Step 2.5 — Build / Type check
After coder completes, detect the project type and run the appropriate check:

**TypeScript** (if `tsconfig.json` exists in the project root):
```bash
npx tsc --noEmit
```
If that fails, also try `npm run build` or `npm run typecheck` if defined in `package.json`.

**Python** (if `pyproject.toml` or `setup.py` exists):
```bash
python -m mypy <changed_files> --ignore-missing-imports
```
If mypy is not installed, fall back to `python -m py_compile <file>` for each changed file. Do NOT run pytest here — tests are run manually via the `test-agent`.

**Other projects**: skip this step.

If the build/type check **fails**:
- Treat it as NEEDS CHANGES (same as reviewer verdict)
- Pass the full error output to the coder in the fix loop (Step 4)
- Do NOT proceed to reviewer until the build passes

### Step 3 — Review (parallel if multiple files)
If only one file was changed: spawn one `reviewer` agent.

If multiple files were changed: spawn one `reviewer` agent **per file** in parallel (all at once in a single message). Each reviewer checks one file independently using `qwen2.5-coder:7b`. Collect all verdicts before proceeding.

Overall verdict is **NEEDS CHANGES** if any single file reviewer returns NEEDS CHANGES.

### Step 4 — Fix loop (if needed)
If the reviewer returns **NEEDS CHANGES** or the build step fails:

1. Capture a diff of what the coder changed in this round:
   ```bash
   git diff
   ```
2. Spawn the `coder` agent again, passing:
   - The reviewer's issues (or build error output)
   - The full `git diff` from step 1 — so coder sees what was already attempted and doesn't repeat the same mistake
3. Re-run Step 2.5 (build check)
4. Then spawn the `reviewer` agent again
5. Repeat at most **3 times** — if still failing after 3 rounds, stop and report the remaining issues to the user

## When to skip the full pipeline

If the user's request is clearly a one-liner (rename, import fix, single value change) — skip planning and review, just make the edit directly.

## Output to user

When the pipeline completes:
- List every file that was changed
- Show the reviewer's final verdict
- If issues remain after 2 fix rounds, list them clearly so the user can decide next steps
