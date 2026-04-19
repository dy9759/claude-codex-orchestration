---
name: claude-codex-orchestration
description: Use when coordinating Claude Code + Codex as dual agents with Gemini as frontend/UI specialist consultant (via gemini-cli MCP), delegating parallel implementation of bounded modules to Codex, splitting work by boundary-clarity not domain, controlling token consumption, cross-harness setup (Cursor/Codex/OpenCode), pre-task thinking (/co:think), strategic plan review (/co:plan-review), engineering principles enforcement (Hyrum, Beyoncé, Chesterton, trunk-based, shift-left, feature-flags, deprecation, maintainability harness), UI style standard (shadcn/radix-nova), and knowledge compounding. Self-contained; optional plugins and Gemini MCP auto-detected.
---

# Claude Code + Codex Orchestration

## Overview

Claude Code = **Tech Lead / Orchestrator + primary executor**.
Codex = **Parallel Implementer** for bounded backend/script modules.
Gemini = **Frontend/UI specialist consultant** (via `gemini-cli` MCP, when available).

**Core principle:** Plan → split cleanly → parallel execute → integrate once. Never two agents on same file simultaneously. Gemini is a consultant, not a co-executor — CC always implements and verifies.

**Announce at start:** "Using claude-codex-orchestration — acting as Tech Lead. Dispatching to Codex for bounded modules; consulting Gemini on frontend/UI as needed."

---

## Reference Index

Deep content lives in `references/` — load only when needed. CC reads this index to route.

| Topic | File | When to load |
|-------|------|--------------|
| Cross-harness setup (CC/Cursor/Codex/OpenCode) | `references/cross-harness.md` | Setting up new harness or migrating AGENTS.md |
| Codex invocation + co-decision + security + quality | `references/codex-protocol.md` | Before any Codex dispatch |
| Context budget + compact-guard + Smart Tool RAG | `references/context-budget.md` | Context > 60% or stuck mid-session |
| Self-correction (3 layers + cron loop) | `references/self-correction.md` | `/co:eval`, `/co:review`, `/co:promote`, `/co:loop` |
| Knowledge compounding (`/co:compound`, `/co:sessions`) | `references/knowledge-compounding.md` | Solving non-trivial problem or before complex work |
| Thinking & decision (`/co:think`, `/co:plan-review`) | `references/thinking-decision.md` | Complex/ambiguous task before Execution Plan |
| Engineering principles (Hyrum, Beyoncé, Chesterton, etc.) | `references/engineering-principles.md` | Integration review + every Codex task gate |
| Maintainability harness (file size, nesting, naming, hard red lines) | `references/maintainability-harness.md` | Every Codex dispatch; seed AGENTS.md with these rules |
| UI style standard (shadcn + radix-nova default, webpage style extraction) | `references/ui-style-standard.md` | Any frontend work; "make it look like [URL]" requests |
| Gemini integration (frontend/UI specialist consultant) | `references/gemini-integration.md` | Large UI revamps, 2–3 visual variants needed, CSS/a11y/structure review, "not ugly but not great" second opinion |

---

## Data File Lifecycle

Per-user session state — **auto-created on first use**, `.gitignore`d, never committed.

| File | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `.eval-scores.jsonl` | `/co:eval` at session end | `/co:review`, Smart Tool RAG quality filter | Two-axis score history, anti-inflation detection |
| `.error-log.jsonl` | Codex failure / integration rejection / Learn-Rule fast path | `/co:review`, Smart Tool RAG quality filter | Error capture, recurrence detection for Layer 3 promotion |
| `.codex-quality.jsonl` | Every Codex dispatch result | Quality tracking (rolling 20-window), auto-evolve trigger | Dispatch success rate, penalty factor, hard-stop gate |
| `.tasks/*.json` | CC before parallel Codex dispatch | Both agents during execution; CC at integration audit | Atomic task claiming, owner field prevents double-writes |

**First session:** files don't exist yet. First `/co:eval` creates `.eval-scores.jsonl` with one entry. First Codex failure creates `.error-log.jsonl`. Empty files silently no-op in quality filters (no rolling window data = no penalty).

**Reset state:** `rm ~/.claude/skills/claude-codex-orchestration/.{eval-scores,error-log,codex-quality}.jsonl` to start fresh.

---

## Session Start: Optional Plugin Detection

At session start, scan `~/.claude/plugins/installed_plugins.json` for optional enhancements. Show hints **once per user** via a sentinel file.

```bash
REGISTRY=~/.claude/plugins/installed_plugins.json
SENTINEL=~/.claude/.orch-plugin-hints-shown

[ -f "$SENTINEL" ] && exit 0

check() { grep -q "\"$1\"" "$REGISTRY" 2>/dev/null; }

MISSING=()
check "caveman"              || MISSING+=("caveman")
check "compound-engineering" || MISSING+=("compound-engineering")
check "superpowers@"         || MISSING+=("superpowers")

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "[Orchestration] Optional plugins not detected: ${MISSING[*]}"
  echo "  Skill works without them. Install guides (external):"
  for p in "${MISSING[@]}"; do
    case "$p" in
      caveman)              echo "    caveman              → https://github.com/JuliusBrussee/caveman" ;;
      compound-engineering) echo "    compound-engineering → https://github.com/EveryInc/compound-engineering-plugin" ;;
      superpowers)          echo "    superpowers          → /plugin install superpowers@claude-plugins-official" ;;
    esac
  done
  echo "  This hint shows once per user."
  touch "$SENTINEL"
fi
```

**What each plugin adds** (all optional):
| Plugin | Enhancement |
|--------|-------------|
| `caveman` | Heavier output token compression (`caveman:compress`) + `/caveman lite\|full\|ultra` levels |
| `compound-engineering` | Richer knowledge-compounding subagents (replaces inline 4-subagent pattern) |
| `superpowers` | `superpowers:using-git-worktrees`, brainstorming, dispatching-parallel-agents |

**Re-trigger:** `rm ~/.claude/.orch-plugin-hints-shown`. **Never block:** skill proceeds regardless.

---

## Session Start: AGENTS.md Bootstrap

At session start (after Plugin Detection), check project root for `AGENTS.md` and `CLAUDE.md`. AGENTS.md is the cross-harness source of truth; `CLAUDE.md` becomes `@AGENTS.md` pointer so Claude Code reads the same file as Cursor / Codex / OpenCode.

Claude Code officially supports `@filename` imports in CLAUDE.md ([code.claude.com/docs/en/memory.md](https://code.claude.com/docs/en/memory.md)) — AGENTS.md content loads into CC session context automatically.

```bash
agents_bootstrap() {
  local project_root has_agents has_claude pointer='@AGENTS.md'
  project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  cd "$project_root" 2>/dev/null || return 0

  has_agents=$([ -f AGENTS.md ] && echo yes || echo no)
  has_claude=$([ -f CLAUDE.md ] && echo yes || echo no)

  is_pointer() {
    [ -f CLAUDE.md ] && \
    [ "$(grep -vE '^\s*$' CLAUDE.md | tr -d '[:space:]')" = "@AGENTS.md" ]
  }

  case "$has_agents:$has_claude" in
    yes:yes)
      if ! is_pointer; then
        echo "[AGENTS] WARN — both CLAUDE.md and AGENTS.md have content."
        echo "         Suggested: merge into AGENTS.md, reduce CLAUDE.md to '@AGENTS.md'."
      fi
      ;;
    yes:no)
      printf '%s\n' "$pointer" > CLAUDE.md
      echo "[AGENTS] Created CLAUDE.md → @AGENTS.md pointer"
      ;;
    no:yes)
      cp CLAUDE.md CLAUDE.md.bak
      mv CLAUDE.md AGENTS.md
      printf '%s\n' "$pointer" > CLAUDE.md
      echo "[AGENTS] Migrated CLAUDE.md → AGENTS.md (backup: CLAUDE.md.bak)"
      ;;
    no:no)
      cat > AGENTS.md <<'TEMPLATE'
# Agents

## Non-Negotiable Rules

- Prefer clarity over cleverness.
- Keep files under 500 lines when possible.
- Keep functions under 40 lines when possible.
- Keep nesting to 3 levels or fewer.
- One function, one responsibility.
- No magic values.
- No silent error swallowing.
- No unnecessary dependencies.
- New logic requires tests.
- Read existing code before writing new code.
- Match project conventions.
- Make the smallest maintainable change.

### Role Definitions

- **Claude Code** — Tech Lead / Orchestrator + primary executor. Owns architecture, cross-module decisions, integration, frontend work (UI components, pages, interactions, styling), anything needing repo-wide context (migrations, CI/CD, release coordination).
- **Codex** — Parallel Implementer. Owns bounded backend/script modules with clear boundaries and independent verifiability (isolated features, self-contained scripts, parallel solution attempts, diff review).
- **Gemini** — Frontend/UI specialist consultant (via `gemini-cli` MCP, optional). Advises on design direction, CSS audits, a11y, multi-file consistency. Never executes — CC always implements and verifies.

### Blocked File Patterns (Codex never writes these)

- Database migrations (ALTER/DROP/CREATE TABLE)
- `.env`, secrets, API keys
- Package manifests (package.json, requirements.txt, go.mod, Cargo.toml)
- CI/CD pipelines (.github/workflows/, Dockerfile, Makefile)
- `rm -rf` / force-delete operations
- Git history rewrites (rebase -i, reset --hard, push --force)

### Workflow

1. Plan → split CC/Codex ownership cleanly
2. Parallel execute in worktrees if needed (`feature/<agent>-<desc>`)
3. Integrate once — single writer per file at any moment
4. Verify: tests + lint + type check before push

### Next-Step Decision Flow (between tasks)

After each task completes, run priority cascade:
1. **Run tests first** — always, no exceptions
2. **If tests fail:**
   - *Blocking* (feature test / was-green regression / build / type / lint in modified files) → fix immediately
   - *Non-blocking* (unrelated module / flaky / pre-existing / warning) → create `gh issue create --label "todo,non-blocking"`, continue
3. **If tests pass** → next task from Execution Plan
4. **When Plan complete** → End-of-plan consolidated review (queued decisions + open issues + milestone menu in ONE prompt, then push)

### Consolidated Decision Protocol (minimize mid-execution interruptions)

- **Pre-flight batch:** at Plan confirmation, CC presents all anticipated decisions (security high-risk, UI theme changes, planned deletions, Gemini consultation) in ONE prompt. User approves in one reply.
- **Mid-execution:** only BLOCKING events interrupt (security-blocked / data-loss / off-limits / task-invalidating). Everything else queues to `.decisions-pending` with safe default applied.
- **End of plan:** ONE consolidated prompt merging queued decisions + open issues + milestone menu. User answers all in one round.

### Frontend/UI consultation

- Small UI change → CC does it directly, no Gemini
- Large revamp / 2–3 variants / CSS audit / a11y review → consult Gemini via `mcp__gemini-cli__*`; CC implements and verifies in browser
- Gemini unavailable → CC continues, never blocks

### UI Style (Frontend Default)

- Default: shadcn/ui + `"style": "radix-nova"` + `baseColor: neutral` + `iconLibrary: lucide`
- See `~/.claude/skills/claude-codex-orchestration/references/ui-style-standard.md` for full `components.json`, webpage style extraction workflow, and secondary style library
- **Do not introduce a second UI library alongside shadcn.** No hardcoded hex colors in components — use CSS variables. Use Tailwind scale, not arbitrary `p-[13px]`.

### Referenced Docs

- Skill: `~/.claude/skills/claude-codex-orchestration/SKILL.md`
- Maintainability harness: `~/.claude/skills/claude-codex-orchestration/references/maintainability-harness.md`
- UI style standard: `~/.claude/skills/claude-codex-orchestration/references/ui-style-standard.md`
- Gemini integration (frontend specialist): `~/.claude/skills/claude-codex-orchestration/references/gemini-integration.md`
- Solved problems (if present): `docs/solutions/`
TEMPLATE
      printf '%s\n' "$pointer" > CLAUDE.md
      echo "[AGENTS] Created AGENTS.md (template) and CLAUDE.md → @AGENTS.md pointer"
      ;;
  esac
}

agents_bootstrap
```

**Safety notes:**
- Migration creates `CLAUDE.md.bak` before overwriting — original never lost
- If both files have content, do NOT auto-merge; warn and let user decide
- Template seeds AGENTS.md with Non-Negotiable Rules — Codex/Cursor/OpenCode read these automatically

---

## **AGENTS.md Write Redirect (mandatory rule)**

> **When writing agent instructions, rules, role definitions, or project conventions — always target `AGENTS.md`, never `CLAUDE.md`.**
>
> CLAUDE.md should remain the single line `@AGENTS.md` (or equivalent include directive). All new rule additions, skill references, blocked-pattern updates, role changes, and workflow documentation go into AGENTS.md.
>
> **Exception:** modifying the `@AGENTS.md` pointer in CLAUDE.md itself.
>
> **Rationale:** AGENTS.md is read by all four harnesses (Claude Code, Cursor, Codex, OpenCode). Writing to CLAUDE.md creates CC-only rules that other agents can't see, breaking cross-harness parity.

---

## Token Budget Mode (Inline Compression)

All **agent-internal communication** uses compressed prose to cut ~75% output tokens while preserving full technical substance. Applies to: execution plans, status updates, Codex task specs, inter-phase summaries, subagent briefs, integration reports.

Compression is **inline style guidance** — no external plugin required. If the `caveman` plugin is installed, CC may delegate; otherwise apply the rules directly.

**Default level: `full`** — drop articles/filler, fragments OK, short synonyms. User may request `lite` or `ultra` by saying "switch to lite/ultra mode".

| Level | Style rules |
|-------|-------------|
| `lite` | Remove filler words only; sentences stay full. Use when user needs readable plan output. |
| `full` | **Default.** Drop articles (a/the/of), fragments OK, short synonyms (use → apply, perform → do). |
| `ultra` | Max compression: abbreviate (DB/auth/fn/impl/env), use arrows for causality (X → Y), single words where phrases work. |

**Never compress:**
- Code blocks (always written normally)
- Security warnings and irreversible action confirmations
- User-facing final deliverables that require clarity
- Multi-step sequences where fragment order risks misread

See `references/context-budget.md` for phase-based context thresholds, compact-guard, identity re-injection.

---

## Phase 0: Understand Before Splitting

1. Explore repo — identify affected modules and files
2. Clarify ambiguities (or use Codex Co-Decision — see `references/codex-protocol.md`)
3. ID minimum viable change
4. Determine truly independent (parallelizable) vs. coupled (sequential) tasks
5. Decide worktrees needed?

Only then: produce Execution Plan.

For ambiguous/novel/high-stakes tasks, run `/co:think` first (see `references/thinking-decision.md`).

---

## Execution Plan Format (Required Before Acting)

```
### Plan

[CC] Task A — files: src/api/...
[Codex] Task B — files: src/ui/...

CC owns: backend, scripts, CI/CD, migrations, integration, tests
Codex owns: [specific files/modules]

Worktrees: yes/no → branches + owners
Subagents: yes/no → who, why
Verify: [test command or check]
```

Show plan. Wait for confirm. Then execute. Optional: run `/co:plan-review` for CEO-mode critique before executing.

---

## Default Work Distribution (boundary-based, not domain-based)

**Split by boundary clarity, not by frontend/backend.** Codex isn't a frontend specialist; this table is a starting heuristic based on "bounded modules parallelize better", not a capability claim.

| Claude Code (Tech Lead + primary executor) | Codex (Parallel Implementer) | Gemini (Specialist Consultant) |
|--------------------------------------------|------------------------------|--------------------------------|
| Requires repo-wide context (architecture, cross-cutting refactor) | Any **backend/script** module with clear file/API boundaries | Frontend design direction (2–3 variants, aesthetic review) |
| Coordinates multiple subsystems | Independently verifiable (has its own tests or clear acceptance criteria) | CSS architecture / a11y / responsive audits |
| Touches migrations, CI/CD, release pipelines | Isolated bug fixes with known scope | UI consistency scan across multiple files |
| **Frontend work** — UI components, pages, interactions, styling, design systems (default: shadcn/ui + radix-nova, see `references/ui-style-standard.md`) | Parallel candidate implementations (compare and pick) | "Not ugly but not great" second opinion |
| Integrates others' output | Current diff review (read-only) | Large-context repo architecture summary |
| Makes final decisions on interfaces | — | — |

**Why frontend → CC by default:** Claude (Sonnet 4.6+) has strong frontend judgment — component design, state management, CSS/design-system coherence, UX edge cases. Codex excels at bounded backend modules and scripts where the interface is stable and the test set is explicit. Assign backward from what each does *best*, not from category stereotypes.

**Practical heuristic:** If the task can be described with `Scope: [paths]` + `Off-limits: [paths]` + a verifiable done-state, **and** it's backend/script/isolated, dispatch to Codex. Frontend and cross-cutting work stays on CC unless there's a specific reason to parallelize.

**Calibration:** This is v0 default. Run 5+ real sessions, then use `.eval-scores.jsonl` weak-point data to adjust per-project (via `/co:review` + `/co:promote`).

---

## Codex Invocation (Summary — full protocol in `references/codex-protocol.md`)

- **Foreground** (< 10 min, bounded) vs **background** (complex, returns job-id)
- **Thread persistence:** new task = fresh; "continue" = `--resume-last`; force new = `--fresh`
- **Write mode:** `--write` for implementation, none for review
- **Effort:** `low` (simple UI), `high` (complex backend), `xhigh` (deep diagnosis)
- **XML structured prompt** (< 200 words) — `<task>`, `<structured_output_contract>`, `<default_follow_through_policy>`, optional `<verification_loop>`, `<grounding_rules>`, `<action_safety>`
- **Result handling:** present findings as-is, STOP before fixing, report failures honestly
- **Co-Decision:** route CC's internal questions to Codex before asking user — keeps input flow uninterrupted
- **Security gate:** scan task spec, block DB/env/CI/secrets, confirm high-risk
- **Quality tracking:** rolling 20-dispatch window, penalty < 40% success rate, hard stop at 3+ consecutive failures

---

## Gemini Consultation (Frontend/UI Specialist)

**Relationship:** CC orchestrator → Gemini specialist → CC fallback. Gemini advises; CC always implements and verifies.

**Fact priority:** browser runtime behavior > local code context > Gemini suggestion. Never treat Gemini as ground truth.

### When to call

| Call Gemini | Don't call Gemini |
|-------------|-------------------|
| Large UI revamp, new page/module | Small style fixes, copy tweaks |
| Need 2–3 visual/interaction variants | Rapid trial-and-error runtime issues |
| Component structure / info architecture unclear | Browser debugging (console, network, DOM) |
| Multi-file UI/CSS consistency audit | Urgent blocking tasks |
| a11y / responsive / semantic HTML review | Tasks CC finishes in < 2 minutes |
| "Not ugly but not great" second opinion | — |

### Invocation

Via `mcp__gemini-cli__*` MCP tools only (never API key). Prompts are natural language, not XML:

```
ask gemini to propose 3 UI variants for [component], prioritize [criterion]
ask gemini to audit CSS architecture for responsive inconsistencies in src/pages/
ask gemini to review the current diff for frontend issues (naming, a11y, perf)
```

Ask Gemini to return: `recommendation / alternatives / risks / implementation notes`.

### Fallback

Gemini unavailable (MCP error, timeout, rate limit) → CC continues without waiting. Log as `category: gemini-unavailable` in `.error-log.jsonl`. **Never block on Gemini availability.**

### Routing vs Codex Co-Decision

| Question nature | Route to |
|-----------------|----------|
| Code architecture, bug classification, risk triage | Codex Co-Decision |
| Frontend design direction, UI aesthetics, a11y | Gemini consultation |
| Both applicable | Pick closest to failure mode. Never ask both on same question. |

Full workflow, hook config, and integration rules in `references/gemini-integration.md`.

---

## Consolidated Decision Protocol (front-load + end-batch)

**Principle:** Minimize mid-execution interruptions. User decisions are batched into **two moments only** — before execution (pre-flight) and after all tasks complete (end-of-plan). Mid-stream questions are queued and silent-defaulted, except for a small list of hard-blocking exceptions.

### Decision Timing Classification

| Type | When | Examples |
|------|------|----------|
| **Pre-flight** (asked during Plan confirmation) | BEFORE execution starts | Plan approval, `/co:plan-review` mode, anticipated high-risk ops, UI theme changes, planned deletions |
| **Queued** (logged, auto-defaulted, asked at end) | Mid-execution, **not** blocking | Codex review findings, Gemini-vs-browser conflicts, non-obvious Chesterton's Fence calls, UI webpage-extraction apply |
| **Blocking** (interrupt immediately, rare) | Anytime | Dispatch Security Gate BLOCKED patterns, destructive ops without backup, cross-scope writes, data loss risk |
| **End-of-plan** (single consolidated prompt) | After Priority 1–3 all done | Open `todo` issues + queued decisions + milestone menu |

### Pre-flight Decision Batching (during Plan confirmation)

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

### Mid-execution: Queue, Don't Interrupt

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

### Blocking Exceptions (always interrupt)

Do NOT queue these — ask user immediately:
1. Dispatch Security Gate `BLOCKED` patterns attempted (DB migration, env, CI, secrets, force-delete, git history rewrite)
2. Any operation that would destroy data without a recoverable backup
3. Cross-scope writes (Codex output touches `Off-limits:` files)
4. Codex reports a CRITICAL severity finding that invalidates the task premise
5. Plan execution cannot proceed without the answer (true block, not merely awkward)

All interruptions use one-line format:
> "BLOCKING: <what>. <A> or <B>?"

### End-of-Plan Consolidated Review

When all Phase 1 tasks complete (Priority 3 reaches end of Plan), run the **single consolidated review**:

```bash
# Gather all three streams
TODO_ISSUES=$(gh issue list --state open --label todo --json number,title,labels --limit 20)
PENDING_DECISIONS=$(cat .decisions-pending 2>/dev/null)
MILESTONE_MENU=<any Phase-0-identified follow-on work that wasn't in this Plan>
```

Present as ONE prompt:
```
## Plan done. All tests green. Pre-push consolidated review:

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
2. Once all green → trigger §5.3 pre-push review prompt (still mandatory)
3. Push

### Priority Cascade (between tasks during Phase 1)

**Never skip steps to "save time" — "I'll test later" is a blocked rationalization.**

### Priority 1 — Run tests (always first)

After any code change, run the relevant verification before anything else:

```
run: tests + lint + type check
├─ all pass → go to Priority 3 (next task)
└─ any fail → go to Priority 2 (triage)
```

Exception: none. Pure-doc changes still run linters. This is Shift Left in practice (`references/engineering-principles.md`).

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

Either path through the consolidated prompt: **before any `git push`**, the `§5.3 code review prompt` from CLAUDE.md fires — ask user "是否需要触发一次全量代码审核？"

---

## Worktree Rules

Create when:
- CC + Codex implement different modules in parallel
- Testing 2+ competing solutions
- Isolating high-risk changes

Rules:
- One writer per worktree — no shared write
- Naming: `feature/<agent>-<desc>` (e.g. `feature/codex-auth-module`)
- Branch lifetime ≤ 1–3 days (trunk-based; see `references/engineering-principles.md`)
- Merge: diff review → cherry-pick or manual integrate
- See `superpowers:using-git-worktrees` for setup (if installed); otherwise standard `git worktree add`

---

## Subagent Rules

CC subagents: repo research, log analysis, CI triage, test validation, solution comparison.
Codex subagents: parallel candidate impls, local fixes, UI variants, review splitting.

Only use when tasks truly independent — clear input/output/file boundaries. Subagent briefs: compressed `full`, <150 words each.

---

## Conflict Prevention

- Never assign same file to both agents simultaneously
- Never give Codex vague cross-repo task — cut clean boundary first
- Never parallelize coupled tasks
- If in doubt: CC does it, Codex reviews it

---

## Quality Gates (Summary — full gates in `references/engineering-principles.md` + `references/maintainability-harness.md`)

Applied at **every Codex dispatch** and **integration**:

- **Scope:** minimum viable; no speculative features
- **Surgical changes:** Codex removes only orphans its own changes created
- **Verify step required:** every task has explicit `verify: [command]`
- **Size gates:** new file < 500 lines (hard warn), function < 80 lines (hard warn), nesting ≤ 3
- **Maintainability:** no magic values, no silent errors, no unnecessary deps, Rule of 3 for duplication
- **Hyrum's Law** on API surface, **Beyoncé Rule** for tests, **Chesterton's Fence** before deletions
- **Pre-push:** ask user "是否需要触发一次全量代码审核？" before any git push

---

## Integration Phase

After both agents complete, output:

```
### Integration

Modified: [file list]
Overlaps: [none / list conflicts]
Regressions: [none / describe]
Tests: [pass/fail summary]
Size violations: [none / new files >500 lines, functions >80 lines, nesting >3]
Maintainability violations: [none / list]
Verdict: ready / needs-fix / codex-rejected
```

Steps:
1. List all modified files — check overlaps
2. Review Codex diff: unintended changes? excess scope? pre-existing dead code touched?
3. Apply **five-axis review**: Correctness / Readability / Architecture / Security / Performance
4. Check maintainability harness violations (see `references/maintainability-harness.md` §18 Hard Red Lines)
5. Check new file/function sizes and nesting
6. Run tests + lint + type check
7. **Pre-push:** ask user — "是否需要触发一次全量代码审核？" before any git push
8. Emit verdict

---

## Invocation Prompts (not registered slash commands)

> **Note:** `/co:*` below are **mnemonic prompts**, not registered Claude Code slash commands. Invoke by typing the prompt (e.g., `/co:eval`) in chat — CC follows the matching section in SKILL.md or the referenced file.

| Prompt | When to invoke | Deep content |
|--------|---------------|--------------|
| `/co:think` | Before complex/ambiguous tasks — clarify, challenge premises, optional Codex cold read | `references/thinking-decision.md` |
| `/co:plan-review` | After Execution Plan drafted — CEO-mode review (EXPAND/SELECTIVE/HOLD/REDUCE) | `references/thinking-decision.md` |
| `/co:eval` | End of every orchestration session | `references/self-correction.md` |
| `/co:review` | Every 5 sessions, or when `.eval-scores.jsonl` has 5+ new entries | `references/self-correction.md` |
| `/co:promote` | After `/co:review` identifies promotion candidate with score ≥ 6 | `references/self-correction.md` |
| `/co:loop` | Start autonomous background refinement (uses `ScheduleWakeup`) | `references/self-correction.md` |
| `/co:compound` | After any session that resolves a non-trivial problem | `references/knowledge-compounding.md` |
| `/co:sessions` | Before starting complex work — search prior sessions for dead ends | `references/knowledge-compounding.md` |

---

## Design Principles

1. **Self-contained** — no mandatory external plugins; optional plugins auto-detected and only enhance
2. **Plan before execute** — no code without approved Execution Plan
3. **Single writer per file** — hard rule, always
4. **Token-aware** — agent-internal comms compressed; code + user deliverables full
5. **Human-in-loop minimization** — Codex Co-Decision first, escalate only on low confidence
6. **Self-correcting** — 3-layer mechanism with locked evaluator to prevent score-gaming
7. **Cross-harness** — AGENTS.md as universal baseline, CLAUDE.md as pointer
8. **Maintainability over speed** — optimize for 6-month readability, not line count
9. **Never stop** — `/co:loop` runs until interrupted; Darwin ratchet keeps improvements
