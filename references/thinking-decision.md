# Thinking & Decision Layer

Two structured thinking modes before acting on complex tasks. Run these **before** producing an Execution Plan when the task is ambiguous, novel, or high-stakes.

---

## `/co:think` — Pre-Task Thinking (office-hours style)

Two modes — detect from context or ask:

**Product/Design mode** (new feature, API design, workflow change):
Ask these one at a time — wait for each response before asking the next. Smart-skip if already answered.
1. What's the narrowest version that proves the core idea?
2. Who exactly is this for, and what are they doing today instead?
3. What's the most likely failure mode?
4. What would a senior engineer say is unnecessary here?
5. If you had 2 hours to demo this, what would you build?

**Technical/Approach mode** (implementation unclear, multiple valid approaches):
1. What's the coolest version of this? What makes it genuinely good?
2. What existing pattern or code gets you 50% there?
3. What would you add with unlimited time? (then ruthlessly cut back)
4. What's the fastest path to something verifiable?

**Escape hatch:** If the user says "just do it" or provides a fully-formed plan → skip to Premise Challenge only.

**Premise Challenge** (always runs after questions):
```
PREMISES:
1. [statement] — CC assessment: valid / questionable
2. [statement] — CC assessment: valid / questionable
3. [assumption this approach depends on] — CC assessment: valid / questionable
```
Proceed when premises are confirmed. If a premise is wrong → revise approach before splitting.

**Cross-model second opinion** (optional — offer, don't auto-run):
> "Want a Codex cold read on this? It gets a structured summary without having seen this conversation."

If yes → dispatch via Codex Co-Decision Protocol with assembled context. Report findings as-is.

---

## `/co:plan-review` — Strategic Plan Review (CEO review style)

Run after an Execution Plan is drafted. Ask user to choose mode first:

| Mode | Posture |
|------|---------|
| **EXPAND** | Dream bigger — what's the 10x version? Push scope up. |
| **SELECTIVE** | Hold scope baseline + surface cherry-pick improvements via AskUserQuestion |
| **HOLD** | Make current plan bulletproof — find every failure mode |
| **REDUCE** | Minimum viable version — cut everything not essential to core outcome |

**Prime Directives** (apply regardless of mode):
1. **Zero silent failures** — every failure mode must be visible to the system, team, and user
2. **Every error has a name** — no catch-all handlers; name the specific exception + what triggers it
3. **Data flows have shadow paths** — for every new data flow: nil input, empty input, upstream error
4. **Interactions have edge cases** — double-click, navigate-away, slow connection, stale state
5. **Observability is scope** — logs/metrics on all new paths; not optional, not afterthought
6. **Everything deferred is written down** — TODOS.md or it doesn't exist
7. **Security is scope** — new codepaths need threat modeling

**Critical rule:** Every scope change is an explicit user opt-in. Never silently add or remove scope.
