#!/usr/bin/env bash

# Expected parameters
ROLE=""
MODEL_OVERRIDE=""
PROMPT=""
PROMPT_FILE=""
CONTEXT_FILE=""
# Find config: project-level first (walk up from $PWD), then global
_DIR="$PWD"
CONFIG_FILE="$HOME/.claude/llm-config.json"
while [ "$_DIR" != "/" ]; do
    if [ -f "$_DIR/llm-config.json" ]; then
        CONFIG_FILE="$_DIR/llm-config.json"
        break
    fi
    _DIR=$(dirname "$_DIR")
done
unset _DIR

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --role) ROLE="$2"; shift ;;
        --model) MODEL_OVERRIDE="$2"; shift ;;
        --prompt) PROMPT="$2"; shift ;;
        --prompt-file) PROMPT_FILE="$2"; shift ;;
        --context-file) CONTEXT_FILE="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Resolve prompt from file if provided
if [ -n "$PROMPT_FILE" ] && [ -f "$PROMPT_FILE" ]; then
    PROMPT=$(cat "$PROMPT_FILE")
fi

# Resolve model
SELECTED_MODEL="$MODEL_OVERRIDE"
if [ -z "$SELECTED_MODEL" ] && [ -n "$ROLE" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        SELECTED_MODEL=$(jq -r ".models.\"$ROLE\"" "$CONFIG_FILE")
    fi
fi

# Fallback defaults if still empty
if [ -z "$SELECTED_MODEL" ] || [ "$SELECTED_MODEL" == "null" ]; then
    case $ROLE in
        coder) SELECTED_MODEL="qwen2.5-coder:14b-instruct-q4_K_M" ;;
        reviewer) SELECTED_MODEL="qwen2.5-coder:7b" ;;
        commit) SELECTED_MODEL="qwen2.5-coder:7b" ;;
        *) SELECTED_MODEL="qwen2.5-coder:7b" ;;
    esac
fi

if [ -z "$PROMPT" ]; then
    echo "Usage: $0 [--role <role> | --model <model>] [--prompt <prompt> | --prompt-file <file>] [--context-file <file>]"
    exit 1
fi

CONTEXT=""
if [ -n "$CONTEXT_FILE" ] && [ -f "$CONTEXT_FILE" ]; then
    CONTEXT=$(cat "$CONTEXT_FILE")
fi

# Build JSON payload safely using temporary files to avoid shell line length limits
TMP_PROMPT=$(mktemp)
TMP_CONTEXT=$(mktemp)
TMP_PAYLOAD=$(mktemp)

echo "$PROMPT" > "$TMP_PROMPT"
echo "$CONTEXT" > "$TMP_CONTEXT"

# Use jq to construct the final JSON
jq -n \
  --arg model "$SELECTED_MODEL" \
  --rawfile prompt "$TMP_PROMPT" \
  --rawfile context "$TMP_CONTEXT" \
  '{
    model: $model,
    messages: (
      if ($context != "") then [
        {role: "system", content: "You are an expert AI assistant. Output ONLY the response requested."},
        {role: "user", content: ("Context information:\n\n" + $context + "\n\n---\n\nBased on the context above, follow these instructions:\n" + $prompt)}
      ] else [
        {role: "system", content: "You are an expert AI assistant. Output ONLY the response requested."},
        {role: "user", content: $prompt}
      ] end
    ),
    stream: false
  }' > "$TMP_PAYLOAD"

# Measure prompt size before cleanup (1 token ≈ 4 chars)
PROMPT_CHARS=$(wc -c < "$TMP_PROMPT" | tr -d ' ')

# Call Ollama API
RESPONSE=$(curl -s -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d @"$TMP_PAYLOAD")

# Cleanup
rm "$TMP_PROMPT" "$TMP_CONTEXT" "$TMP_PAYLOAD"

# Extract response content
RESPONSE_CONTENT=$(echo "$RESPONSE" | jq -r '.message.content')

# Track token usage — best effort, never fail the script
TRACK_SCRIPT="$HOME/.claude/track_savings.sh"
if [ -f "$TRACK_SCRIPT" ]; then
    RESPONSE_CHARS=$(echo "$RESPONSE_CONTENT" | wc -c | tr -d ' ')
    INPUT_TOKENS_EST=$(( PROMPT_CHARS / 4 ))
    OUTPUT_TOKENS_EST=$(( RESPONSE_CHARS / 4 ))
    TASK_LABEL="${ROLE:-${SELECTED_MODEL}}"
    bash "$TRACK_SCRIPT" \
        --task "$TASK_LABEL" \
        --input-tokens "$INPUT_TOKENS_EST" \
        --output-tokens "$OUTPUT_TOKENS_EST" \
        --files "0" > /dev/null 2>&1 || true
fi

# Output message content
echo "$RESPONSE_CONTENT"
