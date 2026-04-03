#!/usr/bin/env bash
set -euo pipefail

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
    "reviewer": "qwen2.5-coder:7b",
    "commit": "qwen2.5-coder:1.5b",
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

for alias_cmd in "local-commit" "open-pr"; do
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


echo ""
bash "$REPO_DIR/scripts/analyze_hardware.sh"

echo ""
echo "Setup complete! To use orchestrator rules in your project, copy ~/.claude/ai_rules.md to your project root."
echo "Example: cp ~/.claude/ai_rules.md ~/Projects/my-app/ai_rules.md"
echo ""
