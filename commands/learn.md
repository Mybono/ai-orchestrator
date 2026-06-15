Analyze past task outcomes to find recurring reviewer issues and propose targeted edits to agent or skill files.

## Instructions

1. If `knowledge/outcomes.jsonl` does not exist or is empty, print:

   ```text
   No outcome data yet. Run some pipeline tasks first, then re-run /learn.
   ```

   Stop here.

2. Read `knowledge/outcomes.jsonl`. Each line is a JSON object with these fields:
   - `task_type` — domain of the task (e.g. `"coder"`, `"doc-writer"`, `"unit-tester"`)
   - `reviewer_issues` — array of strings, one per reviewer issue recorded after the run

3. Count reviewer issues by `task_type`:

   ```bash
   jq -r '.task_type + "\t" + (.reviewer_issues[]? // empty)' knowledge/outcomes.jsonl \
     | sort | uniq -c | sort -rn
   ```

4. For each `task_type`, find the top 3 most frequent issues. If a `task_type` has fewer than 3 distinct issues, list all of them.

5. For each top issue, identify the most relevant target file:
   - Code style or type safety issues → `skills/<lang>-code-standarts.md`
   - Agent behavior or workflow issues → `agents/<role>.md`
   - Command format issues → `commands/<name>.md`

6. Propose a specific edit for each issue. Format the output as:

   ```markdown
   ## Learning report — <today's date>

   ### <task_type>

   **Issue (N occurrences):** <issue text>
   **Target file:** `<file path>`
   **Proposed edit:** <one or two sentences describing the exact rule or example to add>

   ---
   ```

   Repeat the block for every top issue across all task types.

7. Ask the user: "Apply these edits? (yes / select numbers / no)"
   - `yes` — apply all proposed edits using the Edit tool, one file at a time
   - `select numbers` — apply only the numbered edits the user lists
   - `no` — print the report and stop

8. After applying any edits, run `markdownlint-cli2` on every `.md` file changed and fix any errors.

9. Print the list of files changed.
