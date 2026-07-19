#!/usr/bin/env bash
# Appends one JSON outcome record to knowledge/outcomes.jsonl.
# Called by the PostToolUse hook or manually after a pipeline run.
# Args: --task, --task-type, --files, --verdict, --model, [--reviewer-issues], [--duration-s]

set -euo pipefail

TASK=""
TASK_TYPE="generic"
FILES=""
VERDICT=""
MODEL=""
REVIEWER_ISSUES=""
DURATION_S="0"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTCOMES_FILE="$REPO_DIR/knowledge/outcomes.jsonl"

while [ "$#" -gt 0 ]; do
    case $1 in
        --task)             TASK="$2";             shift ;;
        --task-type)        TASK_TYPE="$2";         shift ;;
        --files)            FILES="$2";             shift ;;
        --verdict)          VERDICT="$2";           shift ;;
        --model)            MODEL="$2";             shift ;;
        --reviewer-issues)  REVIEWER_ISSUES="$2";   shift ;;
        --duration-s)       DURATION_S="$2";        shift ;;
        *) echo "Unknown parameter: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ -z "$TASK" ] || [ -z "$VERDICT" ] || [ -z "$MODEL" ]; then
    echo "Usage: $0 --task TEXT --task-type TYPE [--files \"f1 f2\"] --verdict APPROVED|NEEDS_CHANGES --model NAME [--reviewer-issues \"a,b\"] [--duration-s N]" >&2
    exit 1
fi

if ! echo "$DURATION_S" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
    echo "Error: --duration-s must be a non-negative number, got: '$DURATION_S'" >&2
    exit 1
fi

if [ -z "$FILES" ]; then
    FILES_COUNT=0
else
    FILES_COUNT=$(echo "$FILES" | wc -w | tr -d ' ')
fi

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S")

mkdir -p "$(dirname "$OUTCOMES_FILE")"

jq -cn \
    --arg  date             "$TIMESTAMP" \
    --arg  task             "$TASK" \
    --arg  task_type        "$TASK_TYPE" \
    --argjson files_changed "$FILES_COUNT" \
    --argjson files         "$(echo "$FILES" | jq -R 'split(" ") | map(select(length > 0))')" \
    --arg  verdict          "$VERDICT" \
    --arg  model            "$MODEL" \
    --arg  reviewer_issues  "$REVIEWER_ISSUES" \
    --arg  duration_s       "$DURATION_S" \
    '{
        date:            $date,
        task:            $task,
        task_type:       $task_type,
        files_changed:   $files_changed,
        files:           $files,
        verdict:         $verdict,
        model:           $model,
        reviewer_issues: (if ($reviewer_issues | test("^\\s*$")) then [] else ($reviewer_issues | split(",") | map(ltrimstr(" ") | rtrimstr(" "))) end),
        duration_s:      ($duration_s | tonumber)
    }' >> "$OUTCOMES_FILE"

echo "  ✓ Outcome captured: $VERDICT for \"$TASK\" (${FILES_COUNT} file(s), model: $MODEL)"

# Auto-trigger learn.sh every 10 outcomes
_line_count=$(grep -c '^{' "$OUTCOMES_FILE" 2>/dev/null || echo 0)
if [ "$_line_count" -gt 0 ] && [ $(( _line_count % 10 )) -eq 0 ]; then
    bash "$REPO_DIR/scripts/learn.sh" --apply >/dev/null 2>&1 &
    disown
fi

# Auto-trigger embed-outcomes.sh if Ollama is available
if curl -s --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
    bash "$REPO_DIR/scripts/embed-outcomes.sh" >/dev/null 2>&1 &
    disown
fi
