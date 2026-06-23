# 009 — Semantic search graceful fallback when Ollama unavailable

## Problem

`scripts/semantic-search.sh` exits with code 1 and prints `ERROR: Ollama unavailable` when
the local Ollama instance is not running. Any caller that uses `set -e` (including `learn.sh`)
will abort silently at this point — the learning loop skips entirely with no signal to the user
that anything was missed.

## Goal

Make `semantic-search.sh` degrade gracefully: when Ollama is unreachable, emit a warning on
stderr and exit 0 with empty stdout. Callers can distinguish "no results" from "error" via
the exit code while still completing their own flow.

## Scope

- `scripts/semantic-search.sh` line 47 — replace the hard-fail block:

  ```bash
  # before
  if ! curl -s --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
      echo "ERROR: Ollama unavailable" >&2
      exit 1
  fi
  # after
  if ! curl -s --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
      echo "WARN: Ollama unavailable — semantic search skipped" >&2
      exit 0
  fi
  ```

- `scripts/semantic-search.sh` — likewise guard the `embed_query` curl call: if the
  embedding request fails (empty response), emit a warning and exit 0 instead of letting
  `jq` fail on empty input
- Add a `--require-ollama` flag that restores the original strict behaviour for callers that
  need it (e.g. CI environments where a missing Ollama is a real error)

## Acceptance criteria

- `bash scripts/semantic-search.sh --query "null check"` with Ollama stopped → exits 0,
  prints one `WARN:` line to stderr, prints nothing to stdout
- `bash scripts/semantic-search.sh --query "null check" --require-ollama` with Ollama
  stopped → exits 1 as before
- `learn.sh` completes normally when Ollama is down (falls back to exact `uniq -c` grouping)

## Files touched

- `scripts/semantic-search.sh`
