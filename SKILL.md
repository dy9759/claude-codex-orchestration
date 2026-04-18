---
name: claude-codex-orchestration
description: Use when the user wants to coordinate Claude Code + Codex as dual agents, delegate parallel implementation tasks to Codex, split frontend/backend work between agents, or control token consumption during orchestration while maintaining coding output quality.
---

# Claude Code + Codex Orchestration

## Overview

Claude Code = **Tech Lead / Orchestrator**. Codex = **Parallel Implementer**.

**Core principle:** Plan → split cleanly → parallel execute → integrate once. Never two agents on same file simultaneously.

**Announce at start:** "Using claude-codex-orchestration — acting as Tech Lead. Dispatching to Codex where appropriate."

---

## Token Budget Mode (Caveman Integration)

All **agent-internal communication** uses compressed caveman prose to cut ~75% output tokens while preserving full technical substance. This applies to: execution plans, status updates, Codex task specs, inter-phase summaries, subagent briefs, and integration reports.

**Default level: `full`** — drop articles/filler, fragments OK, short synonyms. Switch with `/caveman lite|full|ultra`.

| Level | Use when |
|-------|----------|
| `lite` | User needs readable plan output; remove filler only |
| `full` | Default — classic caveman for all orchestration comms |
| `ultra` | Max token pressure — abbreviate (DB/auth/fn/impl), arrows for causality (X → Y) |

**Never compress:**
- Code blocks (always written normally)
- Security warnings and irreversible action confirmations
- User-facing final deliverables that require clarity
- Multi-step sequences where fragment order risks misread

**Input token reduction:** Before starting a long session, suggest:
> "Run `caveman:compress ~/.claude/CLAUDE.md` to cut input tokens ~46% per session."

---

## Phase 0: Understand Before Splitting

1. Explore repo — identify affected modules and files
2. Clarify ambiguities
3. ID minimum viable change
4. Determine truly independent (parallelizable) vs. coupled (sequential) tasks
5. Decide worktrees needed?

Only then: produce Execution Plan.

---

## Execution Plan Format (Caveman, Required Before Acting)

```
## Plan

[CC] Task A — files: src/api/...
[Codex] Task B — files: src/ui/...

CC owns: backend, scripts, CI/CD, migrations, integration, tests
Codex owns: [specific files/modules]

Worktrees: yes/no → branches + owners
Subagents: yes/no → who, why
Verify: [test command or check]
```

Show plan. Wait for confirm. Then execute.

---

## Default Work Distribution

| Claude Code | Codex |
|-------------|-------|
| Repo explore + design | Frontend pages, UI, interactions |
| Backend logic, APIs, data flow | Screenshot/design-driven fixes |
| Scripts, migrations, CI/CD | Independent feature modules |
| High-risk / cross-cutting changes | Parallel solution attempts |
| Final integration + release | Current diff review |

---

## Dispatching Tasks to Codex (Caveman Format)

Use `codex:codex-rescue` subagent. Task spec MUST be tight caveman prose:

```
Goal: [one-line objective]
Scope: [files/dirs Codex may touch]
Off-limits: [files Codex must NOT modify]
Subagents: yes/no
Worktree: yes/no → branch: [name]
Deliver: change summary, files modified, test results, risks, open Qs
Tone: caveman full — drop filler, fragments OK, code blocks normal
```

Invoke:
```
subagent_type: "codex:codex-rescue"
prompt: [compressed task spec above]
```

**Token rule:** Codex task specs must be <200 words. If draft exceeds that, compress before sending.

---

## Worktree Rules

Create when:
- CC + Codex implement different modules in parallel
- Testing 2+ competing solutions
- Isolating high-risk changes

Rules:
- One writer per worktree — no shared write
- Naming: `feature/<agent>-<desc>` (e.g. `feature/codex-ui-redesign`)
- Merge: diff review → cherry-pick or manual integrate
- See `superpowers:using-git-worktrees` for setup

---

## Subagent Rules

CC subagents: repo research, log analysis, CI triage, test validation, solution comparison.

Codex subagents: parallel candidate impls, local fixes, UI variants, review splitting.

Only use when tasks truly independent — clear input/output/file boundaries. Subagent briefs: caveman `full`, <150 words each.

---

## Conflict Prevention

- Never assign same file to both agents simultaneously
- Never give Codex vague cross-repo task — cut clean boundary first
- Never parallelize coupled tasks
- If in doubt: CC does it, Codex reviews it

---

## Integration Phase (Caveman Status Report Format)

After both agents complete, output:

```
## Integration

Modified: [file list]
Overlaps: [none / list conflicts]
Regressions: [none / describe]
Tests: [pass/fail summary]
Verdict: ready / needs-fix / codex-rejected
```

Steps:
1. List all modified files — check overlaps
2. Review Codex diff for unintended changes
3. Check boundary regressions
4. Run tests
5. Emit verdict

---

## Token Accounting (Per Session)

Track at session end:

```
Input tokens saved: [estimate from compress runs]
Output tokens saved: [caveman level × message count estimate]
Codex dispatch tokens: [task spec word count × dispatches]
Total efficiency gain: [rough %]
```

If total gain < 30%: switch from `full` to `ultra` next session.

---

## Self-Improvement Protocol (Darwin-Inspired)

After each session, score (1-10):

| Dimension | Measures |
|-----------|----------|
| Task split quality | Clean CC/Codex boundaries? |
| Conflict avoidance | File ownership collisions? |
| Plan clarity | Plan prevent ambiguity? |
| Codex dispatch quality | Task spec tight enough? |
| Integration smoothness | Rework needed? |
| Token efficiency | Caveman level effective? |

Improve when any dimension ≤ 6 → rewrite that section.
Ratchet: only keep edits that raise weakest dimension. Revert otherwise.

Log to `~/.claude/skills/claude-codex-orchestration/results.tsv`:
```tsv
timestamp	task	split	conflict	plan	dispatch	integration	tokens	note
```

If 3+ sessions same weak dimension → that section needs full rewrite.
