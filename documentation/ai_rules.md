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

### 4. Git Commit standarts

- Use Conventional Commits format STRICTLY: `type(scope): description`
- Subject line max 72 chars, imperative mood
- Allowed prefixes: feat, fix, docs, chore, refactor, test

### 5. Automatic Skill Integration

Before performing any generation, review, or planning task, the IDE Agent MUST:

1. Identify the primary programming language or task type (e.g., Bash, TypeScript, Documentation, Code Review).
2. Locate the corresponding skill file in the `skills/` directory.
3. Read the skill file and incorporate its rules into the system prompt or generation context.
4. If no specific language skill matches, apply `skills/doc-standarts.md` for text or `skills/humanizer.md` for conversational output.
5. If the task involves a bug, crash, or unexpected behavior, ALWAYS load `skills/root-cause-analysis/SKILL.md`.

This step is MANDATORY to ensure consistency across all models and agents in the pipeline.

### 6. Debugging & Root Cause Analysis (RCA)

When the user shares an error, stack trace, or bug report:
1. **Never guess**: Stop and load the `skills/root-cause-analysis/SKILL.md`.
2. **Delegate to Debugger**: If the context (logs/code) is large, delegate the analysis to the local `debugger` role using `call_ollama.sh`.
3. **5-Whys Analysis**: All bug reports MUST include a structured 5-Whys chain identifying the fundamental cause.
4. **Fix Strategy**: Provide both an immediate fix (hotfix) and a systemic countermeasure (preventive fix).
