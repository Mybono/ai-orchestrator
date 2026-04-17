#!/usr/bin/env bash
# Update graphify knowledge graph for changed files.
# Called from local-commit.sh BEFORE git add -A so updated graph.json
# is staged and included in the same commit.
#
# Usage: graphify-update.sh [file1 file2 ...]
#   With args: update graph for those specific files
#   No args:   get changed files from working tree (git diff + untracked)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAPH_FILE="$REPO_DIR/graphify-out/graph.json"

[ -f "$GRAPH_FILE" ]                          || exit 0
command -v python3 >/dev/null 2>&1            || exit 0
python3 -c "import graphify" 2>/dev/null      || exit 0

# File list: use arguments if provided, otherwise detect from working tree
if [ "$#" -gt 0 ]; then
    CHANGED_FILES="$*"
else
    CHANGED_FILES=$(
        git -C "$REPO_DIR" diff --name-only 2>/dev/null
        git -C "$REPO_DIR" ls-files --others --exclude-standard 2>/dev/null
    ) || exit 0
fi

# Exclude graphify-out/ itself to avoid update loops
CHANGED_FILES=$(echo "$CHANGED_FILES" | grep -v '^graphify-out/' || true)

[ -n "$CHANGED_FILES" ] || exit 0

echo "📊 Updating knowledge graph..."
# shellcheck disable=SC2086
python3 -m graphify "$REPO_DIR" --update $CHANGED_FILES 2>/dev/null || true
