#!/usr/bin/env bash
set -uo pipefail

# Scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CALL_OLLAMA="$SCRIPT_DIR/call_ollama.sh"
CONFIG_FILE="$HOME/.claude/llm-config.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting Multi-Agent Project Analysis...${NC}"

# 1. Project Context
PROJECT_NAME=$(basename "$PWD")
CONTEXT_DIR=".claude/context"
mkdir -p "$CONTEXT_DIR"

# 2. Information Gathering
echo -e "   📂 Gathering project structure..."
STRUCTURE=$(find . -maxdepth 3 -not -path '*/.*' -not -path '*/node_modules/*' -not -path '*/venv/*' | head -n 100)

echo -e "   📄 Locating documentation..."
MD_FILES=$(find . -maxdepth 2 -name "*.md" -not -path '*/.*' -not -path '*/context/*' | head -n 10)

echo -e "   ⚙️ Identifying key logic files..."
LOGIC_FILES=$(find . -maxdepth 2 \( -name "main*" -o -name "app*" -o -name "index*" -o -name "__init__.py" -o -name "package.json" -o -name "pyproject.toml" -o -name "scripts/*.sh" \) -not -path '*/.*' | head -n 10)

# 3. Multi-Agent Analysis
TMP_DIR=$(mktemp -d)

# Agent A: Structure Analysis (7B model - role: reviewer or general 7b)
# Using 'reviewer' role as it defaults to 7b in call_ollama.sh
analyze_structure() {
    local prompt="Analyze the following project structure for '$PROJECT_NAME'. 
    Identify the main functional blocks (folders) and their likely purpose.
    Output a concise summary for the 'Architecture & Conventions' section of a Project Overview.
    
    STRUCTURE:
    $STRUCTURE"
    "$CALL_OLLAMA" --role reviewer --prompt "$prompt" > "$TMP_DIR/structure.txt"
}

# Agent B: Documentation Analysis (14B model - role: coder)
# Using 'coder' role as it defaults to 14b (high-performing model)
analyze_docs() {
    local doc_contents=""
    for f in $MD_FILES; do
        doc_contents+="\n--- $f ---\n$(cat "$f" | head -c 2000)\n"
    done
    
    local prompt="Review these documentation files for project '$PROJECT_NAME'. 
    Summarize the project's goals, main features, and any developer rules mentioned.
    Output in a format suitable for 'Known Constraints' and 'Architecture' sections.
    
    DOCS:
    $doc_contents"
    "$CALL_OLLAMA" --role coder --prompt "$prompt" > "$TMP_DIR/docs.txt"
}

# Agent C: Logic & Tech Stack Analysis (14B model - role: coder)
analyze_logic() {
    local logic_contents=""
    for f in $LOGIC_FILES; do
        if [ -f "$f" ]; then
            logic_contents+="\n--- $f ---\n$(cat "$f" | head -c 3000)\n"
        fi
    done
    
    local prompt="Analyze the core logic and configuration of '$PROJECT_NAME'. 
    Detect the primary programming languages, frameworks, and key entry points.
    Identify any recurring patterns or specific tech-stack constraints.
    
    FILES:
    $logic_contents"
    "$CALL_OLLAMA" --role coder --prompt "$prompt" > "$TMP_DIR/logic.txt"
}

# Run Analysis (Parallel)
echo -e "   🤖 Running tiered analysis (Parallel)..."
analyze_structure & PID_A=$!
analyze_docs & PID_B=$!
analyze_logic & PID_C=$!

wait $PID_A $PID_B $PID_C

# 4. Final Synthesis & Delta Discovery (14B)
echo -e "   🧩 Discovering project deltas..."
STR_SUM=$(cat "$TMP_DIR/structure.txt")
DOC_SUM=$(cat "$TMP_DIR/docs.txt")
LOG_SUM=$(cat "$TMP_DIR/logic.txt")

CURRENT_OVERVIEW=""
if [ -f "$CONTEXT_DIR/project_overview.md" ]; then
    CURRENT_OVERVIEW=$(cat "$CONTEXT_DIR/project_overview.md")
fi

FINAL_PROMPT="You are a Technical Lead. Your task is to compare the CURRENT project overview with a NEW automated analysis and identify any missing files, new patterns, or stale information.

DO NOT rewrite the entire overview. Instead, generate a 'Analysis Delta' report.

## Current Overview
$CURRENT_OVERVIEW

---
## New Analysis Data

### Structure Summary:
$STR_SUM

### Documentation Summary:
$DOC_SUM

### Core Logic Summary:
$LOG_SUM

---
## Your Task:
Output a Markdown report named 'Project Analysis Delta'.
1. **New Files/Folders**: List any important assets found in the new analysis but missing from 'Key Files'.
2. **Architecture Changes**: Identify any new patterns or tech-stack details.
3. **Stale Info**: Point out anything in the current overview that contradicts the new data.
4. **Suggested Updates**: Provide specific markdown snippets to be merged into project_overview.md."

DELTA_FILE="$CONTEXT_DIR/analysis_delta.md"
"$CALL_OLLAMA" --role coder --prompt "$FINAL_PROMPT" > "$DELTA_FILE"

# Clean up Markdown backticks if the model included them
sed -i '' '/^```/d' "$DELTA_FILE" 2>/dev/null || sed -i '/^```/d' "$DELTA_FILE"

rm -rf "$TMP_DIR"

echo -e "${GREEN}✅ Analysis Complete! Delta report saved to: $DELTA_FILE${NC}"
echo -e "${YELLOW}👉 Review the delta and merge relevant parts into project_overview.md${NC}"
