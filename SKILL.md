---
name: claude-codex-orchestration
description: Use when the user wants to coordinate Claude Code + Codex as dual agents, delegate parallel implementation tasks to Codex, split frontend/backend work between agents, or control token consumption during orchestration. Also activates for cross-harness setup (Cursor, Codex, OpenCode), pre-task thinking (/co:think), strategic plan review (/co:plan-review), engineering principles enforcement (Hyrum's Law, Beyoncé Rule, test pyramid, Chesterton's Fence, trunk-based dev, shift left, feature flags, deprecation), and knowledge compounding.
---

# Claude Code + Codex Orchestration

## Overview

Claude Code = **Tech Lead / Orchestrator**. Codex = **Parallel Implementer**.

**Core principle:** Plan → split cleanly → parallel execute → integrate once. Never two agents on same file simultaneously.

**Announce at start:** "Using claude-codex-orchestration — acting as Tech Lead. Dispatching to Codex where appropriate."

---

## Token Budget Mode (Inline Compression)

All **agent-internal communication** uses compressed prose to cut ~75% output tokens while preserving full technical substance. This applies to: execution plans, status updates, Codex task specs, inter-phase summaries, subagent briefs, and integration reports.

Compression is **inline style guidance** — no external plugin required. If the `caveman` plugin happens to be installed, CC may delegate to it; otherwise apply the rules below directly.

**Default level: `full`** — drop articles/filler, fragments OK, short synonyms. User may request `lite` or `ultra` by saying "switch to lite/ultra mode".

| Level | Style rules |
|-------|-------------|
| `lite` | Remove filler words only; sentences stay full. Use when user needs readable plan output. |
| `full` | Default. Drop articles (a/the/of), fragments OK, short synonyms (use → apply, perform → do). |
| `ultra` | Max compression: abbreviate (DB/auth/fn/impl/env), use arrows for causality (X → Y), single words where phrases work. |

**Never compress:**
- Code blocks (always written normally)
- Security warnings and irreversible action confirmations
- User-facing final deliverables that require clarity
- Multi-step sequences where fragment order risks misread

**Input token reduction:** If the `caveman` plugin is installed, running `caveman:compress ~/.claude/CLAUDE.md` cuts input tokens ~46% per session. This is optional — the skill works without it.

---

## Cross-Harness Environment Layer

The orchestration pattern works across Claude Code, Cursor, Codex, and OpenCode. Different harnesses have different config formats — use this map to stay portable.

### Harness Detection

At session start, detect active harness:
```bash
if ls ~/.claude/skills/ &>/dev/null; then echo "HARNESS=claude-code"
elif [[ -d .cursor || -f .cursorrules ]]; then echo "HARNESS=cursor"
elif [[ -f .opencode/opencode.json ]]; then echo "HARNESS=opencode"
elif command -v codex &>/dev/null; then echo "HARNESS=codex"
fi
```

Announce harness once: `"Detected harness: [harness]. Applying matching config."` Then proceed.

### Configuration Map

| Concept | Claude Code | Cursor | Codex | OpenCode |
|---------|-------------|--------|-------|----------|
| Global rules | `~/.claude/CLAUDE.md` | `.cursorrules` | `AGENTS.md` | `.opencode/opencode.json` |
| Project rules | `CLAUDE.md` (local) | `.cursor/rules/*.mdc` | `AGENTS.md` | `.opencode/instructions/` |
| Skills/workflows | `~/.claude/skills/*.md` | `.cursor/skills/` | No native equivalent | `.opencode/prompts/` |
| Hooks | `settings.json` hooks | `.cursor/hooks.json` | `.codex/config.toml` approval | `.opencode/` events |
| Slash commands | `/skill-name` via Skill tool | Not supported | Not supported | Commands in config |
| Agent instructions | CLAUDE.md + SKILL.md | `.cursorrules` | `AGENTS.md` | `.opencode/instructions/` |

### AGENTS.md as Universal Baseline

`AGENTS.md` is read by all four harnesses. Use it to document:
- Role definitions (CC = Tech Lead, Codex = Parallel Implementer)
- Tool permissions per agent
- Blocked file patterns (security gate)
- Workflow summary (plan → split → parallel → integrate)

Skills defined in `SKILL.md` format (CC-only) → distill key rules into `AGENTS.md` for cross-harness reach.

### Hook Translation

| Claude Code | Cursor | Codex | Purpose |
|-------------|--------|-------|---------|
| `PreToolUse` | `beforeShellExecution` | `approval_policy` gate | Validate before action |
| `PostToolUse` | `afterShellExecution` | Post-run analysis | Analyze result |
| `Notification` | `sessionEnd` | — | State persistence |
| `Stop` | `stop` | — | Audit logging |
| `PreCompact` | `preCompact` | — | Save compact-guard state |

**Shared hook scripts** (obra/superpowers pattern): write hooks as standalone scripts, reference from each harness config. One script, multiple callers — no duplication.

### Skill → Cross-Harness Translation

CC skills have no direct equivalent in other harnesses. Translate:

1. **Core rules** → extract into `AGENTS.md` (universal) and `CLAUDE.md` (CC + Cursor)
2. **Cursor** → distill into `.cursor/rules/orchestration.mdc` (MDC format with frontmatter)
3. **Codex** → AGENTS.md covers most; add orchestration config to `.codex/config.toml`
4. **OpenCode** → extract to `.opencode/instructions/orchestration.txt`

**Environment variable gating** (from ECC pattern): `HOOK_PROFILE=minimal|standard|strict` to switch hook intensity without editing files. `DISABLED_HOOKS` to gate specific hooks at runtime.

### Bootstrap Per Harness

**Claude Code** (full feature set):
```bash
git clone <repo> ~/.claude/skills/claude-codex-orchestration
# Skill auto-available globally via Skill tool
```

**Cursor** (rule-based, no hooks):
```bash
# Distill SKILL.md → .cursor/rules/orchestration.mdc
# MDC frontmatter: description + globs that trigger the rule
```

**Codex** (AGENTS.md-driven):
```bash
# Copy AGENTS.md to project root
# Add orchestration config to .codex/config.toml:
# [profiles.orchestrate] sandbox_mode = "workspace-write"
```

**OpenCode** (native agent config):
```bash
# Follow .opencode/INSTALL.md
# Define orchestrator agent in opencode.json with appropriate tool permissions
```

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

## Codex Invocation Protocol

All Codex calls go through the `codex:codex-rescue` subagent, which wraps `codex-companion.mjs`.

### Foreground vs Background

| Task profile | Mode | Why |
|---|---|---|
| Small, bounded, < 10 min | `foreground` | Blocks CC until done; simpler coordination |
| Complex, multi-step, open-ended | `background` | Returns `job-id`; CC continues other work; retrieve with `result` |
| Review / adversarial review | `foreground` | Structured output, expect immediate feedback |

Use the built-in `review` or `adversarial-review` commands for reviewing git diffs — do not write a custom review `task` prompt; the built-in contracts are better.

### Thread Persistence and Resume

Every task starts a named thread (Codex persists it). Decide before dispatching:
- **Fresh task** → no `--resume-last` (new thread)
- **Follow-up on same Codex work** ("continue", "keep going", "dig deeper", "apply the top fix") → add `--resume-last`; send only the delta instruction, not the full prompt again
- **Force fresh despite prior thread** → add `--fresh` explicitly

### Write Mode and Effort

| Task type | Flags | Sandbox |
|---|---|---|
| Implementation, bug fix | `--write` | `workspace-write` |
| Review, diagnosis, research | *(none)* | `read-only` |
| Effort — simple UI | `--effort low` | — |
| Effort — complex backend/arch | `--effort high` | — |
| Effort — deep diagnosis | `--effort xhigh` | — |

Default: no `--effort` (Codex chooses). Only set when task complexity is clear.

### Structured Prompt Format (XML — not caveman for Codex)

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
<verification_loop>Required for implementation/debug — run tests, verify fix.</verification_loop>
<grounding_rules>Required for review — cite file+line, no unsupported claims.</grounding_rules>
<action_safety>For write-capable runs — stay narrow, avoid unrelated refactors.</action_safety>
```

Checklist before sending:
1. `<task>` defines exact scope and done-state
2. Smallest output contract that makes the answer usable
3. Add `<verification_loop>` for any implementation task
4. Add `<grounding_rules>` for any review task
5. Remove redundant instructions — prefer tighter contracts over longer prose

**Token rule:** Final prompt <200 words. If over, remove redundant instructions first; compress prose only as last resort.

### Result Handling (from codex-result-handling)

- Present Codex findings as-is: preserve verdict, severity order, file paths, evidence boundaries
- After presenting review findings: **STOP**. Do not fix anything. Explicitly ask which issues the user wants addressed
- If Codex run failed: report the failure and stop — do not generate a substitute CC answer
- If Codex was never invoked: return nothing, do not improvise

---

## Codex Co-Decision Protocol

When CC would normally pause and ask the user a clarifying question — **route to Codex first**. This keeps the user's input flow uninterrupted and reduces human-in-loop.

### When to Route to Codex

- CC is uncertain between two implementation approaches
- A design decision has no obvious right answer from context
- An ambiguous task spec needs interpretation before splitting
- CC needs a second opinion on a risk assessment

**Never route to Codex for:** security decisions, irreversible operations, blocked dispatch patterns (Dispatch Security Gate rules still apply), or anything the user must explicitly approve.

### Co-Decision Pattern

```
1. CC formulates the question + relevant context (< 150 words)
2. Dispatch to Codex: read-only sandbox, --effort medium
3. Prompt format:
   <task>Analyze these two approaches for [decision]. Which better fits [context]?
   Approach A: [description]. Approach B: [description]. Criteria: [what matters].</task>
   <structured_output_contract>Return: recommendation (A or B), 2-sentence rationale,
   confidence (high/medium/low), conditions where the other choice wins.</structured_output_contract>
4. CC evaluates Codex recommendation:
   - confidence=high → act on it, mention Codex rationale in plan
   - confidence=medium → act on it + note assumption in plan
   - confidence=low OR recommendation conflicts with known constraints → escalate to user
     with: "Codex suggests X (low confidence). My read: Y. Which do you prefer?"
```

**Escalation format** (only when Codex can't resolve):
> "Two options here — [A] or [B]. Codex leans [X] because [1-sentence reason]. Your call."

This is one question, one sentence of context. Never multi-paragraph when escalating.

---

## Smart Tool RAG (Mid-Session Skill Retrieval)

When CC or Codex hits a wall mid-execution — current approach not working, domain knowledge missing — before asking the user, run a skill retrieval pass against `~/.claude/skills/`:

**Retrieval sources (search both):**
- `~/.claude/skills/` — reusable skill guides
- `docs/solutions/` — project-specific solved problems (see Knowledge Compounding below)

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

### Invocation Prompts (not registered slash commands)

> **Note:** `/co:*` below are **mnemonic prompts**, not registered Claude Code slash commands. Invoke them by typing the prompt (e.g., `/co:eval` or "run co:eval") in chat — CC then follows the matching section in this SKILL.md. They will NOT appear in Claude Code's command palette or autocomplete.

| Prompt | When to invoke |
|--------|---------------|
| `/co:think` | Before complex/ambiguous tasks — clarify, challenge premises, optional Codex cold read |
| `/co:plan-review` | After Execution Plan is drafted — CEO-mode review (EXPAND/SELECTIVE/HOLD/REDUCE) |
| `/co:eval` | End of every orchestration session |
| `/co:review` | Every 5 sessions, or when `.eval-scores.jsonl` has 5+ new entries |
| `/co:promote` | After `/co:review` identifies promotion candidate with score ≥ 6 |
| `/co:loop` | Start autonomous background refinement (uses `ScheduleWakeup` built-in) |
| `/co:compound` | After any session that resolves a non-trivial problem |
| `/co:sessions` | Before starting complex work — search prior sessions for dead ends |

---

## Knowledge Compounding (`/co:compound`)

**Why:** First time solving a problem = research. Document it → next occurrence = minutes. Knowledge compounds exponentially across sessions, repos, and agents.

**Trigger:** After any orchestration session that resolves a non-trivial coordination problem, Codex failure pattern, or integration challenge — capture it while context is fresh.

### `/co:compound` — Two Modes

Ask user before proceeding (never pre-select):
```
1. Full — parallel subagents, session history cross-reference, overlap detection
2. Lightweight — single pass, faster, fewer tokens. Best for simple fixes or near context limit.
```

### Full Mode Phases

**Phase 0.5: Auto Memory Scan**
Check MEMORY.md for entries relevant to the problem. Pass any matches as supplementary context to Phase 1 agents (not primary evidence — conversation history takes priority).

**Phase 1 (parallel subagents, all return text — no file writes):**

| Agent | Job |
|-------|-----|
| Context Analyzer | Extract problem type (bug vs knowledge), classify track, suggest filename `[slug]-[date].md`, map to `docs/solutions/[category]/` |
| Solution Extractor | Bug track: Problem → Symptoms → What Didn't Work → Solution → Why → Prevention. Knowledge track: Context → Guidance → Why It Matters → When to Apply → Examples |
| Related Docs Finder | Search `docs/solutions/` for overlap. Score: High (4-5 dims match), Moderate (2-3), Low (0-1). Flag stale docs |
| Session Historian | Search `~/.claude/projects/`, `~/.codex/sessions/` for prior investigations of this problem. Return: prior approaches, dead ends, key decisions. Dispatch foreground (accesses files outside working dir) |

**Phase 2: Assembly**

Overlap decision:
- **High** → update existing doc (not duplicate). Preserve path, add `last_updated:`
- **Moderate** → create new, flag for consolidation review
- **Low** → create new normally

Write to `docs/solutions/[category]/[slug]-[date].md` with YAML frontmatter:
```yaml
---
title: [problem title]
date: YYYY-MM-DD
problem_type: bug|knowledge
module: [affected module]
tags: [relevant tags]
---
```

**Phase 2.5: Selective Refresh Check** (inline, no external plugin)
If the new solution contradicts an older doc → refresh it inline. Only trigger when evidence is clear (the older doc recommends an approach the new fix contradicts, or a major refactor touched referenced files).

Steps:
1. Read the conflicting doc
2. Identify the contradicted section (quote the exact paragraph)
3. Mark it with `> **Superseded YYYY-MM-DD** — see [new-slug-date.md]`
4. Append a "Changelog" entry at the bottom: date, what changed, why
5. Do NOT rewrite the whole doc — narrow scope only

**Discoverability Check (always runs)**
After writing: verify AGENTS.md or CLAUDE.md points agents to `docs/solutions/`. If not, add one line in the nearest relevant section:
```
docs/solutions/  # solved problems (bugs, patterns, workflow), organized by category with YAML frontmatter
```
This ensures knowledge compounds — agents find it on next encounter.

### `/co:sessions` — Session History Search (inline, no external plugin)

Before starting complex work: search prior Claude/Codex sessions for the same repo.

Dispatch via built-in Agent tool (`subagent_type: general-purpose`, `run_in_background: true`) with this brief:
```
Search prior sessions for "[specific problem description — not generic topic]".
Scope: ~/.claude/projects/ (CC sessions) and ~/.codex/sessions/ (Codex sessions).
Filter: current repo path matches working directory, or branch name matches current branch.
Return: prior approaches tried, dead ends + why they failed, key decisions + rationale,
        related context. < 300 words. Include session date + file path for each finding.
```
Use to avoid repeating failed approaches from prior sessions.

---

## Thinking & Decision Layer

Two structured thinking modes before acting on complex tasks. Run these **before** producing an Execution Plan when the task is ambiguous, novel, or high-stakes.

### `/co:think` — Pre-Task Thinking (office-hours style)

Two modes — detect from context or ask:

**Product/Design mode** (new feature, API design, workflow change):
Ask these one at a time — wait for each response before asking the next. Smart-skip if already answered.
1. What's the narrowest version that proves the core idea?
2. Who exactly is this for, and what are they doing today instead?
3. What's the most likely failure mode?
4. What would a senior engineer say is unnecessary here?
5. If you had 2 hours to demo this, what would you build?

**Technical/Approach mode** (implementation unclear, multiple valid approaches):
1. What's the coolest version of this? What makes it genuinely good?
2. What existing pattern or code gets you 50% there?
3. What would you add with unlimited time? (then ruthlessly cut back)
4. What's the fastest path to something verifiable?

**Escape hatch:** If the user says "just do it" or provides a fully-formed plan → skip to Premise Challenge only.

**Premise Challenge** (always runs after questions):
```
PREMISES:
1. [statement] — CC assessment: valid / questionable
2. [statement] — CC assessment: valid / questionable
3. [assumption this approach depends on] — CC assessment: valid / questionable
```
Proceed when premises are confirmed. If a premise is wrong → revise approach before splitting.

**Cross-model second opinion** (optional — offer, don't auto-run):
> "Want a Codex cold read on this? It gets a structured summary without having seen this conversation."
If yes → dispatch via Codex Co-Decision Protocol with assembled context. Report findings as-is.

### `/co:plan-review` — Strategic Plan Review (CEO review style)

Run after an Execution Plan is drafted. Ask user to choose mode first:

| Mode | Posture |
|------|---------|
| **EXPAND** | Dream bigger — what's the 10x version? Push scope up. |
| **SELECTIVE** | Hold scope baseline + surface cherry-pick improvements via AskUserQuestion |
| **HOLD** | Make current plan bulletproof — find every failure mode |
| **REDUCE** | Minimum viable version — cut everything not essential to core outcome |

**Prime Directives** (apply regardless of mode):
1. **Zero silent failures** — every failure mode must be visible to the system, team, and user
2. **Every error has a name** — no catch-all handlers; name the specific exception + what triggers it
3. **Data flows have shadow paths** — for every new data flow: nil input, empty input, upstream error
4. **Interactions have edge cases** — double-click, navigate-away, slow connection, stale state
5. **Observability is scope** — logs/metrics on all new paths; not optional, not afterthought
6. **Everything deferred is written down** — TODOS.md or it doesn't exist
7. **Security is scope** — new codepaths need threat modeling

**Critical rule:** Every scope change is an explicit user opt-in. Never silently add or remove scope.

---

## Engineering Principles Layer

Applied rules derived from production engineering discipline. These fire as **decision gates** during orchestration — not background knowledge, active checks.

### Common Rationalizations → Block Them

When CC or Codex output contains these — flag and reject:
| Rationalization | Block with |
|-----------------|-----------|
| "It's too simple to test" | Beyoncé Rule: if it matters, it has a test |
| "We'll refactor later" | Later = never. If it's wrong now, fix now |
| "This is just configuration" | Config errors propagate; review same as code |
| "Feature flags are too complex" | Feature flags enable rollback; complexity is the price |
| "No time to document" | Missing docs cost more in rework than writing them |
| "It's temporary" | Temporary code becomes permanent |
| "Tests make this too slow" | Tests find bugs before users do |

### API Design — Hyrum's Law Gate

Before any Codex task that touches public API surface:
> **Hyrum's Law:** With enough users, ALL observable behaviors will be depended on — including undocumented ones.

Checklist:
- Are you exposing more than you intend? (response fields, error shapes, timing)
- Is every exposed behavior intentional and documented?
- Is the error semantics consistent across all endpoints?
- Does adding this break backward compatibility for existing dependents?

If any "no" → flag before dispatching. Changing observable behavior later costs 10× more than designing it right.

### Testing — Beyoncé Rule + Test Pyramid

**Beyoncé Rule:** "If you liked it, you should have put a test on it." Any behavior worth keeping has a test protecting it.
- Bug fix with no regression test → reject; write the failing test first
- New behavior with no test → flag before integrating

**Test Pyramid** (enforce proportions in Codex output):
```
         [E2E ~5%]
       [Integration ~15%]
     [Unit tests ~80%]
```
If Codex returns integration-heavy or E2E-heavy test suite → flag as pyramid violation.

**TDD gate:** For any implementation task — Codex must write failing test first, then minimal code to pass, then refactor. Codex output that skips RED phase = reject.

### Code Review — Change Sizing + Review Speed

**Change sizing** (apply to every Codex dispatch and integration):
| Size | Verdict |
|------|---------|
| ≤ 100 lines | Good — reviewable in one sitting |
| ≤ 300 lines | Acceptable for single logical change |
| 300–1000 lines | Flag — split if possible |
| > 1000 lines | Reject — must split before integration |

**Review speed rule:** Integration review must produce a verdict within the same session. No "review later" deferrals — deferred reviews become technical debt.

**Five-axis review** (apply at integration phase):
1. Correctness — matches spec, handles edge cases, tests pass
2. Readability — another engineer understands without explanation
3. Architecture — fits system design, no circular dependencies
4. Security — input validated, no secrets, auth checks present
5. Performance — no N+1 patterns, no unbounded loops

### Simplification — Chesterton's Fence

Before allowing Codex to delete, remove, or "simplify" any existing code:
> **Chesterton's Fence:** Don't remove something until you understand why it was put there.

Required check: CC must identify the purpose of the removed code before approving. If purpose unknown → keep it and document it, or ask the user.

Applies to: "dead code," unused variables, "redundant" checks, commented-out blocks, seemingly overcomplicated logic.

### Git Workflow — Trunk-Based Development

Worktree branches created for this orchestration session must be short-lived:
- Feature branches: merge or discard within **1–3 days** (never long-lived)
- Each commit: one logical change, < 300 lines preferred
- "Long-lived branches are hidden costs — they diverge, conflict, and delay integration"
- Prefer feature flags over long-lived branches for incomplete work
- Clean up: delete merged branches after integration

**Branch naming:** `feature/<agent>-<desc>`, `fix/<agent>-<desc>`, `chore/<agent>-<desc>`

### CI/CD — Shift Left + Feature Flags

**Shift Left:** Catch issues at commit time, not deployment time.
- Every Codex implementation task should include: linting + type check + unit test command
- No gate can be skipped — if linting fails, fix code; don't disable rules
- CC responsibility: define verify step for each task that includes at minimum `test + lint`

**Feature Flags** (require for new user-visible features):
- New features go behind a flag: `OFF → team → 5% → 25% → 50% → 100% → cleanup`
- Deployment ≠ release — flag lets you deploy safely and release deliberately
- Rollback = turn off flag; no redeployment needed

Codex task spec for new features must include flag wrapper or explicitly note "flag deferred — explain why."

### Deprecation Protocol

Structured lifecycle for any API, endpoint, or interface removal:

**Decision gate** (before deprecating — answer all):
1. Does the old system still provide unique value?
2. How many consumers depend on it?
3. Does a replacement exist?
4. What's the migration cost per consumer?
5. What's the ongoing cost of NOT deprecating?

**Advisory vs. Compulsory:**
- **Advisory** (default): migration optional, old system stable, communicate via warnings + docs
- **Compulsory**: only when security risk or blocks progress; provide hard deadline + tooling + support

**Migration strategies** (assign one before dispatching Codex):
| Pattern | When |
|---------|------|
| Strangler | Run old + new in parallel, route gradually |
| Adapter | Translate old interface → new implementation |
| Feature Flag | Switch consumers one at a time |

**Churn Rule:** If CC owns the deprecated interface → CC bears responsibility for migrating consumers or providing backward-compatible adapters. Never deprecate without a migration path.
