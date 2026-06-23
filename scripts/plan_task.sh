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
        set -a
        # shellcheck disable=SC1091
        source "$_DIR/.env" 2>/dev/null || true
        set +a
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
    {
        echo "=== KNOWLEDGE GRAPH INDEX ==="
        cat "$WIKI_DIR/WIKI_INDEX.md"
        echo ""
    } >> "$TMP_CONTEXT"

    # Найти релевантные community файлы по ключевым словам задачи
    # Берём слова длиннее 4 символов из описания задачи
    KEYWORDS=$(echo "$TASK $DOMAIN" | tr ' ' '\n' | awk 'length>4' | tr '\n' '|' | sed 's/|$//')
    # shellcheck disable=SC2016
    KEYWORDS=$(printf '%s' "$KEYWORDS" | sed 's/[.[\*^$()+?{|]/\\&/g')
    if [ -n "$KEYWORDS" ]; then
        RELEVANT=$(grep -il -E "$KEYWORDS" "$WIKI_DIR"/community_*.md 2>/dev/null | head -4)
        if [ -n "$RELEVANT" ]; then
            {
            echo "=== RELEVANT CODEBASE COMMUNITIES ==="
            for f in $RELEVANT; do
                echo "--- $(basename "$f") ---"
                cat "$f"
                echo ""
            done
        } >> "$TMP_CONTEXT"
        fi
    fi
fi

# ─── 2. Project overview ─────────────────────────────────────────────────────
OVERVIEW="$PROJECT_ROOT/.claude/context/project_overview.md"
if [ -f "$OVERVIEW" ]; then
    {
        echo "=== PROJECT OVERVIEW ==="
        cat "$OVERVIEW"
        echo ""
    } >> "$TMP_CONTEXT"
fi

# ─── 2b. Architecture docs ───────────────────────────────────────────────────
for ARCH_FILE in \
    "$PROJECT_ROOT/documentation/ARCHITECTURE.md" \
    "$PROJECT_ROOT/ARCHITECTURE.md" \
    "$PROJECT_ROOT/docs/ARCHITECTURE.md"; do
    if [ -f "$ARCH_FILE" ]; then
        {
            echo "=== ARCHITECTURE ==="
            head -150 "$ARCH_FILE"
            echo ""
        } >> "$TMP_CONTEXT"
        break
    fi
done

# ─── 2c. ~/.claude symlinks map (критично для скриптов знающих реальные пути) ─
if [ -d "$HOME/.claude" ]; then
    {
        echo "=== ~/.claude SYMLINKS (real paths) ==="
        # shellcheck disable=SC2012
        ls -la "$HOME/.claude/"*.sh 2>/dev/null | awk '{print $9, $10, $11}' || true
        echo ""
    } >> "$TMP_CONTEXT"
fi

# ─── 3. Triage context (BFS graph traversal result) ─────────────────────────
if [ -n "$TRIAGE_FILE" ] && [ -f "$TRIAGE_FILE" ]; then
    {
        echo "=== TRIAGE ANALYSIS ==="
        cat "$TRIAGE_FILE"
        echo ""
    } >> "$TMP_CONTEXT"
fi

# ─── 4. Language standards — определяем по задаче, не только по проекту ──────
STANDARDS_FILE=""
STANDARDS_HEADER=""
TASK_LOWER=$(echo "$TASK" | tr '[:upper:]' '[:lower:]')

# Если задача явно о bash/shell скрипте — берём bash стандарты
if echo "$TASK_LOWER" | grep -qE '\.sh|bash script|shell script'; then
    STANDARDS_FILE="$HOME/.claude/skills/bash-code-standarts.md"
    STANDARDS_HEADER="=== BASH/SHELL STANDARDS ==="
elif [ -f "$PROJECT_ROOT/tsconfig.json" ] && ! echo "$TASK_LOWER" | grep -qE '\.py|python'; then
    STANDARDS_FILE="$HOME/.claude/skills/ts-code-standarts.md"
    STANDARDS_HEADER="=== TYPESCRIPT STANDARDS ==="
elif [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ]; then
    STANDARDS_FILE="$HOME/.claude/skills/python-code-standarts.md"
    STANDARDS_HEADER="=== PYTHON STANDARDS ==="
elif [ -f "$PROJECT_ROOT/pubspec.yaml" ]; then
    STANDARDS_FILE="$HOME/.claude/skills/flutter-code-standarts.md"
    STANDARDS_HEADER="=== FLUTTER/DART STANDARDS ==="
fi

if [ -n "$STANDARDS_FILE" ] && [ -f "$STANDARDS_FILE" ]; then
    {
        echo "$STANDARDS_HEADER"
        head -120 "$STANDARDS_FILE"
        echo ""
    } >> "$TMP_CONTEXT"
fi

# ─── 5. Исходные файлы — сначала явно упомянутые в задаче, потом по ключевым словам ──
TASK_LOWER=$(echo "$TASK" | tr '[:upper:]' '[:lower:]')
IS_BASH=$(echo "$TASK_LOWER" | grep -cE '\.sh|bash script|shell script' || true)

# 5a. Файлы явно упомянутые в задаче (паттерн `src/...` или `scripts/...`) — полный контент
{
    echo "=== FILES EXPLICITLY MENTIONED IN TASK (full content) ==="
    # Ищем пути вида src/foo/bar.ts, tickets/012-foo.md, agents/planner.md и т.д.
    MENTIONED=$(echo "$TASK" | grep -oE '`?(src|scripts|agents|commands|tickets|plugins|skills|knowledge)/[^` ,):]+`?' \
        | tr -d '`' | sort -u)
    for rel in $MENTIONED; do
        abs="$PROJECT_ROOT/$rel"
        if [ -f "$abs" ]; then
            echo "--- $abs ---"
            cat "$abs"
            echo ""
        fi
    done
} >> "$TMP_CONTEXT"

if [ "$IS_BASH" -gt 0 ] && [ -d "$PROJECT_ROOT/scripts" ]; then
    # Для bash задач: включаем все .sh скрипты как паттерны стиля
    {
        echo "=== EXISTING BASH SCRIPTS (style patterns) ==="
        for f in "$PROJECT_ROOT/scripts/"*.sh; do
            [ -f "$f" ] || continue
            echo "--- $f ---"
            head -120 "$f"
            echo ""
        done
    } >> "$TMP_CONTEXT"
else
    # Для остальных: grep по ключевым словам — полный контент (не head -80)
    for SEARCH_DIR in "$PROJECT_ROOT/src" "$PROJECT_ROOT/scripts"; do
        if [ -d "$SEARCH_DIR" ] && [ -n "$KEYWORDS" ]; then
            MATCHED_FILES=$(grep -rl -E "$KEYWORDS" "$SEARCH_DIR" \
                --include="*.ts" --include="*.py" --include="*.js" --include="*.sh" \
                2>/dev/null | head -6)
            {
                echo "=== RELEVANT FILES IN $(basename "$SEARCH_DIR")/ (full content) ==="
                for f in $MATCHED_FILES; do
                    echo "--- $f ---"
                    cat "$f"
                    echo ""
                done
            } >> "$TMP_CONTEXT"
        fi
    done
fi

# ─── 6. Промпт для LLM (heredoc с прямой подстановкой — без sed) ─────────────
TMP_PROMPT=$(mktemp)
cat > "$TMP_PROMPT" << PROMPT_EOF
You are a senior software architect. Your job is to create a detailed implementation plan.

The codebase context above contains the FULL CURRENT CONTENT of the relevant files.
You MUST use the actual code from the context — never invent types, signatures, or patterns.

TASK: ${TASK}
DOMAIN: ${DOMAIN}

CRITICAL RULES:
- "Exact Signatures" must show what to ADD to the existing file — copy the surrounding real code
- "Patterns to Follow" must be copy-pasted verbatim from the context files above
- "Files to Change" must list existing files by their exact path — never create a new file if the task says to extend an existing one
- The code generator will output the COMPLETE file content — so every section must describe additions/modifications to the existing code, not replacements
- EVERY file mentioned in "## Plan" steps MUST also appear in "## Files to Change" — if a file is in the plan but not in Files to Change, the code generator will silently skip it
- If the task description references a ticket file (e.g. tickets/012-foo.md), its content is in the context above — use its EXACT specifications (API names, parameter names, implementation details) verbatim, do NOT invent alternatives

Write the file in this exact format:

# Task Context

## Language
<detected language and file type — be specific: "Bash script", "TypeScript", etc.>

## Key Standards for This Task
<3-5 most relevant rules from the standards that apply to this task>

## Task
<one sentence description of what needs to be done>

## Plan
- <step 1 — be specific about which function/type/line to change>
- <step 2>

## Files to Change
- \`<file_path>\`: <specifically what to ADD or MODIFY — reference current code by name>

## Exact Signatures
<copy the CURRENT function/type signature from the context, then show what to add/change>

## Patterns to Follow
<copy-paste 1-2 real snippets verbatim from the context files above — do NOT paraphrase>

## Anti-patterns — Do NOT do this
- Do NOT replace the whole file — output complete file with existing code preserved
- <2 more things that would be wrong based on the codebase conventions>

## Edge Cases to Handle
<edge cases based on similar code in the codebase>

Output ONLY the markdown file content. No explanations, no preamble.
PROMPT_EOF

# ─── 7. Вызов LLM: Cerebras → Ollama → FreeLLM → Claude ─────────────────────
OLLAMA_SCRIPT="$PROJECT_ROOT/scripts/call_ollama.sh"
[ ! -f "$OLLAMA_SCRIPT" ] && OLLAMA_SCRIPT="$HOME/.claude/call_ollama.sh"

RESULT=$(bash "$OLLAMA_SCRIPT" --role planner --prompt-file "$TMP_PROMPT" --context-file "$TMP_CONTEXT")

rm -f "$TMP_PROMPT" "$TMP_CONTEXT"

if [ -z "$RESULT" ]; then
    echo "[plan_task] all LLMs failed" >&2
    exit 1
fi

# ─── 8. Запись результата ─────────────────────────────────────────────────────
echo "$RESULT" > "$OUTPUT_FILE"
echo "[plan_task] wrote $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
