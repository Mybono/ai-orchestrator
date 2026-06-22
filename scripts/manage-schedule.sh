#!/usr/bin/env bash
# Scheduler manager for ai-orchestrator LaunchAgents (macOS).
# Usage: bash scripts/manage-schedule.sh <command> [job-name]
#
# Commands:
#   install          — create & load all jobs
#   uninstall        — unload & remove all jobs
#   list             — show all jobs + status
#   run <job>        — run a job immediately (foreground)
#   logs <job>       — tail the log for a job
#
# To add a new job: append a line to JOBS below, then re-run install.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="/tmp/ai-orchestrator-schedule"
LABEL_PREFIX="com.ai-orchestrator"

# ─── Job definitions ──────────────────────────────────────────────────────────
# Format: "name|hour|minute|script-path-relative-to-repo"
# hour/minute: when to run daily (local time). Use "*" for minute to mean :00.
# ─────────────────────────────────────────────────────────────────────────────
JOBS=(
  "research-oss|9|0|scripts/research-oss.sh"
  # Add new jobs here, e.g.:
  # "daily-digest|18|30|scripts/daily-digest.sh"
)

# ─── Helpers ──────────────────────────────────────────────────────────────────

plist_path() { echo "$LAUNCHAGENTS_DIR/${LABEL_PREFIX}.$1.plist"; }
log_path()   { echo "$LOG_DIR/$1.log"; }

job_label()  { echo "${LABEL_PREFIX}.$1"; }

make_plist() {
  local name="$1" hour="$2" minute="$3" script="$4"
  local label; label=$(job_label "$name")
  local log;   log=$(log_path "$name")
  mkdir -p "$LOG_DIR"
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$REPO_DIR/$script</string>
  </array>
  <key>WorkingDirectory</key>  <string>$REPO_DIR</string>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>            <integer>$hour</integer>
    <key>Minute</key>          <integer>$minute</integer>
  </dict>
  <key>StandardOutPath</key>   <string>$log</string>
  <key>StandardErrorPath</key> <string>$log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
</dict>
</plist>
EOF
}

is_loaded() {
  launchctl list "$(job_label "$1")" &>/dev/null
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_install() {
  mkdir -p "$LAUNCHAGENTS_DIR" "$LOG_DIR"
  for job in "${JOBS[@]}"; do
    IFS='|' read -r name hour minute script <<< "$job"
    plist=$(plist_path "$name")
    make_plist "$name" "$hour" "$minute" "$script" > "$plist"
    # Unload first if already loaded (reload on re-install)
    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist"
    echo "✓ installed: $name  (daily at ${hour}:$(printf '%02d' "$minute"), wake-on-miss)"
    echo "  plist: $plist"
    echo "  log:   $(log_path "$name")"
  done
}

cmd_uninstall() {
  for job in "${JOBS[@]}"; do
    IFS='|' read -r name hour minute script <<< "$job"
    plist=$(plist_path "$name")
    if [ -f "$plist" ]; then
      launchctl unload "$plist" 2>/dev/null || true
      rm "$plist"
      echo "✓ removed: $name"
    else
      echo "  skipped (not installed): $name"
    fi
  done
}

cmd_list() {
  printf '%-20s %-10s %-8s %s\n' "JOB" "STATUS" "TIME" "SCRIPT"
  printf '%-20s %-10s %-8s %s\n' "---" "------" "----" "------"
  for job in "${JOBS[@]}"; do
    IFS='|' read -r name hour minute script <<< "$job"
    if is_loaded "$name"; then
      status="loaded ✓"
    else
      status="not loaded"
    fi
    time=$(printf '%d:%02d' "$hour" "$minute")
    printf '%-20s %-10s %-8s %s\n' "$name" "$status" "$time" "$script"
  done
}

cmd_run() {
  local target="$1"
  for job in "${JOBS[@]}"; do
    IFS='|' read -r name hour minute script <<< "$job"
    if [ "$name" = "$target" ]; then
      echo "Running $name now..."
      bash "$REPO_DIR/$script"
      return 0
    fi
  done
  echo "Unknown job: $target" >&2
  exit 1
}

cmd_logs() {
  local target="$1"
  local log; log=$(log_path "$target")
  if [ -f "$log" ]; then
    tail -f "$log"
  else
    echo "No log yet: $log" >&2
    exit 1
  fi
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────

case "${1:-}" in
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
  list)      cmd_list ;;
  run)       cmd_run "${2:?Usage: run <job-name>}" ;;
  logs)      cmd_logs "${2:?Usage: logs <job-name>}" ;;
  *)
    echo "Usage: bash scripts/manage-schedule.sh <install|uninstall|list|run <job>|logs <job>>"
    exit 1 ;;
esac
