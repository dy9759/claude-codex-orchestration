# Harness Workflow Patterns

Use this reference when a task is fuzzy, long-running, high-verification-risk,
or likely to cross from planning into multi-agent execution. It captures the
small reusable patterns worth borrowing from external harnesses without
vendoring their full command surfaces.

---

## Task Shape Matrix

Classify by clarity and verification risk before choosing a workflow.

| Shape | Default action | Examples |
|-------|----------------|----------|
| Fuzzy + low verification risk | Run `/co-think` in grill/office-hours style, then draft a small plan | New idea, copy/workflow tweak, low-risk UX choice |
| Fuzzy + high verification risk | Lock a Run Contract before execution; do not dispatch yet | Data model, migration, public API, security, complex refactor |
| Clear + low verification risk | Use normal capability routing; Codex-first for bounded bug/detail work | Known bug, small script, isolated backend change |
| Clear + high verification risk | Run Contract + Execution Plan + Proof Pack closeout | Long-running refactor, release, CI, visual/UI QA, irreversible ops |

`roboharness` proof packs are a verification pattern, not a separate routing
lane: use proof packs whenever review cost is high or human trust needs compact
evidence.

---

## Run Contract

For durable, high-risk, or whole-flow runs, lock this before the Execution Plan.
If the user already supplied all fields, summarize and proceed; otherwise ask
only for missing or materially risky fields.

```text
Run Contract
Goal: <concrete outcome>
Success criteria: <observable done signals>
Stop condition: <reviewed plan | implemented+verified | PR-ready | report-only>
Boundaries/non-goals: <scope, cost, safety, compatibility limits>
Verification risk: <low | medium | high> because <one sentence>
```

Hard-stop fields:
- user, demand premise, public contract, data model, security/privacy, paid
  infrastructure, external service, destructive action, local hardware, or API
  keys
- high-risk operations already blocked by `runtime-routing.md`
- multiple plausible phase/ownership splits

If a contract cannot be grounded safely, stop and ask. Do not turn an ambiguous
contract into a broad Codex or CC dispatch.

---

## Route Brief

Before non-trivial edits or dispatches, show a compact route brief. For tiny
direct fixes, one sentence is enough.

```text
Current state: <fuzzy idea | clear bug | draft plan | approved plan | changed code>
Selected path: <direct | /co-think | /co-plan-review | dispatch | external handoff>
Why: <one sentence>
Bypassed/left behind: <stage - reason; stage - reason>
Execution surface: <main session | Codex dispatch | CC dispatch | worker/subagent>
Stop/continue point: <where this run pauses or what completion means>
Proof expected: <commands, artifacts, screenshots, reports>
```

The route brief exists to make shortcuts visible. Do not run every stage just
because it exists.

---

## Proof Pack Closeout

Use a proof pack when a task is long-running, high-risk, user-facing, visual, or
would be hard to review from a raw diff alone.

```text
Proof Pack
Goal: <contract goal or plan task>
Changed files: <list>
Commands run: <command -> pass/fail/notes>
Artifacts: <screenshots, reports, logs, URLs, generated files>
Evidence summary: <what proves it works>
Risks/open questions: <none or list>
Approval needed: <none | user must bless baseline/release/destructive action>
```

Rules:
- Metrics/tests are the hard floor; screenshots or model review are supporting
  evidence.
- Surface changed/ambiguous cases first; do not make the user review unchanged
  noise.
- `AMBIGUOUS` never self-promotes to `PASS`; gather more evidence or ask.
- For new baselines, releases, destructive ops, and high-risk acceptance, user
  blessing is explicit.

---

## Optional External Handoff

These projects are references or optional tools. Do not copy their command
trees into this skill.

| External surface | Use when | How this skill should interact |
|------------------|----------|--------------------------------|
| `mattpocock/skills` `grill-me` / `grill-with-docs` | Requirements are fuzzy or domain language is unclear | Borrow the question discipline in `/co-think`; if installed and user asks, invoke directly |
| `gstack` `office-hours` | Product direction, wedge, demand, or "is this worth building" is unclear | Borrow forcing-question posture; do not vendor gstack preambles/telemetry |
| `gstack` `autoplan` | A plan file exists and user wants a full review gauntlet | Treat as optional review before execution; reconcile accepted decisions into the plan |
| `GSD` / `get-shit-done-redux` | Large phase-based work needs discuss -> plan -> execute -> verify state | Suggest or use as external handoff when installed; otherwise emulate only the phase discipline |
| `MiaoDX/intuitive-flow` | A fuzzy idea must become a durable plan and then a verified run | Borrow source-of-truth, run contract, route brief, worker handoff |
| `MiaoDX/roboharness` | Review needs compact metric/visual evidence | Borrow proof-pack and contract-before-prompt patterns, not robot-specific gates |

Handoff rule: if an external workflow actually runs, report its artifacts. If
this skill only borrows the idea inline, label the output as
`claude-codex-orchestration`, not as GSD/gstack/intuitive-flow output.

---

## Source Of Truth

Keep one authoritative artifact family per stage:

| Stage | Source of truth |
|-------|-----------------|
| Before execution | Execution Plan, `docs/plans/*.md`, issue, or explicitly named user doc |
| During execution | task board, worker handoff, active branch/worktree, verification logs |
| After execution | proof pack, integration summary, PR/commit, release/closeout notes |

Generated review logs, chat history, screenshots, and temporary notes are
evidence. Promote only the accepted decisions into the current source of truth.
