---
name: co-think
description: Pre-task thinking for claude-codex-orchestration (office-hours style). Two modes — Product/Design (5 forcing questions: narrowest version / target user / likely failure / senior-engineer cut / 2-hour demo) and Technical/Approach (4 generative questions: coolest version / 50% existing / unlimited-time then cut / fastest verifiable path). Ask questions one-at-a-time, smart-skip if already answered. Always ends with Premise Challenge. Optional Codex cold-read second opinion. Delegates to references/thinking-decision.md.
---

# /co-think — Pre-Task Thinking

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/thinking-decision.md` §/co-think.

## Quick run

**Detect mode from context or ask user:**
- **Product/Design** — new feature / API / workflow
- **Technical/Approach** — implementation unclear

**Product mode (5 questions, one-at-a-time):**
1. What's the narrowest version proving the core idea?
2. Who exactly is this for, what are they doing instead today?
3. What's the most likely failure mode?
4. What would a senior engineer say is unnecessary?
5. If you had 2 hours to demo, what would you build?

**Technical mode (4 questions):**
1. What's the coolest version? What makes it good?
2. What existing pattern gets you 50% there?
3. What would you add with unlimited time? (then cut)
4. Fastest path to something verifiable?

**Escape hatch:** "just do it" → skip to Premise Challenge only.

**Premise Challenge (always, after questions):**
```
PREMISES:
1. [statement] — valid / questionable
2. [assumption] — valid / questionable
3. [dependency] — valid / questionable
```

**Optional:** offer Codex cold-read (not auto-run): "Want Codex second opinion?"
