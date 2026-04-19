#!/usr/bin/env bash

# Find the script's directory to locate call_ollama.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_SCRIPT="$SCRIPT_DIR/call_ollama.sh"

# Proactive markdown review
bash "$SCRIPT_DIR/markdown_review.sh"

echo "Gathering git context for Pull Request..."

# Check if there are uncommitted changes
if git status --porcelain | grep -q .; then
    read -rp "You have uncommitted changes. Worth committing before opening a PR? (y/N) " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Committing locally..."
        "$SCRIPT_DIR/local-commit.sh"
    fi
fi

# Find default target branch (usually main or master)
TARGET_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
if [ -z "$TARGET_BRANCH" ]; then
    TARGET_BRANCH="main"
fi

echo "Target branch identified as: $TARGET_BRANCH"

# Get commits (log) and diff
COMMITS=$(git log "origin/$TARGET_BRANCH..HEAD" --no-merges --pretty=format:"* %s" 2>/dev/null || git log "$TARGET_BRANCH..HEAD" --no-merges --pretty=format:"* %s" 2>/dev/null)
DIFF=$(git diff "origin/$TARGET_BRANCH...HEAD" 2>/dev/null || git diff "$TARGET_BRANCH...HEAD" 2>/dev/null)

if [ -z "$COMMITS" ] && [ -z "$DIFF" ]; then
    echo "❌ No differences found between current branch and $TARGET_BRANCH."
    exit 0
fi

# Save context to temporary file
TMP_CONTEXT=$(mktemp)
{
    echo "COMMITS:"
    echo "$COMMITS"
    echo -e "\n\nCODE DIFF:"
    echo "$DIFF"
} > "$TMP_CONTEXT"

echo "Ollama (qwen2.5-coder:7b) is drafting your PR description..."

PROMPT="Generate a GitHub PR title and description based on the following git log and diff. 
Return only the content in the following format (STRICTLY NO EMOJIS anywhere):
Title: <brief meaningful title>

Description:
<detailed description of changes>"

MESSAGE=$("$OLLAMA_SCRIPT" --role reviewer --prompt "$PROMPT" --context-file "$TMP_CONTEXT")
rm -f "$TMP_CONTEXT"

if [ -z "$MESSAGE" ] || [ "$MESSAGE" = "null" ]; then
    echo "❌ Failed to call Ollama. Error output:"
    echo "$MESSAGE"
    exit 1
fi

# Clean up Markdown backticks that small models often ignore instructions to omit
MESSAGE=$(echo "$MESSAGE" | sed '/^```/d')

# Parse Title and Body
TITLE=$(echo "$MESSAGE" | grep "^Title:" | sed 's/^Title:[[:space:]]*//' | head -n 1)
BODY=$(echo "$MESSAGE" | awk '/^Description:/{flag=1; next} flag')

if [ -z "$TITLE" ]; then
    # Fallback if the model didn't strictly format "Title:"
    TITLE="Update from branch $(git branch --show-current)"
    BODY="$MESSAGE"
fi

echo -e "\n================= PR PREVIEW ================="
echo -e "\033[1;34mTitle:\033[0m $TITLE"
echo -e "\033[1;34mDescription:\033[0m\n$BODY"
echo -e "==============================================\n"

# Check for Github CLI and Github remote
if command -v gh &> /dev/null && git remote -v 2>/dev/null | grep -q "github.com"; then
    read -rp "GitHub and 'gh' CLI detected! Create this PR automatically? (y/N) " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Creating PR..."
        # Derive label from conventional commit prefix in title
        PR_LABEL=""
        case "$TITLE" in
            feat*|refactor*|perf*)  PR_LABEL="enhancement" ;;
            fix*)                   PR_LABEL="bug" ;;
            docs*)                  PR_LABEL="documentation" ;;
            chore*)                 PR_LABEL="maintenance" ;;
            ci*)                    PR_LABEL="ci/cd" ;;
            test*)                  PR_LABEL="testing" ;;
            security*)              PR_LABEL="security" ;;
        esac
        if [ -n "$PR_LABEL" ]; then
            gh pr create --title "$TITLE" --body "$BODY" --label "$PR_LABEL" 2>/dev/null \
                || gh pr create --title "$TITLE" --body "$BODY"
        else
            gh pr create --title "$TITLE" --body "$BODY"
        fi
        echo "✅ PR Created Successfully!"
    else
        echo "🚫 PR creation cancelled. You can copy the text above."
    fi
else
    echo "You can copy the text above and paste it into your Git platform (GitHub, Bitbucket, GitLab, etc)."
fi
