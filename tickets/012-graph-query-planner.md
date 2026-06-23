# 012 — Wire codebase-memory-mcp graph queries into planner

## Problem

The planner explores the codebase by calling `list_dir` → `read_file` repeatedly until it
accumulates enough context. On a mid-size TypeScript project this costs 5–20 file reads per
planning cycle. `codebase-memory-mcp` is already running in the Claude Code session and can
answer the same structural questions (`"where is execute() defined?"`, `"what calls ToolRunner?"`)
in a single sub-millisecond graph query — but neither `planner.md` nor `ToolRunner.ts` knows
about it.

## Goal

The planner should issue a `search_graph` / `get_code_snippet` call as its **first move** when
exploring code, and fall back to file-by-file scan only when the graph returns nothing.
This applies to both execution paths:

- **Claude agent path** — `planner.md` (used by `/implement` via Claude Code).
- **Local LLM path** — `ToolRunner.ts` (used when Ollama drives the planner).

## Scope

### 1. `agents/planner.md` — Claude agent path (prompt change only)

Add a **Phase 0.5 — Graph-first exploration** block immediately before Phase 1 Step 3
("Explore the codebase"):

```text
#### Phase 0.5 — Graph-first exploration (run before Glob/Grep)

If `codebase-memory-mcp` is available in the current session, call it FIRST:

1. `search_graph(query: "<task keywords>", project: "<repo name>")` — find relevant
   functions, classes, and routes by name. Collect their `qualified_name` values.
2. `get_code_snippet(qualified_name, project)` — read exact source for each hit.
   This returns a precise line range, not the full file.
3. `trace_path(function_name, project, direction: "both")` — if the task involves
   changing a function, trace its callers and callees to understand blast radius.

Only fall back to Glob / Grep / read_file if:
- The graph returns 0 results for all queries, OR
- The project is not yet indexed (index_status returns "not indexed").

Do not re-read files you already have snippets for from the graph.

### 2. `src/core/ToolRunner.ts` — Local LLM path (code change)

**Add to `PLANNER_TOOLS`:**

```typescript
{
  type: 'function',
  function: {
    name: 'graph_query',
    description:
      'Search the codebase knowledge graph for functions, classes, and symbols. ' +
      'Returns signatures and file locations. Much faster than reading files — use this first.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Natural-language search query (e.g. "goal queue push pending")',
        },
        project: {
          type: 'string',
          description: 'Project slug as registered in codebase-memory-mcp (usually the repo folder name)',
        },
      },
      required: ['query', 'project'],
    },
  },
},

**Add case to `execute()` switch:**

```typescript
case 'graph_query':
  return this.graphQuery(String(args['query'] ?? ''), String(args['project'] ?? ''));

**Add private method `graphQuery()`:**

```typescript
private graphQuery(query: string, project: string): string {
  if (!query.trim() || !project.trim()) {
    return '[error] graph_query requires query and project';
  }
  // Send a single search_graph JSON-RPC call to codebase-memory-mcp via stdio.
  // The MCP server binary is resolved from the npx cache or global installs.
  const payload = JSON.stringify({
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: {
      name: 'search_graph',
      arguments: { query, project, limit: 20 },
    },
  });

  const result = spawnSync(
    'npx',
    ['--yes', '@deus-data/codebase-memory-mcp'],
    {
      input: payload + '\n',
      encoding: 'utf8',
      timeout: 5_000,
      cwd: this.projectRoot,
    },
  );

  if (result.error || result.status !== 0) {
    // Graceful degradation — planner will fall back to file scan.
    return '[graph_query unavailable — codebase-memory-mcp not found or timed out]';
  }

  try {
    const parsed = JSON.parse(result.stdout) as { result?: { content?: Array<{ text?: string }> } };
    return parsed.result?.content?.[0]?.text ?? '[no results]';
  } catch {
    return '[graph_query] could not parse MCP response';
  }
}

> **Note:** `spawnSync` with `input` writes the JSON-RPC request to stdin and reads the
> response from stdout. codebase-memory-mcp speaks the MCP stdio transport natively.
> If the binary is absent, `result.error` is set and we return the fallback message —
> existing `read_file` / `search_files` behavior is preserved.

### 3. Verify `run_command` whitelist is not affected

`graph_query` uses its own `spawnSync` call — it does not go through `run_command`.
No whitelist change needed.

## Acceptance criteria

- `graph_query("ToolRunner execute", "ai-orchestrator")` called from the local LLM planner
  returns function signatures without reading any file.
- If `codebase-memory-mcp` is not installed, the tool returns the fallback string and the
  planner continues with `search_files` — no crash, no hanging.
- `planner.md` agent running via `/implement` issues at least one `search_graph` call before
  any `Glob` or `Grep` call on a TypeScript task.
- Token count for a planning cycle on this repo drops measurably (target: ≥30% fewer
  `read_file` calls compared to baseline run without the change).

## Files likely touched

- `agents/planner.md` — Phase 0.5 block (prompt-only change)
- `src/core/ToolRunner.ts` — `PLANNER_TOOLS` entry + `execute()` case + `graphQuery()` method
- `src/types/index.ts` — no change expected (graph_query uses only primitives)


---
