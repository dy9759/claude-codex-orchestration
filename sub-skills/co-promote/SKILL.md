---
name: co-promote
description: Layer 3 promote-to-SKILL for claude-codex-orchestration. Take a candidate identified by /co-review (Durability + Impact + Scope ≥ 6), distill from descriptive to prescriptive, write the rule into SKILL.md or appropriate reference file, remove source .error-log.jsonl entries, trigger Layer 0 auto-score and README sync. Ratchet rule enforces next same-dimension session must improve or revert. Delegates to claude-codex-orchestration references/self-correction.md Layer 3.
---

# /co-promote — Write Candidate Rule into Skill (Layer 3)

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/self-correction.md` §Layer 3.

## Quick run

1. Take the candidate from `/co-review` output (must have score ≥ 6)
2. **Distill from descriptive → prescriptive:**
   - ❌ "Codex kept asking about scope"
   - ✅ "If Codex task spec exceeds 200 words, compress before sending"
3. Pick target file (SKILL.md for core rules; references/*.md for detailed mechanics)
4. Apply simplicity criterion: shorter rewrite at same score wins
5. Write the change; trigger Layer 0 auto-score + README sync per rule
6. Remove source `.error-log.jsonl` entries
7. If a Layer 2.5 `.issue-log.jsonl` issue matches → auto-close with comment "Addressed in `<commit>`. See SKILL.md §`<section>`."
8. **Ratchet:** next session scoring the same dimension must improve, else revert
