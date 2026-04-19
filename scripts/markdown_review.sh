#!/usr/bin/env bash

# markdown_review.sh - Proactive markdown linting and auto-fix
# Used to prevent documentation build failures in CI.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CALL_OLLAMA="$SCRIPT_DIR/call_ollama.sh"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ROOT_DIR=$(git rev-parse --show-toplevel)
fi

cd "$ROOT_DIR" || { echo "❌ Failed to cd to $ROOT_DIR"; exit 1; }

# Find staged .md files (excluding deleted ones and CHANGELOG.md)
STAGED_MD_FILES=$(command git diff --staged --name-only --diff-filter=d | grep '\.md$' | grep -v 'CHANGELOG.md' || true)

if [ -z "$STAGED_MD_FILES" ]; then
    echo "  - No staged markdown files to check."
    exit 0
fi

echo "Checking staged markdown files..."

fix_with_ollama() {
    local file="$1"
    local errors="$2"

    echo "  Asking Ollama to fix remaining errors in $file..."

    local file_content
    file_content=$(cat "$file")

    local tmp_context
    tmp_context=$(mktemp)

    cat <<EOF > "$tmp_context"
FILE PATH: $file

LINT ERRORS TO FIX:
$errors

CURRENT FILE CONTENT:
$file_content
EOF

    local prompt
    prompt=$(cat <<'EOF'
You are a markdown expert. Fix the reported markdownlint errors in the file provided in context.

Common fixes required:
- MD040: Fenced code blocks must have a language specifier. Add an appropriate language (e.g. ```bash, ```json, ```text, ```typescript, ```python, ```yaml, ```sh) after the opening ```. Use ```text for plain output/examples with no programming language.

CRITICAL RULES:
- Return the FULL corrected file content with ALL fixes applied.
- Preserve ALL existing content, structure, code blocks, and formatting exactly.
- Do NOT add, remove, or reword any content beyond what is required to fix the lint errors.
- Return ONLY the raw file content. No explanations, no surrounding markdown fences, no preamble.
EOF
)

    local fixed_content
    fixed_content=$("$CALL_OLLAMA" --role coder --prompt "$prompt" --context-file "$tmp_context")

    rm -f "$tmp_context"

    if [ -n "$fixed_content" ] && [ "$fixed_content" != "null" ]; then
        # Strip any wrapping markdown fence the model may have added
        fixed_content=$(echo "$fixed_content" | sed -e '/^```markdown$/d' -e '/^```$/d')

        echo "$fixed_content" > "$file"
        git add "$file"
        echo "  Fixed $file."
    else
        echo "  ⚠ Ollama could not fix $file — review manually."
        return 1
    fi
}

ALL_PASSED=true

for file in $STAGED_MD_FILES; do
    echo "  Linting $file..."

    # 1. Auto-fix what markdownlint-cli2 can fix automatically
    npx markdownlint-cli2 --fix "$file" > /dev/null 2>&1 || true
    git add "$file"

    # 2. Check for remaining errors after auto-fix
    LINT_ERRORS=$(npx markdownlint-cli2 "$file" 2>&1 || true)

    if [ -n "$LINT_ERRORS" ]; then
        echo "  Remaining errors in $file:"
        echo "$LINT_ERRORS"

        # 3. Ask Ollama to fix what auto-fix couldn't handle (e.g. MD040)
        if fix_with_ollama "$file" "$LINT_ERRORS"; then
            # 4. Final verification
            if npx markdownlint-cli2 "$file" > /dev/null 2>&1; then
                echo "  ✅ $file — all errors resolved."
            else
                echo "  ⚠ $file still has errors after Ollama fix."
                ALL_PASSED=false
            fi
        else
            ALL_PASSED=false
        fi
    else
        echo "  ✅ $file passed linting."
    fi
done

if [ "$ALL_PASSED" = false ]; then
    echo "⚠ Some markdown files still have lint errors. Commit blocked."
    exit 1
fi

echo "Markdown review completed."
exit 0
