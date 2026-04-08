#!/usr/bin/env bash
# check-update.sh — compare local VERSION with latest on GitHub
# Silently exits if offline or GitHub is unreachable.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_VERSION="$(cat "$REPO_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')"
REMOTE_URL="https://raw.githubusercontent.com/Mybono/ai-orchestrator/main/VERSION"

if [ -z "$LOCAL_VERSION" ]; then
    exit 0
fi

REMOTE_VERSION="$(curl -fsSL --max-time 3 "$REMOTE_URL" 2>/dev/null | tr -d '[:space:]')"

if [ -z "$REMOTE_VERSION" ]; then
    exit 0
fi

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo "  ai-orchestrator v$LOCAL_VERSION (up to date)"
else
    echo ""
    echo "  ┌─────────────────────────────────────────────────┐"
    echo "  │  Update available: v$LOCAL_VERSION → v$REMOTE_VERSION"
    echo "  │  Run: cd $REPO_DIR"
    echo "  │       git pull && bash scripts/install.sh"
    echo "  └─────────────────────────────────────────────────┘"
    echo ""
fi
