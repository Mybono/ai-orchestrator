#!/usr/bin/env bash

PERIOD="${1:-all}"
STATS_FILE="$HOME/.claude/token_stats.json"

if [ ! -f "$STATS_FILE" ]; then
    echo "No stats file found at $STATS_FILE"
    exit 0
fi

# Determine cutoff date string (YYYY-MM-DD) using jq-compatible prefix comparison
# Use date command with OS detection
case "$PERIOD" in
    day)
        LABEL="today"
        if date -v-1d +%Y-%m-%d > /dev/null 2>&1; then
            CUTOFF=$(date -v-0d +%Y-%m-%d)   # macOS: today
        else
            CUTOFF=$(date +%Y-%m-%d)          # Linux fallback
        fi
        ;;
    week)
        LABEL="this week"
        if date -v-7d +%Y-%m-%d > /dev/null 2>&1; then
            CUTOFF=$(date -v-7d +%Y-%m-%d)
        else
            CUTOFF=$(date -d "7 days ago" +%Y-%m-%d)
        fi
        ;;
    month)
        LABEL="this month"
        if date -v-30d +%Y-%m-%d > /dev/null 2>&1; then
            CUTOFF=$(date -v-30d +%Y-%m-%d)
        else
            CUTOFF=$(date -d "30 days ago" +%Y-%m-%d)
        fi
        ;;
    all)
        LABEL="all time"
        CUTOFF=""
        ;;
    *)
        echo "Usage: $0 [day|week|month]"
        exit 1
        ;;
esac

# Build jq filter: if cutoff is set, filter runs where date >= cutoff
if [ -n "$CUTOFF" ]; then
    JQ_FILTER=".runs | map(select(.date >= \"$CUTOFF\"))"
else
    JQ_FILTER=".runs"
fi

SUMMARY=$(jq -r \
    --arg label "$LABEL" \
    "
    $JQ_FILTER as \$filtered |
    {
        period: \$label,
        runs: (\$filtered | length),
        input_tokens: (\$filtered | map(.input_tokens_est) | add // 0),
        output_tokens: (\$filtered | map(.output_tokens_est) | add // 0),
        saved_usd: (\$filtered | map(.saved_usd_est) | add // 0)
    } |
    .total_tokens = (.input_tokens + .output_tokens) |
    [
        \"───────────────────────────────\",
        \" ai-orchestrator savings\",
        \" Period: \" + .period,
        \" Runs: \" + (.runs | tostring),
        \" Tokens saved: ~\" + (.total_tokens | . / 1000 | floor | tostring) + \"k\",
        \" Estimated saving: \$\" + (.saved_usd | . * 100 | round | . / 100 | tostring),
        \"───────────────────────────────\"
    ] | join(\"\n\")
    " "$STATS_FILE")

echo "$SUMMARY"
