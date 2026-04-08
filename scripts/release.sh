#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

NEW_VERSION="${1:-}"

if [ -z "$NEW_VERSION" ]; then
    CURRENT="$(cat "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
    MAJOR=$(echo "$CURRENT" | cut -d. -f1)
    MINOR=$(echo "$CURRENT" | cut -d. -f2)
    PATCH=$(echo "$CURRENT" | cut -d. -f3)
    NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
    echo "Auto-bumping patch: $CURRENT → $NEW_VERSION"
fi

# 1. Bump version + commit + tag
bash "$SCRIPT_DIR/bump-version.sh" "$NEW_VERSION"

# 2. Push commits
echo ""
echo "Pushing to origin..."
git -C "$ROOT_DIR" push origin HEAD
echo "  ✓ pushed"

# 3. Generate release title and notes via Ollama
echo ""
echo "Generating release notes..."

PREV_TAG=$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$PREV_TAG" ]; then
    COMMITS=$(git -C "$ROOT_DIR" log "${PREV_TAG}..HEAD" --no-merges --pretty=format:"* %s")
else
    COMMITS=$(git -C "$ROOT_DIR" log --no-merges --pretty=format:"* %s" | head -20)
fi

TMP_CONTEXT=$(mktemp)
echo "COMMITS since last release:
$COMMITS" > "$TMP_CONTEXT"

PROMPT="Write a GitHub release title and release notes for version $NEW_VERSION based on these commits.
Return ONLY this format:
Title: <short meaningful title>

Notes:
<markdown release notes with sections like What's Changed, Bug Fixes, etc>"

MESSAGE=$("$SCRIPT_DIR/call_ollama.sh" --role commit --prompt "$PROMPT" --context-file "$TMP_CONTEXT")
rm -f "$TMP_CONTEXT"

TITLE=$(echo "$MESSAGE" | grep "^Title:" | sed 's/^Title:[[:space:]]*//' | head -n 1)
NOTES=$(echo "$MESSAGE" | awk '/^Notes:/{flag=1; next} flag')

if [ -z "$TITLE" ]; then
    TITLE="Release v$NEW_VERSION"
fi
if [ -z "$NOTES" ]; then
    NOTES="$COMMITS"
fi

echo ""
echo "  Title: $TITLE"
echo "  Notes preview: $(echo "$NOTES" | head -3)..."

# 4. Create GitHub Release
echo ""
echo "Creating GitHub Release..."
gh release create "v$NEW_VERSION" \
    --title "$TITLE" \
    --notes "$NOTES"
echo "  ✓ Release v$NEW_VERSION published"

# 4. Optionally open a PR
echo ""
read -rp "Open a Pull Request? (y/N) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/open-pr.sh"
fi
