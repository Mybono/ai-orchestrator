[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · **Cluster**

---

# Cluster Mode

Three inference backends — selected automatically based on `exo-config.json`:

| Condition | Backend | Description |
|---|---|---|
| File absent | `AgentRunner` | Local Ollama only (original behavior) |
| `combined: false` | `DistributedRunner` | Each role routed to a specific Ollama node by IP |
| `combined: true` | `ExoRunner` | Single model split across machines via Exo (pipeline parallelism) |

---

## exo-config.json

### Fields

| Field | Type | Description |
|---|---|---|
| `combined` | boolean | `false` = distributed Ollama, `true` = Exo combined |
| `exo.model` | string | Model used in combined mode |
| `exo.gateway.host` | string | Exo API host (default `localhost`) |
| `exo.gateway.port` | number | Exo API port (default `52415`) |
| `nodes[].name` | string | Human-readable label |
| `nodes[].host` | string | IP address or `localhost` |
| `nodes[].port` | number | Ollama port (default `11434`) |
| `nodes[].roles` | object | Map of `role → model`; first matching node wins |

### Example — two Macs on same WiFi

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

---

## Distributed Mode (`combined: false`)

Each role is routed to the first node in `nodes[]` whose `roles` map contains it. Falls back to `localhost:11434` + model from `llm-config.json` if no match.

### Setup

1. On each worker machine, allow remote connections:

   ```bash
   OLLAMA_HOST=0.0.0.0 ollama serve
   ```

2. Find the worker's IP:

   ```bash
   ipconfig getifaddr en0
   ```

3. Edit `exo-config.json` — set `combined: false`, add the worker as a node with its IP and `roles` map
4. Run the orchestrator normally — routing is automatic

### Role distribution (example)

| Role | Node | Model |
|---|---|---|
| `coder`, `reviewer` | m4-main | qwen3:32b-q4_K_M |
| `unit-tester`, `doc-writer` | m5-worker | gemma2:9b / mistral:7b |
| `quick-coder` | m4-main (fallback: m5-worker) | qwen3:8b |
| All others | localhost fallback | from llm-config.json |

---

## Combined Mode (`combined: true`)

Both machines run the `exo` daemon. The model is split by layer across machines, enabling models too large for a single machine.

### When to use

| Setup | RAM for model | Max model |
|---|---|---|
| M4 48GB alone | ~40 GB | ~32B Q8 or ~70B Q4 |
| M5 24GB alone | ~18 GB | ~14B Q8 |
| Both combined | ~58 GB | ~70B Q6, or ~32B Q8 faster |

### Setup

1. Install Exo on both machines:

   ```bash
   pip install exo-explore
   ```

2. Run on each machine — peers auto-discover via mDNS on the same network:

   ```bash
   exo
   ```

3. Set `combined: true` in `exo-config.json` and configure `exo.model` and `exo.gateway`
4. Orchestrator sends requests to `localhost:52415`; Exo handles layer distribution internally

---

## Source Files

| File | Purpose |
|---|---|
| `exo-config.json` | Cluster configuration (project root) |
| `src/core/ExoConfigLoader.ts` | Loads and validates the config; returns `ClusterConfig \| null` |
| `src/core/DistributedRunner.ts` | Routes roles to Ollama nodes by IP |
| `src/core/ExoRunner.ts` | Calls Exo's OpenAI-compatible API (port 52415) |
| `src/types/index.ts` | `ClusterConfig`, `ClusterNode`, `ExoGateway` types |

---

[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · **Cluster**
