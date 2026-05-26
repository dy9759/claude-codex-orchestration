# Codex Invocation Protocol + Co-Decision + Security + Quality

All Codex calls go through the `codex:codex-rescue` subagent, which wraps `codex-companion.mjs`.

## Foreground vs Background

| Task profile | Mode | Heartbeat | Why |
|---|---|---|---|
| Small, bounded, < 10 min | `foreground` | Timeout only (10min default) | Blocks orchestrator until done; simpler coordination |
| Complex, multi-step, open-ended | `background` | Full (L1/L2/L3) | Returns `job-id`; orchestrator continues other work; heartbeat monitors |
| Review / adversarial review | `foreground` | Timeout only (5min default) | Structured output, expect immediate feedback |

**Heartbeat integration:** Background tasks automatically enable heartbeat monitoring per `heartbeat-protocol.md`. Foreground tasks get a portable timeout wrapper — if exceeded, orchestrator kills and falls back to self-execution.

Use the built-in `review` or `adversarial-review` commands for reviewing git diffs — do not write a custom review `task` prompt; the built-in contracts are better.

## Thread Persistence and Resume

Every task starts a named thread (Codex persists it). Decide before dispatching:
- **Fresh task** → no `--resume-last` (new thread)
- **Follow-up on same Codex work** ("continue", "keep going", "dig deeper", "apply the top fix") → add `--resume-last`; send only the delta instruction, not the full prompt again
- **Force fresh despite prior thread** → add `--fresh` explicitly

## Write Mode and Effort

| Task type | Flags | Sandbox |
|---|---|---|
| Implementation, bug fix | `--write` | `workspace-write` |
| Review, diagnosis, research | *(none)* | `read-only` |
| Effort — simple UI | `--effort low` | — |
| Effort — complex backend/arch | `--effort high` | — |
| Effort — deep diagnosis | `--effort xhigh` | — |

Default: no `--effort` (Codex chooses). Only set when task complexity is clear.

## Structured Prompt Format (XML — not caveman for Codex)

Codex prompts use XML block structure, not caveman prose. Prompt Codex like an **operator, not a collaborator**:

```xml
<task>
  Concrete job + relevant repo/failure context. One task per run.
  State what "done" looks like explicitly.
</task>

<structured_output_contract>
  Exact shape, ordering, brevity requirements for the response.
  E.g.: "Return: changed files list, test results, risk flags, open questions."
</structured_output_contract>

<default_follow_through_policy>
  What Codex should do instead of asking routine questions.
  E.g.: "If a file is missing, create it. If a test fails, fix it."
</default_follow_through_policy>

<!-- Add only what the task needs: -->
<verification_loop>Required for implementation/debug — provide Test Plan, run tests, verify fix, review test quality.</verification_loop>
<grounding_rules>Required for review — cite file+line, no unsupported claims.</grounding_rules>
<action_safety>For write-capable runs — stay narrow, avoid unrelated refactors.</action_safety>
```

Checklist before sending:
1. `<task>` defines exact scope and done-state
2. Smallest output contract that makes the answer usable
3. Add `<verification_loop>` for any implementation task
4. Add `<grounding_rules>` for any review task
5. For behavior changes or test edits, apply `testing-quality.md` in the output contract
6. Remove redundant instructions — prefer tighter contracts over longer prose

**Token rule:** Final prompt <200 words. If over, remove redundant instructions first; compress prose only as last resort.

## Result Handling

- Present Codex findings as-is: preserve verdict, severity order, file paths, evidence boundaries
- After presenting review findings: **STOP**. Do not fix anything. Explicitly ask which issues the user wants addressed
- If Codex run failed: report the failure and stop — do not generate a substitute CC answer
- If Codex was never invoked: return nothing, do not improvise
- If Codex is unavailable or unhealthy, say that plainly and use `runtime-routing.md` fallback rules; do not label local reasoning as Codex input

---

## Codex Co-Decision Protocol

When CC would normally pause and ask the user a clarifying question — **route to Codex first**. Keeps user input flow uninterrupted, reduces human-in-loop.

### When to Route to Codex

- CC uncertain between two implementation approaches
- Design decision with no obvious right answer from context
- Ambiguous task spec needs interpretation before splitting
- CC needs a second opinion on a risk assessment

**Never route to Codex for:** security decisions, irreversible operations, blocked dispatch patterns (Dispatch Security Gate rules apply), anything user must explicitly approve.

### Time-Budget Rule

Codex Co-Decision is a latency tradeoff, not a ritual. Use it only when the second opinion is likely to save more time than it costs.

Skip Co-Decision and proceed directly when:
- the local answer is obvious from code/tests/docs
- the user has already stated the preference
- the decision is high-risk and needs explicit user approval
- a one-line user question is faster than dispatching Codex
- Codex is unavailable, unauthenticated, over budget, or under a quality hard-stop

Default Co-Decision timeout: 90s. On timeout, log `category: codex-unavailable` and continue with the safe local default or ask the user if truly blocked.

### Co-Decision Pattern

```
1. CC formulates question + context (< 150 words)
2. Dispatch to Codex: read-only sandbox, --effort medium
3. Prompt format:
   <task>Analyze these two approaches for [decision]. Which better fits [context]?
   Approach A: [description]. Approach B: [description]. Criteria: [what matters].</task>
   <structured_output_contract>Return: recommendation (A or B), 2-sentence rationale,
   confidence (high/medium/low), conditions where the other choice wins.</structured_output_contract>
4. CC evaluates Codex recommendation:
   - confidence=high   → act on it, mention Codex rationale in plan
   - confidence=medium → act on it + note assumption in plan
   - confidence=low OR conflicts with known constraints → escalate to user with pre-loaded recommendation
```

**Escalation format** (only when Codex can't resolve):
> "Two options here — [A] or [B]. Codex leans [X] because [1-sentence reason]. Your call."

One question, one sentence of context. Never multi-paragraph when escalating.

---

## Dispatch Security Gate

Pre-dispatch check on every Codex task spec before `codex:codex-rescue` is invoked.

**Blocked by default (require explicit CC decision, never auto-dispatch to Codex):**
```
database migrations (ALTER TABLE, DROP TABLE, CREATE TABLE)
environment variable changes (.env, process.env, os.environ writes)
package manifest changes (package.json, requirements.txt, go.mod, Cargo.toml)
CI/CD pipeline changes (.github/workflows/, .gitlab-ci.yml, Dockerfile, Makefile)
secrets / credentials (API keys, tokens, passwords in any form)
rm -rf / force delete operations
git history rewrite (rebase -i, reset --hard, push --force)
```

**High-risk patterns — show warning + require user confirmation before dispatch:**
```
bulk file renames or moves
cross-module imports (file touching two declared scopes)
test suite modifications that could mask failures
config.ts / settings.py / *.config.js (shared config files)
```

**Per-agent scope enforcement:**
- CC: full access within declared worktree
- Codex: read-only outside `Scope:` field; write-only within `Scope:` field; never write to `Off-limits:` list
- If Codex output touches files outside `Scope:` → automatic `status: rejected`, record as `scope-creep` error

**Security check format** — before any Codex dispatch, output:
```
[Security] Scanning task spec...
Blocked patterns: [none / list]
High-risk patterns: [none / list]
Scope: [declared files]
Verdict: safe-to-dispatch / requires-confirmation / blocked
```

If `blocked`: rewrite task spec to remove the blocked operation. Keep the blocked work with the current orchestrator, require explicit user approval, and include rollback/Test Plan steps before any execution.
If `requires-confirmation`: pause, show warning in full (not caveman), wait for user yes/no.

---

## Codex Quality Tracking

Track per-dispatch Codex performance. Persist to `.codex-quality.jsonl`:

```json
{"date":"YYYY-MM-DD","task_id":1,"spec_words":N,"status":"success|rejected|wandered","latency_ms":N,"error_category":"dispatch|conflict|integration|scope-creep|none","consecutive_failures":N}
```

**Quality metrics (computed from rolling last-20 dispatches):**

| Metric | Healthy | Warning | Action |
|--------|---------|---------|--------|
| Success rate | ≥ 70% | 40–70% | Tighten spec template |
| Avg spec words | < 150 | > 200 | Always compress before send |
| Consecutive failures | 0–2 | 3+ | **Pause dispatch, diagnose** |

**Penalty factor** (from OpenSpace ToolQualityRecord logic):
- Success rate ≥ 40% → no penalty, proceed normally
- Success rate < 40% → penalize: require explicit file list in every spec, halve scope, add off-limits for all adjacent files
- 3+ consecutive failures → hard stop: do not dispatch to Codex until root cause identified

**Semantic failure injection** — technical success ≠ acceptance: if integration review rejects Codex output (scope-creep, size violation, unintended changes), record as `status: rejected` even if Codex itself returned no errors. Feeds the same success-rate metric as hard failures.

**Auto-evolve trigger** — every 5 Codex dispatches, check quality. If warning threshold hit → run `/co-review` targeting `dispatch` dimension. Do not wait for the 5-session cadence.

---

## Task Board (Multi-Codex Parallel Safety)

When dispatching 2+ Codex tasks in parallel, use a task board to prevent double-claiming:

**Directory:** `.tasks/` in repo root. Each task is a JSON file:
```json
{
  "id": 1,
  "subject": "implement login UI",
  "scope": "src/ui/auth/",
  "status": "pending",
  "owner": null,
  "dispatch": {
    "pid": null,
    "started_at": null,
    "timeout_s": 1800,
    "heartbeat": {
      "last_check": null,
      "status": "DISPATCHED",
      "stall_count": 0,
      "output_bytes": 0
    }
  }
}
```

The `dispatch` block is populated when the task is dispatched to an agent. See `heartbeat-protocol.md` for state machine and fallback logic.

**Claim rule:** CC assigns `owner` + sets `status: "in_progress"` atomically before dispatching to Codex. No task gets two owners. If Codex finishes early and grabs a new task — it must read `.tasks/` and claim explicitly. CC audits `.tasks/` at integration to verify no overlaps.

**Status lifecycle:** `pending` → `in_progress` → `completed` | `rejected`

**Learn-Rule fast path:** If Codex makes the same mistake twice within a session, capture immediately:
```
[LEARN] Category: Rule (one line)
Mistake: What went wrong
Correction: What to do instead
```
Add to active Codex task spec for remainder of session. Log to `.error-log.jsonl` for Layer 3 promotion.
