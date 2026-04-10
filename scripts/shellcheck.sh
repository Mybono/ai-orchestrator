#!/usr/bin/env bash

# shellcheck.sh - Proactive shell script linting and auto-fix
# Used to prevent ShellCheck failures in CI.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CALL_OLLAMA="$SCRIPT_DIR/call_ollama.sh"

# Ensure we are in the repository root
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ROOT_DIR=$(git rev-parse --show-toplevel)
else
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$ROOT_DIR" || { echo "❌ Failed to cd to $ROOT_DIR"; exit 1; }

echo "Checking for staged shell scripts..."

# Find staged files
STAGED_FILES=$(command git diff --staged --name-only --diff-filter=d || true)

if [ -z "$STAGED_FILES" ]; then
    echo "  - No staged files to check."
    exit 0
fi

SHELL_FILES=""
for file in $STAGED_FILES; do
    # Skip if file was deleted
    [ ! -f "$file" ] && continue
    
    # 1. Check by extension
    if [[ "$file" =~ \.(sh|bash|ksh|zsh)$ ]]; then
        SHELL_FILES="$SHELL_FILES $file"
        continue
    fi
    
    # 2. Check by shebang (for files without extension or with unknown extension)
    # Only check if first line starts with #! and contains sh/bash/ksh/zsh
    FIRST_LINE=$(head -n 1 "$file" 2>/dev/null || true)
    if [[ "$FIRST_LINE" =~ ^#!.*(sh|bash|ksh|zsh) ]]; then
        SHELL_FILES="$SHELL_FILES $file"
    fi
done

if [ -z "$SHELL_FILES" ]; then
    echo "  - No staged shell scripts found."
    exit 0
fi

# Function to fix a specific file using Ollama
fix_with_ollama() {
    local file="$1"
    local errors="$2"
    
    echo "Asking Ollama to fix ShellCheck warnings in $file..."
    
    local file_content
    file_content=$(cat "$file")
    
    local tmp_context
    tmp_context=$(mktemp)
    
    cat <<EOF > "$tmp_context"
FILE PATH: $file

SHELLCHECK ERRORS/WARNINGS:
$errors

CURRENT CONTENT:
$file_content
EOF
    
    local prompt
    prompt=$(cat <<EOF
You are a shell scripting expert. Fix the reported ShellCheck errors and warnings in the file provided in context.
CRITICAL: Return the FULL file content with all corrections applied. 
Maintain all existing structure, logic, and formatting.
Handle POSIX compatibility, quoting, and unused variables as recommended by ShellCheck.
ONLY return the raw file content, NO explanations, NO wrapping backticks.
EOF
)
    
    local fixed_content
    fixed_content=$("$CALL_OLLAMA" --role coder --prompt "$prompt" --context-file "$tmp_context")
    
    rm -f "$tmp_context"
    
    if [ -n "$fixed_content" ] && [[ "$fixed_content" != *"Error"* ]]; then
        # Remove any leading/trailing backticks the model might have added
        fixed_content=$(echo "$fixed_content" | sed -e '/^```bash$/d' -e '/^```sh$/d' -e '/^```$/d')
        
        echo "$fixed_content" > "$file"
        git add "$file"
        echo "✅ Fixed ShellCheck issues in $file using Ollama."
    else
        echo "❌ Failed to fix $file with Ollama."
        return 1
    fi
}

for file in $SHELL_FILES; do
    echo "  Linting $file..."
    
    # Run ShellCheck
    if ! shellcheck "$file"; then
        LINT_ERRORS=$(shellcheck "$file" 2>&1 || true)
        echo "  [!] Found ShellCheck issues in $file."
        
        # Call Ollama to fix
        fix_with_ollama "$file" "$LINT_ERRORS"
    else
        echo "  - $file passed ShellCheck."
    fi
done

echo "Shell script review completed."
exit 0
