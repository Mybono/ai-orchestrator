#!/usr/bin/env bash
set -euo pipefail

TASK="${1:-}"
if [ -z "$TASK" ]; then
    echo "Usage: $0 \"task description\""
    exit 1
fi

PROJECT_ROOT="$(pwd)"
CONTEXT_DIR="$PROJECT_ROOT/.claude/context"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Load .env ───────────────────────────────────────────────────────────────
_DIR="$PROJECT_ROOT"
while [ "$_DIR" != "/" ]; do
    if [ -f "$_DIR/.env" ]; then
        set -a
        # shellcheck disable=SC1091
        source "$_DIR/.env" 2>/dev/null || true
        set +a
        break
    fi
    _DIR=$(dirname "$_DIR")
done
unset _DIR

# ─── Find node/npx ───────────────────────────────────────────────────────────
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -d "$NVM_DIR/versions/node" ]; then
    LATEST_NODE=$(find "$NVM_DIR/versions/node" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1)
    LATEST_NODE="${LATEST_NODE##*/}"
    export PATH="$NVM_DIR/versions/node/$LATEST_NODE/bin:$PATH"
fi

mkdir -p "$CONTEXT_DIR"

log()  { echo "[pipeline] $*"; }
fail() { echo "[pipeline] ERROR: $*" >&2; }

# ════════════════════════════════════════════════════════════════════════════
# STEP 1 — TRIAGE
# ════════════════════════════════════════════════════════════════════════════
log "Step 1 — Triage"
PROJECT_ROOT="$PROJECT_ROOT" bash "$HOME/.claude/triage-agent.sh" "$TASK" >&2 || true

TRIAGE_FILE="$CONTEXT_DIR/triage_ts.md"
DOMAINS="coder"
ROUTE=""

if [ -f "$TRIAGE_FILE" ]; then
    DOMAINS=$(awk '/^## Domains/{found=1; next} found && /^## /{exit} found && /^- /{print substr($0,3)}' \
        "$TRIAGE_FILE" | tr '\n' ',' | sed 's/,$//')
    ROUTE=$(awk '/^## Route/{getline; print; exit}' "$TRIAGE_FILE" | tr -d '[:space:]')
fi
DOMAINS="${DOMAINS:-coder}"
log "Domains: $DOMAINS | Route: ${ROUTE:-default}"

case "$ROUTE" in
    direct-edit|quick-coder|plugin-route)
        log "Route '$ROUTE' — skipping pipeline"
        exit 0
        ;;
esac

# ════════════════════════════════════════════════════════════════════════════
# STEP 2 — PLAN (parallel per domain)
# ════════════════════════════════════════════════════════════════════════════
log "Step 2 — Planning"

PLAN_PIDS=()
IFS=',' read -ra DOMAIN_LIST <<< "$DOMAINS"
for DOMAIN in "${DOMAIN_LIST[@]}"; do
    DOMAIN="${DOMAIN// /}"
    [ -z "$DOMAIN" ] && continue
    log "  Planning: $DOMAIN"
    bash "$SCRIPT_DIR/plan_task.sh" \
        --task "$TASK" --domain "$DOMAIN" \
        --triage "$TRIAGE_FILE" --project "$PROJECT_ROOT" >/dev/null &
    PLAN_PIDS+=($!)
done

for PID in "${PLAN_PIDS[@]}"; do
    wait "$PID" || { fail "Planner failed (pid=$PID)"; exit 1; }
done

for DOMAIN in "${DOMAIN_LIST[@]}"; do
    DOMAIN="${DOMAIN// /}"
    [ -z "$DOMAIN" ] && continue
    CTX="$CONTEXT_DIR/task_context_${DOMAIN}.md"
    if [ -f "$CTX" ]; then
        log "  Ready: task_context_${DOMAIN}.md"
    else
        fail "Missing: $CTX"; exit 1
    fi
done

# ════════════════════════════════════════════════════════════════════════════
# STEP 3 — CODE + BUILD + REVIEW
# ════════════════════════════════════════════════════════════════════════════
log "Step 3 — Code + build + review"

set +e
PROJECT_ROOT="$PROJECT_ROOT" bash "$HOME/.claude/ts-orchestrator.sh" "$DOMAINS"
EXIT=$?
set -e

case $EXIT in
    0) log "Done." ;;
    2) fail "Build check failed"; exit 2 ;;
    3) fail "Review failed"; exit 3 ;;
    *) fail "Orchestrator exited: $EXIT"; exit $EXIT ;;
esac

log "Changed files:"
git diff --name-only HEAD 2>/dev/null | sed 's/^/  /' || true
