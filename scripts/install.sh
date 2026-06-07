#!/usr/bin/env bash
# install.sh — настройка ai-orchestrator на новой машине
# Устанавливает: nvm/Node.js, jq, Ollama, модели, npm-зависимости,
# создаёт ~/.claude симлинки и шаблон .env
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/llm-config.json"
CLAUDE_DIR="$HOME/.claude"

log()  { echo "[install] $*"; }
ok()   { echo "[install] ✓ $*"; }
warn() { echo "[install] ⚠ $*" >&2; }
die()  { echo "[install] ERROR: $*" >&2; exit 1; }

# ─── Flags ───────────────────────────────────────────────────────────────────
SKIP_MODELS=0
SKIP_OLLAMA=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --skip-models)  SKIP_MODELS=1; shift ;;
    --skip-ollama)  SKIP_OLLAMA=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--skip-models] [--skip-ollama]"
      echo "  --skip-models   skip ollama model pulls (faster on CI)"
      echo "  --skip-ollama   skip ollama install entirely"
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# ─── 1. System tools ─────────────────────────────────────────────────────────
log "Checking system tools..."

if ! command -v jq &>/dev/null; then
  log "Installing jq..."
  if [[ "$(uname)" == "Darwin" ]]; then
    command -v brew &>/dev/null || die "Homebrew not found. Install it: https://brew.sh"
    brew install jq
  else
    sudo apt-get install -y jq 2>/dev/null || sudo yum install -y jq 2>/dev/null || die "Install jq manually"
  fi
fi
ok "jq $(jq --version)"

# ─── 2. Node.js via nvm ──────────────────────────────────────────────────────
log "Setting up Node.js..."

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ ! -d "$NVM_DIR" ]]; then
  log "Installing nvm..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# Load nvm without sourcing .bashrc (works in non-interactive shells)
export NVM_DIR
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
command -v nvm &>/dev/null || die "nvm not found after install"

# Use version from .nvmrc or fall back to LTS
if [[ -f "$PROJECT_ROOT/.nvmrc" ]]; then
  NODE_VERSION=$(cat "$PROJECT_ROOT/.nvmrc")
else
  NODE_VERSION="lts/*"
fi

log "Using Node.js: $NODE_VERSION"
nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
ok "node $(node --version)  npm $(npm --version)"

# ─── 3. npm install ──────────────────────────────────────────────────────────
log "Installing npm dependencies..."
cd "$PROJECT_ROOT"
npm install --prefer-offline 2>/dev/null || npm install
ok "npm dependencies installed"

# ─── 4. tsx (TypeScript runner) ──────────────────────────────────────────────
if ! command -v tsx &>/dev/null; then
  log "Installing tsx globally..."
  npm install -g tsx
fi
ok "tsx $(tsx --version 2>/dev/null || echo 'ok')"

# ─── 5. Ollama ───────────────────────────────────────────────────────────────
if [[ "$SKIP_OLLAMA" -eq 0 ]]; then
  if ! command -v ollama &>/dev/null; then
    log "Installing Ollama..."
    if [[ "$(uname)" == "Darwin" ]]; then
      brew install --cask ollama
    else
      curl -fsSL https://ollama.com/install.sh | sh
    fi
  fi
  ok "ollama $(ollama --version 2>/dev/null | head -1)"

  # Ensure Ollama daemon is running
  if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
    log "Starting Ollama daemon..."
    ollama serve &>/dev/null &
    sleep 3
    curl -sf http://localhost:11434/api/tags &>/dev/null || warn "Ollama daemon may not be running"
  fi

  # ─── 6. Pull Ollama models ───────────────────────────────────────────────
  if [[ "$SKIP_MODELS" -eq 0 ]] && [[ -f "$CONFIG_FILE" ]]; then
    log "Pulling Ollama models from llm-config.json..."

    # Collect unique model names from the "models" section (local Ollama only)
    MODELS=$(jq -r '.models | to_entries[] | .value' "$CONFIG_FILE" | sort -u)

    while IFS= read -r MODEL; do
      [[ -z "$MODEL" ]] && continue
      if ollama list 2>/dev/null | grep -q "^${MODEL%%:*}"; then
        ok "model already present: $MODEL"
      else
        log "Pulling model: $MODEL"
        ollama pull "$MODEL" || warn "Failed to pull $MODEL — skipping"
      fi
    done <<< "$MODELS"
  fi
fi

# ─── 7. .env scaffold ────────────────────────────────────────────────────────
log "Checking .env..."
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
  cat > "$PROJECT_ROOT/.env" <<'EOF'
# API keys for free LLM proxy and fallback providers
# Free LLM proxy (localhost:3001) — used for planning
FREELLM_API_KEY=free

# Optional: Groq / Cerebras / Gemini as alternative free backends
GROQ_API_KEY=
CEREBRAS_API_KEY=
GEMINI_API_KEY=

# Anthropic Claude (used as planner fallback when free LLM is unavailable)
ANTHROPIC_API_KEY=
EOF
  ok ".env created from template — fill in your API keys"
else
  ok ".env already exists"
fi

# ─── 8. ~/.claude symlinks ───────────────────────────────────────────────────
log "Creating ~/.claude symlinks..."
mkdir -p "$CLAUDE_DIR"

# Map: symlink-name → scripts/ source filename
# Format: "symlink_name source_filename"
declare -a SYMLINKS=(
  "analyze_hardware.sh  analyze_hardware.sh"
  "analyze_project.sh   analyze_project.sh"
  "analyze_soft.sh      analyze_soft.sh"
  "call_ollama.sh       call_ollama.sh"
  "check-update.sh      check-update.sh"
  "local-commit.sh      local-commit.sh"
  "markdown_review.sh   markdown_review.sh"
  "open-pr.sh           open-pr.sh"
  "plan_task.sh         plan_task.sh"
  "run-pipeline.sh      run_pipeline.sh"
  "shellcheck.sh        shellcheck.sh"
  "stats.sh             stats.sh"
  "track_savings.sh     track_savings.sh"
  "update-knowledge.sh  update-knowledge.sh"
  "graphify-update.sh   graphify-update.sh"
)

for ENTRY in "${SYMLINKS[@]}"; do
  LINK_NAME=$(echo "$ENTRY" | awk '{print $1}')
  SRC_NAME=$(echo "$ENTRY" | awk '{print $2}')
  SRC="$SCRIPT_DIR/$SRC_NAME"
  LINK="$CLAUDE_DIR/$LINK_NAME"

  if [[ ! -f "$SRC" ]]; then
    warn "Source not found, skipping: scripts/$SRC_NAME"
    continue
  fi

  chmod +x "$SRC"

  if [[ -L "$LINK" && "$(readlink "$LINK")" == "$SRC" ]]; then
    ok "symlink ok: ~/.claude/$LINK_NAME"
  else
    ln -sf "$SRC" "$LINK"
    ok "symlinked: ~/.claude/$LINK_NAME → scripts/$SRC_NAME"
  fi
done

# ─── 9. Free LLM proxy check ─────────────────────────────────────────────────
log "Checking free LLM proxy (localhost:3001)..."
FREE_URL=$(jq -r '.free_api_url // "http://localhost:3001/v1/chat/completions"' "$CONFIG_FILE" 2>/dev/null)
FREE_HOST="${FREE_URL%%/v1*}"
if curl -sf --max-time 3 "$FREE_HOST/v1/models" &>/dev/null || \
   curl -sf --max-time 3 "$FREE_HOST" &>/dev/null; then
  ok "Free LLM proxy reachable: $FREE_HOST"
else
  warn "Free LLM proxy not reachable at $FREE_HOST"
  warn "Pipeline will fall back to Claude (ANTHROPIC_API_KEY required)"
fi

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  ai-orchestrator setup complete"
echo "════════════════════════════════════════"
echo ""
echo "  Next steps:"
echo "  1. Edit .env and fill in your API keys"
echo "  2. Start Ollama: ollama serve"
echo "  3. Run a task:   bash scripts/run_pipeline.sh \"your task\""
echo ""
