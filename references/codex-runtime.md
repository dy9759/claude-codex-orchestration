# Codex as Orchestrator — CC Dispatch Protocol

When Codex is the runtime (detected via `$CODEX_SESSION_ID`, `$CODEX_THREAD_ID`, `$CODEX_CI`, or `$CODEX_SHELL`), it acts as orchestrator. This document mirrors `codex-protocol.md` for the reverse direction: Codex dispatching to CC.

---

## CC Dispatch Template

```bash
# Standard dispatch
claude -p "<prompt>" --output-format json --max-budget-usd N

# Background dispatch with executable heartbeat + output capture
.codex/orchestration/bin/dispatch-with-heartbeat.sh \
  "$TASK_ID" "${TIMEOUT_S:-600}" -- \
  claude -p "<prompt>" \
  --output-format json --max-budget-usd "${BUDGET:-5}"

# Foreground timeout-only dispatch
.codex/orchestration/bin/run-with-timeout.sh "${TIMEOUT_S:-600}" \
  claude -p "<prompt>" \
  --output-format json --max-budget-usd "${BUDGET:-5}"
```

Use `.codex/orchestration/bin/dispatch-with-heartbeat.sh` for background dispatches and `.codex/orchestration/bin/run-with-timeout.sh` for foreground timeout-only dispatches. The timeout wrapper avoids assuming GNU `timeout`; macOS does not ship GNU coreutils by default. It delegates to `timeout`/`gtimeout` when present and otherwise uses a POSIX-ish shell fallback.

For runtime and peer-agent detection, use:

```bash
.codex/orchestration/bin/detect-orchestration-runtime.sh summary
.codex/orchestration/bin/detect-orchestration-runtime.sh health
.codex/orchestration/bin/detect-orchestration-runtime.sh route frontend
```

If `claude` is missing, unauthenticated, or times out, Codex keeps execution local or asks the user according to `runtime-routing.md` rather than pretending CC was consulted. `available_agents` is based on version + auth health, not binary presence alone.

### Prompt Format (Natural Language — CC Processes NL Better Than XML)

```
Task: [concrete job description + explicit done-state]
Scope: [file paths this task touches]
Off-limits: [paths CC must not modify]
Context: [relevant background — keep under 100 words]
Test Plan: [command + expected failure signal]
Output: [expected deliverables — files changed, test results, test-quality review]
```

### Budget Guidelines

| Task Profile | Budget | Timeout |
|-------------|--------|---------|
| Simple bounded (<50 lines) | $2 | 5min |
| Medium module (50-200 lines) | $5 | 10min |
| Complex cross-file (200+ lines) | $10 | 20min |
| Architecture/planning (read-heavy) | $5 | 15min |
| Hard cap per single dispatch | $20 | 30min |

---

## Codex-Native Plan Format

When Codex is orchestrator, Plan format adapts to `workflow-core.md` using runtime-agnostic labels:

```
### Plan

[Self] Task A — files: src/backend/... (Codex executes locally)
[Dispatch:CC] Task B — files: src/ui/... (CC does frontend)
[Dispatch:CC] Task C — architecture analysis (CC does repo-wide reasoning)

Self owns: bounded backend modules, scripts, isolated fixes
CC owns: frontend, cross-cutting, architecture review, integration support
High-risk ops: current orchestrator owns after explicit approval

Test Plan: [command + expected failure signal]
```

**Resolution:** `[Self]` = Codex local. `[Dispatch:CC]` = invoke `claude -p`. Routing resolved by `resolve_routing()` from `cross-harness.md`.

---

## Sub-skill Compatibility (Codex Runtime)

Codex does not register slash commands. After `sub-skills/install-codex.sh`, AGENTS.md maps each `/co-*` token to a natural-language workflow under `.codex/orchestration/commands/`.

| Sub-skill | Works in Codex | Adaptation |
|-----------|:-:|----------|
| `/co-think` | Yes | Pure reasoning, no CC dependency |
| `/co-plan-review` | Yes | Pure reasoning, no CC dependency |
| `/co-eval` | Yes | Writes JSONL, no CC dependency |
| `/co-score` | Yes | Reads git diff + writes JSONL |
| `/co-compound` | Partial | 4 parallel subagents → sequential execution (no Agent tool in Codex) |
| `/co-sessions` | Partial | Agent tool → direct shell search of `~/.claude/projects/` + `~/.codex/sessions/` |
| `/co-review` | Yes | Reads JSONL, no CC dependency |
| `/co-promote` | Yes | Writes SKILL.md + git commit |
| `/co-loop` | Degraded | ScheduleWakeup CC-only → single-execution mode (no auto-repeat) |

### co-compound in Codex

Replace 4 parallel Agent dispatches with sequential shell operations:

```bash
# Instead of 4 subagents, run sequentially:
# 1. Context analysis (inline reasoning)
# 2. Solution extraction (inline reasoning)
# 3. Related docs search (grep docs/solutions/)
# 4. Session history search (grep ~/.claude/projects/ + ~/.codex/sessions/)
```

Output format unchanged — same `docs/solutions/[category]/[slug]-[date].md` with YAML frontmatter.

### co-sessions in Codex

Replace Agent tool dispatch with direct search:

```bash
# Direct search instead of subagent
grep -rl "<problem keywords>" ~/.claude/projects/ ~/.codex/sessions/ 2>/dev/null \
  | head -20 \
  | while read f; do
      echo "=== $f ==="
      head -50 "$f"
    done
```

### co-loop in Codex

`ScheduleWakeup` is CC-specific (plugin API). In Codex:
- Run eval → review → promote cycle **once**
- Log completion: `"[co-loop] Single execution complete. Re-run manually for next cycle."`
- No auto-scheduling — user must re-invoke

---

## CC Dispatch Quality Tracking

Mirror of `.codex-quality.jsonl` for CC dispatches:

**File:** `.cc-quality.jsonl`

```json
{
  "date": "YYYY-MM-DD",
  "task_id": "N",
  "spec_words": N,
  "status": "success|rejected|wandered",
  "latency_ms": N,
  "budget_usd": N,
  "error_category": "dispatch|conflict|integration|scope-creep|none",
  "consecutive_failures": N
}
```

**Same thresholds as Codex quality tracking:**
- Success rate ≥ 70% → healthy
- Success rate 40-70% → tighten prompts
- Success rate < 40% → penalize (halve scope, require explicit file list)
- 3+ consecutive failures → hard stop, diagnose before resuming

---

## High-Risk Task Strategy (Unified)

Same blocked patterns as `codex-protocol.md` §Dispatch Security Gate apply in Codex runtime, but the ownership language changes from "assign to CC" to "keep with the current orchestrator unless the user explicitly routes it elsewhere."

- DB migrations, env/secrets, package manifests, CI/CD/release, destructive file/git operations → no automatic cross-agent dispatch
- The current orchestrator writes a plan, risk list, rollback/Test Plan step, and asks for explicit approval
- CC may be used for read-only review or planning if available
- Implementation happens locally only after approval, unless the user explicitly says to route it to CC

This preserves the Claude Code path: when CC is runtime, CC remains the local orchestrator for these tasks. In Codex runtime, Codex does not become "Codex-first" for high-risk work; it becomes the accountable orchestrator and must pause for approval.

---

## Gemini Access from Codex Runtime

Codex cannot reach `mcp__gemini-cli__*` directly. Two options:

1. **CC relay** — dispatch to CC with explicit Gemini consultation request (see `runtime-routing.md` §Gemini Relay)
2. **Skip** — if Gemini consultation is optional and CC is unavailable, proceed without. Log `category: gemini-unavailable` to `.error-log.jsonl`

Never block on Gemini availability from Codex runtime.
