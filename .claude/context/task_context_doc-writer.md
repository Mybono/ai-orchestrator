# Task: Create documentation/CLUSTER.md

Create a new file `documentation/CLUSTER.md` that fully documents the Cluster Mode feature.

## Navigation header and footer (use exactly this)

```
[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · **Cluster**
```

Place this line at the very top, then `---`, then content, then `---`, then the same line at the very bottom.

## Content to include

### 1. Title: `# Cluster Mode`

### 2. Overview table

Three backends selected automatically from `exo-config.json`:

| Condition | Backend | Description |
|---|---|---|
| File absent | `AgentRunner` | Local Ollama only (original behavior) |
| `combined: false` | `DistributedRunner` | Each role routed to a specific Ollama node by IP |
| `combined: true` | `ExoRunner` | Single model split across machines via Exo (pipeline parallelism) |

### 3. Section: `## exo-config.json`

Show full example config for both modes and explain every field:
- `combined` — boolean, selects backend
- `exo.model` — model for combined mode
- `exo.gateway.host` / `exo.gateway.port` — Exo API endpoint (default 52415)
- `nodes[].name` — label
- `nodes[].host` — IP or `localhost`
- `nodes[].port` — Ollama port (default 11434)
- `nodes[].roles` — map of role → model; first matching node wins

Example for `combined: false` (two Macs on same WiFi):
```json
{
  "combined": false,
  "exo": {
    "model": "qwen3:32b-q4_K_M",
    "gateway": { "host": "localhost", "port": 52415 }
  },
  "nodes": [
    {
      "name": "m4-main",
      "host": "localhost",
      "port": 11434,
      "roles": {
        "coder":       "qwen3:32b-q4_K_M",
        "reviewer":    "qwen3:32b-q4_K_M",
        "quick-coder": "qwen3:8b",
        "commit":      "qwen2.5-coder:7b",
        "triage":      "qwen3:8b"
      }
    },
    {
      "name": "m5-worker",
      "host": "10.127.229.214",
      "port": 11434,
      "roles": {
        "coder":       "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
        "unit-tester": "gemma2:9b",
        "doc-writer":  "mistral:7b",
        "quick-coder": "qwen2.5-coder:7b"
      }
    }
  ]
}
```

### 4. Section: `## Distributed Mode (combined: false)`

Setup steps:
1. On each worker: `OLLAMA_HOST=0.0.0.0 ollama serve`
2. Find worker IP: `ipconfig getifaddr en0`
3. Edit `exo-config.json` with the worker's IP and role→model mapping
4. Run orchestrator normally — routing is automatic

Routing rule: iterates `nodes[]` in order, first node with the role wins. Falls back to `localhost:11434` + model from `llm-config.json`.

Role distribution table (example):
| Role | Node | Model |
|---|---|---|
| `coder`, `reviewer` | m4-main | qwen3:32b-q4_K_M |
| `unit-tester`, `doc-writer` | m5-worker | gemma2:9b / mistral:7b |
| `quick-coder` | m4-main (fallback: m5-worker) | qwen3:8b |

### 5. Section: `## Combined Mode (combined: true)`

When to use: models too large for one machine (e.g. 70B at Q8 quality). Exo splits model layers across machines.

Setup:
1. `pip install exo-explore` on both machines
2. `exo` on each machine — auto-discovers peers via mDNS on same network
3. Set `combined: true`, configure `exo.model` and `exo.gateway`
4. Orchestrator hits `localhost:52415`; Exo handles layer distribution internally

RAM planning:
| Config | Available for model |
|---|---|
| M4 48GB alone | ~40 GB |
| M5 24GB alone | ~18 GB |
| Both combined | ~58 GB |

### 6. Section: `## Source Files`

| File | Purpose |
|---|---|
| `exo-config.json` | Cluster config (project root) |
| `src/core/ExoConfigLoader.ts` | Loads and validates config; returns `ClusterConfig \| null` |
| `src/core/DistributedRunner.ts` | Routes roles to Ollama nodes by IP |
| `src/core/ExoRunner.ts` | Calls Exo OpenAI-compatible API (port 52415) |
| `src/types/index.ts` | `ClusterConfig`, `ClusterNode`, `ExoGateway` types |

## Output format

Output exactly one %%FILE block. No text outside it.

%%FILE documentation/CLUSTER.md
<complete file content>
%%ENDFILE
