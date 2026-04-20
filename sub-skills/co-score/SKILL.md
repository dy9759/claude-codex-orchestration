---
name: co-score
description: Layer 0 skill-modification score for claude-codex-orchestration. Auto-fire after any commit touching SKILL.md / references/*.md / README.md / CLAUDE.md.template / AGENTS.md template. Two-step process — Step 1 README coherence check (grep README for changed skill-file references, verify descriptions still accurate, update in same commit if stale), Step 2 8-dimension weighted score (Design 20% / Docs 15% / Self-Containment 15% / Cross-Harness 10% / Executability 15% / Validation 10% / Engineering 10% / Usability 5%). Single-dim drop ≥3 requires justification. Append to git-tracked .skill-scores.jsonl. Delegates to references/self-correction.md Layer 0.
---

# /co-score — Skill Modification Score (Layer 0)

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/self-correction.md` §Layer 0.

## Quick run (2 steps)

### Step 1 — README coherence check
For each changed skill file, grep README.md for references:
- Reference found + description still accurate → note "README unchanged, only internal X modified"
- Reference found + description stale → update README in same commit
- No reference → skip

### Step 2 — 8-dim weighted score (rubric locked)

| Dim | Weight | Criterion |
|-----|:---:|------|
| Design Completeness | 20% | Covers stated scope? |
| Documentation Quality | 15% | Navigable by new reader? |
| Self-Containment | 15% | Works without external plugins / specific CLAUDE.md? |
| Cross-Harness Coverage | 10% | Works on CC+Cursor+Codex+OpenCode? |
| Executability | 15% | Can CC follow rules without guessing? |
| Validation Evidence | 10% | Exercised in real sessions? Data populated? |
| Engineering Rigor | 10% | Locked evaluator, anti-inflation, ratchet rules? |
| Usability | 5% | Fast adoption? |

Score each 0–100. Devil's Advocate (argue lower AND higher) before committing.

### Output (commit message footer)

```
Skill score: N.N/100 (Δ vs prior: +/-N.N)
Dims: design N(+/-N) docs N(+/-N) ... (all 8)
Top changes: <dim> +N, <dim> +N
Regressions: <if any, with justification>
```

Append one JSONL line to `.skill-scores.jsonl` (git-tracked).

### Regression rule
Any single dim drop ≥ 3 requires explicit justification in commit message footer.

### Locked evaluator
Rubric weights are immutable. Argue in commit, don't edit the rubric.
