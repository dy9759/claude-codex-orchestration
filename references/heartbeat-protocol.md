# Heartbeat & Fallback Protocol

## Problem

Cross-agent dispatch has no visibility into execution status. Failure modes:
- Subagent silent failure (process crash, sandbox limit)
- Task disappears (session timeout, context overflow)
- No progress (infinite loop, blocked on input)

Without heartbeat, orchestrator waits indefinitely or assumes success blindly.

---

## Architecture

```
+---------------+    dispatch     +----------------+
| Orchestrator  | -------------> | Dispatch Agent  |
|  (runtime)    |                |  (CC/Codex)     |
|               | <-- heartbeat  |                 |
|               |    (periodic)  |                 |
+---------------+                +----------------+
```

Heartbeat is **orchestrator-driven** (pull model). Orchestrator checks dispatch status periodically — dispatch agent writes no special heartbeat signal.

---

## Three-Level Detection

| Level | Interval | Check Method | Applies to |
|-------|----------|-------------|------------|
| L1: Process alive | 30s | `kill -0 <pid>` or `ps -p <pid>` | All dispatches |
| L2: Progress check | 2min | Output file mtime / stdout byte count delta | Background dispatches |
| L3: Semantic probe | 5min | Read partial output, judge meaningful progress | Long dispatches (>10min) |

### L1 — Process Alive

```bash
heartbeat_l1() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null && echo "ALIVE" || echo "DEAD"
}
```

Cheapest check. Runs every 30s. Catches crashes and OOM kills.

### L2 — Progress Check

```bash
heartbeat_l2() {
  local output_file="$1" last_bytes="$2"
  local current_bytes
  current_bytes=$(wc -c < "$output_file" 2>/dev/null || echo 0)

  if [ "$current_bytes" -gt "$last_bytes" ]; then
    echo "PROGRESSING:$current_bytes"
  else
    echo "STALLED:$current_bytes"
  fi
}
```

Checks output file growth. If no new bytes in 2 intervals (4min), escalates to STALLED.

### L3 — Semantic Probe

Only for dispatches running >10min. Read last 50 lines of output, check for:
- Error patterns (`error`, `fatal`, `panic`, `traceback`)
- Repetition (same line repeated 10+ times → stuck loop)
- Meaningful content (new file paths, test results, code changes)

Implemented by orchestrator reading output file tail — no dispatch agent cooperation needed.

---

## Heartbeat State Machine

```
DISPATCHED --> ALIVE --> PROGRESSING --> COMPLETED
                 |           |
              STALLED --> TIMEOUT --> FALLBACK
                 |
               DEAD ----> FALLBACK
```

| State | Meaning | Transition |
|-------|---------|-----------|
| **DISPATCHED** | Task sent, PID recorded | → ALIVE on first L1 success |
| **ALIVE** | Process exists, progress unknown | → PROGRESSING on L2 byte increase |
| **PROGRESSING** | Output growing, work happening | → COMPLETED when process exits 0 |
| **STALLED** | Process exists but >2 intervals no output | → TIMEOUT after stall_limit |
| **DEAD** | Process gone (crash/kill/OOM) | → FALLBACK immediately |
| **TIMEOUT** | Exceeded 2x estimated time or stall_limit | → FALLBACK |
| **COMPLETED** | Process exited 0, output available | Terminal state |
| **FALLBACK** | Orchestrator takes over | Terminal state |

---

## Dispatch with Heartbeat (Executable Contract)

```bash
.codex/orchestration/bin/dispatch-with-heartbeat.sh \
  "$TASK_ID" "${TIMEOUT_S:-1800}" -- \
  claude -p "$PROMPT" --output-format json --max-budget-usd "${BUDGET:-5}"
```

Use the repo-local helper before Codex install:

```bash
./scripts/dispatch-with-heartbeat.sh "$TASK_ID" 600 -- codex exec "$PROMPT"
```

The helper accepts the command as argv after `--`; never pass a shell string and never use `eval`. It validates `task_id`, captures output to `.tasks/<task-id>.output`, and writes state to `.tasks/<task-id>.heartbeat.json`.

Implemented by the helper:
- L1 process-alive check (`kill -0`)
- L2 output-byte progress check
- timeout kill + exit `124`
- final statuses `COMPLETED`, `DEAD`, or `TIMEOUT`

L3 semantic probe is an orchestrator responsibility: read `.tasks/<task-id>.output` during a long run and judge whether the partial output is meaningful. Do not claim L3 happened unless that inspection actually ran.

---

## Fallback Mechanism (Three-Level Strategy)

| Condition | Action |
|-----------|--------|
| **STALLED >5min** | Send SIGINT → wait 30s → if resumes, continue |
| **STALLED >10min** | Kill process → orchestrator self-executes task (capability degradation, no data loss) |
| **DEAD** | Read partial output → assess progress → resume from checkpoint or re-execute |
| **TIMEOUT (>2x estimate)** | Kill → split into smaller subtasks → re-route via capability matrix |
| **3 consecutive dispatch failures** | Pause cross-agent dispatch → all remaining tasks self-executed → log to `.error-log.jsonl` |

### Fallback Decision Tree

```
heartbeat_fallback(status, task):

  if status == DEAD:
    output = read_partial_output(task)
    if output.has_meaningful_progress:
      resume_from_output(task, output)   # continue from last good state
    else:
      reexecute_locally(task)            # start over locally

  if status == STALLED:
    send_signal(task.pid, SIGINT)
    wait(30s)
    if heartbeat_check(task) == PROGRESSING:
      return                              # recovered, continue
    kill(task.pid, SIGKILL)
    reexecute_locally(task)

  if status == TIMEOUT:
    kill(task.pid, SIGKILL)
    subtasks = split_task(task)
    for st in subtasks:
      route(st)                           # re-route via capability matrix

  # Log all fallback events
  log_fallback(task, status, action_taken)
```

### Fallback Logging

Every fallback event appends to `.error-log.jsonl`:

```json
{
  "date": "YYYY-MM-DD",
  "category": "heartbeat-fallback",
  "task_id": "N",
  "original_agent": "codex|cc",
  "heartbeat_status": "DEAD|STALLED|TIMEOUT",
  "stall_count": N,
  "elapsed_s": N,
  "output_bytes": N,
  "fallback_action": "resume|reexecute|split",
  "outcome": "success|failed"
}
```

---

## Task Board Extension

Existing `.tasks/*.json` schema extended with `dispatch` block:

```json
{
  "id": 1,
  "subject": "implement login UI",
  "scope": "src/ui/auth/",
  "status": "in_progress",
  "owner": "codex",
  "dispatch": {
    "pid": 12345,
    "started_at": "2026-04-22T10:00:00Z",
    "timeout_s": 1800,
    "heartbeat": {
      "last_check": "2026-04-22T10:05:00Z",
      "status": "PROGRESSING",
      "stall_count": 0,
      "output_bytes": 4096
    }
  }
}
```

**Backward compatible:** tasks without `dispatch` block work as before. Heartbeat only activates when `dispatch` block present.

---

## Default Timeouts

| Task Profile | Default Timeout | Stall Limit |
|-------------|----------------|-------------|
| Foreground bounded (<100 lines) | 10min | 3 intervals (6min) |
| Foreground medium (100-500 lines) | 20min | 5 intervals (10min) |
| Background complex | 30min | 8 intervals (16min) |
| Review (read-only) | 5min | 2 intervals (4min) |

Override per-task in dispatch: `dispatch-with-heartbeat.sh "$task_id" 3600 -- <command> [args...]` for 1-hour timeout.

---

## Integration Points

- **`workflow-core.md`** — background dispatches launch through the heartbeat helper
- **`codex-protocol.md`** — background Codex dispatches must use the helper; foreground tasks use portable timeout
- **`codex-runtime.md`** — CC dispatch from Codex launches `claude -p` through `.codex/orchestration/bin/dispatch-with-heartbeat.sh`
- **`cross-harness.md`** — installed Codex bundles copy `dispatch-with-heartbeat.sh` into `.codex/orchestration/bin/`
