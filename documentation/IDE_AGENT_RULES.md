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
- **call_ollama.sh**: Located at `~/.claude/call_ollama.sh` (Used by AI for delegating tasks)
- **local-commit.sh**: Located at `~/.claude/local-commit.sh` (Terminal alias to generate git commits using local LLM)
- **Code Generation**: `qwen2.5-coder:14b` (or `7b` for simpler tasks)
- **Documentation**: `qwen3:8b`

### 3. Git Commit Standards
- Use Conventional Commits format STRICTLY: `type(scope): description`
- Subject line max 72 chars, imperative mood
- Allowed prefixes: feat, fix, docs, chore, refactor, test
