# 011 — Outcome decay: weight recent records more in learn.sh

## Problem

`scripts/learn.sh` reads all records in `knowledge/outcomes.jsonl` regardless of age.
An issue that fired repeatedly six months ago and was then fixed carries the same weight
as an issue from last week. This distorts the `MIN_COUNT` threshold: old resolved patterns
keep suppressing newer signals, and amended skills can't be amended again because the
original issue count stays artificially high.

## Goal

Add a configurable decay window so `process_task_type()` only considers outcomes within a
rolling time period. Records older than the window can optionally be archived rather than
deleted so history is not lost.

## Scope

- `scripts/learn.sh` — add `--since DAYS` flag (default: `90`):

  ```bash
  --since)  SINCE_DAYS="$2"; shift 2 ;;
  ```

- `guard_exit_if_no_data()` — count only records within the window
- `process_task_type()` — update the `jq` filter to include a date guard:

  ```bash
  jq --arg t "$task_type" --arg since "$since_epoch" -r '
      select(.task_type == $t)
      | select((.timestamp // 0) >= ($since | tonumber))
      | .reviewer_issues[]?
  ' "$OUTCOMES_FILE"
  ```

  where `since_epoch` is computed as `date -d "-${SINCE_DAYS} days" +%s` (Linux) /
  `date -v-${SINCE_DAYS}d +%s` (macOS) before the loop
- Add `--no-decay` flag to restore the current all-time behaviour (useful for initial
  bootstrap when outcomes.jsonl is sparse)
- `scripts/embed-outcomes.sh` (if exists) — apply the same window when regenerating
  embeddings so `semantic-search.sh` results also reflect recent history

## Acceptance criteria

- `knowledge/outcomes.jsonl` has 5 records with `timestamp` 200 days ago and 1 record
  from today, all same issue and `task_type`
- `bash scripts/learn.sh --since 90` counts 1 occurrence → does not reach `MIN_COUNT=3`,
  no amendment generated
- `bash scripts/learn.sh --no-decay` counts 6 occurrences → amendment generated
- `bash scripts/learn.sh` (default 90-day window) behaves identically to `--since 90`
- macOS and Linux date commands both work (tested via CI matrix)

## Files touched

- `scripts/learn.sh`
- `scripts/embed-outcomes.sh` (if present)
