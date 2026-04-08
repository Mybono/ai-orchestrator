#!/usr/bin/env bash
set -euo pipefail

# Find the script's directory to locate the root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

NEW_VERSION="${1:-}"

if [ -z "$NEW_VERSION" ]; then
    echo "❌ Usage: $0 <new_version>"
    echo "Current version: $(cat "$ROOT_DIR/VERSION")"
    exit 1
fi

echo "🚀 Bumping version to $NEW_VERSION..."

# 1. Update VERSION file
echo "$NEW_VERSION" > "$ROOT_DIR/VERSION"

# 2. Update package.json using jq
if [ -f "$ROOT_DIR/package.json" ]; then
    tmp_json=$(mktemp)
    jq --arg v "$NEW_VERSION" '.version = $v' "$ROOT_DIR/package.json" > "$tmp_json" && mv "$tmp_json" "$ROOT_DIR/package.json"
    echo "  ✓ package.json updated"
fi

# 3. Update pyproject.toml using sed
if [ -f "$ROOT_DIR/pyproject.toml" ]; then
    # Looking for version = "..." in the [project] section
    sed -i '' "s/^version = \".*\"/version = \"$NEW_VERSION\"/" "$ROOT_DIR/pyproject.toml"
    echo "  ✓ pyproject.toml updated"
fi

echo "✅ Version bumped successfully to $NEW_VERSION!"
echo ""

# Commit and tag
git -C "$ROOT_DIR" add -A
git -C "$ROOT_DIR" commit -m "chore: bump version to $NEW_VERSION"
git -C "$ROOT_DIR" tag "v$NEW_VERSION"

echo "Next step — push the release:"
echo "  git push origin main --tags"
