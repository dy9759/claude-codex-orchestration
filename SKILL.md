---
name: claude-codex-orchestration
description: Use when the user wants to coordinate Claude Code + Codex as dual agents, delegate parallel implementation tasks to Codex, split frontend/backend work between agents, or control token consumption during orchestration while maintaining coding output quality.
---

# Claude Code + Codex Orchestration

## Overview

Claude Code = **Tech Lead / Orchestrator**. Codex = **Parallel Implementer**.

**Core principle:** Plan → split cleanly → parallel execute → integrate once. Never two agents on same file simultaneously.

**Announce at start:** "Using claude-codex-orchestration — acting as Tech Lead. Dispatching to Codex where appropriate."

---

## Token Budget Mode (Caveman Integration)

All **agent-internal communication** uses compressed caveman prose to cut ~75% output tokens while preserving full technical substance. This applies to: execution plans, status updates, Codex task specs, inter-phase summaries, subagent briefs, and integration reports.

**Default level: `full`** — drop articles/filler, fragments OK, short synonyms. Switch with `/caveman lite|full|ultra`.

| Level | Use when |
|-------|----------|
| `lite` | User needs readable plan output; remove filler only |
| `full` | Default — classic caveman for all orchestration comms |
| `ultra` | Max token pressure — abbreviate (DB/auth/fn/impl), arrows for causality (X → Y) |

**Never compress:**
- Code blocks (always written normally)
- Security warnings and irreversible action confirmations
- User-facing final deliverables that require clarity
- Multi-step sequences where fragment order risks misread

**Input token reduction:** Before starting a long session, suggest:
> "Run `caveman:compress ~/.claude/CLAUDE.md` to cut input tokens ~46% per session."

---

## Phase 0: Understand Before Splitting

1. Explore repo — identify affected modules and files
2. Clarify ambiguities
3. ID minimum viable change
4. Determine truly independent (parallelizable) vs. coupled (sequential) tasks
5. Decide worktrees needed?

Only then: produce Execution Plan.

---

## Execution Plan Format (Caveman, Required Before Acting)

```
## Plan

[CC] Task A — files: src/api/...
[Codex] Task B — files: src/ui/...

CC owns: backend, scripts, CI/CD, migrations, integration, tests
Codex owns: [specific files/modules]

Worktrees: yes/no → branches + owners
Subagents: yes/no → who, why
Verify: [test command or check]
```

Show plan. Wait for confirm. Then execute.

---

## Default Work Distribution

| Claude Code | Codex |
|-------------|-------|
| Repo explore + design | Frontend pages, UI, interactions |
| Backend logic, APIs, data flow | Screenshot/design-driven fixes |
| Scripts, migrations, CI/CD | Independent feature modules |
| High-risk / cross-cutting changes | Parallel solution attempts |
| Final integration + release | Current diff review |

---

## Dispatching Tasks to Codex (Caveman Format)

Use `codex:codex-rescue` subagent. Task spec MUST be tight caveman prose:

```
Goal: [one-line objective]
Scope: [files/dirs Codex may touch]
Off-limits: [files Codex must NOT modify]
Subagents: yes/no
Worktree: yes/no → branch: [name]
Deliver: change summary, files modified, test results, risks, open Qs
Tone: caveman full — drop filler, fragments OK, code blocks normal
```

Invoke:
```
subagent_type: "codex:codex-rescue"
prompt: [compressed task spec above]
```

**Token rule:** Codex task specs must be <200 words. If draft exceeds that, compress before sending.

---

## Smart Tool RAG (Mid-Session Skill Retrieval)

When CC or Codex hits a wall mid-execution — current approach not working, domain knowledge missing — before asking the user, run a skill retrieval pass against `~/.claude/skills/`:

**Two-stage pipeline (mirrors OpenSpace SkillRanker):**
1. **BM25 stage** — tokenize task description, score all skills on `name + description + body[:2000]`. Keep top candidates. If total skills ≤ 10, skip to stage 2 directly.
2. **Semantic stage** — re-rank BM25 candidates by concept overlap with the stuck query. Prefer skills with higher quality signals from `.eval-scores.jsonl`.
3. **Quality filter** — if a candidate skill has ≥ 2 error-log entries for `dispatch` or `integration` failures, demote it in ranking.

**Trigger conditions:**
- Codex task spec rejected twice with same error → retrieve skill for that error category
- CC uncertain about worktree setup, context compaction, or integration → retrieve matching skill
- New domain/language/framework in scope → retrieve before dispatching

**Fallback:** If no relevant skill found → proceed, but flag "no skill matched" in the session eval weak_point.

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

**Semantic failure injection** — technical success ≠ acceptance: if integration review rejects Codex output (scope-creep, size violation, unintended changes), record as `status: rejected` even if Codex itself returned no errors. This feeds the same success-rate metric as hard failures.

**Auto-evolve trigger** — every 5 Codex dispatches, check quality. If warning threshold hit → run `/co:review` targeting `dispatch` dimension. Do not wait for the 5-session cadence.

---

## Dispatch Security Gate

Pre-dispatch check on every Codex task spec before `codex:codex-rescue` is invoked. Block or confirm dangerous patterns.

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

If `blocked`: rewrite task spec to remove the blocked operation, assign it to CC instead.
If `requires-confirmation`: pause, show warning in full (not caveman), wait for user yes/no.

---

## Task Board (Multi-Codex Parallel Safety)

When dispatching 2+ Codex tasks in parallel, use a task board to prevent double-claiming:

**Directory:** `.tasks/` in repo root. Each task is a JSON file:
```json
{"id": 1, "subject": "implement login UI", "scope": "src/ui/auth/", "status": "pending", "owner": null}
```

**Claim rule:** CC assigns `owner` + sets `status: "in_progress"` atomically before dispatching to Codex. No task gets two owners. If Codex finishes early and grabs a new task — it must read `.tasks/` and claim explicitly. CC audits `.tasks/` at integration to verify no overlaps.

**Status lifecycle:** `pending` → `in_progress` → `completed` | `rejected`

**Learn-Rule fast path:** If Codex makes the same mistake twice within a session, capture immediately:
```
[LEARN] Category: Rule (one line)
Mistake: What went wrong
Correction: What to do instead
```
Add to active Codex task spec for remainder of session. Log to `.error-log.jsonl` for Layer 3 promotion.

---

## Worktree Rules

Create when:
- CC + Codex implement different modules in parallel
- Testing 2+ competing solutions
- Isolating high-risk changes

Rules:
- One writer per worktree — no shared write
- Naming: `feature/<agent>-<desc>` (e.g. `feature/codex-ui-redesign`)
- Merge: diff review → cherry-pick or manual integrate
- See `superpowers:using-git-worktrees` for setup

---

## Subagent Rules

CC subagents: repo research, log analysis, CI triage, test validation, solution comparison.

Codex subagents: parallel candidate impls, local fixes, UI variants, review splitting.

Only use when tasks truly independent — clear input/output/file boundaries. Subagent briefs: caveman `full`, <150 words each.

---

## Conflict Prevention

- Never assign same file to both agents simultaneously
- Never give Codex vague cross-repo task — cut clean boundary first
- Never parallelize coupled tasks
- If in doubt: CC does it, Codex reviews it

---

## Quality Gates (Applied to Both Agents)

Rules derived from global engineering standards, made explicit for multi-agent context.

**Task scope (Simplicity First):**
- Codex task spec must state minimum viable scope — no speculative features, no unrequested abstractions
- If Codex returns more than asked: flag excess, reject or trim before integrating
- Ask: "Would a senior engineer say this Codex output is overcomplicated?" If yes, send back

**File ownership discipline (Surgical Changes):**
- Codex removes only imports/variables/functions its own changes made unused
- Codex must NOT touch pre-existing dead code unless task spec explicitly says so
- Every changed line in Codex output must trace to the task spec — flag unrelated changes

**Verifiable success criteria (Goal-Driven Execution):**
- Every task in the Execution Plan must have an explicit verify step
- Format per task: `[CC/Codex] Task → verify: [test command or observable check]`
- No task is "done" until its verify step passes

**Output size gate:**
- New files from Codex: must be <500 lines. If exceeded → flag, request split before integrating
- Max nesting depth: 20. Deeper → flag, request helper function extraction

---

## Integration Phase (Caveman Status Report Format)

After both agents complete, output:

```
## Integration

Modified: [file list]
Overlaps: [none / list conflicts]
Regressions: [none / describe]
Tests: [pass/fail summary]
Size violations: [none / new files >500 lines]
Verdict: ready / needs-fix / codex-rejected
```

Steps:
1. List all modified files — check overlaps
2. Review Codex diff: unintended changes? excess scope? pre-existing dead code touched?
3. Check new file sizes — flag any >500 lines
4. Check boundary regressions
5. Run tests
6. **Pre-push:** ask user — "是否需要触发一次全量代码审核？" before any git push
7. Emit verdict

---

## Token & Context Budget (Per Session)

**Phase-based context thresholds** — if over limit, act immediately:

| Phase | Context target | Action if over |
|-------|---------------|----------------|
| Phase 0 (planning) | < 20% | Keep plan output shorter |
| Parallel execution | < 60% | Compact between Codex dispatches |
| Integration | < 80% | Delegate review to subagent |
| Final review / push | < 90% | Start fresh session via `/resume` |

**compact-guard** — before any `/compact`, save to a scratch file (only 5 files survive compaction):
1. Current task — one sentence
2. Files in progress — which files CC and Codex are editing
3. Active Codex task specs
4. Decisions made this session
5. Next step immediately post-compact

**Identity re-injection** — after compaction resumes, CC must reinject:
> "You are Claude Code acting as Tech Lead for [project]. Current task: [task]. Codex is handling: [scope]. Next: [step]."

Without re-injection, CC loses orchestration context and may duplicate Codex work.

**Token accounting:**
```
Input tokens saved: [compress runs estimate]
Output tokens saved: [caveman level × messages]
Total efficiency gain: [rough %]
```
If gain < 30% → switch `full` → `ultra` next session.

---

## Self-Correction System

Three-layer mechanism: **evaluate → capture errors → promote learnings**.

---

### Layer 1: Session Self-Eval (`/co:eval`)

Run after every orchestration session. Two-axis scoring — do NOT pick a number first.

**Axis A — Orchestration Ambition** (what was attempted):
- `Low` — routine task, clear split, no new coordination challenge
- `Medium` — real coordination complexity, partial failure was possible
- `High` — novel split, high-risk parallel work, significant integration challenge

**Axis B — Execution Quality** (how well it went):
- `Poor` — conflicts, rework, Codex output rejected, plan failed
- `Adequate` — completed but with gaps, extra iterations needed
- `Strong` — clean split, zero overlap, integration first-pass

**Composite score matrix** (read it, do not override):

|                        | Poor (1) | Adequate (2) | Strong (3) |
|------------------------|:--------:|:------------:|:----------:|
| **Low Ambition (1)**   |    1     |      2       |     2      |
| **Medium Ambition (2)**|    2     |      3       |     4      |
| **High Ambition (3)**  |    2     |      4       |     5      |

**Devil's Advocate (mandatory before finalizing):**
1. Case for LOWER — what was easier than it looked? What failure was avoided by luck?
2. Case for HIGHER — what was genuinely hard? What coordination challenge was novel?
3. Resolution — if either case changes an axis rating, re-rate and recompute. State final score + 1-sentence justification addressing both sides.

**Anti-inflation check:** Read `.eval-scores.jsonl`. If 4+ of the last 5 scores are identical → flag clustering, force re-evaluation of current session.

**Persist to** `~/.claude/skills/claude-codex-orchestration/.eval-scores.jsonl`:
```json
{"date":"YYYY-MM-DD","score":N,"ambition":"Low|Medium|High","execution":"Poor|Adequate|Strong","task":"1-sentence summary","weak_point":"dispatch|split|integration|tokens|none"}
```

---

### Layer 2: Error Auto-Capture

When Codex returns failure, task spec causes confusion, or integration is rejected — immediately log to `.error-log.jsonl`:

```json
{"date":"YYYY-MM-DD","category":"dispatch|conflict|integration|scope-creep|token","task_spec_words":N,"error":"1-sentence description","root_cause":"vague-scope|missing-boundary|no-verify-step|oversized-output|other"}
```

**Error categories:**
| Category | What happened |
|----------|--------------|
| `dispatch` | Codex task spec was too vague — Codex wandered or asked for clarification |
| `conflict` | File ownership collision — two agents touched same file |
| `integration` | Codex output rejected — excess scope, size violation, or unintended changes |
| `scope-creep` | Codex modified files outside its declared scope |
| `token` | Caveman level didn't reduce output meaningfully |

---

### Layer 3: Review & Promote (`/co:review`, `/co:promote`)

**`/co:review`** — run every 5 sessions or when `.eval-scores.jsonl` has 5+ entries:

1. Read `.eval-scores.jsonl` + `.error-log.jsonl`
2. Find recurring `weak_point` or `root_cause` (appears 2+ times)
3. Check if SKILL.md already addresses it
4. Score each candidate for promotion:

| Dimension | 0 | 1 | 2 | 3 |
|-----------|---|---|---|---|
| **Durability** | One-time | Temporary | Stable pattern | Structural truth |
| **Impact** | Nice-to-know | Saves iteration | Prevents conflict | Prevents breakage |
| **Scope** | Single task | One phase | Whole skill | All orchestrations |

**Promote if total ≥ 6.** Watch at 4-5. Ignore ≤ 3.

**`/co:promote`** — distill and write the improvement into SKILL.md:

Distillation rules (from descriptive to prescriptive):
- ❌ "Codex kept asking about scope because the spec wasn't tight enough"
- ✅ "If Codex task spec exceeds 200 words, compress before sending — vague specs cause wandering"

- ❌ "We had a conflict on config.ts again"  
- ✅ "config.ts is always CC-owned — never assign to Codex, even if task seems UI-only"

After promoting: remove the source entries from `.error-log.jsonl` to prevent stale noise.

**Ratchet rule:** Only keep SKILL.md edits where the promoted rule addresses a real recurrence (2+ log entries). Revert speculative additions.

**Simplicity criterion** (from karpathy/autoresearch): When two rewrites achieve the same score, keep the shorter one. Deleting text + equal score = win. Never add words to fix a weak score if removing words achieves the same result.

**Locked evaluator**: The Layer 1 scoring matrix is immutable — do NOT modify the matrix when it produces an uncomfortable score. Modifying the evaluator to game your own score invalidates all history. If the score seems wrong, argue via devil's advocate, not by editing the matrix.

**Strategy escalation** — if the same `weak_point` persists for 5+ consecutive sessions:

| Stuck sessions | Escalate to |
|---------------|-------------|
| 5 | Micro-fix: rewrite only the failing bullet/sentence |
| 8 | Section rewrite: restructure the whole failing section |
| 12 | Radical restructure: reconsider the section's purpose entirely |
| 15+ | Flag to user: this skill may have a structural design flaw |

**Autonomous cron loop** — for background skill refinement (while user is away):
1. CC runs `/co:eval` + `/co:review`
2. If promotion candidate found (score ≥ 6): run `/co:promote`, git commit
3. Schedule next cycle via `ScheduleWakeup` (270s — stays within cache TTL)
4. Repeat until: no candidates found, or user interrupts
5. Never stop asking to continue — run indefinitely until manually interrupted

**Darwin loop:** After promoting, next session scores same dimension. Improves → keep. Doesn't → rule was wrong, revert and reclassify root cause.

---

### Slash Command Reference

| Command | When to run |
|---------|-------------|
| `/co:eval` | End of every orchestration session |
| `/co:review` | Every 5 sessions, or when `.eval-scores.jsonl` has 5+ new entries |
| `/co:promote` | After `/co:review` identifies promotion candidate with score ≥ 6 |
| `/co:loop` | Start autonomous background refinement (cron-based, runs while user is away) |
