# CI/CD Bash Patterns

## GitHub Actions

### Script structure for a step

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "::group::Setup"
# ... setup commands ...
echo "::endgroup::"

echo "::group::Build"
# ... build ...
echo "::endgroup::"
```

### Pass data between steps

```bash
# Set output
echo "artifact_path=${OUTPUT_PATH}" >> "$GITHUB_OUTPUT"
echo "build_number=${BUILD_NUM}" >> "$GITHUB_OUTPUT"

# Set env var for subsequent steps
echo "MY_VAR=value" >> "$GITHUB_ENV"
```

### Annotate errors in source

```bash
# Will show inline annotation in PR
echo "::error file=src/main.swift,line=42::Missing return statement"
echo "::warning file=Podfile,line=10::Deprecated pod version"
```

### Conditional logic based on event

```bash
if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
  echo "Running PR checks..."
elif [[ "$GITHUB_REF" == refs/tags/* ]]; then
  TAG="${GITHUB_REF#refs/tags/}"
  echo "Building tag: $TAG"
fi
```

---

## GitLab CI

### Script structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# Section folding in logs
section_start() {
  echo -e "section_start:$(date +%s):${1}\r\e[0K${2:-$1}"
}
section_end() {
  echo -e "section_end:$(date +%s):${1}\r\e[0K"
}

section_start "build" "Building project..."
# ... build ...
section_end "build"
```

### Set dotenv artifact (pass vars between jobs)

```bash
echo "VERSION=${VERSION}" > build.env
echo "ARTIFACT_URL=${URL}" >> build.env
# In .gitlab-ci.yml: artifacts: reports: dotenv: build.env
```

---

## Bitrise

### Log formatting

```bash
# Bitrise reads these for step summary
echo "+-----------------------------------------------------------+"
echo "| Step: My Script                                           |"
echo "+-----------------------------------------------------------+"

# Error format Bitrise picks up
echo "error: Something went wrong"   # surfaces in UI
```

### envman — set env vars for subsequent steps

```bash
envman add --key MY_OUTPUT --value "${VALUE}"
envman add --key BUILD_PATH --value "${BUILD_DIR}"
```

### Common Bitrise env vars

```bash
BITRISE_SOURCE_DIR      # repo root
BITRISE_DEPLOY_DIR      # artifacts output dir
BITRISE_BUILD_NUMBER    # current build number
BITRISE_GIT_BRANCH      # current branch
BITRISE_PULL_REQUEST_ID # PR number (if PR build)
BITRISE_APP_SLUG        # app identifier
```

### Safe artifact copy

```bash
copy_artifact() {
  local src="$1"
  local dest="${BITRISE_DEPLOY_DIR}/$(basename "$src")"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
    echo "Artifact: $dest"
  else
    echo "warning: Artifact not found: $src" >&2
  fi
}
```

---

## Generic CI patterns

### Version bumping

```bash
bump_version() {
  local file="$1"
  local current
  current=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$file" | head -1)
  local major minor patch
  IFS='.' read -r major minor patch <<< "$current"
  echo "${major}.${minor}.$((patch + 1))"
}
```

### Wait for service readiness

```bash
wait_for_port() {
  local host="$1" port="$2" timeout="${3:-30}"
  local start
  start=$(date +%s)
  until nc -z "$host" "$port" 2>/dev/null; do
    if (( $(date +%s) - start > timeout )); then
      die "Timeout waiting for $host:$port"
    fi
    sleep 1
  done
  echo "Service ready: $host:$port"
}
```

### Slack notification on failure

```bash
notify_slack() {
  local message="$1"
  local webhook="${SLACK_WEBHOOK_URL:?'SLACK_WEBHOOK_URL not set'}"
  curl -s -X POST "$webhook" \
    -H 'Content-type: application/json' \
    --data "{\"text\": \"${message}\"}" \
    >/dev/null
}

# Usage in trap
on_failure() {
  notify_slack "❌ Build failed: ${GITHUB_WORKFLOW:-$(basename "$0")} on branch ${GITHUB_REF_NAME:-unknown}"
}
trap on_failure ERR
```

### Detect if running in CI

```bash
in_ci() {
  [[ -n "${CI:-}" ]] || [[ -n "${CONTINUOUS_INTEGRATION:-}" ]]
}

if in_ci; then
  # headless / non-interactive behavior
  export FASTLANE_SKIP_UPDATE_CHECK=1
fi
```
