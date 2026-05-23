---
name: co-loop
description: Autonomous background refinement loop for claude-codex-orchestration. Runs /co-eval + /co-review, if candidate ≥ 6 runs /co-promote and commits, then schedules next cycle via ScheduleWakeup (270s, stays within cache TTL). Never self-stops — continues until user manually interrupts. Darwin ratchet: next session scoring the promoted dimension must improve or rule is reverted. Strategy escalation for persistent weak points (5/8/12/15+ sessions).
---

# /co-loop — Autonomous Background Refinement

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/self-correction.md` §Layer 3 "Autonomous cron loop".

## Quick run

1. Run `/co-eval` on last session
2. Run `/co-review` to find promote candidates
3. If candidate ≥ 6 → `/co-promote` → `git commit` (triggers Layer 0 score)
4. **CC runtime:** `ScheduleWakeup(270s, "continue /co-loop", "autonomous refinement")` → repeat until user interrupts
5. **Codex runtime (no ScheduleWakeup):** Single execution only. Log: `"[co-loop] Single execution complete. Re-run manually for next cycle."` No auto-scheduling — user must re-invoke.

## Strategy escalation (same weak point ≥ N sessions)

| Stuck sessions | Escalate to |
|---------------|-------------|
| 5 | Micro-fix: rewrite only failing bullet/sentence |
| 8 | Section rewrite: restructure whole failing section |
| 12 | Radical restructure: reconsider section's purpose |
| 15+ | Flag to user: possible structural design flaw |

## Darwin ratchet

After promoting: next session scoring same dimension improves → keep. Doesn't improve → rule was wrong, revert and reclassify root cause.
