#!/usr/bin/env bash

# Find the script's directory to locate call_ollama.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_SCRIPT="$SCRIPT_DIR/call_ollama.sh"

# If the staging area is empty, stage all changes
if git diff --cached --quiet; then
    echo "💡 Staging area is empty. Staging all changes (git add -A)..."
    git add -A
fi

# Get the staged diff
DIFF=$(git diff --cached)

if [ -z "$DIFF" ]; then
    echo "❌ No changes to commit."
    exit 0
fi

# Save the diff to a temporary file
TMP_DIFF=$(mktemp)
echo "$DIFF" > "$TMP_DIFF"

# 3. Call Ollama (commit role)
echo "🤖 Ollama is analyzing the code and writing a commit message..."

PROMPT="Review the following git diff and write a concise, meaningful commit message. 
One line summary (max 50 chars), then a blank line, then a bulleted list of changes if necessary.
Write ONLY the message, no extra text, no 'Short summary:' prefix."

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
    echo "✅ Committed successfully!"
else
    echo "🚫 Commit cancelled."
fi
