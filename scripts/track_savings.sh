#!/usr/bin/env bash

TASK=""
FILES=""
CONTEXT_FILE="$HOME/.claude/context/task_context.md"
OUTPUT_FILE="$HOME/.claude/context/coder_output.md"
STATS_FILE="$HOME/.claude/token_stats.json"
INPUT_TOKENS_ARG=""
OUTPUT_TOKENS_ARG=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --task) TASK="$2"; shift ;;
        --files) FILES="$2"; shift ;;
        --context-file) CONTEXT_FILE="$2"; shift ;;
        --output-file) OUTPUT_FILE="$2"; shift ;;
        --input-tokens) INPUT_TOKENS_ARG="$2"; shift ;;
        --output-tokens) OUTPUT_TOKENS_ARG="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$TASK" ]; then
    echo "Usage: $0 --task \"description\" [--files \"file1 file2\"] [--input-tokens N --output-tokens N]"
    exit 1
fi

# Count bytes → tokens (1 token ≈ 4 chars)
if [ -n "$INPUT_TOKENS_ARG" ] && [ -n "$OUTPUT_TOKENS_ARG" ]; then
    INPUT_TOKENS="$INPUT_TOKENS_ARG"
    OUTPUT_TOKENS="$OUTPUT_TOKENS_ARG"
else
    if [ -f "$CONTEXT_FILE" ]; then
        INPUT_BYTES=$(wc -c < "$CONTEXT_FILE" | tr -d ' ')
    else
        INPUT_BYTES=0
    fi

    if [ -f "$OUTPUT_FILE" ]; then
        OUTPUT_BYTES=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
    else
        OUTPUT_BYTES=0
    fi

    INPUT_TOKENS=$(( INPUT_BYTES / 4 ))
    OUTPUT_TOKENS=$(( OUTPUT_BYTES / 4 ))
fi

# Count files changed
if [ -z "$FILES" ]; then
    FILES_COUNT=0
else
    FILES_COUNT=$(echo "$FILES" | wc -w | tr -d ' ')
fi

# Calculate estimated USD saved (Claude Sonnet pricing: $3/M input, $15/M output)
# Use jq for float arithmetic
SAVED_USD=$(jq -n \
    --argjson input_tokens "$INPUT_TOKENS" \
    --argjson output_tokens "$OUTPUT_TOKENS" \
    '($input_tokens / 1000000 * 3) + ($output_tokens / 1000000 * 15)' )

# Ensure stats file exists
if [ ! -f "$STATS_FILE" ]; then
    echo '{"runs": []}' > "$STATS_FILE"
fi

# Build new entry and append to runs array
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S")
TMP_ENTRY=$(mktemp)
TMP_UPDATED=$(mktemp)

jq -n \
    --arg date "$TIMESTAMP" \
    --arg task "$TASK" \
    --argjson files_changed "$FILES_COUNT" \
    --argjson input_tokens_est "$INPUT_TOKENS" \
    --argjson output_tokens_est "$OUTPUT_TOKENS" \
    --argjson saved_usd_est "$SAVED_USD" \
    '{
        date: $date,
        task: $task,
        files_changed: $files_changed,
        input_tokens_est: $input_tokens_est,
        output_tokens_est: $output_tokens_est,
        saved_usd_est: $saved_usd_est
    }' > "$TMP_ENTRY"

jq --slurpfile entry "$TMP_ENTRY" '.runs += [$entry[0]]' "$STATS_FILE" > "$TMP_UPDATED"
mv "$TMP_UPDATED" "$STATS_FILE"

rm -f "$TMP_ENTRY"

echo "  ✓ Savings tracked: ~${INPUT_TOKENS} input + ~${OUTPUT_TOKENS} output tokens, \$${SAVED_USD} saved"
