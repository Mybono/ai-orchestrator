Run the local commit script to stage and commit all current changes.

Steps:

1. Run `bash ./scripts/local-commit.sh`
2. If committed successfully, report back to the user.

Merge detection: If a `git merge` is in progress (`.git/MERGE_HEAD` exists), the script skips Ollama and commits using the existing merge message. `CHANGELOG.md` is synced automatically — the merge commit is excluded from it.

Privacy Note: This command uses a local LLM via Ollama to generate the commit message. No code is sent to external APIs.
