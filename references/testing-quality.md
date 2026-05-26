# Testing Quality Gates

Use this reference when a task changes behavior, fixes a bug, adds tests, edits
test infrastructure, or claims verification evidence. The goal is not "more
tests"; the goal is evidence that would fail for the right broken behavior.

Inspired by Google Engineering Practices code-review guidance: tests should be
appropriate to the change, land with the production change except emergencies,
and be reviewed as maintained code.

---

## Test Plan

Replace vague `verify:` entries with a compact Test Plan for non-trivial work.

```text
Test Plan
Change type: <bug fix | new behavior | refactor | API/contract | UI | infra>
Automated tests: <commands and target files>
Expected failure signal: <what would fail if the bug/behavior regresses>
Manual evidence: <none | browser steps | screenshot | logs | demo>
Not tested: <none | reason + residual risk + follow-up>
```

Tiny direct changes may use one sentence, but still name the verification
signal.

---

## Change Type Matrix

| Change type | Minimum test expectation |
|-------------|--------------------------|
| Bug fix | Regression test that fails on old behavior when feasible; include reproduction command or fixture |
| New business logic | Focused unit tests for core branches plus integration test for the main boundary |
| API / contract | Contract or integration tests for request/response/error shape; include backward-compatibility case |
| UI behavior | Browser interaction or component test plus screenshot/a11y evidence when visual behavior matters |
| Refactor | Existing relevant suite green; add characterization tests first if coverage is weak or behavior is subtle |
| Concurrency / cache / retry | Targeted test for ordering, timeout, retry, stale state, or race-risk path; also explain reasoning |
| Test-only change | Show the test would fail for a real broken behavior; do not weaken assertions to make CI pass |
| Docs / copy / config | Verify render/build/parse path when available; otherwise state why automated testing is not useful |

Prefer small focused tests over broad fragile E2E tests. Use the test pyramid
unless the change is explicitly cross-system or user-facing.

---

## Test Quality Review

Tests are code. Review them before accepting a patch:

- Would this test fail if the target behavior broke?
- Are assertions simple, meaningful, and behavior-focused?
- Are different behaviors split into separate test cases?
- Is the setup minimal, readable, and matched to local conventions?
- Are mocks/fakes narrow enough that they do not hide integration failures?
- Is the test deterministic, without sleeps, real network, or order dependence?
- Did the change avoid deleting, weakening, or skipping tests to make CI pass?
- If snapshots are used, is the assertion intentionally visual/structural rather
  than a blanket dump?

Reject tests with no assertions, assertions that only mirror implementation
details, broad snapshots with no intent, or changed expectations that mask a
failure without explaining the behavior change.

---

## No-Test Exception

If automated tests are not added for behavior-changing work, the closeout must
include:

```text
No-test exception
Reason:
Manual evidence:
Residual risk:
Follow-up:
```

Valid reasons are narrow: emergency, impossible-to-automate local hardware,
external service sandbox unavailable, pure documentation/copy with no render
path, or pre-existing test harness absence after a reasonable check.

"Too small", "obvious", or "takes too long" are not valid reasons.

---

## Integration Gate

Before verdict `ready`, the orchestrator checks:

1. Production change and relevant tests are in the same change, unless a no-test
   exception is recorded.
2. The Test Plan names the command and failure signal.
3. Test quality review found no masking, brittle, or assertion-free tests.
4. UI/user-facing changes include runtime/manual evidence when code review alone
   is weak.
5. Concurrency changes include reasoning about race/deadlock/stale-state risks.
