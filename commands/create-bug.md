Create a structured bug report and save it to .claude/context/.

## Instructions

1. Ask the user for the following (one question at a time):
   - "Describe the bug in one sentence:"
   - "Steps to reproduce (numbered list):"
   - "Expected behavior:"
   - "Actual behavior:"

2. Generate a bug report using this template:

   ```markdown
   # Bug: <short title>

   ## Summary
   <one-sentence description>

   ## Steps to Reproduce
   1. <step>
   2. <step>
   3. <step>

   ## Expected Behavior
   <what should happen>

   ## Actual Behavior
   <what actually happens>

   ## Environment
   - OS: <detect with `uname -sr`>
   - Branch: <detect with `git branch --show-current`>
   - Relevant files: <list any files likely involved>

   ## Severity
   - [ ] Critical (data loss / crash)
   - [ ] High (feature broken)
   - [ ] Medium (degraded UX)
   - [ ] Low (cosmetic)

   ## Suggested Fix
   <hypothesis, or "unknown — needs investigation">
   ```

3. Derive a slug from the first 3 words of the title. Save to `.claude/context/bug_<slug>.md`.

4. Print the file path.
