# Maintainability Harness

Applied to **every Codex dispatch** and **every CC write to project files**. These rules live in project `AGENTS.md` so both CC and Codex read them; they also gate integration here.

---

## Non-Negotiable Rules (top of AGENTS.md)

- Prefer clarity over cleverness.
- Keep files under 500 lines when possible.
- Keep functions under 40 lines when possible.
- Keep nesting to 3 levels or fewer.
- One function, one responsibility.
- No magic values.
- No silent error swallowing.
- No unnecessary dependencies.
- New logic requires tests.
- Read existing code before writing new code.
- Match project conventions.
- Make the smallest maintainable change.

---

## 0. First Principle

All code changes optimize for **long-term maintainability over short-term speed**.
- Clarity over cleverness
- Explicitness over magic
- Small safe changes over large risky rewrites

## 1. Scope of Change

- Only change what is necessary for the task
- Do not refactor unrelated areas unless required for correctness or maintainability
- When touching messy code, improve locally; do not expand scope without clear benefit
- Preserve backward compatibility unless the task explicitly allows breaking changes

## 2. File Size and Structure

| Threshold | Action |
|-----------|--------|
| < 300 lines | Preferred |
| < 500 lines | Acceptable |
| ≥ 500 lines | Hard warning — strongly prefer splitting by responsibility |

- Prefer single-responsibility files
- Do not create "god files" that mix API, business logic, persistence, UI, and utilities

## 3. Function Design

| Threshold | Action |
|-----------|--------|
| ≤ 40 lines | Preferred |
| ≤ 80 lines | Hard warning — requires justification |
| > 80 lines | Split |

- One function does one thing
- If a function needs a long comment to explain its flow, split it
- Prefer 0–3 parameters for common functions
- If parameters exceed 5, group them into a typed object / config structure
- Return types must be stable and predictable

## 4. Nesting and Control Flow

| Depth | Action |
|-------|--------|
| ≤ 3 levels | Preferred |
| 4 levels | Refactor unless clearly justified |
| 5+ levels | Must flatten |

Techniques to flatten:
- Guard clauses and early returns
- Helper functions
- Strategy maps
- State machines
- Table-driven logic

## 5. Naming

- Names reveal intent
- Variables answer "what is this"
- Functions answer "what does this do"
- Booleans read naturally: `isReady`, `hasAccess`, `canRetry`
- Include units: `timeoutMs`, `retryDelaySeconds`, `maxRetries`
- Avoid vague names unless generic/justified: `data`, `temp`, `obj`, `info`, `handler`, `process`, `utils`

## 6. Module Boundaries

- Clear separation of concerns
- Business logic not buried inside controllers, routes, views, command handlers
- Data access does not leak everywhere
- Shared utilities stay small and truly reusable
- Avoid circular dependencies
- New modules organized by business domain or stable architectural layer

## 7. Comments and Documentation

- No comments that restate the code
- Comments explain: why this exists, business constraints, non-obvious tradeoffs, edge cases
- Public functions/classes/exported APIs have concise doc comments
- Document surprising behavior
- Document historical-reason workarounds

## 8. Reuse and Duplication (Rule of 3)

- Same logic appears twice → consider extraction
- Same logic appears **three times** → extract it unless strong reason not to
- Do not over-abstract prematurely
- Prefer duplication over bad abstraction when pattern is still unstable

## 9. Types and Interfaces

- Prefer explicit types over implicit assumptions
- Define narrow interfaces
- Do not use weakly-typed "catch-all" structures when a domain type fits
- Validate external input at boundaries
- Keep internal domain models distinct from transport models when needed

## 10. Error Handling

- Never swallow errors silently
- Errors must be actionable and traceable
- Enough context in logs and error messages to debug
- Do not expose raw internal errors to end users
- Fail fast on invalid state unless product requires graceful degradation

## 11. Configuration and Constants

- No magic numbers, strings, or hidden defaults in business logic
- Extract meaningful constants
- Environment-specific values in config, not inline code
- Secrets never hardcoded

## 12. Testing

- New business logic includes tests
- Bug fixes include regression test when feasible
- Tests verify behavior, not implementation trivia
- Prefer small focused tests over broad fragile ones
- Cover: expected path, edge cases, failure path for critical logic

## 13. Observability

- Important flows emit debuggable logs or traces
- Logs structured and useful
- No noisy logging without purpose
- Background jobs / retries / external calls have diagnosable failures

## 14. Dependency Discipline

Before adding a new dependency, answer:
- What problem does it solve?
- Why are existing tools / stdlib insufficient?
- Expected maintenance cost?

Do not add new dependencies casually.

## 15. API and Contract Safety

- Preserve existing contracts unless explicitly asked to change
- If a contract changes, update: callers, tests, docs, migration notes
- Prefer additive change over breaking replacement

## 16. Refactoring Rules

- Refactor in small safe steps
- Do not mix large refactors with feature delivery unless necessary
- Keep commits / patches logically grouped
- If code becomes cleaner but behavior changes, call that out explicitly

## 17. Agent Behavior Rules

When generating or editing code:
1. Read surrounding code before modifying
2. Match existing architecture unless clearly harmful
3. Follow existing naming and layering conventions
4. Minimize diff size while preserving clarity
5. Add or update tests when behavior changes
6. Avoid speculative abstractions
7. Avoid creating new files unless they improve structure
8. Avoid hidden side effects
9. Explain tradeoffs when multiple implementation paths exist
10. Prefer maintainable code over the shortest code

## 18. Hard Red Lines

Do not generate code that:
- Mixes multiple unrelated responsibilities in one file or class
- Introduces deep nesting without justification
- Adds unexplained global state
- Bypasses validation at boundaries
- Duplicates complex logic without reason
- Hardcodes secrets or environment values
- Ignores existing tests or breaks them silently
- Adds dependencies casually
- Leaves dead code after replacement
- Uses misleading names

## 19. Output Requirements (Agent Deliverable)

For every non-trivial code change, provide:
- What changed
- Why this design is maintainable
- Any tradeoffs
- Tests added or updated
- Follow-up refactors worth doing later (if any)

## 20. Decision Rule

When two solutions both work, choose the one that:
- Easier for a new teammate to understand
- Has clearer boundaries
- Is easier to test
- Creates less coupling
- Is safer to modify in six months

---

## Integration Gates (orchestration-specific)

Before accepting Codex output into integration, verify against this harness:

| Gate | Trigger | Action |
|------|---------|--------|
| File size | New file > 500 lines | Reject, request split |
| Function size | Any new function > 80 lines | Flag, request split or justification |
| Nesting | Any new nesting > 3 levels | Flag, request flattening |
| Magic values | Hardcoded numbers/strings in business logic | Flag, request constant extraction |
| Rule of 3 | Same logic ≥ 3 times across diff | Flag, request extraction |
| Error handling | `catch { }` / bare except without context | Reject |
| New dependency | package.json / Cargo.toml / go.mod modified | Dispatch Security Gate — block unless justified |
| Hard red lines | Any item from §18 detected | Reject |

Log violations to `.error-log.jsonl` with category `maintainability`.
