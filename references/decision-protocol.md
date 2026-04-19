# Consolidated Decision Protocol + Next-Step Priority Cascade

**Principle:** Minimize mid-execution interruptions. User decisions are batched into **two moments only** — before execution (pre-flight) and after all tasks complete (end-of-plan). Mid-stream questions are queued and silent-defaulted, except for a small list of hard-blocking exceptions.

---

## Decision Timing Classification

| Type | When | Examples |
|------|------|----------|
| **Pre-flight** (asked during Plan confirmation) | BEFORE execution starts | Plan approval, `/co:plan-review` mode, anticipated high-risk ops, UI theme changes, planned deletions |
| **Queued** (logged, auto-defaulted, asked at end) | Mid-execution, **not** blocking | Codex review findings, Gemini-vs-browser conflicts, non-obvious Chesterton's Fence calls, UI webpage-extraction apply |
| **Blocking** (interrupt immediately, rare) | Anytime | Dispatch Security Gate BLOCKED patterns, destructive ops without backup, cross-scope writes, data loss risk |
| **End-of-plan** (single consolidated prompt) | After Priority 1–3 all done | Open `todo` issues + queued decisions + milestone menu |

---

## Pre-flight Decision Batching (during Plan confirmation)

After producing the Execution Plan, CC scans the planned tasks for **anticipated decision points** and presents them as a **single batched prompt** alongside the Plan. User approves/rejects each in one round.

Pre-flight checklist CC runs against the Plan:
1. Any task touch files matching Dispatch Security Gate high-risk patterns? (batch rename, config.ts, test-suite mods)
2. Any task plan to modify `components.json` or radix-nova theme variables?
3. Any task plan to delete / remove / "simplify" existing code?
4. Any task require a design direction or visual variant (Gemini consult)?
5. Does any task fall within `Off-limits:` boundaries?

Batch prompt format:
```
Plan ready. Before execute, 4 decisions to pre-approve:

[1] Task T3 will batch-rename 12 files across auth/ module. Approve? (y/n/ask-later)
[2] Task T5 will change radix-nova primary color to brand-accent. Approve? (y/n/ask-later)
[3] Task T7 plans to delete legacy-auth.ts (purpose unclear — Chesterton's Fence).
    → Keep / Delete / Investigate-then-ask (y=delete, k=keep, i=investigate)
[4] Task T9 needs 2–3 UI variants for new dashboard. Consult Gemini? (y/n)

Reply: 1y 2n 3k 4y   (or answer individually / ask-later on any)
```

User answers in one line. CC records to `.decisions-approved` in repo root. Execution proceeds without re-asking.

---

## Mid-execution: Queue, Don't Interrupt

During Phase 1 execution, when CC encounters a decision point **not pre-approved**:

```
if blocking (security-blocked / destructive / off-limits breach):
    interrupt user with 1-line prompt, stop until answered
else:
    queue to .decisions-pending with safe default applied
    log: "[Decision queued] <task> <question> — defaulted to <safe action>"
    continue execution
```

`.decisions-pending` format (one JSON per line):
```json
{"task":"T5","question":"Codex review flagged 3 issues in src/auth/login.tsx, severity medium","default_action":"present-only, do not auto-fix","needs_user_call":true}
```

**Safe defaults** by category:

| Mid-stream scenario | Safe default |
|---------------------|--------------|
| Codex review findings (any severity) | Present-only, do not auto-fix |
| Gemini suggestion conflicts with browser | Follow browser, note Gemini dissent |
| Chesterton's Fence (unknown-purpose code) | Keep the code, document the mystery |
| UI webpage-extract apply | Write to preview branch, not main |
| Non-blocking test failure | `gh issue create --label "todo,non-blocking"` (current Priority 2 rule) |

---

## Blocking Exceptions (always interrupt)

Do NOT queue these — ask user immediately:
1. Dispatch Security Gate `BLOCKED` patterns attempted (DB migration, env, CI, secrets, force-delete, git history rewrite)
2. Any operation that would destroy data without a recoverable backup
3. Cross-scope writes (Codex output touches `Off-limits:` files)
4. Codex reports a CRITICAL severity finding that invalidates the task premise
5. Plan execution cannot proceed without the answer (true block, not merely awkward)

All interruptions use one-line format:
> "BLOCKING: <what>. <A> or <B>?"

---

## End-of-Plan Consolidated Review

When all Phase 1 tasks complete (Priority 3 reaches end of Plan), run the **single consolidated review**:

```bash
# Gather all three streams
TODO_ISSUES=$(gh issue list --state open --label todo --json number,title,labels --limit 20)
PENDING_DECISIONS=$(cat .decisions-pending 2>/dev/null)
MILESTONE_MENU=<any Phase-0-identified follow-on work that wasn't in this Plan>
```

Present as ONE prompt:
```
### Plan done. All tests green. Pre-push consolidated review:

A. Queued decisions from execution (3):
   A1. Task T5 — Codex review: 3 medium findings in login.tsx. Fix now / file issues / ignore?
   A2. Task T7 — Gemini said to reorder dashboard cards; browser runtime fine either way. Apply / skip?
   A3. Task T9 — webpage-extract proposed 2 color token changes. Apply / skip?

B. Existing open issues (2):
   B1. #61 — real-meeting retest (priority: high)
   B2. #73 — [bug] flaky CSS animation on Safari (priority: low, non-blocking)

C. Next-milestone candidates (4, from Phase 0 roadmap):
   C1. F — meeting REST handler wire
   C2. T — real cloud-sync target (MyMemo Hub)
   C3. U — frontend memory list + filter UI
   C4. V — MCP tool e2e

D. Push now? (requires §5.3 code review prompt first)

Reply format: "A1=fix A2=apply A3=skip B=handle-B1-now C=C2 D=yes-push"
or free-form
```

User answers in one round. CC processes all decisions atomically, then:
1. Run Priority 1 (tests) after each decision
2. Once all green → trigger pre-push review prompt (ask user "是否需要触发一次全量代码审核？")
3. Push

---

## Priority Cascade (between tasks during Phase 1)

**Never skip steps to "save time" — "I'll test later" is a blocked rationalization.**

### Priority 1 — Run tests (always first)

After any code change, run the relevant verification before anything else:

```
run: tests + lint + type check
├─ all pass → go to Priority 3 (next task)
└─ any fail → go to Priority 2 (triage)
```

Exception: none. Pure-doc changes still run linters. This is Shift Left in practice (`engineering-principles.md`).

### Priority 2 — Test Failure Triage

Classify the failure, then act accordingly.

**Blocking failure** (fix before proceeding):
- Test for the feature CC just implemented
- A test that was green before CC's change on the touched code path
- Build fails / type error / lint error in the modified files
- Regression that affects the critical user path

→ **Fix immediately**. Do not proceed to the next task. Re-run tests until green.

**Non-blocking failure** (capture, continue):
- Test in an unrelated module that coincidentally breaks
- Known-flaky test
- Pre-existing failure unrelated to current task
- Warning (not error) in modified files

→ **Create a GitHub issue**, then continue:

```bash
gh issue create \
  --title "[bug] <specific failure — one line>" \
  --label "todo,non-blocking" \
  --body "$(cat <<'EOF'
**Reproduction:** <command or steps>
**Expected:** <behavior>
**Actual:** <behavior + short error excerpt>
**Affected files:** <paths>
**Context:** discovered during <current task name>
EOF
)"
```

Record the issue number in the Execution Plan's `Deferred` section so it doesn't get lost.

**Unclear whether blocking?** Route through Codex Co-Decision: ask Codex to classify with `confidence` level. If low confidence → escalate to user one-line question.

### Priority 3 — Next task from Execution Plan

Pick the next incomplete item. Announce: "Next: [task]. Verify: [command]."

### Priority 4 — Plan Complete → End-of-Plan Consolidated Review

See "End-of-Plan Consolidated Review" above — merges queued decisions, open issues, milestone menu into one prompt. Do NOT create separate sub-dialogs.

Either path through the consolidated prompt: **before any `git push`**, ask user "是否需要触发一次全量代码审核？" first.
