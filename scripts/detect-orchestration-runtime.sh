#!/usr/bin/env bash
# Detect the active orchestration runtime and dispatchable peer agents.
#
# Usage:
#   detect-orchestration-runtime.sh summary
#   detect-orchestration-runtime.sh runtime
#   detect-orchestration-runtime.sh agents [runtime]
#   detect-orchestration-runtime.sh route <task-type> [runtime] [available-agents]

set -euo pipefail

add_word() {
  local list="$1" word="$2"
  case " $list " in
    *" $word "*) printf '%s\n' "$list" ;;
    *) printf '%s\n' "${list:+$list }$word" ;;
  esac
}

has_word() {
  local word="$1" list="$2"
  case " $list " in
    *" $word "*) return 0 ;;
    *) return 1 ;;
  esac
}

cli_ok() {
  local cmd="$1"
  local script_dir timeout_helper
  command -v "$cmd" >/dev/null 2>&1 || return 1
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  timeout_helper="$script_dir/run-with-timeout.sh"
  if [ -x "$timeout_helper" ]; then
    "$timeout_helper" 3 "$cmd" --version >/dev/null 2>&1 || return 1
  else
    "$cmd" --version >/dev/null 2>&1 || return 1
  fi
}

detect_harness() {
  if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_SESSION:-}" ]; then
    echo "claude-code"; return
  fi
  if [ -n "${CODEX_SESSION_ID:-}" ] || [ -n "${CODEX_THREAD_ID:-}" ] || \
     [ -n "${CODEX_CI:-}" ] || [ -n "${CODEX_SHELL:-}" ]; then
    echo "codex"; return
  fi
  if [ -n "${CURSOR_AGENT:-}" ]; then
    echo "cursor"; return
  fi
  if [ -n "${OPENCODE_SESSION:-}" ]; then
    echo "opencode"; return
  fi

  if [ -f .cursorrules ] || [ -d .cursor ]; then
    echo "cursor"; return
  fi
  if [ -f .opencode/opencode.json ]; then
    echo "opencode"; return
  fi
  if command -v codex >/dev/null 2>&1; then
    echo "codex"; return
  fi
  if [ -d "$HOME/.claude/skills" ]; then
    echo "claude-code"; return
  fi

  echo "unknown"
}

runtime_agent() {
  case "$1" in
    claude-code) echo "cc" ;;
    codex) echo "codex" ;;
    *) echo "$1" ;;
  esac
}

gemini_configured() {
  grep -q "gemini-cli" "$HOME/.claude/settings.json" 2>/dev/null && return 0
  grep -q "gemini-cli" ".claude/settings.json" 2>/dev/null && return 0
  return 1
}

detect_available_agents() {
  local runtime="${1:-$(detect_harness)}"
  local agents=""

  case "$runtime" in
    claude-code) agents="$(add_word "$agents" "cc")" ;;
    codex) agents="$(add_word "$agents" "codex")" ;;
  esac

  if cli_ok claude; then
    agents="$(add_word "$agents" "cc")"
  fi
  if cli_ok codex; then
    agents="$(add_word "$agents" "codex")"
  fi

  if gemini_configured; then
    if [ "$runtime" = "claude-code" ]; then
      agents="$(add_word "$agents" "gemini")"
    elif has_word "cc" "$agents"; then
      agents="$(add_word "$agents" "gemini-via-cc")"
    fi
  fi

  echo "$agents"
}

is_high_risk_task() {
  case "$1" in
    migrations|database|db|cicd|ci|release|secrets|env|package-manifest|package|destructive-git|destructive-file|destructive)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

resolve_routing() {
  local task_type="$1"
  local runtime="${2:-$(detect_harness)}"
  local available="${3:-$(detect_available_agents "$runtime")}"
  local runtime_agent_name preferred fallback

  runtime_agent_name="$(runtime_agent "$runtime")"

  if is_high_risk_task "$task_type"; then
    echo "local:$runtime:requires-explicit-approval"
    return
  fi

  case "$task_type" in
    architecture|planning|frontend|cross-cutting)
      preferred="cc"; fallback="self" ;;
    integration|merge)
      preferred="self"; fallback="" ;;
    bounded-backend|isolated-script|parallel-impl|code-review|isolated-fix|bug-fix|detail-change|maintenance-fix|existing-detail)
      preferred="codex"; fallback="cc" ;;
    ui-design-judgment|ui-design|design-review|a11y-review)
      preferred="gemini"; fallback="cc" ;;
    *)
      preferred="self"; fallback="" ;;
  esac

  if [ "$preferred" = "gemini" ]; then
    if [ "$runtime" = "claude-code" ] && has_word "gemini" "$available"; then
      echo "consult:gemini"
      return
    fi
    if has_word "gemini-via-cc" "$available"; then
      echo "dispatch:cc:gemini-relay"
      return
    fi
  fi

  if [ "$preferred" = "self" ] || [ "$preferred" = "$runtime_agent_name" ]; then
    echo "local:$runtime"
    return
  fi

  if has_word "$preferred" "$available"; then
    echo "dispatch:$preferred"
    return
  fi

  if [ "$fallback" = "self" ] || [ "$fallback" = "$runtime_agent_name" ]; then
    echo "local:$runtime"
    return
  fi

  if [ -n "$fallback" ] && has_word "$fallback" "$available"; then
    echo "dispatch:$fallback"
    return
  fi

  echo "local:$runtime:degraded"
}

command_name="${1:-summary}"
case "$command_name" in
  runtime)
    detect_harness
    ;;
  agents)
    detect_available_agents "${2:-$(detect_harness)}"
    ;;
  route)
    if [ $# -lt 2 ]; then
      echo "usage: $0 route <task-type> [runtime] [available-agents]" >&2
      exit 2
    fi
    if [ $# -ge 4 ]; then
      resolve_routing "$2" "$3" "$4"
    else
      resolve_routing "$2" "${3:-$(detect_harness)}"
    fi
    ;;
  summary)
    runtime="$(detect_harness)"
    agents="$(detect_available_agents "$runtime")"
    echo "runtime=$runtime"
    echo "available_agents=$agents"
    ;;
  *)
    echo "usage: $0 [summary|runtime|agents|route]" >&2
    exit 2
    ;;
esac
