---
name: co-review
description: Layer 3 promote-candidate review for claude-codex-orchestration. Every 5 sessions (or when .eval-scores.jsonl has 5+ new entries), scan the weak-point + root-cause distribution in recent logs, identify recurring patterns (≥ 2× occurrences), score each candidate on Durability + Impact + Scope (0–3 each), flag those ≥ 6 for /co-promote. Delegates to claude-codex-orchestration references/self-correction.md Layer 3.
---

# /co-review — Promote-Candidate Review (Layer 3)

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/self-correction.md` §Layer 3.

## Quick run

1. Read `.eval-scores.jsonl` + `.error-log.jsonl` in the skill directory
2. Group by `weak_point` and `root_cause`
3. For each recurring pattern (appears ≥ 2 times):
   - Check if SKILL.md / references/ already addresses it
   - Score: **Durability + Impact + Scope** (each 0–3)
   - ≥ 6 → promote candidate (list for `/co-promote`)
   - 4–5 → watch
   - ≤ 3 → ignore
4. Output ordered list of promote candidates with reasoning
5. Suggest user run `/co-promote <candidate>` for the top one

Also check `.issue-log.jsonl` — if an external issue (Layer 2.5) can be closed by promoting this candidate, note that in output.
