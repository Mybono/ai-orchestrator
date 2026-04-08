# Bash/Shell Scripting Standards

## Safety header (required in every script)

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

## Naming

- `UPPER_CASE` — constants and env vars
- `snake_case` — local variables and functions
- Descriptive names: `input_file` not `f`

## Variables

- Always quote: `"$var"`, `"$@"`, `"${array[@]}"`
- Use `${var}` in strings: `"${prefix}_suffix"`
- Declare readonly constants: `readonly MAX_RETRIES=3`
- Never use uninitialized variables (`set -u` catches this)

## Error handling

- `die()` function for fatal errors — always print to stderr
- `trap cleanup EXIT` for temp file cleanup
- Explicit exit codes — never rely on implicit 0
- Errors to stderr: `echo "ERROR: ..." >&2`

## Functions

- One responsibility per function
- Local variables: `local var="value"`
- Return data via stdout, status via exit code

## Input validation

- Validate arg count: `[[ $# -lt 1 ]] && die "Usage: ..."`
- Check required tools: `command -v jq >/dev/null || die "jq required"`
- Validate file existence before use: `[[ -f "$file" ]] || die "..."`

## Portability

- Use `#!/usr/bin/env bash`, not `#!/bin/bash`
- Avoid bashisms when POSIX sh is sufficient
- Use `mktemp` for temp files, never hardcoded paths

## Review checklist

1. Shebang + `set -euo pipefail` present?
2. All `$vars` quoted?
3. Pipe failures propagate (`pipefail`)?
4. Temp files cleaned up on EXIT?
5. No hardcoded paths or secrets?
6. Non-zero exit on failure?
7. Errors go to stderr?
8. Common shellcheck rules pass (SC2086, SC2046, SC2006)?
