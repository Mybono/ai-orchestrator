#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/claude-setup-$(date +%Y%m%d_%H%M%S)"

SYMLINK_TARGETS=(
  "CLAUDE.md"
  "agents"
  "commands"
  "skills"
)

echo "Installing claude-setup from: $REPO_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

mkdir -p "$CLAUDE_DIR"

backup_if_exists() {
  local target="$CLAUDE_DIR/$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    echo "  Backing up $1 → $BACKUP_DIR/"
    mv "$target" "$BACKUP_DIR/"
  fi
}

for item in "${SYMLINK_TARGETS[@]}"; do
  backup_if_exists "$item"
  ln -sfn "$REPO_DIR/$item" "$CLAUDE_DIR/$item"
  echo "  ✓ $item"
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
  echo "" >> "$SHELL_RC"
  echo "# claude-setup: commit agent" >> "$SHELL_RC"
  echo "$ALIAS_LINE" >> "$SHELL_RC"
  echo "  ✓ alias commit → added to $SHELL_RC"
  echo "    Run: source $SHELL_RC"
fi

echo ""
echo "Done. To update: cd $REPO_DIR && git pull"

# Optional: pull Ollama models
if command -v ollama &>/dev/null; then
  echo ""
  read -r -p "Pull Ollama models? (y/N) " pull_models
  if [[ "$pull_models" =~ ^[Yy]$ ]]; then
    models=(
      "qwen2.5-coder:14b-instruct-q4_K_M"
      "qwen2.5-coder:7b"
      "qwen2.5-coder:1.5b"
      "qwen3:8b"
      "nomic-embed-text"
    )
    for model in "${models[@]}"; do
      echo "Pulling $model..."
      ollama pull "$model"
    done
  fi
else
  echo ""
  echo "Note: Ollama not found. Install from https://ollama.com and pull models listed in CLAUDE.md"
fi
