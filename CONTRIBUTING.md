# Contributing to ai-orchestrator

We're glad you're here. This project is built on a few core beliefs that keep it fast, portable, and useful. If you want to help, here is how we work.

## Project philosophy

- **Pure Bash**: Everything core happens in Bash, `jq`, and `curl`. We don't use Python for orchestration. If it can be done with a shell script, it should be.
- **Portability**: The system must run on any macOS or Linux machine without a complex setup.
- **Local-first**: LLM calls stay local. We delegate coding and reviews to Ollama to save tokens and keep data on your machine.

## How to get things done

### 1. The /implement pipeline

For anything more than a typo fix, use the `/implement` command. It triggers our internal pipeline: **Planner** → **Coder** → **Reviewer**. This ensures your changes follow our language standards and don't break the architecture.

### 2. Commits and Pull Requests

Don't spend time writing manual commit messages. Use the local AI to analyze your diffs:

```bash
./scripts/local-commit.sh
```

Before you open a PR on GitHub, draft the description with our generator:

```bash
./scripts/open-pr.sh
```

## Structure

- **`agents/`**: The "brains" — system prompts and rules for our AI agents.
- **`commands/`**: Slash commands for the IDE.
- **`skills/`**: Language-specific coding standards.
- **`scripts/`**: The engine room — core logic and utilities.
- **`documentation/`**: Architecture guides and rules.

## Your first contribution

1. **Fork** the repo at [Mybono/ai-orchestrator](https://github.com/Mybono/ai-orchestrator).
2. **Clone** it and run `./scripts/install.sh` to set up your environment.
3. **Create a branch** for your work.
4. **Use the tools**: Lean on `/implement` for the heavy lifting and `local-commit.sh` for your git log.
5. **PR**: Use the description from `open-pr.sh` so we can see exactly what changed and why.

## A note on style

- Keep scripts modular.
- Use `jq` for JSON — no external dependencies.
- Match the standards in the `skills/` directory for whatever language you're touching.

Thanks for helping us build this.
