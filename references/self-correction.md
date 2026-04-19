# Self-Correction System

Four-layer mechanism: **score skill edits → evaluate sessions → capture errors → promote learnings**.

---

## Layer 0: Skill Modification Score (`/co:score`) — auto-fire after every skill edit

**Trigger:** Any commit that modifies `SKILL.md`, `references/*.md`, `CLAUDE.md.template`, or the AGENTS.md template inside `references/session-start.md`.

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
