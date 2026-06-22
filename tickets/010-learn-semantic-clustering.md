# 010 — Semantic issue clustering in learn.sh

## Problem

`scripts/learn.sh` groups recurring reviewer issues with `sort | uniq -c` — exact string match
only. Semantically identical issues reported in different words ("Null check missing",
"Missing null guard", "No null check before access") accumulate as three separate entries and
none of them ever reaches the `MIN_COUNT=3` threshold, so the learning loop never fires for
them.

## Goal

Replace the exact-match grouping step with a semantic clustering step using the Ollama
instance that is already available in the project (`scripts/call_ollama.sh`). Each unique
issue string gets embedded; issues within a cosine-similarity threshold are merged into one
canonical issue before the count is applied. When Ollama is unavailable the script falls back
to the current `uniq -c` behaviour (dependency on ticket 009).

## Scope

- `scripts/learn.sh` `process_task_type()` — after extracting `issues_json`, pass the list
  to a new helper `cluster_issues()`:
  ```bash
  cluster_issues() {
      # Input:  JSON array of issue strings on stdin
      # Output: JSON array of deduplicated canonical issue strings
      # Uses call_ollama.sh with a clustering prompt:
      #   "Group the following reviewer issues by meaning. Return one representative
      #    phrase per group. Input: <issues_json>"
      # Falls back to passing the array through unchanged if call_ollama.sh fails.
  }
  ```
- The clustered list is then piped into the existing `uniq -c | awk -v min=...` chain, so
  semantically equivalent issues count toward the same threshold
- `cluster_issues()` must be idempotent — calling it twice on the same list returns the same
  canonical set
- Log (`>&2`) which issues were merged so behaviour is observable

## Acceptance criteria

- `knowledge/outcomes.jsonl` contains 3 records with issues `"Null check missing"`,
  `"Missing null guard"`, `"No null check before access"` (one per record, same `task_type`)
- `bash scripts/learn.sh --min-count 3` clusters them → generates one skill amendment for
  the null-check pattern
- With Ollama stopped: `learn.sh` falls back to exact matching, exits 0, emits one `WARN:` line

## Dependencies

- Ticket 009 (Ollama fallback) — cluster_issues() graceful failure path depends on it

## Files touched

- `scripts/learn.sh`
