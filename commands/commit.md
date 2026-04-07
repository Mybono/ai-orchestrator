Run the commit agent to stage and commit all current changes.

The agent calls `local-commit.sh`, which generates a commit message via Ollama, shows a preview, and asks for confirmation before committing.

To open a pull request instead, say "open pr" or run `bash ~/.claude/open-pr.sh` directly.
