# Self-Correction System

Four-layer mechanism: **score skill edits → evaluate sessions → capture errors → promote learnings**.

---

## Layer 0: Skill Modification Score (`/co:score`) — auto-fire after every skill edit

**Trigger:** Any commit that modifies `SKILL.md`, `references/*.md`, `README.md`, `CLAUDE.md.template`, or the AGENTS.md template inside `references/session-start.md`. (README.md included because it directly affects the Documentation Quality and Usability dimensions.)

**Action:** After staging changes (before the commit message is finalized), compute the 8-dimension weighted score and append to `.skill-scores.jsonl` in repo root. Include the score in the commit message footer.

**Rubric (immutable weights):**

| Dimension | Weight | Criterion |
|-----------|:------:|-----------|
| Design Completeness | 20% | Does the skill cover everything needed for its stated scope? |
| Documentation Quality | 15% | Can a new reader navigate and understand without prior context? |
| Self-Containment | 15% | Works without external plugins or assumptions about host CLAUDE.md? |
| Cross-Harness Coverage | 10% | Works on CC + Cursor + Codex + OpenCode? |
| Executability | 15% | Can CC follow the rules without guessing? |
| Validation Evidence | 10% | Has it been exercised in real sessions? Data files populated? |
| Engineering Rigor | 10% | Locked evaluator, anti-inflation, ratchet rules, etc.? |
| Usability | 5% | How fast can a user adopt it? |

**Scoring each dimension:** 0–100 (integer). Use the Devil's Advocate technique from Layer 1 — argue for lower, argue for higher, then commit to a number.

**Weighted total:** `Σ (weight × dim_score)` — round to one decimal.

**Persist to `.skill-scores.jsonl`:**
```json
{"date":"YYYY-MM-DD","commit":"<short-sha>","score":N.N,"delta":+/-N.N,"dims":{"design":N,"docs":N,"self-contained":N,"cross-harness":N,"executable":N,"validation":N,"engineering":N,"usability":N},"changes":"<1-sentence summary>"}
```

The file is **git-tracked** (unlike per-user JSONL state) — it records the skill's evolution arc and is shared across all users.

**Regression flag:** if any single dimension drops ≥3 vs the prior commit, CC must explain the tradeoff in the commit message footer. Example:
> *Executability -4 (traded for +6 Self-Containment by removing caveman plugin dependency).*

**Commit message footer template:**
```
Skill score: N.N/100 (Δ vs prior: +/-N.N)
Top changes: <dim1> +N, <dim2> +N
Regressions: <if any, with justification>
```

**Locked evaluator (same rule as Layer 1):** the rubric weights and dimensions are immutable. Do not adjust them to make a change look better. If a weak score feels unfair, argue in the commit message, not by editing the rubric here.

### Auto-README Sync Check (mandatory step of Layer 0)

Every Layer 0 run, **before** computing the score, run this README coherence check:

```bash
readme_sync_check() {
  local changed_files
  changed_files=$(git diff --cached --name-only | grep -E '^(SKILL\.md|references/.*\.md|CLAUDE\.md\.template)$')

  [ -z "$changed_files" ] && return 0  # no skill file changes, skip

  local stale=()
  for f in $changed_files; do
    # For each changed skill file, find its name/key concepts in README
    local basename=$(basename "$f" .md)
    # If README references this file OR a section name from it that no longer matches → stale
    if grep -q "$basename" README.md 2>/dev/null; then
      # README references this file; verify descriptions still match new content
      # (CC does this semantically, not regex)
      stale+=("$f referenced in README — verify description still accurate")
    fi
  done

  if [ ${#stale[@]} -gt 0 ]; then
    echo "[README-sync] README.md references the following modified files:"
    printf '  - %s\n' "${stale[@]}"
    echo "Update README.md in this same commit OR explain in commit message why README is still accurate."
  fi
}
```

**Rule:** after any skill file edit, CC must:
1. Run `readme_sync_check`
2. For each flagged file, semantically compare README's description to the new content
3. If README is now stale → update README in **the same commit** (preferred), or in an immediate follow-up
4. If README is still accurate despite the change → note that in the commit message ("README unchanged: only internal <X> was modified, public description holds")

**Why same commit, not follow-up?** README drifting behind skill content is the #1 way users lose trust in docs. Keeping them lockstep in one commit eliminates "half-updated" intermediate states visible on GitHub.

**Score dimension tie-in:** a stale README detected but not updated → flag as Documentation Quality regression in the score. Forces either update-or-justify.

**Compare to Layer 0's main score:** the sync check runs first (fact-gathering); the score then reflects the actual state (including any README updates that just happened).

**Compare to Layer 1:** Layer 1 scores *session execution quality* (how well the orchestration worked). Layer 0 scores *skill quality* (how good the skill spec itself is). Two different axes, two different log files.

---

## Layer 1: Session Self-Eval (`/co:eval`)

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

### Long-Session Auto-Prompt (proactive `/co:eval` trigger)

**Problem observed (MyTeam session 042d4cee, 2026-04-17→19):** 48-hour marathon session with 36 Codex dispatches but only 2 `/co:*` invocations. User accumulated rich experience that was never captured to `.eval-scores.jsonl` because "session end" never cleanly arrived.

**Solution:** CC proactively prompts `/co:eval` when either threshold is hit:
- Dispatch count since last eval ≥ **10**
- Time since last eval ≥ **6 hours**

**State files (local, `.gitignored`):**
- `.last-eval-dispatch-count` — running counter, reset to 0 after each successful `/co:eval`
- `.last-eval-timestamp` — Unix epoch, reset after each successful `/co:eval`

**Prompt follows Question Format Standard:**

```
[Orchestration] Pressure threshold reached: 10+ dispatches / 6+ hours since last eval.

Q: Run /co:eval now to capture current learnings?

Options:
  y.     Run now (recommended — populates .eval-scores.jsonl, enables darwin ratchet)
  n.     Skip (counters reset, prompt again at next threshold)
  later. Defer (counters continue accumulating, prompt again in 1 hour)
  never. Silence for remainder of this session

Recommendation: y (confidence: high)
  CC: data-less sessions mean Layer 3 /co:review has nothing to scan;
      your marathon experience is at risk of evaporating.
  Codex: not consulted (meta-skill decision).
  Gemini: N/A.

Reply: y / n / later / never
```

**Answer flow:**
- `y` → run `/co:eval` → reset both counters
- `n` → reset counters → silent until next 10/6h threshold
- `later` → don't reset; re-prompt in 1 hour
- `never` → write `.skip-eval-this-session` sentinel (removed on next session start)

**Why not just "every 10 dispatches"?** Short bursts of dispatches on a single small task shouldn't be interrupted. The **AND** of count-or-time gives natural marathon detection.

**Compare to Layer 0 /co:score:** Layer 0 fires *after every skill-file commit* (discrete event). This auto-prompt fires *during long work sessions* (pressure-based). They don't overlap.

---

## Layer 2: Error Auto-Capture

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

## Layer 2.5: External Escalation (auto-report to skill repo)

**Purpose:** when structural self-correction signals exceed threshold, auto-report to the skill's own GitHub repo (`dy9759/claude-codex-orchestration`) so improvements can be shared across all users — not to the host project's repo.

**Key principle:** `local capture → threshold aggregation → auto-upload`. A single one-off failure does NOT create an issue (would flood the repo). Only structural signals do.

### Trigger Matrix (4 categories that auto-escalate)

| Category | Condition | Data source | Fingerprint format |
|----------|-----------|-------------|-------------------|
| **Recurrent root cause** | Same `root_cause` or `weak_point` ≥ 2× in last 7 sessions | `.eval-scores.jsonl` + `.error-log.jsonl` | `darwin:<category>:<root_cause>` |
| **Codex quality hard-stop** | Rolling-20 success rate < 40% OR ≥ 3 consecutive failures | `.codex-quality.jsonl` | `quality:hard-stop:<category>` |
| **Darwin regression** | `/co:promote`-added rule failed to improve target dimension in next same-dim session | `.skill-scores.jsonl` + `.eval-scores.jsonl` | `darwin:regression:<dim>` |
| **Structural flaw** | Same `weak_point` persists 5+ consecutive sessions | `.eval-scores.jsonl` | `structural:<weak_point>` |

### Local-only (never escalate)

- Single dispatch/conflict/integration/scope-creep/token failure
- Known-dirty host project, flaky tests, host-project-unrelated failures
- Tool unavailability (`gh` not authenticated, offline)

### Flow: capture → classify → threshold → dedupe → upload → log

```
[Layer 1/2 signal recorded]
          │
          ▼
[classify: matches one of 4 escalation triggers?]
          │
          ▼ yes
[compute fingerprint: mechanism:category:root_cause]
          │
          ▼
[check gh availability]
   ├─ gh OK:
   │     ├─ gh issue list --repo dy9759/claude-codex-orchestration \
   │     │    --search "in:title <fingerprint>" --state open
   │     │
   │     ├─ existing issue found → gh issue comment <N> --body <evidence>
   │     └─ not found            → gh issue create --repo dy9759/... \
   │                                 --title "[<Mechanism>] <fingerprint>" \
   │                                 --body <template>
   │
   └─ gh unavailable:
         └─ append to .issue-candidates.jsonl (pending queue)
                    │
                    ▼
      [next session: retry pending queue when gh available]
                    │
                    ▼
      [success: move entry from candidates.jsonl → issue-log.jsonl]
```

### Title Prefix Standard (label-optional)

To avoid fragile `gh issue create --label <X>` (label may not exist in target repo), encode category in title prefix:

| Prefix | Meaning |
|--------|---------|
| `[Darwin]` | Promoted rule failed to improve its target dimension |
| `[CE]` | Compound engineering signal (recurring root cause / integration failure pattern) |
| `[Quality]` | Codex dispatch quality hard-stop or threshold breach |
| `[Structural]` | Weak point persists beyond strategy-escalation max (structural flaw) |

Examples:
- `[Darwin] promoted rule failed to improve dispatch/vague-scope`
- `[CE] recurring integration rejection: oversized-output`
- `[Quality] Codex hard-stop: 3 consecutive dispatch failures on vague-scope`
- `[Structural] weak_point 'integration' persists 5+ sessions (flaw level)`

Labels like `auto-report`, `darwin`, `quality` MAY be added if they exist in target repo (check via `gh label list`), but never required.

### Issue Body Template

```markdown
## Fingerprint
`<mechanism>:<category>:<root_cause>`

## Signal Summary
- Mechanism: <Darwin regression / CE recurring / Quality hard-stop / Structural>
- First observed: <YYYY-MM-DD>
- Occurrences: <N> in last <7 sessions / 20 dispatches / etc.>
- Trend: <increasing | stable | decreasing>

## Evidence
| Session date | weak_point / root_cause | Context |
|--------------|-------------------------|---------|
| 2026-04-19   | dispatch / vague-scope  | Codex wandered on T3, spec was 220 words |
| 2026-04-21   | dispatch / vague-scope  | Same, spec 240 words |

## Hypothesis
<1–2 sentences: what aspect of the skill may need adjustment>

## Proposed Action
- [ ] Investigate via `/co:review` at next scheduled checkpoint
- [ ] Candidate for `/co:promote` if Durability+Impact+Scope total ≥ 6
- [ ] Consider strategy escalation (micro-fix → section rewrite → radical restructure)
- [ ] User judgment needed on whether this is skill-level or host-project-level

---
Auto-generated by claude-codex-orchestration Layer 2.5 External Escalation.
Skill commit: `<short-sha>` | Reported by: session dated `<YYYY-MM-DD>`
```

### Fallback Queue (local, resilient)

When `gh` is unavailable (no auth, offline, rate-limited), write the candidate to `.issue-candidates.jsonl` instead of dropping the signal:

```json
{"date":"2026-04-19","fingerprint":"darwin:dispatch:vague-scope","mechanism":"Darwin regression","evidence":{"sessions":[...],"summary":"..."},"template_body":"<full markdown body>","attempts":0}
```

**Retry cadence:** each Session Start Part 4 (after git-update check), also flush `.issue-candidates.jsonl`:
- For each pending entry → attempt dedup+upload flow
- On success → move to `.issue-log.jsonl` with `{..., "attempts":N, "issue_url":"https://github.com/..."}`
- On failure → increment `attempts`; drop after 5 attempts (avoid infinite retry of broken entries)

### `.issue-log.jsonl` (uploaded / linked)

Append-only record of successful escalations:
```json
{"date":"2026-04-19","fingerprint":"darwin:dispatch:vague-scope","action":"created","issue_url":"https://github.com/dy9759/claude-codex-orchestration/issues/42","attempts":1}
{"date":"2026-04-21","fingerprint":"darwin:dispatch:vague-scope","action":"commented","issue_url":"https://github.com/dy9759/claude-codex-orchestration/issues/42","attempts":1}
```

Both files git-tracked (like `.skill-scores.jsonl`) — future users see what problems have been reported and their current status.

### Hard Safety Rules

- **Target repo is fixed**: always `dy9759/claude-codex-orchestration`, never the host project. `gh issue create --repo dy9759/claude-codex-orchestration` explicit.
- **Dedup first, always**: never create duplicate open issues for the same fingerprint.
- **User awareness**: first time Layer 2.5 escalates in a session, echo a one-line notice: `[Escalation] auto-reported <fingerprint> to skill repo issue <URL>`.
- **Opt-out**: `~/.claude/.orch-escalation-disabled` sentinel disables external escalation entirely (local capture still runs).
- **Does NOT use Question Format Standard** — this is a background channel, not a user interaction. See `decision-protocol.md` note.

### Compare to /co:review + /co:promote

Layer 2.5 is upstream of promotion:
- **Layer 2 (Error Auto-Capture)** — records each failure locally
- **Layer 2.5 (External Escalation)** — when threshold hit, reports to skill repo for community awareness
- **Layer 3 (`/co:review`, `/co:promote`)** — periodic scan, may resolve some escalated issues by promoting fixes

After `/co:promote` writes a new rule into SKILL.md, the corresponding `.issue-candidates.jsonl` entries and matching open issues should be auto-closed with a comment: `"Addressed in <commit>. See SKILL.md §<section>."`

---

## Layer 3: Review & Promote (`/co:review`, `/co:promote`)

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
