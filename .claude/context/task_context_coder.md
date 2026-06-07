# Task Context

## Language
Bash script

## Key Standards for This Task
- Use `#!/usr/bin/env bash` shebang
- Set `set -euo pipefail` for safety
- Quote all variables: `"$var"`, `"${array[@]}"`

## Task
Write a bash script `scripts/run_pipeline.sh` that autonomously runs the full coding pipeline.

## Plan
- Call `triage-agent.sh` to get domains and route
- Run planner in parallel per domain and wait for completion
- Call `ts-orchestrator.sh` with domains and handle exit codes

## Files to Change
- `scripts/run_pipeline.sh`: new bash script

## Exact Signatures
```bash
./run_pipeline.sh [--skip-gates]
```

## Patterns to Follow
```bash
#!/usr/bin/env bash
set -euo pipefail

# Load .env from project root (walk up from $PWD) — populates GROQ_API_KEY etc.
_DIR="$PWD"
while [ "$_DIR" != "/" ]; do
    if [ -f "$_DIR/.env" ]; then
        set -a; source "$_DIR/.env" 2>/dev/null || true; set +a
        break
    fi
    _DIR=$(dirname "$_DIR")
done
unset _DIR
```

## Anti-patterns — Do NOT do this
- Do not use hardcoded paths
- Do not ignore errors (e.g., do not use `|| true`)

## Edge Cases to Handle
- Handle early exits for routes (direct-edit, quick-coder, plugin-route)
- Handle non-zero exit codes from `ts-orchestrator.sh` (2 or 3)
