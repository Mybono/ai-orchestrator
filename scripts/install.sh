#!/usr/bin/env bash
set -euo pipefail

# Support for pipe-to-bash (curl -sSL ... | bash)
if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" == "/dev/stdin" ]; then
    echo "Piped installation detected. Cloning ai-orchestrator..."
    INSTALL_DIR="$HOME/Projects/ai-orchestrator"
    if [ -d "$INSTALL_DIR" ]; then
        echo "  ! Directory $INSTALL_DIR already exists. Updating..."
        cd "$INSTALL_DIR" && git pull
    else
        mkdir -p "$HOME/Projects"
        git clone https://github.com/Mybono/ai-orchestrator "$INSTALL_DIR"
    fi
    # Execute the cloned script with the local context
    exec bash "$INSTALL_DIR/scripts/install.sh" "$@"
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/ai-orchestrator-$(date +%Y%m%d_%H%M%S)"

SYMLINK_TARGETS=(
  "documentation/CLAUDE.md"
  "documentation/ai_rules.md"
  "agents"
  "commands"
  "skills"
  "scripts/call_ollama.sh"
  "scripts/local-commit.sh"
  "scripts/open-pr.sh"
  "scripts/analyze_hardware.sh"
  "scripts/analyze_soft.sh"
  "scripts/analyze_project.sh"
  "scripts/track_savings.sh"
  "scripts/stats.sh"
  "scripts/check-update.sh"
  "scripts/markdown_review.sh"
  "scripts/shellcheck.sh"
)

echo "Installing ai-orchestrator from: $REPO_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# Run software dependency analysis first
bash "$REPO_DIR/scripts/analyze_soft.sh"
echo ""

mkdir -p "$CLAUDE_DIR"

# Initialize llm-config.json in repo if not exists
REPO_CONFIG="$REPO_DIR/llm-config.json"
GLOBAL_CONFIG="$CLAUDE_DIR/llm-config.json"

if [[ ! -f "$REPO_CONFIG" ]]; then
    echo "Initializing llm-config.json in project root..."
    cat > "$REPO_CONFIG" <<EOF
{
  "models": {
    "coder": "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "planner": "hf.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:IQ4_XS",
    "reviewer": "qwen2.5-coder:7b",
    "quick-coder": "qwen3.5:0.8b",
    "commit": "qwen3.5:0.8b",
    "triage": "qwen3.5:0.8b",
    "embedding": "nomic-embed-text"
  }
}
EOF
fi

# Symlink config to global location
echo "🔗 Symlinking llm-config.json to $GLOBAL_CONFIG"
ln -sfn "$REPO_CONFIG" "$GLOBAL_CONFIG"

backup_if_exists() {
  local target="$CLAUDE_DIR/$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    echo "  Backing up $1 → $BACKUP_DIR/"
    mv "$target" "$BACKUP_DIR/"
  fi
}

for item in "${SYMLINK_TARGETS[@]}"; do
  basename_item=$(basename "$item")
  target_name="${basename_item%.template}"
  backup_if_exists "$target_name"
  ln -sfn "$REPO_DIR/$item" "$CLAUDE_DIR/$target_name"
  echo "  ✓ $target_name"
done

# Generate TS orchestrator wrapper scripts (embed absolute REPO_DIR path)
TRIAGE_WRAPPER="$CLAUDE_DIR/triage-agent.sh"
cat > "$TRIAGE_WRAPPER" <<WRAPPER
#!/bin/bash
# Load nvm if npm/npx not in PATH
if ! command -v npx >/dev/null 2>&1 && [ -s "\$HOME/.nvm/nvm.sh" ]; then
  # shellcheck source=/dev/null
  source "\$HOME/.nvm/nvm.sh"
fi
if ! command -v npx >/dev/null 2>&1; then
  echo "❌ Node.js not found. The TypeScript orchestrator requires Node.js." >&2
  echo "" >&2
  echo "  Recommended — install via nvm (no sudo required):" >&2
  echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash" >&2
  echo "    nvm install --lts" >&2
  echo "" >&2
  echo "  Or download from: https://nodejs.org" >&2
  if command -v open >/dev/null 2>&1; then
    read -rp "  Open nodejs.org in browser? (Y/n) " _ans
    [[ -z "\$_ans" || "\$_ans" =~ ^[Yy]$ ]] && open "https://nodejs.org"
  fi
  exit 1
fi
PROJECT_ROOT="\$(pwd)"
cd "$REPO_DIR"
PROJECT_ROOT="\$PROJECT_ROOT" npx tsx src/agents/TriageAgent.ts "\$@"
WRAPPER
chmod +x "$TRIAGE_WRAPPER"
echo "  ✓ triage-agent.sh (wraps $REPO_DIR)"

TS_ORCH_WRAPPER="$CLAUDE_DIR/ts-orchestrator.sh"
cat > "$TS_ORCH_WRAPPER" <<WRAPPER
#!/bin/bash
# Load nvm if npm not in PATH
if ! command -v npm >/dev/null 2>&1 && [ -s "\$HOME/.nvm/nvm.sh" ]; then
  # shellcheck source=/dev/null
  source "\$HOME/.nvm/nvm.sh"
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "❌ Node.js not found. The TypeScript orchestrator requires Node.js." >&2
  echo "" >&2
  echo "  Recommended — install via nvm (no sudo required):" >&2
  echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash" >&2
  echo "    nvm install --lts" >&2
  echo "" >&2
  echo "  Or download from: https://nodejs.org" >&2
  if command -v open >/dev/null 2>&1; then
    read -rp "  Open nodejs.org in browser? (Y/n) " _ans
    [[ -z "\$_ans" || "\$_ans" =~ ^[Yy]$ ]] && open "https://nodejs.org"
  fi
  exit 1
fi
PROJECT_ROOT="\$(pwd)"
cd "$REPO_DIR"
PROJECT_ROOT="\$PROJECT_ROOT" npm start "\$@"
WRAPPER
chmod +x "$TS_ORCH_WRAPPER"
echo "  ✓ ts-orchestrator.sh (wraps $REPO_DIR)"

# Generate settings.json from template (substitutes __HOME__ with real $HOME)
SETTINGS_TEMPLATE="$REPO_DIR/.claude/settings.json.template"
SETTINGS_DEST="$CLAUDE_DIR/settings.json"

if [[ -f "$SETTINGS_TEMPLATE" ]]; then
  backup_if_exists "settings.json"
  sed "s|__HOME__|$HOME|g" "$SETTINGS_TEMPLATE" > "$SETTINGS_DEST"
  echo "  ✓ settings.json (generated for $HOME)"
else
  echo "  WARNING: $SETTINGS_TEMPLATE not found — skipping settings.json generation"
fi

# ── ~/.local/bin symlinks (work in ALL shells, not just interactive) ──────────
echo ""
echo "Setting up ~/.local/bin commands..."
mkdir -p "$HOME/.local/bin"
for cmd_script in local-commit open-pr analyze_project stats; do
  ln -sfn "$CLAUDE_DIR/${cmd_script}.sh" "$HOME/.local/bin/$cmd_script"
  echo "  ✓ ~/.local/bin/$cmd_script"
done

# Add ~/.local/bin to PATH — both .zshrc (interactive) and .zprofile (login)
# shellcheck disable=SC2016  # $HOME/$PATH intentionally unexpanded — resolves at shell startup
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
for rc_file in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc"; do
  # Create .zprofile if missing (macOS login shells need it)
  [[ "$rc_file" == "$HOME/.zprofile" ]] && touch "$rc_file"
  [[ -f "$rc_file" ]] || continue
  if ! grep -qF '.local/bin' "$rc_file" 2>/dev/null; then
    printf '\n%s\n' "$PATH_LINE" >> "$rc_file"
    echo "  ✓ PATH updated in $(basename "$rc_file")"
  else
    echo "  ✓ ~/.local/bin already in $(basename "$rc_file")"
  fi
done

# ── Shell aliases (for tab-completion friendliness in interactive shells) ─────
SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && SHELL_RC="$HOME/.bashrc"

ALIAS_LINE="alias commit='claude -p \"stage all changes and commit\" --agent commit --model haiku --allowedTools \"Bash\"'"
if grep -q "alias commit=" "$SHELL_RC" 2>/dev/null; then
  echo "  ✓ alias commit already exists in $SHELL_RC"
else
  { echo ""; echo "# ai-orchestrator aliases"; echo "$ALIAS_LINE"; } >> "$SHELL_RC"
  echo "  ✓ alias commit added"
fi

for alias_cmd in "local-commit" "open-pr" "analyze_project" "stats"; do
  if ! grep -q "alias $alias_cmd=" "$SHELL_RC" 2>/dev/null; then
    echo "alias $alias_cmd='~/.claude/${alias_cmd}.sh'" >> "$SHELL_RC"
    echo "  ✓ alias $alias_cmd added to $SHELL_RC"
  fi
done

# Make helper scripts executable
for script in call_ollama.sh local-commit.sh open-pr.sh analyze_project.sh track_savings.sh stats.sh markdown_review.sh shellcheck.sh; do
  if [[ -f "$REPO_DIR/scripts/$script" ]]; then
    chmod +x "$REPO_DIR/scripts/$script"
    echo "  ✓ $script is executable"
  fi
done


# Install git hooks into the ai-orchestrator repo itself
HOOKS_DIR="$REPO_DIR/.git/hooks"
if [ -d "$HOOKS_DIR" ]; then
    echo ""
    echo "Installing git hooks..."

    # pre-commit: regenerate CHANGELOG.md via git-cliff
    cat > "$HOOKS_DIR/pre-commit" <<'HOOK'
#!/bin/sh
if [ -f .git/hooks/.cliff-running ]; then
  exit 0
fi
if ! command -v git-cliff >/dev/null 2>&1; then
  exit 0
fi
touch .git/hooks/.cliff-running
git-cliff --config cliff.toml -o CHANGELOG.md 2>/dev/null
git add CHANGELOG.md 2>/dev/null || true
rm -f .git/hooks/.cliff-running
HOOK
    chmod +x "$HOOKS_DIR/pre-commit"
    echo "  ✓ pre-commit hook (git-cliff changelog)"

    # commit-msg: commitlint (skip if not installed locally, skip merge commits)
    cat > "$HOOKS_DIR/commit-msg" <<'HOOK'
#!/bin/sh
# Skip merge commits — they never follow Conventional Commits format
if [ -f .git/MERGE_HEAD ]; then
  exit 0
fi
if ! command -v npx >/dev/null 2>&1; then
  exit 0
fi
if ! npx --no-install commitlint --version >/dev/null 2>&1; then
  exit 0
fi
npx --no-install commitlint --edit "$1" || {
    echo ""
    echo "  Correct format: <type>: <description>"
    echo "  Example:        feat: add login screen"
    echo "  Types:          feat, fix, docs, chore, ci, refactor, perf, style, revert"
    echo ""
    exit 1
}
HOOK
    chmod +x "$HOOKS_DIR/commit-msg"
    echo "  ✓ commit-msg hook (commitlint, skips merge commits)"

    # post-merge: regenerate CHANGELOG.md after any merge (safety net)
    cat > "$HOOKS_DIR/post-merge" <<'HOOK'
#!/bin/sh
# Update CHANGELOG after merge — the merge commit itself is filtered out
# by git-cliff (filter_unconventional = true), so only real commits appear.
if ! command -v git-cliff >/dev/null 2>&1; then
  exit 0
fi
if [ ! -f cliff.toml ]; then
  exit 0
fi
git-cliff --config cliff.toml -o CHANGELOG.md 2>/dev/null
if ! git diff --quiet CHANGELOG.md 2>/dev/null; then
  git add CHANGELOG.md
  git commit -m "chore: sync changelog after merge" --no-verify
fi
HOOK
    chmod +x "$HOOKS_DIR/post-merge"
    echo "  ✓ post-merge hook (git-cliff changelog sync)"

    # post-commit: update graphify knowledge graph for changed files
    POST_COMMIT_HOOK="$HOOKS_DIR/post-commit"
    GRAPHIFY_LINE="bash \"$REPO_DIR/scripts/graphify-update.sh\""
    if [ ! -f "$POST_COMMIT_HOOK" ]; then
        printf '#!/bin/sh\n' > "$POST_COMMIT_HOOK"
        chmod +x "$POST_COMMIT_HOOK"
    fi
    if ! grep -qF "graphify-update.sh" "$POST_COMMIT_HOOK"; then
        printf '\n# graphify knowledge graph update\n%s\n' "$GRAPHIFY_LINE" >> "$POST_COMMIT_HOOK"
        echo "  ✓ post-commit hook (graphify-update)"
    else
        echo "  ✓ post-commit hook already contains graphify-update"
    fi
fi

echo ""
bash "$REPO_DIR/scripts/analyze_hardware.sh"

# ── npm install (TypeScript orchestrator dependencies) ────────────────────────
echo ""
echo "Installing TypeScript dependencies..."
_npm=""
if command -v npm >/dev/null 2>&1; then
  _npm="npm"
elif [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.nvm/nvm.sh"
  command -v npm >/dev/null 2>&1 && _npm="npm"
fi

if [ -n "$_npm" ]; then
  (cd "$REPO_DIR" && npm install --silent 2>&1) && echo "  ✓ npm dependencies installed" \
    || echo "  ⚠ npm install failed — check $REPO_DIR manually"
else
  echo "  ⚠ npm not found — skipping. Run 'npm install' in $REPO_DIR after installing Node.js"
  echo "    Install Node.js via nvm: https://github.com/nvm-sh/nvm"
fi

# ── Pull required Ollama models ───────────────────────────────────────────────
echo ""
echo "Checking Ollama models..."
if command -v ollama >/dev/null 2>&1 && curl -s --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
  OLLAMA_MODELS=$(jq -r '.models | to_entries[] | .value' "$REPO_CONFIG" 2>/dev/null \
    | grep -v '^claude-' | grep -v '^hf\.co/' | grep -v '^$' | sort -u)
  INSTALLED_MODELS=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}')
  for model in $OLLAMA_MODELS; do
    if echo "$INSTALLED_MODELS" | grep -qF "$model"; then
      echo "  ✓ $model already installed"
    else
      echo "  Pulling $model..."
      ollama pull "$model" && echo "  ✓ $model pulled" || echo "  ⚠ Failed to pull $model"
    fi
  done
elif command -v ollama >/dev/null 2>&1; then
  echo "  ⚠ Ollama installed but not running — start Ollama and re-run install to pull models"
else
  echo "  ⚠ Ollama not installed — skipping model pull"
fi

# ── ANTHROPIC_API_KEY check ───────────────────────────────────────────────────
echo ""
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "  ⚠ ANTHROPIC_API_KEY is not set — Claude API fallback will not work."
  echo "    Add to your shell: export ANTHROPIC_API_KEY=sk-ant-..."
else
  echo "  ✓ ANTHROPIC_API_KEY is set"
fi

echo ""
echo "🔍 Running initial project analysis..."
bash "$REPO_DIR/scripts/analyze_project.sh"

echo ""
echo "Setup complete! To use orchestrator rules in your project, copy ~/.claude/ai_rules.md to your project root."
echo "Example: cp ~/.claude/ai_rules.md ~/Projects/my-app/ai_rules.md"
echo ""
echo "  💡 Open a new terminal (or run: source ~/.zshrc) to activate PATH changes."
echo ""
bash "$REPO_DIR/scripts/check-update.sh"
