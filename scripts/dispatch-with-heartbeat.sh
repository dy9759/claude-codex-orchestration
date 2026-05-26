#!/usr/bin/env bash
# Run a command under .tasks/ heartbeat monitoring without eval.
#
# Usage:
#   dispatch-with-heartbeat.sh <task-id> <timeout-seconds> -- <command> [args...]
#
# Environment:
#   ORCH_TASKS_DIR          Directory for heartbeat/output files (default: .tasks)
#   HEARTBEAT_INTERVAL_S    Poll interval in seconds (default: 30)

set -euo pipefail
set +m

usage() {
  echo "usage: $0 <task-id> <timeout-seconds> -- <command> [args...]" >&2
}

if [ "$#" -lt 4 ]; then
  usage
  exit 2
fi

task_id="$1"
timeout_s="$2"
shift 2

if [ "${1:-}" != "--" ]; then
  usage
  exit 2
fi
shift

case "$task_id" in
  ''|*[!A-Za-z0-9._-]*)
    echo "task-id may contain only letters, numbers, dot, underscore, and dash: $task_id" >&2
    exit 2
    ;;
esac

case "$timeout_s" in
  ''|*[!0-9]*)
    echo "timeout must be an integer number of seconds: $timeout_s" >&2
    exit 2
    ;;
esac

interval_s="${HEARTBEAT_INTERVAL_S:-30}"
case "$interval_s" in
  ''|*[!0-9]*|0)
    echo "HEARTBEAT_INTERVAL_S must be a positive integer: $interval_s" >&2
    exit 2
    ;;
esac

tasks_dir="${ORCH_TASKS_DIR:-.tasks}"
mkdir -p "$tasks_dir"

output_file="$tasks_dir/$task_id.output"
meta_file="$tasks_dir/$task_id.heartbeat.json"

byte_count() {
  local bytes
  bytes="$(wc -c < "$output_file" 2>/dev/null || echo 0)"
  bytes="${bytes//[!0-9]/}"
  printf '%s\n' "${bytes:-0}"
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

write_meta() {
  local status="$1" stall_count="$2" last_bytes="$3" exit_code="${4:-null}"
  local now tmp
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp "$tasks_dir/.heartbeat.XXXXXX")"
  cat > "$tmp" <<EOF
{
  "task_id": "$(json_escape "$task_id")",
  "pid": $pid,
  "started_at": "$(json_escape "$started_at")",
  "last_check": "$(json_escape "$now")",
  "timeout_s": $timeout_s,
  "status": "$(json_escape "$status")",
  "stall_count": $stall_count,
  "last_bytes": $last_bytes,
  "output_file": "$(json_escape "$output_file")",
  "exit_code": $exit_code
}
EOF
  mv "$tmp" "$meta_file"
}

terminate_child() {
  kill "$pid" 2>/dev/null || true
  sleep 2
  kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
}

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_epoch="$(date +%s)"

"$@" > "$output_file" 2>&1 &
pid="$!"

last_bytes=0
stall_count=0
write_meta "DISPATCHED" "$stall_count" "$last_bytes"

while kill -0 "$pid" 2>/dev/null; do
  current_bytes="$(byte_count)"
  if [ "$current_bytes" -gt "$last_bytes" ]; then
    stall_count=0
    last_bytes="$current_bytes"
    write_meta "PROGRESSING" "$stall_count" "$last_bytes"
  else
    stall_count=$((stall_count + 1))
    write_meta "STALLED" "$stall_count" "$last_bytes"
  fi

  now_epoch="$(date +%s)"
  if [ $((now_epoch - start_epoch)) -ge "$timeout_s" ]; then
    terminate_child
    set +e
    wait "$pid" 2>/dev/null
    set -e
    current_bytes="$(byte_count)"
    write_meta "TIMEOUT" "$stall_count" "$current_bytes" 124
    exit 124
  fi

  sleep "$interval_s"
done

set +e
wait "$pid" 2>/dev/null
exit_code="$?"
set -e

current_bytes="$(byte_count)"
if [ "$exit_code" -eq 0 ]; then
  write_meta "COMPLETED" 0 "$current_bytes" "$exit_code"
else
  write_meta "DEAD" "$stall_count" "$current_bytes" "$exit_code"
fi

exit "$exit_code"
