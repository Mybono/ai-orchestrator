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
  "settings.json"
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
