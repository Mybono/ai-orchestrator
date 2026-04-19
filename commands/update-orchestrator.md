Initialize ai-orchestrator for the current project.

## Step 1 — Verify global installation

```bash
ls ~/.claude/agents/ 2>/dev/null && echo "OK" || echo "MISSING"
```

If the output is `MISSING` — stop immediately and tell the user:

> ai-orchestrator is not installed globally. Run the installer first:
>
> ```bash
> curl -sSL https://raw.githubusercontent.com/Mybono/ai-orchestrator/main/scripts/install.sh | bash
> ```

## Step 2 — Create project context directory

```bash
mkdir -p .claude/context
echo "Created .claude/context/"
```

## Step 3 — Build knowledge graph (graphify)

Check if graphify output already exists:

```bash
ls graphify-out/graph.json 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

**If `MISSING`** — build the knowledge graph now. Invoke the graphify skill on the current directory:

Use the Skill tool: `skill: "graphify"`, args: `.`

This will produce `graphify-out/graph.json` which the Triage agent uses on every `/implement` run.

**If `EXISTS`** — inform the user the graph is already built and offer to rebuild:
> Knowledge graph already exists. Run `/graphify . --update` to update it, or `/graphify .` to rebuild from scratch.

## Step 4 — Report

Tell the user:

- `.claude/context/` is ready
- Whether `graphify-out/graph.json` was built or already existed
- That `project_overview.md` will be created automatically on the first `/implement` run (the planner builds it from scratch after exploring the codebase)
- The project is ready — run `/implement "your task"` to start
