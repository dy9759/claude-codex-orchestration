# Workflow Core — Phase 0 → Plan → Execution → Integration

The full orchestration flow CC runs for any non-trivial task. Load this reference when starting a new task.

---

## Phase 0: Understand Before Splitting

1. **Explore context:**
   - If user referenced a PRD / design doc (e.g. `@path/to/prd.md`, `@path/to/architecture.md`) → **load and read in full first** before touching code
   - Grep repo for affected modules and files based on PRD requirements
   - Map: PRD sections → code paths → candidate Plan tasks
   - If no PRD → explore repo directly from user's spoken intent
2. Clarify ambiguities (or use Codex Co-Decision — see `codex-protocol.md`)
3. ID minimum viable change
4. Determine truly independent (parallelizable) vs. coupled (sequential) tasks
5. **Detect branch protection:**
   ```bash
   default_branch=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null)
   current_branch=$(git branch --show-current 2>/dev/null)
   if [ "$current_branch" = "$default_branch" ]; then
     is_protected=$(gh api "repos/{owner}/{repo}/branches/$default_branch" --jq '.protected' 2>/dev/null)
     [ "$is_protected" = "true" ] && echo "PROTECTED"
   fi
   ```
   - Protected → Plan must use `feature/<agent>-<desc>` branch; Integration ends with `gh pr create`, not direct push
   - Detection fails (no `gh` / no network) → assume possibly protected; prefer feature branch for any session touching multiple files
6. Decide worktrees needed?

Only then: produce Execution Plan.

For ambiguous/novel/high-stakes tasks, run `/co:think` first (see `thinking-decision.md`).

**PRD-first precedent** (MyTeam session 042d4cee): user started with `2026-04-17-architecture-diagrams.md` + 4 module PRDs; loading these before exploration avoided wandering and kept Codex specs tight.

**Branch-protection precedent** (MyTeam session 98c45441): attempting `git push origin main` hit a hook block mid-flow. Detecting upfront lets Plan route through PR instead of failing at the final step.

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
| **Frontend work** — UI components, pages, interactions, styling, design systems (default: shadcn/ui + radix-nova, see `ui-style-standard.md`) | Parallel candidate implementations (compare and pick) | "Not ugly but not great" second opinion |
| Integrates others' output | Current diff review (read-only) | Large-context repo architecture summary |
| Makes final decisions on interfaces | — | — |

**Why frontend → CC by default:** Claude (Sonnet 4.6+) has strong frontend judgment — component design, state management, CSS/design-system coherence, UX edge cases. Codex excels at bounded backend modules and scripts where the interface is stable and the test set is explicit. Assign backward from what each does *best*, not from category stereotypes.

**Practical heuristic:** If the task can be described with `Scope: [paths]` + `Off-limits: [paths]` + a verifiable done-state, **and** it's backend/script/isolated, dispatch to Codex. Frontend and cross-cutting work stays on CC unless there's a specific reason to parallelize.

**Calibration:** This is v0 default. Run 5+ real sessions, then use `.eval-scores.jsonl` weak-point data to adjust per-project (via `/co:review` + `/co:promote`).

---

## Three-Stage Subagent Pattern (superpowers:subagents integration)

When `superpowers@claude-plugins-official` is installed, prefer its **three-stage pattern** for any Codex-owned task with meaningful review needs:

1. **implementer subagent** — writes the code per spec
2. **spec-compliance-reviewer subagent** — verifies output matches the task spec (scope, deliverables, boundaries)
3. **code-quality-reviewer subagent** — checks readability, naming, maintainability harness compliance

Replaces a single `codex-rescue` dispatch with three focused dispatches. Observed in real use (MyTeam session 042d4cee) for architecture refactor across Account / Session / Channel / Project modules.

**When to use three-stage:**

| Trigger | Action |
|---------|--------|
| Task ≥ 300 lines OR touches 3+ files | Three-stage |
| Task < 100 lines OR isolated fix | Single dispatch (`codex-rescue`) |
| Unsure | Three-stage (cost is 3 dispatches; quality ratchet is real) |

**How stages integrate with Codex Co-Decision:**
- **Stage 1 (implementer)** typically uses Codex via `codex-rescue` with `--write`
- **Stages 2–3 (reviewers)** are CC subagents (fresh context, read-only) dispatched via built-in `Agent` tool — **not** Codex
- Reviewers carry `maintainability-harness.md §18 Hard Red Lines` as rejection criteria

**Reviewer briefs (condensed):**

*Spec-compliance reviewer:*
```
Task: verify implementation against the original spec.
Output: list of (spec bullet, passed/failed, evidence).
Reject on: missed requirements, scope creep beyond declared files, unverified behaviors.
```

*Code-quality reviewer:*
```
Task: review against references/maintainability-harness.md §18 Hard Red Lines.
Output: list of (red-line, violated-or-not, file:line).
Reject on: any §18 hard red-line violation.
```

**Fallback if superpowers not installed:**
Fold the three stages into one Codex spec via `<verification_loop>` + `<grounding_rules>` with an internal review checklist. Less rigorous (single-agent has blindspots on its own output) but works.

---

## Codex Invocation (Summary)

Full protocol in `codex-protocol.md`. Key points:

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

## Gemini Consultation (Summary)

Full protocol in `gemini-integration.md`. Key points:

**Relationship:** CC orchestrator → Gemini specialist → CC fallback. Gemini advises; CC always implements and verifies.

**Fact priority:** browser runtime behavior > local code context > Gemini suggestion.

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

---

## Worktree Rules

Create when:
- CC + Codex implement different modules in parallel
- Testing 2+ competing solutions
- Isolating high-risk changes

Rules:
- One writer per worktree — no shared write
- Naming: `feature/<agent>-<desc>` (e.g. `feature/codex-auth-module`)
- Branch lifetime ≤ 1–3 days (trunk-based; see `engineering-principles.md`)
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

## Quality Gates (Summary)

Full gates in `engineering-principles.md` + `maintainability-harness.md`. Applied at **every Codex dispatch** and **integration**:

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
4. Check maintainability harness violations (see `maintainability-harness.md` §18 Hard Red Lines)
5. Check new file/function sizes and nesting
6. Run tests + lint + type check
7. **Pre-push:** ask user — "是否需要触发一次全量代码审核？" before any git push
8. Emit verdict
