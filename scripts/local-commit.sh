#!/usr/bin/env bash

# Find the script's directory to locate call_ollama.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_SCRIPT="$SCRIPT_DIR/call_ollama.sh"

echo "Staging all changes (git add -A)..."
git add -A

# Get the staged diff
DIFF=$(git diff --cached)

if [ -z "$DIFF" ]; then
    echo "❌ No changes to commit."
    exit 0
fi

# Save the diff to a temporary file
TMP_DIFF=$(mktemp)
echo "$DIFF" > "$TMP_DIFF"

PROJECT_NAME=$(basename "$PWD")
CURRENT_BRANCH=$(git branch --show-current)
STAGED_FILES=$(git diff --cached --name-only | tr '\n' ', ' | sed 's/, $//')

echo "📂 Staged files: $STAGED_FILES"
echo "🤖 Ollama is analyzing the code and writing a commit message..."

PROMPT="As a Git expert, review this git diff for the project '$PROJECT_NAME' (branch: '$CURRENT_BRANCH').
Write a concise, professional commit message in Conventional Commits format: type(scope): description.

STRICT RULES:
1. FOCUS ONLY on the provided diff. Do NOT hallucinate features or files not present in the diff.
2. If the diff shows changes to prompts or LLM logic, describe them accurately.
3. Output ONLY the message itself. No explanations, no quotes, no markdown backticks."

MESSAGE=$("$OLLAMA_SCRIPT" --role commit --prompt "$PROMPT" --context-file "$TMP_DIFF")

# Clean up Markdown backticks that small models often ignore instructions to omit
MESSAGE=$(echo "$MESSAGE" | sed '/^```/d')



rm -f "$TMP_DIFF"

if [ -z "$MESSAGE" ] || [[ "$MESSAGE" == *"Error"* ]]; then
    echo "❌ Failed to call Ollama. Error output:"
    echo "$MESSAGE"
    exit 1
fi

echo -e "\nProposed commit message:"
echo -e "\033[1;32m$MESSAGE\033[0m\n"

# Prompt the user for confirmation
read -rp "Commit with this message? (y/N) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    git commit -m "$MESSAGE"

    # Update CHANGELOG if git-cliff and config are available
    if command -v git-cliff >/dev/null 2>&1 && [ -f cliff.toml ]; then
        git-cliff --config cliff.toml -o CHANGELOG.md 2>/dev/null
        git add CHANGELOG.md 2>/dev/null || true
        git commit --amend --no-edit 2>/dev/null || true
    fi

    echo "✅ Committed successfully!"
else
    echo "🚫 Commit cancelled."
fi
