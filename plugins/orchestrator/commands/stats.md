Show token savings and pipeline performance summary for the ai-orchestrator.

## Step 1 — Token savings report

```bash
bash ~/.claude/stats.sh "$ARGUMENTS"

Pass a period as the argument: `day`, `week`, `month`, or leave empty for all-time totals.

## Step 2 — Pipeline efficiency analysis

Apply [performance-monitor](../../../agents/performance-monitor.md) to analyse the pipeline data:

**Token usage per agent** (if `.claude/context/` logs exist):

```bash
# Check last pipeline run artifacts
ls -lt .claude/context/ | head -10
wc -l .claude/context/task_context.md .claude/context/coder_output.md 2>/dev/null

Report:

- Which agent consumed the most tokens in the last run.
- Whether the prompt-to-output ratio is healthy (warn if < 0.1 — too much context loaded).
- How many fix-loop iterations the last `/implement` needed (0 = optimal, 3 = investigate).

**Workflow completion rate** (from git log):

```bash
git log --oneline --since="1 week ago" | head -20

Identify if recent commits correlate with pipeline completions or manual fixes outside the pipeline.

**Cost optimization hints** (if patterns detected):

- If `task_context.md` > 500 lines: recommend enabling progressive loading (Step 0 context budget).
- If fix loop ran 3 times: flag the agent that triggered the most retries.
- If multiple reviewers spawned for every run: check if parallelism is actually needed or if single-file tasks dominate.

## Output format

```text
=== Token Savings ===
<output of stats.sh>

=== Pipeline Health ===
Last run: <date>
Fix loop iterations: <n>
Context size: <lines> lines in task_context.md
Recommendation: <one line if any issue detected, else "Pipeline healthy">
