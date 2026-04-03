#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/ai-orchestrator-$(date +%Y%m%d_%H%M%S)"

SYMLINK_TARGETS=(
  "documentation/CLAUDE.md"
  "documentation/IDE_AGENT_RULES.md"
  "agents"
  "commands"
  "skills"
  "scripts/call_ollama.sh"
  "scripts/local-commit.sh"
  "scripts/open-pr.sh"
  "scripts/analyze_hardware.sh"
)

echo "Installing ai-orchestrator from: $REPO_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

mkdir -p "$CLAUDE_DIR"

# Check and install dependencies (jq)
if ! command -v jq &>/dev/null; then
    echo "jq not found. Attempting to install..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
            brew install jq
        else
            echo "❌ Error: Homebrew not found. Please install jq manually: https://jqlang.github.io/jq/download/"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y jq
        else
            echo "❌ Error: Could not detect package manager. Please install jq manually."
            exit 1
        fi
    fi
fi

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
  backup_if_exists "$basename_item"
  ln -sfn "$REPO_DIR/$item" "$CLAUDE_DIR/$basename_item"
  echo "  ✓ $basename_item"
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
  echo "# ai-orchestrator aliases" >> "$SHELL_RC"
  echo "$ALIAS_LINE" >> "$SHELL_RC"
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

echo ""
read -r -p "Generate/update ai_rules.md for IDE agents in current directory ($PWD)? (y/N) " gen_rules
if [[ "$gen_rules" =~ ^[Yy]$ ]]; then
  if [[ -f "$PWD/ai_rules.md" ]]; then
    echo "  ! ai_rules.md already exists. Appending IDE orchestrator rules to the EOF..."
    echo "" >> "$PWD/ai_rules.md"
    cat "$REPO_DIR/documentation/IDE_AGENT_RULES.md" >> "$PWD/ai_rules.md"
    echo "  ✓ Orchestrator rules successfully appended"
  else
    cat "$REPO_DIR/documentation/IDE_AGENT_RULES.md" > "$PWD/ai_rules.md"
    echo "  ✓ Created new ai_rules.md with orchestrator templates"
  fi
fi
