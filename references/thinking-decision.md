# Thinking & Decision Layer

Two structured thinking modes before acting on complex tasks. Run these **before** producing an Execution Plan when the task is ambiguous, novel, or high-stakes.

---

## `/co-think` — Pre-Task Thinking (grill / office-hours style)

Use `/co-think` before the Execution Plan when the task is fuzzy, the product
wedge is unclear, or the implementation path has multiple plausible shapes.

Operating rules:
- Answer from repo/code/docs before asking. Check named docs, `AGENTS.md`,
  `CONTEXT.md`, `CONTEXT-MAP.md`, `docs/`, ADRs, and adjacent code patterns.
- Ask only user-owned or genuinely ambiguous questions.
- Ask one question at a time. Smart-skip anything already answered or inferable.
- Include a recommendation + confidence when asking per `decision-protocol.md`.
- For fuzzy + high-verification-risk work, switch to a Run Contract before
  dispatch (see `harness-workflows.md`).

Decision ownership:

| Decision type | Examples | Action |
|---------------|----------|--------|
| User-owned | target user, demand premise, public contract, security/privacy, data model, paid infra, external service, phase split | Ask explicitly |
| Mechanical | local conventions, imports, framework patterns, file naming, existing test command | Derive from repo/docs |
| Taste | copy tone, layout preference, naming alternatives, non-critical UX polish | Recommend a default; surface at checkpoint if material |

Question lanes — detect from context; ask the lane only if unclear:

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
5. Which assumption would be most expensive if wrong?

**Domain/Docs mode** (existing domain language or project rules matter):
1. Which existing doc/code path is source of truth?
2. Which terms/contracts must not be renamed or reinterpreted?
3. Which prior decision or ADR constrains this?
4. What would make this change incompatible with current users or agents?

**Escape hatch:** If the user says "just do it" or provides a fully-formed plan → skip to Premise Challenge only.

**Premise Challenge** (always runs after questions):
```
PREMISES:
1. [statement] — orchestrator assessment: valid / questionable
2. [statement] — orchestrator assessment: valid / questionable
3. [assumption this approach depends on] — orchestrator assessment: valid / questionable
```
Proceed when premises are confirmed. If a premise is wrong → revise approach before splitting.

**Cross-model second opinion** (optional — offer, don't auto-run):
> "Want a Codex cold read on this? It gets a structured summary without having seen this conversation."

If yes → dispatch via Codex Co-Decision Protocol with assembled context. Report findings as-is.

---

## `/co-plan-review` — Strategic Plan Review (CEO review style)

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
