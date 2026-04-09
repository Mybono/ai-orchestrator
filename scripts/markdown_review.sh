#!/usr/bin/env bash

# markdown_review.sh - Proactive markdown linting and auto-fix
# Used to prevent documentation build failures in CI.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CALL_OLLAMA="$SCRIPT_DIR/call_ollama.sh"

# Ensure we are in the repository root for git and file path consistency
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ROOT_DIR=$(git rev-parse --show-toplevel)
else
    # Fallback to relative path if not inside a git repo yet (e.g. symlink issue)
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$ROOT_DIR" || { echo "❌ Failed to cd to $ROOT_DIR"; exit 1; }

echo "Checking for staged markdown files in: $PWD"
if [ ! -d .git ]; then
    echo "  [!] Warning: .git directory not found. Current directory contents:"
    ls -F
fi

# Find staged .md files (excluding deleted ones and CHANGELOG.md)
# Using 'command git' to avoid aliases and '--staged' as a synonymous alternative to '--cached'
STAGED_MD_FILES=$(command git diff --staged --name-only --diff-filter=d | grep '\.md$' | grep -v 'CHANGELOG.md' || true)

if [ -z "$STAGED_MD_FILES" ]; then
    echo "  - No staged markdown files to check."
    exit 0
fi

# Function to fix a specific file using Ollama
fix_with_ollama() {
    local file="$1"
    local errors="$2"
    
    echo "Asking Ollama to fix $file..."
    
    local file_content
    file_content=$(cat "$file")
    
    local tmp_context
    tmp_context=$(mktemp)
    
    cat <<EOF > "$tmp_context"
FILE PATH: $file

LINT ERRORS:
$errors

CURRENT CONTENT:
$file_content
EOF
    
    local prompt
    prompt=$(cat <<EOF
You are a markdown expert. Fix the reported lint errors in the file provided in context. 
CRITICAL: Return the FULL file content with all corrections applied. 
Maintain all existing structure, code blocks, and formatting. 
ONLY return the raw file content, NO explanations, NO wrapping backticks.
EOF
)
    
    local fixed_content
    fixed_content=$("$CALL_OLLAMA" --role coder --prompt "$prompt" --context-file "$tmp_context")
    
    rm -f "$tmp_context"
    
    if [ -n "$fixed_content" ] && [[ "$fixed_content" != *"Error"* ]]; then
        # Remove any leading/trailing backticks the model might have added as a code block wrapper
        fixed_content=$(echo "$fixed_content" | sed -e '/^```markdown$/d' -e '/^```$/d')
        
        echo "$fixed_content" > "$file"
        git add "$file"
        echo "Fixed $file using Ollama."
    else
        echo "Failed to fix $file with Ollama."
        return 1
    fi
}

for file in $STAGED_MD_FILES; do
    echo "  Linting $file..."
    
    # 1. Try standard auto-fix first
    npx markdownlint-cli2 --fix "$file" > /dev/null 2>&1 || true
    git add "$file"
    
    # 2. Check for remaining errors
    LINT_ERRORS=$(npx markdownlint-cli2 "$file" 2>&1 || true)
    
    if echo "$LINT_ERRORS" | grep -q "error"; then
        echo " Found lint errors in $file."
        
        # 3. Call Ollama to fix remaining errors
        fix_with_ollama "$file" "$LINT_ERRORS"
    else
        echo "  - $file passed linting."
    fi
done

echo "Markdown review completed."
exit 0
