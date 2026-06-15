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
DURATION_S=0

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTCOMES_FILE="$REPO_DIR/knowledge/outcomes.jsonl"

while [[ "$#" -gt 0 ]]; do
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

if [[ -z "$TASK" || -z "$VERDICT" || -z "$MODEL" ]]; then
    echo "Usage: $0 --task TEXT --task-type TYPE --files \"f1 f2\" --verdict APPROVED|NEEDS_CHANGES --model NAME [--reviewer-issues \"a,b\"] [--duration-s N]" >&2
    exit 1
fi

if [[ -z "$FILES" ]]; then
    FILES_COUNT=0
else
    FILES_COUNT=$(echo "$FILES" | wc -w | tr -d ' ')
fi

DATE=$(date +"%Y-%m-%dT%H:%M:%S")

jq -n \
    --arg  date             "$DATE" \
    --arg  task             "$TASK" \
    --arg  task_type        "$TASK_TYPE" \
    --argjson files_changed "$FILES_COUNT" \
    --arg  verdict          "$VERDICT" \
    --arg  model            "$MODEL" \
    --arg  reviewer_issues  "$REVIEWER_ISSUES" \
    --argjson duration_s    "$DURATION_S" \
    '{
        date:            $date,
        task:            $task,
        task_type:       $task_type,
        files_changed:   $files_changed,
        verdict:         $verdict,
        model:           $model,
        reviewer_issues: (if $reviewer_issues == "" then [] else ($reviewer_issues | split(",") | map(ltrimstr(" ") | rtrimstr(" "))) end),
        duration_s:      $duration_s
    }' >> "$OUTCOMES_FILE"

echo "  ✓ Outcome captured: $VERDICT for \"$TASK\" (${FILES_COUNT} file(s), model: $MODEL)"
