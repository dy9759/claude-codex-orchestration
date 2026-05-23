# Runtime-Agnostic Capability Routing

Core principle: **whoever is the runtime is the orchestrator, but task assignment always routes by capability matrix**.

CC and Codex are symmetric orchestrators. When CC is runtime, it orchestrates and dispatches to Codex. When Codex is runtime, it orchestrates and dispatches to CC. Task routing follows the same capability matrix regardless of who is orchestrating.

---

## Capability Matrix (Single Source of Truth)

| Task Type | Preferred | Fallback | Reasoning |
|-----------|-----------|----------|-----------|
| Architecture & planning | CC | Orchestrator self | CC repo-wide reasoning stronger |
| Frontend/UI | CC | Gemini consult → CC | CC (Sonnet 4.6+) component/state/CSS judgment strong |
| Cross-cutting refactors | CC | None (must be CC) | Needs repo-wide context |
| High-risk ops (migrations, CI/CD, release, secrets/env, package manifests, destructive git/file ops) | Orchestrator after explicit approval | CC read-only review | Safety-sensitive, never auto-dispatched |
| Integration & merge | Orchestrator | None | Needs both-sides context |
| Bounded backend modules | Codex | CC | Codex excels at isolated, testable modules |
| Isolated scripts | Codex | CC | Clear boundaries, verifiable output |
| Parallel candidate impls | Codex | CC subagent | Multi-attempt pattern |
| Code review (read-only) | Codex | CC subagent | Codex review capability strong |
| Isolated bug fixes | Codex | CC | Known scope, clear done-state |
| Existing-project detail changes | Codex | CC | Small scoped edits with local patterns and verifiable outcome |
| UI/UX design judgment | Gemini | CC | Aesthetics, a11y, CSS architecture |

**"Preferred" means the agent best suited — not the current runtime.** If preferred == runtime, execute locally. If preferred != runtime, dispatch to preferred agent.

### Codex-First Maintenance Bias

Default to Codex for maintenance work in an existing project when the orchestrator can name a narrow scope, off-limits paths, and a verification check.

Route these to Codex first:
- Bug fixes with a known failing behavior, stack trace, test failure, or reproduction path
- Detail changes to existing behavior, copy, validation, API shape, state handling, or small UI logic
- Targeted test fixes and small follow-up patches after review
- Existing-module edits that should preserve surrounding patterns rather than redesign them

Keep with CC instead when the task needs repo-wide architecture judgment, frontend visual/design judgment, broad cross-module refactoring, or when ownership cannot be made explicit. High-risk ops are a separate category: do not route them through the Codex-first maintenance bias or any automatic cross-agent dispatch. The current orchestrator must produce a plan, ask for explicit approval, and keep execution local unless the user explicitly routes it elsewhere.

---

## Routing Algorithm

```
route(task_type, runtime, available_agents):
  preferred = MATRIX[task_type].preferred
  fallback  = MATRIX[task_type].fallback

  # 1. Preferred agent is current runtime → do locally
  if preferred == runtime:
    return { action: "local", agent: runtime }

  # 2. Preferred agent available → dispatch
  if preferred in available_agents:
    return { action: "dispatch", agent: preferred }

  # 3. Fallback is current runtime → do locally
  if fallback == runtime:
    return { action: "local", agent: runtime }

  # 4. Fallback agent available → dispatch to fallback
  if fallback in available_agents:
    return { action: "dispatch", agent: fallback }

  # 5. Graceful degradation — runtime does it
  return { action: "local", agent: runtime, degraded: true }
```

**Degradation logging:** When step 5 triggers, log to `.error-log.jsonl` with `category: routing-degradation` so `/co-review` can track patterns.

**High-risk override:** before the algorithm above, if task_type is migrations/CI/release/secrets/env/package manifests/destructive git or file operations, return `local:<runtime>:requires-explicit-approval`. Never cross-dispatch these automatically.

---

## Cross-Agent Invocation Mechanisms (Symmetric Design)

| Direction | Mechanism | Mode |
|-----------|-----------|------|
| CC → Codex | `codex exec "<prompt>"` via `codex:codex-rescue` subagent | Existing, unchanged |
| Codex → CC | `claude -p "<prompt>" --output-format json --max-budget-usd N` | **New** |
| Any → Gemini | `mcp__gemini-cli__*` (only reachable from CC) | Codex routes via CC relay |

### CC → Codex (unchanged)

See `codex-protocol.md` for full invocation protocol: XML structured prompt, write mode, effort levels, security gate, quality tracking.

### Codex → CC (new)

When Codex is orchestrator and needs CC for a task:

```bash
# Basic dispatch
claude -p "<task prompt>" --output-format json --max-budget-usd 5

# With portable timeout wrapper (see codex-runtime.md)
.codex/orchestration/bin/run-with-timeout.sh 600 \
  claude -p "<task prompt>" --output-format json --max-budget-usd 5

# Save output for heartbeat monitoring
claude -p "<task prompt>" --output-format json --max-budget-usd 5 \
  > ".tasks/${task_id}.output" 2>&1
```

**CC dispatch prompt format** (mirrors Codex XML contract but in natural language — CC processes NL better):

```
Task: [concrete job + done-state]
Scope: [file paths]
Off-limits: [paths CC must not touch]
Verify: [test command or check]
Output: [expected deliverables]
Budget: $[N] max
```

**Budget guidelines:**
- Simple bounded task: `--max-budget-usd 2`
- Medium module work: `--max-budget-usd 5`
- Complex cross-file task: `--max-budget-usd 10`
- Never exceed `--max-budget-usd 20` per single dispatch

### Gemini Relay (Codex → CC → Gemini)

Codex cannot reach Gemini MCP directly. For UI/design consultation:
1. Codex dispatches to CC with explicit Gemini consultation request
2. CC invokes `mcp__gemini-cli__*`, gets response
3. CC returns Gemini advice in its output
4. Codex applies advice

Prompt template for relay:
```
Task: Consult Gemini on [UI/design question].
Ask Gemini: [specific question with context]
Return: Gemini's recommendation + your (CC) assessment of feasibility.
Budget: $2 max
```

---

## Runtime Detection Integration

Runtime detection happens at Phase 0 step 0 (see `workflow-core.md`). The routing table consults `detect_harness()` from `cross-harness.md` and `detect_available_agents()` to determine:

1. **Who am I?** (runtime identity)
2. **Who else is available?** (dispatchable agents)
3. **Route each task** via capability matrix

```bash
# Resolved at session start, cached for session duration
RUNTIME="$(detect_harness)"          # cc | codex | cursor | opencode
AVAILABLE="$(detect_available_agents)"  # e.g. "cc codex gemini"

# Per-task routing
for task in plan_tasks; do
  routing=$(resolve_routing "$task_type" "$RUNTIME" "$AVAILABLE")
  # routing = { action: local|dispatch, agent: cc|codex|gemini }
done
```

---

## Plan Label Convention

Old labels (CC-centric):
```
[CC] Task A
[Codex] Task B
```

New labels (runtime-agnostic):
```
[Self] Task A           — orchestrator executes locally
[Dispatch:CC] Task B    — dispatch to Claude Code
[Dispatch:Codex] Task C — dispatch to Codex
[Consult:Gemini] Task D — advisory consultation (CC implements)
```

The routing algorithm resolves `[Self]` and `[Dispatch:*]` based on runtime + available agents. Same plan works from either runtime.

---

## Quality Tracking (Symmetric)

| Direction | Quality File | Format |
|-----------|-------------|--------|
| CC → Codex dispatch | `.codex-quality.jsonl` | Existing (see `codex-protocol.md`) |
| Codex → CC dispatch | `.cc-quality.jsonl` | **New**, mirrors `.codex-quality.jsonl` |

`.cc-quality.jsonl` schema:
```json
{"date":"YYYY-MM-DD","task_id":N,"spec_words":N,"status":"success|rejected|wandered","latency_ms":N,"error_category":"dispatch|conflict|integration|scope-creep|none","consecutive_failures":N,"budget_usd":N}
```

Same rolling-20 window metrics and penalty/hard-stop thresholds as Codex quality tracking apply.
