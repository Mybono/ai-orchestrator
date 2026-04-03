## IDE Agent Orchestration & Delegation Rules

*These rules instruct embedded AI agents (like Antigravity, Cursor, Copilot, etc.) on how to use local resources to save API tokens.*

### 1. Delegation Workflow
For heavy generation tasks (writing large code components, tests, or extensive documentation), the IDE Agent MUST NOT generate the text itself. It must act as the **Orchestrator and Reviewer**:
1. Gather the necessary context using your native file-reading tools.
2. Save this context to a temporary file (e.g., `/tmp/context.md`).
3. Delegate the actual generation to local Ollama by running the helper script in the terminal:
   `bash ~/.claude/call_ollama.sh --model <model> --prompt "..." --context-file /tmp/context.md`
4. Read the script output from stdout.
5. Review the code. If it is correct, use your native tools to insert it into the project files.

### 2. Required Local Models & Scripts
- **call_ollama.sh**: Located at `~/.claude/call_ollama.sh` (Used by AI for delegating general text/code tasks)
- **local-commit.sh**: Located at `~/.claude/local-commit.sh` (Terminal alias to fast-generate git commits using local LLM)
- **open-pr.sh**: Located at `~/.claude/open-pr.sh` (Used by AI or human to generate and open Pull Requests via local LLM)
- **Code Generation**: `qwen2.5-coder:14b` (or `7b` for simpler tasks)
- **Documentation/PRs**: `qwen2.5-coder:7b` down to `qwen3:8b`

### 3. Pull Request Delegation
If the user asks to "open a PR", "create a PR summary", or similar, DO NOT use IDE API tokens to read the git diff and write the text. The context is often too large.
Instead, simply run `bash ~/.claude/open-pr.sh` and return the output. This script automatically handles grabbing commits, diffs, formatting the description, and (if installed) using the GitHub CLI to open the PR.

### 4. Git Commit Standards
- Use Conventional Commits format STRICTLY: `type(scope): description`
- Subject line max 72 chars, imperative mood
- Allowed prefixes: feat, fix, docs, chore, refactor, test
