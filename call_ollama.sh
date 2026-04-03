#!/usr/bin/env bash

# Ожидаем параметры
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --model) MODEL="$2"; shift ;;
        --prompt) PROMPT="$2"; shift ;;
        --context-file) CONTEXT_FILE="$2"; shift ;;
        *) echo "Неизвестный параметр: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$MODEL" ] || [ -z "$PROMPT" ]; then
    echo "Использование: $0 --model <model> --prompt <prompt> [--context-file <file>]"
    exit 1
fi

CONTEXT=""
if [ -n "$CONTEXT_FILE" ] && [ -f "$CONTEXT_FILE" ]; then
    CONTEXT=$(cat "$CONTEXT_FILE")
fi

# Формируем JSON через jq (чтобы безопасно экранировать любой код!)
PAYLOAD=$(jq -n \
  --arg model "$MODEL" \
  --arg context "$CONTEXT" \
  --arg prompt "$PROMPT" \
  '{
    model: $model,
    messages: (
      if ($context != "") then [
        {role: "system", content: ("Context information:\n\n" + $context + "\n\nYou must strictly adhere to the user'\''s instructions. Output ONLY the response requested.")},
        {role: "user", content: $prompt}
      ] else [
        {role: "system", content: "You are an expert AI assistant. Output ONLY the response requested."},
        {role: "user", content: $prompt}
      ] end
    ),
    stream: false
  }')

# Отправляем запрос к локальному Ollama API. jq -r вытащит чистый текст
curl -s -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | jq -r '.message.content'
