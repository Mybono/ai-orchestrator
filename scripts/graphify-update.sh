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

# Resolve correct interpreter (same pattern as graphify skill)
GRAPHIFY_PYTHON="python3"
if [ -f "$REPO_DIR/graphify-out/.graphify_python" ]; then
    GRAPHIFY_PYTHON=$(cat "$REPO_DIR/graphify-out/.graphify_python")
fi

# shellcheck disable=SC2016
"$GRAPHIFY_PYTHON" -c "
import sys, json
from graphify.detect import detect_incremental, save_manifest
from graphify.extract import collect_files, extract
from graphify.build import build_from_json
from graphify.export import to_json
from pathlib import Path

repo = Path(sys.argv[1])
result = detect_incremental(repo)
new_total = result.get('new_total', 0)
if new_total == 0:
    sys.exit(0)

new_files = result.get('new_files', {})
all_changed = [repo / f for files in new_files.values() for f in files]

code_files = []
for f in all_changed:
    code_files.extend(collect_files(f) if f.is_dir() else [f])

if code_files:
    extraction = extract(code_files)
    G = build_from_json(extraction)
    if G.number_of_nodes() == 0:
        print('Warning: extraction returned 0 nodes — graph not updated', file=sys.stderr)
    else:
        to_json(G, {}, str(repo / 'graphify-out' / 'graph.json'))
        print(f'Updated graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges')

save_manifest(result.get('files', {}))
" "$REPO_DIR" 2>/dev/null || true
