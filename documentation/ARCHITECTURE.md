# Architecture

[README](../README.md) · **Architecture** · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md)

## Pipeline

The `/implement` command triggers the full pipeline:

```text
planner → pre-review → coder → build check → reviewer(s) → verdict
```

Each stage is a separate agent. If the reviewer returns NEEDS CHANGES, the coder runs again. The fix loop repeats at most 3 times before the pipeline stops and reports remaining issues.

### Stage details

| Stage | Agent | Description |
|-------|-------|-------------|
| Plan | planner | Explores codebase, writes `.claude/context/task_context.md` |
| Pre-Review | pre-reviewer | Validates the plan's logic and architecture (uses Qwen 3.5 0.8b) |
| Code | coder | Reads context file, calls Ollama, applies changes |
| Build check | — | `tsc --noEmit` (TS) or `py_compile` (Python); blocks review if it fails |
| Review | reviewer | Diffs each changed file, calls Ollama, returns APPROVED or NEEDS CHANGES |
| Fix loop | coder + reviewer | Repeats up to 3 rounds on NEEDS CHANGES verdict |

When multiple files are changed, the pipeline spawns one reviewer agent per file in parallel and collects all verdicts before deciding.

## call_ollama.sh

`scripts/call_ollama.sh` is the single interface every agent uses to reach a local Ollama model. It is symlinked to `~/.claude/call_ollama.sh` during installation.

### Interface

```bash
bash ~/.claude/call_ollama.sh \
  --role <role> \
  --prompt "<text>" \
  [--context-file <path>] \
  [--model <override>]
```

### How it works

1. Walks up from `$PWD` to find the nearest `llm-config.json`. Project-level config wins over `~/.claude/llm-config.json`.
2. Resolves the Ollama model name for the given role using `jq`.
3. Writes the prompt and optional context file to temp files, then builds the JSON payload with `jq` (avoids shell line-length limits).
4. Sends `POST http://localhost:11434/api/chat` and extracts `.message.content` from the response.
5. Calls `track_savings.sh` in best-effort mode to record estimated token usage.

If `llm-config.json` is missing or the role is not found, the script falls back to hardcoded defaults:

| Role | Fallback model |
|------|----------------|
| `coder` | `hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS` |
| `planner` | `hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS` |
| `architect` | `hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS` |
| `reviewer` | `qwen2.5-coder:7b` |
| `commit` | `qwen3.5:0.8b` |
| (any other) | `qwen2.5-coder:7b` |

## Model Configuration

`llm-config.json` in the repo root is the single source of truth for model routing. It is symlinked to `~/.claude/llm-config.json` so any project can override it by placing its own `llm-config.json` in the project root.

```json
{
  "models": {
    "coder": "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "planner": "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "architect": "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "reviewer": "qwen2.5-coder:7b",
    "quick-coder": "qwen3.5:0.8b",
    "commit": "qwen3.5:0.8b",
    "triage": "qwen3.5:0.8b",
    "embedding": "nomic-embed-text"
  }
}
```

`call_ollama.sh` resolves the role → model mapping at call time, so changing this file takes effect immediately without restarting anything.

## Symlinks

`scripts/install.sh` creates symlinks from `~/.claude/` into the cloned repo using `ln -sfn`. After installation, a `git pull` in the repo directory instantly updates all global tooling with no reinstall required.

Items symlinked into `~/.claude/`:

- `documentation/CLAUDE.md`
- `documentation/ai_rules.md`
- `agents/`
- `commands/`
- `skills/`
- `scripts/call_ollama.sh`
- `scripts/local-commit.sh`
- `scripts/open-pr.sh`
- `scripts/analyze_hardware.sh`
- `scripts/analyze_soft.sh`
- `scripts/analyze_project.sh`
- `scripts/track_savings.sh`
- `scripts/stats.sh`
- `scripts/check-update.sh`
- `scripts/markdown_review.sh`
- `llm-config.json`

## Context Files

Agents share state through files in `.claude/context/`:

| File | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `task_context.md` | planner | coder, reviewer | Full plan: signatures, patterns, file contents |
| `coder_output.md` | coder | — | Summary of what was implemented |
| `project_overview.md` | planner | planner | Cached project map; speeds up future planner runs |

---

[README](../README.md) · **Architecture** · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md)
