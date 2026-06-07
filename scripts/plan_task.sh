#!/usr/bin/env bash
# plan_task.sh — планирует задачу через бесплатный LLM используя граф кодовой базы
# Заменяет Claude planner subagent в implement pipeline
#
# Usage:
#   plan_task.sh --task "описание задачи" --domain coder
#   plan_task.sh --task "..." --domain coder --triage .claude/context/triage.md

TASK=""
DOMAIN="coder"
TRIAGE_FILE=""
PROJECT_ROOT="$PWD"

# Load .env (GROQ_API_KEY, FREELLM_API_KEY и т.д.)
_DIR="$PROJECT_ROOT"
while [ "$_DIR" != "/" ]; do
    if [ -f "$_DIR/.env" ]; then
        set -a; source "$_DIR/.env" 2>/dev/null || true; set +a
        break
    fi
    _DIR=$(dirname "$_DIR")
done
unset _DIR

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --task)    TASK="$2";        shift 2 ;;
        --domain)  DOMAIN="$2";      shift 2 ;;
        --triage)  TRIAGE_FILE="$2"; shift 2 ;;
        --project) PROJECT_ROOT="$2"; shift 2 ;;
        *) echo "[plan_task] unknown arg: $1"; exit 1 ;;
    esac
done

if [ -z "$TASK" ]; then
    echo "Usage: $0 --task <description> [--domain <domain>] [--triage <path>]"
    exit 1
fi

CONTEXT_DIR="$PROJECT_ROOT/.claude/context"
mkdir -p "$CONTEXT_DIR"
OUTPUT_FILE="$CONTEXT_DIR/task_context_${DOMAIN}.md"
TMP_CONTEXT=$(mktemp)

echo "[plan_task] domain=$DOMAIN task='$TASK'" >&2

# ─── 1. Graph context ────────────────────────────────────────────────────────
WIKI_DIR="$PROJECT_ROOT/graphify-out/wiki"
if [ -f "$WIKI_DIR/WIKI_INDEX.md" ]; then
    echo "=== KNOWLEDGE GRAPH INDEX ===" >> "$TMP_CONTEXT"
    cat "$WIKI_DIR/WIKI_INDEX.md" >> "$TMP_CONTEXT"
    echo "" >> "$TMP_CONTEXT"

    # Найти релевантные community файлы по ключевым словам задачи
    # Берём слова длиннее 4 символов из описания задачи
    KEYWORDS=$(echo "$TASK $DOMAIN" | tr ' ' '\n' | awk 'length>4' | tr '\n' '|' | sed 's/|$//')
    if [ -n "$KEYWORDS" ]; then
        RELEVANT=$(grep -il -E "$KEYWORDS" "$WIKI_DIR"/community_*.md 2>/dev/null | head -4)
        if [ -n "$RELEVANT" ]; then
            echo "=== RELEVANT CODEBASE COMMUNITIES ===" >> "$TMP_CONTEXT"
            for f in $RELEVANT; do
                echo "--- $(basename "$f") ---" >> "$TMP_CONTEXT"
                cat "$f" >> "$TMP_CONTEXT"
                echo "" >> "$TMP_CONTEXT"
            done
        fi
    fi
fi

# ─── 2. Project overview ─────────────────────────────────────────────────────
OVERVIEW="$PROJECT_ROOT/.claude/context/project_overview.md"
if [ -f "$OVERVIEW" ]; then
    echo "=== PROJECT OVERVIEW ===" >> "$TMP_CONTEXT"
    cat "$OVERVIEW" >> "$TMP_CONTEXT"
    echo "" >> "$TMP_CONTEXT"
fi

# ─── 3. Triage context (BFS graph traversal result) ─────────────────────────
if [ -n "$TRIAGE_FILE" ] && [ -f "$TRIAGE_FILE" ]; then
    echo "=== TRIAGE ANALYSIS ===" >> "$TMP_CONTEXT"
    cat "$TRIAGE_FILE" >> "$TMP_CONTEXT"
    echo "" >> "$TMP_CONTEXT"
fi

# ─── 4. Language standards ───────────────────────────────────────────────────
STANDARDS_FILE=""
if [ -f "$PROJECT_ROOT/tsconfig.json" ]; then
    STANDARDS_FILE="$HOME/.claude/skills/ts-code-standarts.md"
    echo "=== TYPESCRIPT STANDARDS ===" >> "$TMP_CONTEXT"
elif [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ]; then
    STANDARDS_FILE="$HOME/.claude/skills/python-code-standarts.md"
    echo "=== PYTHON STANDARDS ===" >> "$TMP_CONTEXT"
elif [ -f "$PROJECT_ROOT/pubspec.yaml" ]; then
    STANDARDS_FILE="$HOME/.claude/skills/flutter-code-standarts.md"
    echo "=== FLUTTER/DART STANDARDS ===" >> "$TMP_CONTEXT"
fi

if [ -n "$STANDARDS_FILE" ] && [ -f "$STANDARDS_FILE" ]; then
    head -120 "$STANDARDS_FILE" >> "$TMP_CONTEXT"
    echo "" >> "$TMP_CONTEXT"
fi

# ─── 5. Релевантные исходные файлы (grep по ключевым словам) ─────────────────
SRC_DIR="$PROJECT_ROOT/src"
if [ -d "$SRC_DIR" ] && [ -n "$KEYWORDS" ]; then
    echo "=== RELEVANT SOURCE FILES ===" >> "$TMP_CONTEXT"
    # Ищем файлы содержащие ключевые слова задачи
    MATCHED_FILES=$(grep -rl -E "$KEYWORDS" "$SRC_DIR" \
        --include="*.ts" --include="*.py" --include="*.js" 2>/dev/null | head -5)
    for f in $MATCHED_FILES; do
        echo "--- $f ---" >> "$TMP_CONTEXT"
        head -80 "$f" >> "$TMP_CONTEXT"
        echo "" >> "$TMP_CONTEXT"
    done
fi

# ─── 6. Промпт для LLM ───────────────────────────────────────────────────────
TMP_PROMPT=$(mktemp)
cat > "$TMP_PROMPT" << 'PROMPT_EOF'
You are a senior software architect. Your job is to create a detailed implementation plan.

Using the codebase context provided, write a task context file that will guide a code generator.

TASK: TASK_PLACEHOLDER
DOMAIN: DOMAIN_PLACEHOLDER

Write the file in this exact format:

# Task Context

## Language
<detected language> — standards from `.claude/skills/<file>`

## Key Standards for This Task
<3-5 most relevant rules from the standards that apply to this task>

## Task
<one sentence description of what needs to be done>

## Plan
- <step 1>
- <step 2>
...

## Files to Change
- `<file_path>`: <what to change and why>

## Exact Signatures
<for every function/method to add, write the exact signature>

## Patterns to Follow
<1-2 real code snippets from the codebase showing the exact style to follow>

## Anti-patterns — Do NOT do this
<2-3 things that would be wrong based on the codebase conventions>

## Edge Cases to Handle
<edge cases based on similar code in the codebase>

Output ONLY the markdown file content. No explanations, no preamble.
PROMPT_EOF

# Подставляем задачу и домен в промпт
sed -i '' "s/TASK_PLACEHOLDER/$TASK/g" "$TMP_PROMPT" 2>/dev/null || \
sed -i "s/TASK_PLACEHOLDER/$TASK/g" "$TMP_PROMPT"
sed -i '' "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$TMP_PROMPT" 2>/dev/null || \
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$TMP_PROMPT"

# ─── 7. Вызов LLM: freellmapi → Claude (Ollama не используется для планнера) ──
# Находим конфиг для free_api
CONFIG_FILE="$HOME/.claude/llm-config.json"
_D="$PROJECT_ROOT"
while [ "$_D" != "/" ]; do
    if [ -f "$_D/llm-config.json" ]; then CONFIG_FILE="$_D/llm-config.json"; break; fi
    _D=$(dirname "$_D")
done
unset _D

FREE_URL=$(jq -r '.free_api_url // empty' "$CONFIG_FILE" 2>/dev/null)
FREE_URL="${FREE_URL:-http://localhost:3001/v1/chat/completions}"
FREE_MODEL=$(jq -r '.free_api.planner // "auto"' "$CONFIG_FILE" 2>/dev/null)
FREE_MODEL="${FREE_MODEL:-auto}"

TMP_FREE_PAYLOAD=$(mktemp)
jq -n \
  --arg model "$FREE_MODEL" \
  --rawfile prompt "$TMP_PROMPT" \
  --rawfile context "$TMP_CONTEXT" \
  '{model: $model, max_tokens: 8192,
    messages: [
      {role: "system", content: ("You are a senior software architect. Use the codebase context below.\n\n" + $context)},
      {role: "user", content: $prompt}
    ]}' > "$TMP_FREE_PAYLOAD"

echo "[plan_task] trying free LLM: $FREE_MODEL via $FREE_URL" >&2
FREE_RESPONSE=$(curl -s --max-time 180 -X POST "$FREE_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${FREELLM_API_KEY:-${FREE_API_KEY:-free}}" \
  -d @"$TMP_FREE_PAYLOAD")
rm -f "$TMP_FREE_PAYLOAD"

RESULT=$(echo "$FREE_RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)

# Если free LLM не сработал — используем Claude (как раньше)
if [ -z "$RESULT" ]; then
    echo "[plan_task] free LLM unavailable — falling back to Claude" >&2
    FALLBACK_MODEL=$(jq -r '.fallback.planner // "claude-sonnet-4-6"' "$CONFIG_FILE" 2>/dev/null)
    FALLBACK_MODEL="${FALLBACK_MODEL:-claude-sonnet-4-6}"

    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        echo "[plan_task] ANTHROPIC_API_KEY not set — cannot fall back to Claude" >&2
        rm -f "$TMP_PROMPT" "$TMP_CONTEXT"
        exit 1
    fi

    TMP_CLAUDE_PAYLOAD=$(mktemp)
    jq -n \
      --arg model "$FALLBACK_MODEL" \
      --rawfile prompt "$TMP_PROMPT" \
      --rawfile context "$TMP_CONTEXT" \
      '{model: $model, max_tokens: 8192,
        system: [{type: "text", text: ("You are a senior software architect.\n\n" + $context), cache_control: {type: "ephemeral"}}],
        messages: [{role: "user", content: $prompt}]}' > "$TMP_CLAUDE_PAYLOAD"

    CLAUDE_RESPONSE=$(curl -s --max-time 180 -X POST https://api.anthropic.com/v1/messages \
      -H "Content-Type: application/json" \
      -H "x-api-key: ${ANTHROPIC_API_KEY}" \
      -H "anthropic-version: 2023-06-01" \
      -H "anthropic-beta: prompt-caching-2024-07-31" \
      -d @"$TMP_CLAUDE_PAYLOAD")
    rm -f "$TMP_CLAUDE_PAYLOAD"

    RESULT=$(echo "$CLAUDE_RESPONSE" | jq -r '.content[0].text // empty' 2>/dev/null)
    [ -n "$RESULT" ] && echo "[plan_task] Claude used as fallback ($FALLBACK_MODEL)" >&2
fi

rm -f "$TMP_PROMPT" "$TMP_CONTEXT"

if [ -z "$RESULT" ]; then
    echo "[plan_task] all LLMs failed" >&2
    exit 1
fi

# ─── 8. Запись результата ─────────────────────────────────────────────────────
echo "$RESULT" > "$OUTPUT_FILE"
echo "[plan_task] wrote $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
