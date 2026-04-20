---
name: co-eval
description: Layer 1 session self-eval for claude-codex-orchestration. Two-axis rating (Ambition × Execution) with locked 3×3 composite matrix (score 1–5), mandatory Devil's Advocate (argue lower AND higher before committing), anti-inflation check (last 5 entries, 4+ identical flags). Persists to .eval-scores.jsonl. Run at session end or when long-session prompt triggers (≥10 dispatches OR ≥6h since last eval). Delegates to claude-codex-orchestration references/self-correction.md Layer 1.
---

# /co-eval — Session Self-Eval (Layer 1)

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/self-correction.md` §Layer 1.

## Quick run

1. **Axis A — Ambition:** Low / Medium / High (orchestration complexity attempted)
2. **Axis B — Execution:** Poor / Adequate / Strong (how it went)
3. **Devil's Advocate (mandatory):** argue lower → argue higher → commit to final
4. **Lookup score** in locked 3×3 composite matrix (1–5)
5. **Anti-inflation:** read last 5 `.eval-scores.jsonl` entries; 4+ identical → flag
6. **Write** `{"date","score","ambition","execution","task","weak_point"}` to `.eval-scores.jsonl`
7. **Reset long-session counters:**
   ```bash
   rm -f ~/.claude/skills/claude-codex-orchestration/.last-eval-dispatch-count
   rm -f ~/.claude/skills/claude-codex-orchestration/.last-eval-timestamp
   ```

## If no orchestration session happened (meta case)

If the current session was **building** the skill (not using it), `/co-eval` does not apply — use `/co-score` instead (Layer 0 skill edit rubric).
