# ai-orchestrator

Portable AI Developer setup: agents, slash commands, IDE orchestration, and language standarts.  
Works with any project — TypeScript, Python, Flutter, Swift, C++.

All orchestration is handled via pure Bash and `jq`.

![ai-orchestrator pipeline](documentation/pipeline.svg)

## What's included

```markdown
ai-orchestrator/
├── documentation/
│   ├── CLAUDE.md            # Global instructions for Claude CLI
│   └── ai_rules.md          # Orchestration rules for embedded IDE Agents
├── agents/            # Subagents (run automatically via /implement)
│   ├── planner.md     # Explores codebase, writes implementation plan
│   ├── coder.md       # Generates code via local Ollama (role: coder)
│   ├── reviewer.md    # Reviews code against standarts (role: reviewer)
│   ├── quick-coder.md # Fast fixes (role: commit)
│   ├── commit.md      # Stages and commits changes (role: commit)
│   ├── doc-writer.md  # Creates/updates documentation (role: reviewer)
│   └── test-agent.md  # Writes and runs tests (role: coder)
├── commands/          # Slash commands
│   ├── implement.md   # /implement — full plan → code → review pipeline
├── skills/            # Language coding standarts
│   ├── ...-code-standarts.md
├── scripts/
│   ├── call_ollama.sh     # Central LLM interface (Bash + jq + curl)
│   ├── local-commit.sh    # Fast local LLM-driven git commits
│   ├── open-pr.sh         # Local LLM-driven Pull Request descriptions
│   ├── analyze_hardware.sh # Auto-configures models based on your RAM/GPU
│   ├── analyze_project.sh  # Multi-agent tiered project structure analysis
│   └── install.sh         # Installer — configures dependencies and symlinks
└── llm-config.json    # Centralized model roles (symlinked to ~/.claude/)
```markdown

## How it works

The core workflow is a pipeline triggered by `/implement`:

```markdown
planner → coder → build check → reviewer(s) → verdict
```markdown

- **Zero Python dependency**: All agents now call `call_ollama.sh` directly, which uses `curl` and `jq` for API interaction.
- **Role-based Config**: One source of truth for all models in `llm-config.json`.
- **Portable**: symlinks ensure that updates to this repo apply globally to your system immediately.

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed
- [Ollama](https://ollama.com) installed and running
- **`jq`** (JSON processor) — `install.sh` will attempt to install it via brew/apt.

## Installation & Setup

All you need is one command to check dependencies, configure the system, and optimize models for your hardware:

```bash
git clone https://github.com/Mybono/ai-orchestrator ~/Projects/ai-orchestrator
cd ~/Projects/ai-orchestrator
chmod +x scripts/install.sh
./scripts/install.sh
```markdown

### What happens during installation

1. **Software Check**: Scripts detect and help install `jq` and `Ollama`.
2. **Environment Setup**: Symlinks created in `~/.claude/`, shell aliases added.
3. **Hardware Analysis**: System RAM/GPU analyzed to pick the best models.
4. **Configuration**: `llm-config.json` generated and optimized for your machine.

## Configuration (`llm-config.json`)

The system uses roles to determine which model to use for which task. The config is stored in the project root and symlinked to `~/.claude/llm-config.json`.

| Role | Default Model | Purpose |
|------|---------------|---------|
| `coder` | `qwen2.5-coder:14b...` | Heavy code generation (main agent) |
| `reviewer` | `qwen2.5-coder:7b` | Code review and documentation |
| `commit` | `qwen2.5-coder:7b` | Commit messages and tiny fixes |
| `embedding` | `nomic-embed-text` | Semantic search and RAG |

Example of `llm-config.json`:

```json
{
  "models": {
    "coder": "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "reviewer": "qwen2.5-coder:7b",
    "commit": "qwen2.5-coder:7b",
    "embedding": "nomic-embed-text"
  }
}
```markdown

## IDE Agent Delegation Workflow (Antigravity & Cursor)

IDE agents (like Antigravity) act as the Architect but delegate heavy lifting to local models via `call_ollama.sh`:

- **Coding**: Uses the `coder` role from `llm-config.json`.
- **Review**: Uses the `reviewer` role.

The delegation command:

```bash
# Uses the model defined for the 'coder' role in your config
bash ~/.claude/call_ollama.sh --role coder --prompt "implement X" --context-file /tmp/context.md
```markdown

## Project Onboarding

To use these orchestration rules in your project (so IDE agents like Antigravity/Cursor can see them):

1. **Copy the rules** from the system directory to your project root:

   ```bash
   cp ~/.claude/ai_rules.md ~/Projects/your-project/ai_rules.md
   ```

2. **(Optional) Multi-agent support**: You can also name it `.cursorrules` or `.clauderules` if you use those specific tools.

3. **Check delegation**: Once added, your IDE agent should start using `call_ollama.sh` for heavy lifting instead of spending your cloud tokens.

## Project Analysis (`analyze_project`)

The system includes a sophisticated analysis tool that provides a deep understanding of any project's architecture.

```bash
# Run from your project root
analyze_project
```markdown

### How it works (Multi-Agent Tiered Analysis)

The script orchestrates multiple local models in parallel:
- **Structure Agent (7B)**: Rapidly maps the folder hierarchy and functional blocks.
- **Documentation Agent (14B)**: Reads and summarizes all discovered `.md` files.
- **Logic Agent (14B)**: Analyzes entry points, core classes, and tech-stack patterns.

The findings are synthesized into a **Delta Report** (`.claude/context/analysis_delta.md`). The IDE agent then reviews this report and merges relevant updates into the authoritative `project_overview.md`.

## Updating

```bash
cd ~/Projects/ai-orchestrator
git pull
```markdown

Changes apply immediately — no reinstall needed.
