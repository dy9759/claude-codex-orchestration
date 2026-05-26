# Engineering Principles Layer

Applied rules derived from production engineering discipline. These fire as **decision gates** during orchestration — not background knowledge, active checks.

See also: `maintainability-harness.md` for 20-section code-output standards (file size, function size, nesting, naming, Rule of 3, dependency discipline, hard red lines).

---

## Common Rationalizations → Block Them

When CC or Codex output contains these — flag and reject:

| Rationalization | Block with |
|-----------------|-----------|
| "It's too simple to test" | Beyoncé Rule: if it matters, it has a test |
| "We'll refactor later" | Later = never. If it's wrong now, fix now |
| "This is just configuration" | Config errors propagate; review same as code |
| "Feature flags are too complex" | Feature flags enable rollback; complexity is the price |
| "No time to document" | Missing docs cost more in rework than writing them |
| "It's temporary" | Temporary code becomes permanent |
| "Tests make this too slow" | Tests find bugs before users do |
| "This is just a small fix" | Small fixes still need the full review gates |
| "Nobody depends on this behavior" | Hyrum's Law — someone always does |

---

## API Design — Hyrum's Law Gate

Before any Codex task that touches public API surface:
> **Hyrum's Law:** With enough users, ALL observable behaviors will be depended on — including undocumented ones.

Checklist:
- Are you exposing more than you intend? (response fields, error shapes, timing)
- Is every exposed behavior intentional and documented?
- Is the error semantics consistent across all endpoints?
- Does adding this break backward compatibility for existing dependents?

If any "no" → flag before dispatching. Changing observable behavior later costs 10× more than designing it right.

---

## Testing — Beyoncé Rule + Test Pyramid

**Beyoncé Rule:** "If you liked it, you should have put a test on it." Any behavior worth keeping has a test protecting it.
- Bug fix with no regression test → reject; write the failing test first
- New behavior with no test → flag before integrating
- Test edits are reviewed as production code: they must be correct, useful, and able to fail for the right broken behavior

**Test Pyramid** (enforce proportions in Codex output):
```
         [E2E ~5%]
       [Integration ~15%]
     [Unit tests ~80%]
```
If Codex returns integration-heavy or E2E-heavy test suite → flag as pyramid violation.

**TDD / characterization gate:** For bug fixes and new business behavior, prefer RED first: reproduce failing behavior, write minimal code to pass, then refactor. For refactors, UI polish, docs, scripts, or config, require either existing relevant tests green or characterization tests before changing subtle behavior. If automated tests are not added, record a no-test exception per `testing-quality.md`.

---

## Code Review — Change Sizing + Review Speed

**Change sizing** (apply to every Codex dispatch and integration):

| Size | Verdict |
|------|---------|
| ≤ 100 lines | Good — reviewable in one sitting |
| ≤ 300 lines | Acceptable for single logical change |
| 300–1000 lines | Flag — split if possible |
| > 1000 lines | Reject — must split before integration |

**Review speed rule:** Integration review produces a verdict within the same session. No "review later" deferrals — deferred reviews become technical debt.

**Five-axis review** (apply at integration phase):
1. **Correctness** — matches spec, handles edge cases, tests pass
2. **Readability** — another engineer understands without explanation
3. **Architecture** — fits system design, no circular dependencies
4. **Security** — input validated, no secrets, auth checks present
5. **Performance** — no N+1 patterns, no unbounded loops

---

## Simplification — Chesterton's Fence

Before allowing Codex to delete, remove, or "simplify" any existing code:
> **Chesterton's Fence:** Don't remove something until you understand why it was put there.

Required check: CC must identify the purpose of the removed code before approving. If purpose unknown → keep it and document it, or ask the user.

Applies to: "dead code," unused variables, "redundant" checks, commented-out blocks, seemingly overcomplicated logic.

---

## Git Workflow — Trunk-Based Development

Worktree branches created for this orchestration session must be short-lived:
- Feature branches: merge or discard within **1–3 days** (never long-lived)
- Each commit: one logical change, < 300 lines preferred
- "Long-lived branches are hidden costs — they diverge, conflict, and delay integration"
- Prefer feature flags over long-lived branches for incomplete work
- Clean up: delete merged branches after integration

**Branch naming:** `feature/<agent>-<desc>`, `fix/<agent>-<desc>`, `chore/<agent>-<desc>`

---

## CI/CD — Shift Left + Feature Flags

**Shift Left:** Catch issues at commit time, not deployment time.
- Every Codex implementation task includes: linting + type check + unit test command
- No gate can be skipped — if linting fails, fix code; don't disable rules
- CC responsibility: define a Test Plan for each non-trivial task that includes at minimum `test + lint` and the expected failure signal

**Feature Flags** (require for new user-visible features):
- New features go behind a flag: `OFF → team → 5% → 25% → 50% → 100% → cleanup`
- Deployment ≠ release — flag lets you deploy safely and release deliberately
- Rollback = turn off flag; no redeployment needed

Codex task spec for new features must include flag wrapper or explicitly note "flag deferred — explain why."

---

## Deprecation Protocol

Structured lifecycle for any API, endpoint, or interface removal:

**Decision gate** (before deprecating — answer all):
1. Does the old system still provide unique value?
2. How many consumers depend on it?
3. Does a replacement exist?
4. What's the migration cost per consumer?
5. What's the ongoing cost of NOT deprecating?

**Advisory vs. Compulsory:**
- **Advisory** (default): migration optional, old system stable, communicate via warnings + docs
- **Compulsory**: only when security risk or blocks progress; provide hard deadline + tooling + support

**Migration strategies** (assign one before dispatching Codex):

| Pattern | When |
|---------|------|
| Strangler | Run old + new in parallel, route gradually |
| Adapter | Translate old interface → new implementation |
| Feature Flag | Switch consumers one at a time |

**Churn Rule:** If CC owns the deprecated interface → CC bears responsibility for migrating consumers or providing backward-compatible adapters. Never deprecate without a migration path.
