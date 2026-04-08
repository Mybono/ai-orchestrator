Run the local commit script and then push changes to the remote repository.

Steps:

1. Run `bash ./scripts/local-commit.sh`
2. If committed successfully, run `git push`
3. If push is successful, display a summary of the commit and push status.

Merge detection: If a `git merge` is in progress, the script handles it automatically — no Ollama call, merge message used as-is, `CHANGELOG.md` synced before push.

Privacy Note: The commit message is generated locally via Ollama. Only the final commit metadata and code are sent to your git remote during push.
