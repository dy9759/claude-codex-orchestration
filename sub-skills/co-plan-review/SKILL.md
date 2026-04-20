---
name: co-plan-review
description: CEO-mode plan review for claude-codex-orchestration. Run after an Execution Plan is drafted. User chooses one of four modes (EXPAND/SELECTIVE/HOLD/REDUCE) dictating posture — dream bigger vs baseline+cherry-pick vs make-bulletproof vs minimum-viable. Seven Prime Directives apply in all modes: zero silent failures / named errors / shadow paths / interaction edge cases / observability-is-scope / deferred-is-written-down / security-is-scope. Critical rule: every scope change is explicit user opt-in. Delegates to references/thinking-decision.md.
---

# /co-plan-review — Strategic Plan Review (CEO-mode)

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/thinking-decision.md` §/co:plan-review.

## Quick run

**Ask user to choose mode first** (Question Format Standard):

| Mode | Posture |
|------|---------|
| **EXPAND** | Dream bigger — 10x version? Push scope up |
| **SELECTIVE** | Hold baseline + AskUserQuestion on each cherry-pick |
| **HOLD** | Make bulletproof — find every failure mode |
| **REDUCE** | Minimum viable — cut anything non-essential |

**Prime Directives (all modes):**
1. Zero silent failures — every failure visible to system/team/user
2. Every error has a name — no catch-all handlers
3. Data flows have shadow paths — nil, empty, upstream-error
4. Interactions have edge cases — double-click, navigate-away, slow conn, stale state
5. Observability is scope — logs/metrics on all new paths
6. Everything deferred is written down — TODOS.md or doesn't exist
7. Security is scope — new codepaths need threat modeling

**Critical rule:** every scope change is an explicit user opt-in. Never silently add or remove scope.
