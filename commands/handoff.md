Transfer context from this session so the next Claude Code session can resume without losing state.

## Instructions

1. Read all context files that exist in `.claude/context/`:

   ```bash
   ls .claude/context/ 2>/dev/null
   ```

   Read: `task_context.md`, `coder_output.md`, `triage.md`, `architect_decision.md`, `conflict_log.md` (whichever exist).

2. Get current git state:

   ```bash
   git status --short
   git log --oneline -5
   ```

3. Read `.claude/todo.md` if it exists.

4. Write a handoff summary to `.claude/context/handoff.md` using this structure:

   ```markdown
   # Handoff — <date>

   ## Current State
   <one paragraph: what was being built, where things stand>

   ## In Progress
   - <ticket or task currently open>

   ## Pending Tasks
   - <next steps in order>

   ## Key Files Changed
   - `<path>`: <what changed>

   ## Blockers
   <any unresolved issues, or "none">

   ## Next Step
   <single most important action for the next session>
   ```

5. Print: `Handoff saved to .claude/context/handoff.md — paste its contents at the start of your next session.`
