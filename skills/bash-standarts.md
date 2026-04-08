---
name: bash-scripting
description: >
  Write, review, debug, and improve bash/shell scripts for any context: CI/CD pipelines
  (GitHub Actions, GitLab CI, Bitrise), DevOps automation, macOS/Linux system tasks,
  file processing, and data transformation. Use this skill whenever the user asks to
  write a shell script, improve an existing one, debug a bash error, or automate
  any task via command line — even if they just say "make a script that does X" or
  paste a broken script without explanation. Also trigger for requests involving
  cron jobs, entrypoints, deploy scripts, migration scripts, or any .sh file.
---
 
# Bash Scripting Skill
 
## Phase 1: Understand Before Writing
 
Before writing a script, extract:
 
1. **Shell target** — bash? zsh? POSIX sh? If unspecified, default to `#!/usr/bin/env bash`.
2. **Execution environment** — local machine, CI runner (GitHub Actions / GitLab / Bitrise), Docker container, remote server?
3. **Inputs** — args, env vars, stdin, files?
4. **Outputs** — stdout, files, exit codes, side effects?
5. **Error behavior** — fail-fast or continue? Silent or loud?
6. **Idempotency** — must the script be safe to run multiple times?
 
If the user pastes a broken script, skip the interview and go straight to diagnosis.
 
---
 
## Phase 2: Script Standards
 
Apply these to every script you write or review:
 
### Safety header (always include)
```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```
- `set -e` — exit on error
- `set -u` — treat unset variables as errors
- `set -o pipefail` — catch errors in pipes
- `IFS` — safer word splitting
 
**Exception**: Omit `set -e` only if the script intentionally continues on errors (document why).
 
### Variable hygiene
```bash
# Always quote variables
echo "$var"           # good
echo $var             # bad — breaks on spaces/globs
 
# Use ${} for clarity in strings
echo "${prefix}_suffix"
 
# Readonly constants
readonly MAX_RETRIES=3
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```
 
### Error handling patterns
```bash
# Trap for cleanup
cleanup() {
  local exit_code=$?
  rm -f "$tmpfile"
  exit "$exit_code"
}
trap cleanup EXIT
 
# Explicit error messages
die() {
  echo "ERROR: $*" >&2
  exit 1
}
 
# Check required tools
require() {
  command -v "$1" >/dev/null 2>&1 || die "Required tool not found: $1"
}
```
 
### Argument parsing
For simple scripts use positional args with validation:
```bash
[[ $# -lt 1 ]] && die "Usage: $(basename "$0") <arg1> [arg2]"
ARG1="${1:?'arg1 is required'}"
```
 
For complex scripts use `getopts`:
```bash
while getopts ":f:o:vh" opt; do
  case $opt in
    f) INPUT_FILE="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    v) VERBOSE=true ;;
    h) usage; exit 0 ;;
    :) die "Option -$OPTARG requires an argument" ;;
    \?) die "Unknown option: -$OPTARG" ;;
  esac
done
shift $((OPTIND - 1))
```
 
### Logging
```bash
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[WARN]  $*" >&2; }
err()  { echo "[ERROR] $*" >&2; }
```
 
---
 
## Phase 3: Context-Specific Patterns
 
### CI/CD (GitHub Actions / GitLab / Bitrise)
 
```bash
# GitHub Actions: set outputs
echo "version=${VERSION}" >> "$GITHUB_OUTPUT"
 
# GitHub Actions: add to PATH
echo "${HOME}/.local/bin" >> "$GITHUB_PATH"
 
# GitHub Actions: group log output
echo "::group::Build step"
# ... commands ...
echo "::endgroup::"
 
# GitHub Actions: mask secrets in logs
echo "::add-mask::${SECRET_VALUE}"
 
# GitLab CI: section folding
echo -e "section_start:$(date +%s):build\r\e[0KBuilding..."
# ... commands ...
echo -e "section_end:$(date +%s):build\r\e[0K"
```
 
**CI script checklist:**
- Never hardcode secrets — use env vars
- Always set `set -euo pipefail`
- Exit with explicit codes for downstream steps
- Log versions of critical tools at start (`xcodebuild -version`, `ruby --version`, etc.)
- Use `|| true` consciously, never reflexively
 
### File & data processing
 
```bash
# Safe temp files
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT
 
# Process files safely (handles spaces in names)
while IFS= read -r -d '' file; do
  process "$file"
done < <(find . -name "*.txt" -print0)
 
# Read file line by line
while IFS= read -r line; do
  echo "$line"
done < input.txt
 
# Check file/dir existence
[[ -f "$file" ]] || die "File not found: $file"
[[ -d "$dir" ]]  || mkdir -p "$dir"
```
 
### macOS-specific
 
```bash
# Detect macOS
[[ "$(uname)" == "Darwin" ]] || die "macOS only"
 
# Use gdate/gsed if GNU tools needed (via brew coreutils)
require gdate
 
# macOS temp dir
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/myscript.XXXXXX")
```
 
### Retry logic (useful in CI)
```bash
retry() {
  local max_attempts=${MAX_RETRIES:-3}
  local delay=${RETRY_DELAY:-5}
  local attempt=1
  until "$@"; do
    if (( attempt >= max_attempts )); then
      err "Command failed after $attempt attempts: $*"
      return 1
    fi
    warn "Attempt $attempt failed. Retrying in ${delay}s..."
    sleep "$delay"
    (( attempt++ ))
  done
}
 
# Usage
retry curl -f "https://example.com/api"
```
 
---
 
## Phase 4: Review Checklist
 
When reviewing an existing script, check in order:
 
1. **Safety** — shebang + `set -euo pipefail` present?
2. **Quoting** — all `$vars` quoted? `"$@"` not `$@`?
3. **Uninitialized vars** — any variable used before being set?
4. **Pipe failures** — `cmd1 | cmd2` — does failure in `cmd1` propagate?
5. **Temp file leaks** — cleanup on EXIT trapped?
6. **Hardcoded values** — paths, credentials, env-specific strings?
7. **Exit codes** — does the script exit non-zero on failure?
8. **Error messages** — do errors go to stderr (`>&2`)?
9. **Idempotency** — what happens on second run?
10. **Shellcheck** — mentally apply common shellcheck rules (SC2086, SC2046, SC2006)
 
---
 
## Phase 5: Output Format
 
**For new scripts**: Write the complete script, then add a brief section:
- What it does
- How to run it (`chmod +x script.sh && ./script.sh <args>`)
- Key assumptions / dependencies
 
**For reviews**: List issues by severity (🔴 Critical / 🟡 Warning / 🟢 Suggestion), then provide corrected version.
 
**For debugging**: State the root cause first, then the fix. Don't just swap code — explain why.
 
---
 
## Common Pitfalls Reference
 
See `references/pitfalls.md` for an expanded list of bash gotchas with examples.
See `references/ci-patterns.md` for CI/CD-specific snippets (Bitrise, GitHub Actions, GitLab).