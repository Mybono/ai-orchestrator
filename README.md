# ai-orchestrator

[![CI](https://github.com/Mybono/ai-orchestrator/actions/workflows/ci.yml/badge.svg)](https://github.com/Mybono/ai-orchestrator/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**README** · [Architecture](documentation/ARCHITECTURE.md) · [Agents](documentation/AGENTS.md) · [Skills & Commands](documentation/SKILLS.md)

---

Portable AI developer setup: Claude thinks, local Ollama executes.

Works with any project — TypeScript, Python, Flutter, Swift, C++.
No Python dependency — all orchestration is pure Bash and `jq`.

![ai-orchestrator pipeline](documentation/pipeline.svg)

## How it works

`/implement` triggers the full pipeline:

```
planner → coder → build check → reviewer(s) → verdict
```

Claude writes the plan. A local Ollama model writes the code. Claude reviews the output.
Details: [Architecture](documentation/ARCHITECTURE.md) · [Agents](documentation/AGENTS.md)

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- [Ollama](https://ollama.com) installed and running
- `jq` — installed automatically by `install.sh`

## Installation

```bash
curl -sSL https://raw.githubusercontent.com/Mybono/ai-orchestrator/main/scripts/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/Mybono/ai-orchestrator ~/Projects/ai-orchestrator
cd ~/Projects/ai-orchestrator
./scripts/install.sh
```

The installer checks dependencies, creates symlinks in `~/.claude/`, and selects models based on your hardware.

## Configuration

Model routing is controlled by [`llm-config.json`](llm-config.json) in the repo root:

```json
{
  "models": {
    "coder":     "qwen3-coder:30b-a3b-q4_K_M",
    "reviewer":  "qwen2.5-coder:7b",
    "commit":    "qwen2.5-coder:7b",
    "embedding": "nomic-embed-text"
  }
}
```

Change a model name — takes effect immediately, no restart needed.
See [Architecture → Model Configuration](documentation/ARCHITECTURE.md#model-configuration) for details.

## Commands

| Command | What it does |
|---------|-------------|
| [`/implement`](commands/implement.md) | Full plan → code → build → review pipeline |
| [`/review`](commands/review.md) | Check current changes against language standards |
| [`/stats`](commands/stats.md) | Show token savings (`day`, `week`, `month`, or all-time) |
| [`/debug`](commands/debug.md) | Trace root cause of an error |

All commands and agents: [Skills & Commands](documentation/SKILLS.md) · [Agents](documentation/AGENTS.md)

## Token savings

Every Ollama call is tracked. View estimated savings vs Claude Sonnet pricing:

```bash
/stats week
```

```
───────────────────────────────
 ai-orchestrator savings
 Period: this week
 Runs: 12
 Tokens saved: ~186k
 Estimated saving: $7.20
───────────────────────────────
```

## Project onboarding

To apply orchestration rules in any project:

```bash
cp ~/.claude/ai_rules.md ~/Projects/your-project/ai_rules.md
```

Compatible with `.cursorrules` and `.clauderules`.

## Updating

```bash
cd ~/Projects/ai-orchestrator && git pull
```

Changes apply immediately via symlinks — no reinstall needed.

---

**README** · [Architecture](documentation/ARCHITECTURE.md) · [Agents](documentation/AGENTS.md) · [Skills & Commands](documentation/SKILLS.md) 
