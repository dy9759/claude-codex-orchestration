---
name: co-think
description: Pre-task thinking for claude-codex-orchestration (grill / office-hours style). Source-first: inspect repo/docs before asking. Product/Design, Technical/Approach, and Domain/Docs lanes. Ask only user-owned or genuinely ambiguous questions, one at a time, with recommendation + confidence. High-verification-risk fuzzy work becomes a Run Contract before dispatch. Always ends with Premise Challenge. Optional Codex cold-read second opinion. Delegates to references/thinking-decision.md.
---

# /co-think — Pre-Task Thinking

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/thinking-decision.md` §/co-think.

## Quick run

**Source-first rule:**
- Check named docs, `AGENTS.md`, `CONTEXT.md`, `CONTEXT-MAP.md`, `docs/`,
  ADRs, and adjacent code patterns before asking.
- Ask only user-owned decisions: target user, demand premise, public contract,
  security/privacy, data model, paid infra, external service, phase split.
- Derive mechanical choices from the repo; recommend defaults for taste choices.
- Ask one question at a time, with recommendation + confidence.

**Detect lane from context; ask only if unclear:**
- **Product/Design** — new feature / API / workflow
- **Technical/Approach** — implementation unclear
- **Domain/Docs** — project vocabulary, docs, ADRs, or contracts constrain work

**Product mode (5 questions, one-at-a-time):**
1. What's the narrowest version proving the core idea?
2. Who exactly is this for, what are they doing instead today?
3. What's the most likely failure mode?
4. What would a senior engineer say is unnecessary?
5. If you had 2 hours to demo, what would you build?

**Technical mode (5 questions):**
1. What's the coolest version? What makes it good?
2. What existing pattern gets you 50% there?
3. What would you add with unlimited time? (then cut)
4. Fastest path to something verifiable?
5. Which assumption is most expensive if wrong?

**Domain/Docs mode (4 questions):**
1. Which existing doc/code path is source of truth?
2. Which terms/contracts must not be renamed or reinterpreted?
3. Which prior decision or ADR constrains this?
4. What would make this incompatible with current users or agents?

**Escape hatch:** "just do it" or fully formed plan → skip to Premise Challenge only.
For fuzzy + high-verification-risk work, lock a Run Contract before dispatch.

**Premise Challenge (always, after questions):**
```
PREMISES:
1. [statement] — valid / questionable
2. [assumption] — valid / questionable
3. [dependency] — valid / questionable
```

**Optional:** offer Codex cold-read (not auto-run): "Want Codex second opinion?"
