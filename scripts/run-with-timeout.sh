#!/usr/bin/env bash
# Portable timeout wrapper for macOS/Linux.
# Usage: run-with-timeout.sh <seconds> <command> [args...]

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <seconds> <command> [args...]" >&2
  exit 2
fi

timeout_s="$1"
shift

case "$timeout_s" in
  ''|*[!0-9]*)
    echo "timeout must be an integer number of seconds: $timeout_s" >&2
    exit 2
    ;;
esac

if command -v timeout >/dev/null 2>&1; then
  exec timeout "$timeout_s" "$@"
fi

if command -v gtimeout >/dev/null 2>&1; then
  exec gtimeout "$timeout_s" "$@"
fi

timed_out="$(mktemp)"
rm -f "$timed_out"

"$@" &
pid=$!

(
  sleep "$timeout_s"
  if kill -0 "$pid" 2>/dev/null; then
    touch "$timed_out"
    kill "$pid" 2>/dev/null || true
    sleep 2
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
  fi
) &
watchdog=$!

set +e
wait "$pid" 2>/dev/null
status=$?
set -e

kill "$watchdog" 2>/dev/null || true
wait "$watchdog" 2>/dev/null || true

if [ -f "$timed_out" ]; then
  rm -f "$timed_out"
  exit 124
fi

rm -f "$timed_out"
exit "$status"
