# ai-orchestrator

Portable AI Developer setup: agents, slash commands, IDE orchestration, and language standards.  
Works with any project — TypeScript, Python, Flutter, Swift, C++.

**Now 100% Python-free.** All orchestration is handled via pure Bash and `jq`.

## What's included

```
ai-orchestrator/
├── documentation/
│   ├── CLAUDE.md            # Global instructions for Claude CLI
│   └── IDE_AGENT_RULES.md   # Orchestration rules for embedded IDE Agents
├── agents/            # Subagents (run automatically via /implement)
│   ├── planner.md     # Explores codebase, writes implementation plan
│   ├── coder.md       # Generates code via local Ollama (role: coder)
│   ├── reviewer.md    # Reviews code against standards (role: reviewer)
│   ├── quick-coder.md # Fast fixes (role: commit)
│   ├── commit.md      # Stages and commits changes (role: commit)
│   ├── doc-writer.md  # Creates/updates documentation (role: reviewer)
│   └── test-agent.md  # Writes and runs tests (role: coder)
├── commands/          # Slash commands
│   ├── implement.md   # /implement — full plan → code → review pipeline
├── skills/            # Language coding standards
│   ├── ...-code-standarts.md
├── scripts/
│   ├── call_ollama.sh     # Central LLM interface (Bash + jq + curl)
│   ├── local-commit.sh    # Fast local LLM-driven git commits
│   ├── open-pr.sh         # Local LLM-driven Pull Request descriptions
│   ├── analyze_hardware.sh # Auto-configures models based on your RAM/GPU
│   └── install.sh         # Installer — configures dependencies and symlinks
└── llm-config.json    # Centralized model roles (symlinked to ~/.claude/)
```

## How it works

The core workflow is a pipeline triggered by `/implement`:
```
planner → coder → build check → reviewer(s) → verdict
```

- **Zero Python dependency**: All agents now call `call_ollama.sh` directly, which uses `curl` and `jq` for API interaction.
- **Role-based Config**: One source of truth for all models in `llm-config.json`.
- **Portable**: symlinks ensure that updates to this repo apply globally to your system immediately.

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed
- [Ollama](https://ollama.com) installed and running
- **`jq`** (JSON processor) — `install.sh` will attempt to install it via brew/apt.

## Installation

```bash
git clone https://github.com/Mybono/ai-orchestrator ~/Projects/ai-orchestrator
cd ~/Projects/ai-orchestrator
chmod +x scripts/install.sh
./scripts/install.sh
```

### Setup & Hardware Analysis

After installation, run the hardware analysis script to automatically pick the best models for your RAM/GPU:

```bash
bash scripts/analyze_hardware.sh
```

This will populate your `llm-config.json` with recommended models and offer to pull them via `ollama pull`.

## Configuration (`llm-config.json`)

The system uses roles to determine which model to use for which task. The config is stored in the project root and symlinked to `~/.claude/llm-config.json`.

| Role | Default Model | Purpose |
|------|---------------|---------|
| `coder` | `qwen2.5-coder:14b...` | Heavy code generation (main agent) |
| `reviewer` | `qwen2.5-coder:7b` | Code review and documentation |
| `commit` | `qwen2.5-coder:1.5b` | Commit messages and tiny fixes |
| `embedding` | `nomic-embed-text` | Semantic search and RAG |

Example of `llm-config.json`:
```json
{
  "models": {
    "coder": "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "reviewer": "qwen2.5-coder:7b",
    "commit": "qwen2.5-coder:1.5b",
    "embedding": "nomic-embed-text"
  }
}
```

## IDE Agent Delegation Workflow (Antigravity & Cursor)

IDE agents (like Antigravity) act as the Architect but delegate heavy lifting to local models via `call_ollama.sh`:
- **Coding**: Uses the `coder` role from `llm-config.json`.
- **Review**: Uses the `reviewer` role.

The delegation command:
```bash
# Uses the model defined for the 'coder' role in your config
bash ~/.claude/call_ollama.sh --role coder --prompt "implement X" --context-file /tmp/context.md
```

## Updating

```bash
cd ~/Projects/ai-orchestrator
git pull
```
clean textual response, reviewing it against the standards in `/skills/`, and securely applying the code directly into the active IDE session.

## Updating

```bash
cd ~/Projects/ai-orchestrator
git pull
```

Changes apply immediately — no reinstall needed.
