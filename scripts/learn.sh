#!/usr/bin/env bash
# Level 2 self-learning: reads knowledge/outcomes.jsonl, finds recurring reviewer issues,
# calls Ollama to generate skill amendments, and append to skills/discovered/.
# Usage: bash scripts/learn.sh [--min-count N] [--apply] [--query TEXT] [--since DAYS] [--no-decay]
# Globals read: REPO_DIR (derived from BASH_SOURCE[0])
# Outputs: skill amendment text to stdout (dry-run) or writes to skills/discovered/ (--apply)
# Exit 0 silently when no outcomes file or fewer than 10 records

set -euo pipefail

MIN_COUNT=3
APPLY_FLAG=""
QUERY=""
SINCE_DAYS=90
NO_DECAY=""
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTCOMES_FILE="$REPO_DIR/knowledge/outcomes.jsonl"
CALL_OLLAMA="$REPO_DIR/scripts/call_ollama.sh"
DISCOVERED_DIR="$REPO_DIR/skills/discovered"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --min-count) MIN_COUNT="$2"; shift 2 ;;
        --apply)     APPLY_FLAG="true"; shift ;;
        --query)     QUERY="$2"; shift 2 ;;
        --since)     SINCE_DAYS="$2"; shift 2 ;;
        --no-decay)  NO_DECAY="true"; shift ;;
        *) echo "Unknown parameter: $1" >&2; exit 1 ;;
    esac
done

count_outcomes() {
    # Returns number of JSON object lines in outcomes.jsonl (excludes comment lines)
    grep -c '^{' "$OUTCOMES_FILE" 2>/dev/null || echo 0
}

compute_since_epoch() {
    # Returns epoch seconds for start of decay window, or 0 when --no-decay is set.
    # Supports both macOS (date -v) and GNU/Linux (date -d) date formats.
    if [ "$NO_DECAY" = "true" ]; then
        echo 0
        return
    fi
    if date -v-1d +%s >/dev/null 2>&1; then
        date -v-${SINCE_DAYS}d +%s
    else
        date -d "-${SINCE_DAYS} days" +%s
    fi
}

map_task_type_to_skill() {
    local task_type="$1"
    # Returns absolute path to the target skill file
    # Mapping:
    #   typescript|ts  → skills/ts-code-standarts.md
    #   python         → skills/python-code-standarts.md
    #   bash|shell     → skills/bash-code-standarts.md
    #   *              → agents/reviewer.md
    case "$task_type" in
        typescript|ts) echo "$REPO_DIR/skills/ts-code-standarts.md" ;;
        python)        echo "$REPO_DIR/skills/python-code-standarts.md" ;;
        bash|shell)    echo "$REPO_DIR/skills/bash-code-standarts.md" ;;
        *)             echo "$REPO_DIR/agents/reviewer.md" ;;
    esac
}

guard_exit_if_no_data() {
    # Guard: exit 0 silently if outcomes.jsonl does not exist or has fewer than 10 data lines
    if [ ! -f "$OUTCOMES_FILE" ]; then
        exit 0
    fi

    local since_epoch
    since_epoch=$(compute_since_epoch)

    local line_count
    if [ "$since_epoch" -gt 0 ]; then
        line_count=$(jq -s --argjson since "$since_epoch" \
            '[.[] | select((.timestamp // 0) >= $since)] | length' \
            "$OUTCOMES_FILE" 2>/dev/null || echo 0)
    else
        line_count=$(count_outcomes)
    fi

    if [ "$line_count" -lt 10 ]; then
        exit 0
    fi
}

process_task_type() {
    local task_type="$1"
    local since_epoch="$2"
    local skill_file
    skill_file=$(map_task_type_to_skill "$task_type")

    # Extract all reviewer_issues for this task_type within the decay window,
    # flatten the arrays, count occurrences. Issues appearing 3+ times get included.
    local issues_json
    issues_json=$(jq --arg t "$task_type" --argjson since "$since_epoch" -r '
        select(.task_type == $t)
        | select((.timestamp // 0) >= $since)
        | .reviewer_issues[]?
    ' "$OUTCOMES_FILE" | sort | uniq -c | awk -v min="$MIN_COUNT" '$1 >= min {$1=""; sub(/^ /, ""); print}' | jq -R -s -c 'split("\n") | map(select(length > 0))')

    # Skip if no issues meet threshold
    if [ "$issues_json" = "[]" ]; then
        return
    fi

    # Build prompt: list recurring issues and request skill amendment
    local prompt
    prompt="Based on the following recurring reviewer issues detected for task type '$task_type', propose a specific amendment to the skill standards file at '$skill_file'. The amendment should add a bullet point, example, or pattern that addresses these issues.\n\nRecurring issues:\n"

    local issue_list
    issue_list=$(echo "$issues_json" | jq -r '.[]?')
    while IFS= read -r issue; do
        [ -n "$issue" ] && prompt="$prompt- $issue\n"
    done <<< "$issue_list"

    prompt="$prompt\nOutput ONLY the markdown text to append to the skill file (no preamble, no explanation)."

    # Call Ollama with reviewer role for analysis
    local response
    response=$("$CALL_OLLAMA" --role reviewer --prompt "$prompt" 2>/dev/null || true)

    # Discard response if empty. Apply flag writes file; otherwise print result.
    if [ -z "$response" ]; then
        echo "ERROR: Empty response from Ollama for task_type '$task_type'" >&2
        return
    fi

    local datestamp
    datestamp=$(date +"%Y%m%d")
    local output_file="$DISCOVERED_DIR/${task_type}-${datestamp}.md"

    if [ "$APPLY_FLAG" = "true" ]; then
        mkdir -p "$DISCOVERED_DIR"
        echo "$response" > "$output_file"
    else
        echo "# Proposed amendment for $skill_file"
        echo "$response"
        echo ""
    fi
}

main_query() {
    local since_epoch="$1"
    local semantic_search="$REPO_DIR/scripts/semantic-search.sh"

    if [ ! -f "$semantic_search" ]; then
        echo "ERROR: semantic-search.sh not found at $semantic_search" >&2
        exit 1
    fi

    # Retrieve semantically similar outcomes
    local records
    records=$(bash "$semantic_search" --query "$QUERY" 2>/dev/null || true)

    if [ -z "$records" ]; then
        echo "No similar outcomes found for query: $QUERY" >&2
        exit 0
    fi

    # Collect issues from returned records within decay window
    local issues_json
    issues_json=$(echo "$records" | jq --argjson since "$since_epoch" \
        'select((.timestamp // 0) >= $since) | .reviewer_issues[]?' \
        | sort | uniq -c \
        | awk -v min="$MIN_COUNT" '$1 >= min {$1=""; sub(/^ /, ""); print}' \
        | jq -R -s -c 'split("\n") | map(select(length > 0))')

    local prompt
    prompt="Based on the following recurring reviewer issues found in outcomes semantically similar to the query '${QUERY}', propose a specific amendment to the relevant skill standards. The amendment should add a bullet point, example, or pattern that addresses these issues.\n\nRecurring issues:\n"

    if [ "$issues_json" = "[]" ] || [ -z "$issues_json" ]; then
        # Fall back to all distinct issues within the window when none meet threshold
        local all_issues
        all_issues=$(echo "$records" | jq --argjson since "$since_epoch" \
            'select((.timestamp // 0) >= $since) | .reviewer_issues[]?' | sort -u)
        if [ -z "$all_issues" ]; then
            echo "No reviewer issues in similar outcomes." >&2
            exit 0
        fi
        while IFS= read -r issue; do
            [ -n "$issue" ] && prompt="$prompt- $issue\n"
        done <<< "$all_issues"
    else
        local issue_list
        issue_list=$(echo "$issues_json" | jq -r '.[]?')
        while IFS= read -r issue; do
            [ -n "$issue" ] && prompt="$prompt- $issue\n"
        done <<< "$issue_list"
    fi

    prompt="$prompt\nOutput ONLY the markdown text to append to the skill file (no preamble, no explanation)."

    local response
    response=$("$CALL_OLLAMA" --role reviewer --prompt "$prompt" 2>/dev/null || true)

    if [ -z "$response" ]; then
        echo "ERROR: Empty response from Ollama" >&2
        exit 1
    fi

    local datestamp
    datestamp=$(date +"%Y%m%d")
    local output_file="$DISCOVERED_DIR/query-${datestamp}.md"

    if [ "$APPLY_FLAG" = "true" ]; then
        mkdir -p "$DISCOVERED_DIR"
        echo "$response" > "$output_file"
    else
        echo "# Proposed amendment for query: $QUERY"
        echo "$response"
        echo ""
    fi
}

main() {
    local since_epoch
    since_epoch=$(compute_since_epoch)

    if [ -n "$QUERY" ]; then
        main_query "$since_epoch"
    else
        guard_exit_if_no_data

        # Get distinct task_types from outcomes
        local task_types
        task_types=$(jq -r 'select(.task_type != null) | .task_type' "$OUTCOMES_FILE" | sort -u)

        # Process each task_type
        while IFS= read -r task_type; do
            [ -n "$task_type" ] && process_task_type "$task_type" "$since_epoch"
        done <<< "$task_types"
    fi
}

main
