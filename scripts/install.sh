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
PROJECT_ROOT="\$(pwd)"
cd "$REPO_DIR"
PROJECT_ROOT="\$PROJECT_ROOT" npx tsx src/agents/TriageAgent.ts "\$@"
WRAPPER
chmod +x "$TRIAGE_WRAPPER"
echo "  ✓ triage-agent.sh (wraps $REPO_DIR)"

TS_ORCH_WRAPPER="$CLAUDE_DIR/ts-orchestrator.sh"
cat > "$TS_ORCH_WRAPPER" <<WRAPPER
#!/bin/bash
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

# Add shell alias
SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == */bash ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

ALIAS_LINE="alias commit='claude -p \"stage all changes and commit\" --agent commit --model haiku --allowedTools \"Bash\"'"

if grep -q "alias commit=" "$SHELL_RC" 2>/dev/null; then
  echo "  ✓ alias commit already exists in $SHELL_RC"
else
{
  echo ""
  echo "# ai-orchestrator aliases"
  echo "$ALIAS_LINE"
} >> "$SHELL_RC"
  echo "  ✓ alias commit added"
fi

for alias_cmd in "local-commit" "open-pr" "analyze_project" "stats"; do
  if ! grep -q "alias $alias_cmd=" "$SHELL_RC" 2>/dev/null; then
    echo "alias $alias_cmd='~/.claude/$alias_cmd.sh'" >> "$SHELL_RC"
    echo "  ✓ alias $alias_cmd added to $SHELL_RC"
  fi
done

# Make helper scripts executable
if [[ -f "$REPO_DIR/scripts/call_ollama.sh" ]]; then
  chmod +x "$REPO_DIR/scripts/call_ollama.sh"
  echo "  ✓ call_ollama.sh is executable"
fi

if [[ -f "$REPO_DIR/scripts/local-commit.sh" ]]; then
  chmod +x "$REPO_DIR/scripts/local-commit.sh"
  echo "  ✓ local-commit.sh is executable"
fi

if [[ -f "$REPO_DIR/scripts/open-pr.sh" ]]; then
  chmod +x "$REPO_DIR/scripts/open-pr.sh"
  echo "  ✓ open-pr.sh is executable"
fi

if [[ -f "$REPO_DIR/scripts/analyze_project.sh" ]]; then
  chmod +x "$REPO_DIR/scripts/analyze_project.sh"
  echo "  ✓ analyze_project.sh is executable"
fi

if [[ -f "$REPO_DIR/scripts/track_savings.sh" ]]; then
  chmod +x "$REPO_DIR/scripts/track_savings.sh"
  echo "  ✓ track_savings.sh is executable"
fi

if [[ -f "$REPO_DIR/scripts/stats.sh" ]]; then
  chmod +x "$REPO_DIR/scripts/stats.sh"
  echo "  ✓ stats.sh is executable"
fi


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

echo ""
echo "🔍 Running initial project analysis..."
bash "$REPO_DIR/scripts/analyze_project.sh"

echo ""
echo "Setup complete! To use orchestrator rules in your project, copy ~/.claude/ai_rules.md to your project root."
echo "Example: cp ~/.claude/ai_rules.md ~/Projects/my-app/ai_rules.md"
echo ""
bash "$REPO_DIR/scripts/check-update.sh"
