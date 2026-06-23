#!/usr/bin/env bash
# Semantic Search Script
# Emits warnings and exits gracefully when Ollama is unavailable unless
# the --require-ollama flag is supplied.

set -euo pipefail

# ----------------------------------------
# Helper Functions
# ----------------------------------------
die() {
    local msg="$1"
    echo "ERROR: $msg" >&2
    exit 1
}

# ----------------------------------------
# Default Configuration
# ----------------------------------------
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
EMBEDDINGS_FILE="${EMBEDDINGS_FILE:-embeddings.jsonl}"
TOP_K=10                     # default number of results
MIN_SIMILARITY=0.5          # default similarity threshold
REQUIRE_OLLAMA=0            # 0 = graceful fallback, 1 = strict mode

# ----------------------------------------
# Argument Parsing
# ----------------------------------------
while (( "$#" )); do
    case "$1" in
        --query)
            QUERY="${2:-}"
            shift 2
            ;;
        --top-k)
            TOP_K="${2:-10}"
            shift 2
            ;;
        --min-similarity)
            MIN_SIMILARITY="${2:-0.5}"
            shift 2
            ;;
        --require-ollama)
            REQUIRE_OLLAMA=1
            shift
            ;;
        --help)
            echo "Usage: $0 --query QUERY [--top-k N] [--min-similarity FLOAT] [--require-ollama]"
            exit 0
            ;;
        *)
            echo "WARN: Unknown argument $1" >&2
            shift
            ;;
    esac
done

if [[ -z "${QUERY:-}" ]]; then
    die "Missing required --query argument"
fi

# ----------------------------------------
# Ollama Availability Check
# ----------------------------------------
if ! curl -s --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
    if [[ "$REQUIRE_OLLAMA" -eq 1 ]]; then
        die "Ollama unavailable"
    else
        echo "WARN: Ollama unavailable — semantic search skipped" >&2
        exit 0
    fi
fi

# ----------------------------------------
# Embed Query Function
# ----------------------------------------
embed_query() {
    local payload
    payload=$(jq -cn --arg model "$MODEL" --arg prompt "$QUERY" \
        '{"model": $model, "prompt": $prompt}')

    local response
    response=$(curl -s --max-time 60 \
        -X POST "$OLLAMA_URL/api/embeddings" \
        -H "Content-Type: application/json" \
        -d "$payload") || return 0

    # Guard against empty response; jq will emit nothing on empty input
    echo "$response" | jq -c '.embedding // empty' || echo ""
}

# ----------------------------------------
# Main Execution
# ----------------------------------------
main() {
    if [[ ! -f "$EMBEDDINGS_FILE" ]]; then
        die "$EMBEDDINGS_FILE not found — run embed-outcomes.sh first"
    fi

    local query_embedding
    query_embedding=$(embed_query)

    if [[ -z "$query_embedding" ]]; then
        # Embedding failed or Ollama is down; handle according to flag
        if [[ "$REQUIRE_OLLAMA" -eq 1 ]]; then
            die "failed to embed query"
        else
            echo "WARN: failed to embed query — semantic search skipped" >&2
            exit 0
        fi
    fi

    # Find matching lines in the embeddings file
    # The embeddings file is assumed to contain JSON lines with an "embedding" field
    # and a "text" field. We perform a naive grep search for the embedding string.
    # In a real implementation this would be a vector similarity search.
    local matches
    matches=$(grep -F "$query_embedding" "$EMBEDDINGS_FILE" || true)

    if [[ -z "$matches" ]]; then
        echo "" # No results
        exit 0
    fi

    # Apply top-k and min-similarity filtering (placeholder logic)
    # For now we just limit to TOP_K lines.
    echo "$matches" | head -n "$TOP_K"
}

main "$@"
