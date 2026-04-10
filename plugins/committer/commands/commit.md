Run the local commit script to stage and commit all current changes.

## Expert Committer Rules

As a Git expert, follow these rules for the commit message:

1. **Format**: Use Conventional Commits strictly: `type(scope): description`.
2. **Constraint**: Message MUST BE EXACTLY ONE LINE and MAX 72 CHARACTERS.
3. **Content**: FOCUS ONLY on the provided diff. Do NOT include a body, list of files, or any technical details.
4. **Output**: Output ONLY the message itself. No explanations, no quotes, no markdown backticks.
5. **Visuals**: STRICTLY NO EMOJIS.

## PR Generation Prompt

Generate a GitHub PR title and description based on the following git log and diff.
Return only the content in the following format (STRICTLY NO EMOJIS anywhere):
Title: <brief meaningful title>

Description:
<detailed description of changes>

## Steps

1. Run `bash ./scripts/local-commit.sh`
2. If committed successfully, report back to the user.

Merge detection: If a `git merge` is in progress (`.git/MERGE_HEAD` exists), the script skips Ollama and commits using the existing merge message. `CHANGELOG.md` is synced automatically — the merge commit is excluded from it.

Privacy Note: This command uses a local LLM via Ollama to generate the commit message. No code is sent to external APIs.
