# claude-setup

Portable Claude Code configuration: agents, slash commands, and language standards.  
Works with any project — TypeScript, Python, Flutter, Swift, C++.

## What's included

```
claude-setup/
├── CLAUDE.md          # Global instructions for Claude Code
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
└── install.sh         # Installer — creates symlinks in ~/.claude/
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
git clone <your-repo-url> ~/Projects/claude-setup
cd ~/Projects/claude-setup
chmod +x install.sh
./install.sh
```

The script creates symlinks from `~/.claude/` into this repo, so a `git pull` is enough to update everything — no reinstall needed.

### What install.sh does

1. Creates `~/.claude/` if it doesn't exist
2. Backs up any existing files to `~/.claude/backups/`
3. Creates symlinks: `~/.claude/CLAUDE.md`, `~/.claude/agents/`, `~/.claude/commands/`, `~/.claude/skills/`, `~/.claude/settings.json`
4. Adds `commit` shell alias to `~/.zshrc` (or `~/.bashrc`)
5. Optionally pulls Ollama models

### Shell alias

`install.sh` adds a `commit` command to your shell that runs the commit agent directly via Haiku — no Sonnet overhead:

```bash
commit   # stage all changes and commit, from any git repo
```

After install, run `source ~/.zshrc` to activate it in the current terminal.

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

## Updating

```bash
cd ~/Projects/claude-setup
git pull
```

Changes apply immediately — no reinstall needed.
