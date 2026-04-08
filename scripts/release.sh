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

# 2. Push commits and tag
echo ""
echo "Pushing to origin..."
git -C "$ROOT_DIR" push origin HEAD --tags
echo "  ✓ v$NEW_VERSION pushed"

# 3. Optionally open a PR
echo ""
read -rp "Open a Pull Request? (y/N) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/open-pr.sh"
else
    echo "Done. Release v$NEW_VERSION is live."
fi
