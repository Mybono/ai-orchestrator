# ai-orchestrator

Portable AI Developer setup: agents, slash commands, IDE orchestration, and language standards.  
Works with any project — TypeScript, Python, Flutter, Swift, C++.

## What's included

```
ai-orchestrator/
├── documentation/
│   ├── CLAUDE.md            # Global instructions for Claude CLI
│   └── IDE_AGENT_RULES.md   # Orchestration rules for embedded IDE Agents
├── agents/            # Subagents (run automatically via /implement)
│   ├── planner.md     # Explores codebase, writes implementation plan
│   ├── coder.md       # Generates code via local Ollama model
│   ├── reviewer.md    # Reviews code against language standards
│   ├── quick-coder.md # Fast fixes (single function, imports, renames)
│   ├── commit.md      # Stages and commits changes
│   ├── doc-writer.md  # Creates/updates documentation
│   └── test-agent.md  # Writes and runs tests
├── commands/          # Slash commands
│   ├── implement.md   # /implement — full plan → code → review pipeline
│   ├── review.md      # /review — check changes against standards
│   ├── debug.md       # /debug — analyze errors and stack traces
│   └── standards.md   # /standards — show active language standards
├── skills/            # Language coding standards
│   ├── ts-code-standarts.md
│   ├── python-code-standarts.md
│   ├── fluter-code-standarts.md
│   ├── swift-code-standarts.md
│   ├── c-code-standarts.md
│   └── doc-standarts.md
├── scripts/
│   ├── call_ollama.sh     # Bash script to query local Ollama models on demand
│   ├── local-commit.sh    # Fast local LLM-driven git commits
│   ├── open-pr.sh         # Local LLM-driven Pull Request descriptions
│   └── install.sh         # Installer — creates symlinks in ~/.claude/ and configures projects
```

## How it works

The core workflow is a pipeline triggered by `/implement`:

```
planner → coder → build check → reviewer(s) → verdict
```

- **planner** — detects the project language, reads standards, explores the codebase, writes `.claude/context/task_context.md`
- **coder** — reads the context file, calls a local Ollama model to generate code
- **reviewer** — reviews the diff against language standards via Ollama, returns APPROVED or NEEDS CHANGES

All code generation runs through local Ollama models, not Claude API tokens.

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed
- [Ollama](https://ollama.com) installed and running
- (Optional) [GitHub CLI](https://cli.github.com/) for automated Pull Request creation (`brew install gh && gh auth login`)

### Ollama models

Pull the required models:

```bash
ollama pull qwen2.5-coder:14b-instruct-q4_K_M   # main code generation
ollama pull qwen2.5-coder:7b                      # code review
ollama pull qwen2.5-coder:1.5b                    # quick fixes, commits
ollama pull qwen3:8b                              # planning fallback, docs
ollama pull nomic-embed-text                      # semantic search
```

The `install.sh` script will offer to pull these automatically.

## Installation

```bash
git clone https://github.com/Mybono/ai-orchestrator ~/Projects/ai-orchestrator
cd ~/Projects/ai-orchestrator
chmod +x scripts/install.sh
./scripts/install.sh
```

The script creates symlinks from `~/.claude/` into this repo, so a `git pull` is enough to update everything — no reinstall needed.

### What install.sh does

1. Creates `~/.claude/` if it doesn't exist
2. Backs up any existing files to `~/.claude/backups/`
3. Creates symlinks: `~/.claude/CLAUDE.md`, `~/.claude/IDE_AGENT_RULES.md`, `agents/`, `commands/`, `skills/`, `call_ollama.sh`, `local-commit.sh`, and `open-pr.sh`.
4. Adds `commit`, `local-commit`, and `open-pr` shell aliases to `~/.zshrc` (or `~/.bashrc`)
5. Optionally pulls required Ollama models
6. Optionally initializes or updates `ai_rules.md` in your current project with IDE Agent orchestration rules.

### Shell aliases

`install.sh` injects handy git aliases into your `~/.zshrc` to save API token overhead:

```bash
local-commit   # stages all changes and generates commit message via local Ollama in <1 second
open-pr        # generates a structured PR description from git intent and diffs (auto-creates if gh is installed)
```

After install, run `source ~/.zshrc` to activate them in the current terminal.

## Usage

| Command | What it does |
|---------|-------------|
| `/implement` | Full plan → code → build → review pipeline |
| `/review` | Check current `git diff` against language standards |
| `/debug` | Analyze an error or stack trace |
| `/commit` | Stage and commit changes |

Claude also responds to natural language:
- "commit"  → runs commit agent
- "implement" → runs /implement
- "write docs" → runs doc-writer agent

## IDE Agent Delegation Workflow (Antigravity & Cursor)

*Note: The core CLI workflow (with `/implement`, hooks and `.md` agents) remains fully intact and works exactly as described above. The following process applies exclusively to embedded IDE agents.*

When working with an IDE-embedded agent (like Antigravity), it acts as the Architect and Reviewer directly within the editor. Instead of using the Markdown agent pipeline, it works by:
1. Creating an isolated task context file (e.g., `/tmp/context.md`).
2. Delegating heavy code/documentation generation to the local Ollama model via terminal:
   `bash ~/.claude/call_ollama.sh --model qwen2.5-coder:14b --prompt "implement X" --context-file /tmp/context.md`
   *(For documentation, `qwen3:8b` is used).*
3. Receiving the clean textual response, reviewing it against the standards in `/skills/`, and securely applying the code directly into the active IDE session.

## Updating

```bash
cd ~/Projects/ai-orchestrator
git pull
```

Changes apply immediately — no reinstall needed.
