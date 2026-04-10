#!/usr/bin/env bash
set -uo pipefail

# Scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CALL_OLLAMA="$SCRIPT_DIR/call_ollama.sh"
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
# Define ignore patterns (regex for grep -v or multiple -not -path for find)
IGNORE_PATTERN='(\.git|\.next|node_modules|venv|dist|build|out|target|bin|obj|coverage|\.claude/backups)'

# 1. Structure Analysis (maxdepth 4 to see subfolders in src)
STRUCTURE=$(find . -maxdepth 4 -not -path '*/.*' | grep -Ev "$IGNORE_PATTERN" | head -n 120)

echo -e "   📄 Locating documentation..."
# Include root MD files and ai_rules.md explicitly
MD_FILES=$(find . -maxdepth 2 -name "*.md" -o -name ".cursorrules" -o -name "ai_rules.md" | grep -Ev "node_modules|dist|build|context/" | head -n 15)

echo -e "   ⚙️ Identifying key logic files..."
# Prioritize src/ if it exists, otherwise look in root
LOGIC_FILES=$(find . -maxdepth 3 \( -path "./src/*" -o -path "./scripts/*" -o -name "main*" -o -name "app*" -o -name "index*" -o -name "__init__.py" -o -name "package.json" -o -name "pyproject.toml" -o -name "llm-config.json" \) | grep -Ev "$IGNORE_PATTERN" | head -n 15)

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

# Agent B: Documentation Analysis (14B model - role: planner)
# Using 'planner' role as it is designed for high-level architectural understanding
analyze_docs() {
    local doc_contents=""
    for f in $MD_FILES; do
        doc_contents+="\n--- $f ---\n$(cat "$f" | head -c 2000)\n"
    done
    
    local prompt="Review these documentation and orchestration files for project '$PROJECT_NAME'. 
    Summarize the project's goals, main features, and any developer rules mentioned.
    Pay special attention to 'ai_rules.md' or orchestration instructions.
    Output in a format suitable for 'Known Constraints' and 'Architecture' sections.
    
    DOCS:
    $doc_contents"
    "$CALL_OLLAMA" --role planner --prompt "$prompt" > "$TMP_DIR/docs.txt"
}

# Agent C: Logic & Tech Stack Analysis (14B model - role: planner)
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
    "$CALL_OLLAMA" --role planner --prompt "$prompt" > "$TMP_DIR/logic.txt"
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

### Ground Truth Structure (Reference this ONLY):
$STRUCTURE

### Structure Analysis Summary:
$STR_SUM

### Documentation Summary:
$DOC_SUM

### Core Logic Summary (Focus on src/ and core logic):
$LOG_SUM

---
## Your Task:
Output a Markdown report named 'Project Analysis Delta'.

**STRICT NAMING RULES**: 
1. Only mention files that are EXPLICITLY listed in the 'Ground Truth Structure'. 
2. DO NOT invent file names, extensions, or hooks (e.g., if you don't see useTranslation.tsx, do not mention it).
3. MATCH the exact casing and extensions from the Ground Truth (e.g., LanguageContext.tsx, NOT languageContext.ts).

**CRITICAL INSTRUCTION**: Only describe the project's SOURCE code (typically in src/). DO NOT include compiled artifacts from dist/, build/, or out/ in your analysis. If you see redundant structures in both src/ and dist/, IGNORE the dist/ version.
1. **New Files/Folders**: List any important assets found in the new analysis but missing from 'Key Files'.
2. **Architecture Changes**: Identify any new patterns or tech-stack details.
3. **Stale Info**: Point out anything in the current overview that contradicts the new data.
4. **Suggested Updates**: Provide specific markdown snippets to be merged into project_overview.md."

DELTA_FILE="$CONTEXT_DIR/analysis_delta.md"
"$CALL_OLLAMA" --role planner --prompt "$FINAL_PROMPT" > "$DELTA_FILE"

# Clean up Markdown backticks if the model included them
sed -i '' '/^```/d' "$DELTA_FILE" 2>/dev/null || sed -i '/^```/d' "$DELTA_FILE"

rm -rf "$TMP_DIR"

echo -e "${GREEN}✅ Analysis Complete! Delta report saved to: $DELTA_FILE${NC}"
echo -e "${YELLOW}👉 Review the delta and merge relevant parts into project_overview.md${NC}"
