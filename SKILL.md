---
name: claude-codex-orchestration
description: Use when coordinating Claude Code + Codex as dual agents with Gemini as frontend/UI specialist consultant (via gemini-cli MCP), delegating parallel implementation of bounded modules to Codex, splitting work by boundary-clarity not domain, controlling token consumption, cross-harness setup (Cursor/Codex/OpenCode), pre-task thinking (/co-think), strategic plan review (/co-plan-review), engineering principles enforcement (Hyrum, Beyoncé, Chesterton, trunk-based, shift-left, feature-flags, deprecation, maintainability harness), UI style standard (shadcn/radix-nova), and knowledge compounding. Self-contained; optional plugins and Gemini MCP auto-detected.
---

# Claude Code + Codex Orchestration

## Overview

Runtime agent = orchestrator. Task routing by capability matrix, not runtime identity. CC and Codex are symmetric orchestrators — whoever is runtime dispatches to the other by capability. Gemini = frontend/UI specialist consultant (optional, via `gemini-cli` MCP).

**Core:** Plan → split cleanly → parallel execute → integrate once. Single writer per file. Gemini consults; orchestrator always implements and verifies.

**Announce at start:** "Using claude-codex-orchestration — orchestrating from [runtime]. Routing by capability matrix. Dispatching to [available agents] as needed."

---

## Self-Sufficient Core Rules (apply even without matching CLAUDE.md)

These hold regardless of what's in the host machine's CLAUDE.md:

1. **Pre-push gate** — before any `git push`, ask user: `"是否需要触发一次全量代码审核？"`
2. **AGENTS.md write redirect** — all agent instructions / rules / conventions go to **project `AGENTS.md`**, never `CLAUDE.md`. CLAUDE.md stays as single-line `@AGENTS.md` pointer. Exception: modifying the pointer itself.
3. **Token Budget** — agent-internal comms compressed (`full` default: drop articles, fragments OK, short synonyms). Never compress: code blocks, security warnings, user deliverables. User can say "switch to lite/ultra".
4. **Execution Plan required** — never write code without a Plan confirmed by user. For durable/high-risk/whole-flow tasks, lock a Run Contract first. Every task has explicit `verify:` step.
5. **Single writer per file** — never assign same file to both agents simultaneously.
6. **Size limits** — new files ≤ 500 lines; functions ≤ 80 lines; nesting ≤ 3 levels. Flag violations at integration.
7. **Session Start (first invocation)** — run `session-start.md` protocol: (1) optional plugin detection, (2) AGENTS.md bootstrap, (3) global `~/.claude/CLAUDE.md` §5.2 auto-seed + version check, (4) skill self-update check (every 3 days, `git fetch origin main` + offer pull if behind), (5) escalation queue flush, (6) sub-skill install check (seed `/co-*` registered commands from `sub-skills/` if missing). All gated by sentinels; silent after first effective run.
8. **Post-edit score** — after any commit that modifies `SKILL.md`, `references/*.md`, `README.md`, or `CLAUDE.md.template`, compute the 8-dimension weighted score (see `self-correction.md` Layer 0) and append one line to `.skill-scores.jsonl`. Any single-dim drop ≥3 vs prior commit → justify in the commit message footer.
9. **Every question includes a recommendation** — any user-facing interaction (pre-flight decisions, end-of-plan review, blocking interrupts, mode selection, y/n confirmations) must include: (a) options with one-line tradeoff, (b) **explicit recommendation** with confidence level, (c) agent views where relevant — CC always, Codex on code/arch questions, Gemini on UI/design. See `references/decision-protocol.md` §Question Format Standard.
10. **Capability routing** — task assignment by agent capability matrix (`references/runtime-routing.md`), not runtime identity. Bug fixes and detail changes in an existing project are **Codex-first** when scope is bounded and verifiable; exceptions: repo-wide architecture, frontend/UI judgment, cross-cutting refactors, unclear ownership, or Codex unavailable/unstable. High-risk ops (DB/env/secrets/package manifests/CI/release/destructive ops) are never auto-dispatched: current orchestrator writes a plan and asks explicit approval first. CC as runtime dispatches to Codex; Codex as runtime executes locally or dispatches to CC by the same matrix.
11. **Heartbeat on dispatch** — every cross-agent dispatch includes heartbeat monitoring (L1 process alive / L2 progress / L3 semantic). Fallback on STALLED/DEAD/TIMEOUT per `references/heartbeat-protocol.md`.
12. **Layer 2.5 External Escalation** — structural skill-level signals (recurrent root cause ≥2/7 sessions, Codex quality hard-stop, Darwin regression, structural flaw persisting 5+ sessions) auto-report to **skill repo** (`dy9759/claude-codex-orchestration`), not host project. Dedup by fingerprint `mechanism:category:root_cause`. Fallback queue `.issue-candidates.jsonl` when `gh` unavailable. Opt-out via `~/.claude/.orch-escalation-disabled`. See `references/self-correction.md` Layer 2.5.

---

## Reference Index

Deep content lives in `references/` — load **only when needed** by task type. Each row's description must match well enough for CC to auto-route.

| Need | File | When to load |
|------|------|--------------|
| **Session bootstrap** (plugin detection + AGENTS.md migration + Data File Lifecycle) | `references/session-start.md` | First skill invocation in a session; CLAUDE.md ↔ AGENTS.md state unclear |
| **Workflow core** (Phase 0 → Plan format → Work Distribution → Codex/Gemini summary → Worktree/Subagent/Conflict → Quality Gates → Integration Phase) | `references/workflow-core.md` | Starting any non-trivial task |
| **Decision protocol** (pre-flight batching + mid-execution queue + end-of-plan consolidated review + Priority 1–4 cascade) | `references/decision-protocol.md` | Plan has multiple anticipated user decisions; between-tasks priority flow |
| **Codex full protocol** (invocation + co-decision + security gate + quality tracking + task board) | `references/codex-protocol.md` | Before any Codex dispatch |
| **Gemini integration** (when/how to consult + routing vs Codex + hook config) | `references/gemini-integration.md` | Frontend/UI task that may need design input |
| **Thinking layer** (`/co-think` grill/office-hours + `/co-plan-review` CEO review) | `references/thinking-decision.md` | Ambiguous/novel task before Plan; CEO-mode plan critique |
| **Harness workflows** (clarity × verification risk, Run Contract, Route Brief, Proof Pack, optional GSD/gstack/intuitive-flow/roboharness handoff) | `references/harness-workflows.md` | Fuzzy, high-verification-risk, long-running, or external-handoff tasks |
| **Knowledge compounding** (`/co-compound` 4-subagent pipeline + `/co-sessions` cross-session search) | `references/knowledge-compounding.md` | After resolving non-trivial problem; before complex work to check history |
| **Self-correction** (3-layer eval/capture/promote + `/co-eval` `/co-review` `/co-promote` `/co-loop`) | `references/self-correction.md` | Session end; every 5 sessions; autonomous refinement |
| **Cross-harness setup** (CC/Cursor/Codex/OpenCode config maps + hook translation) | `references/cross-harness.md` | Harness migration; setting up new project |
| **Engineering principles** (Hyrum, Beyoncé, Test Pyramid, Chesterton, Trunk-based, Shift Left, Feature Flags, Deprecation, Change Sizing, Common Rationalizations) | `references/engineering-principles.md` | Integration review; every Codex task gate |
| **Maintainability harness** (20-section spec: file size, function size, nesting, naming, Rule of 3, typed interfaces, error handling, deps, Hard Red Lines) | `references/maintainability-harness.md` | Seeds AGENTS.md Non-Negotiable Rules; enforced at integration |
| **UI style standard** (shadcn/radix-nova default `components.json` + secondary style library + webpage style extraction + frontend Hard Red Lines) | `references/ui-style-standard.md` | Any frontend work; "make it look like [URL]" requests |
| **Runtime routing** (capability matrix + routing algorithm + cross-agent invocation + plan labels) | `references/runtime-routing.md` | Any task dispatch; runtime is not CC; planning agent assignment |
| **Heartbeat protocol** (3-level detection + state machine + fallback + task board extension) | `references/heartbeat-protocol.md` | Cross-agent dispatch monitoring; background task tracking |
| **Codex runtime** (CC dispatch templates + Codex-native Plan + sub-skill compat + CC quality tracking) | `references/codex-runtime.md` | Codex is orchestrator; dispatching to CC |
| **Context budget** (phase thresholds + compact-guard + identity re-injection + Smart Tool RAG) | `references/context-budget.md` | Context > 60% used; stuck mid-session |

---

## Invocation Commands (registered slash commands — use `/co-*` with hyphen)

> These are **registered Claude Code skills** (each has its own dir under `~/.claude/skills/co-*`). Appear in `/` command palette and autocomplete. The `/co:*` form (colon) was the old mnemonic — use **`/co-*` (hyphen)** going forward.

| Command | Purpose | Delegates to |
|---------|---------|-------------|
| `/co-think` | Pre-task ambiguity resolution (product/technical mode) | `thinking-decision.md` |
| `/co-plan-review` | CEO-mode Plan critique (EXPAND/SELECTIVE/HOLD/REDUCE) | `thinking-decision.md` |
| `/co-score` | Score this skill edit on 8 dims, append to `.skill-scores.jsonl` (auto-fire after skill file commits) | `self-correction.md` |
| `/co-eval` | Session end two-axis score + reset long-session counters | `self-correction.md` |
| `/co-review` | Every 5 sessions — scan error log, find promotion candidates | `self-correction.md` |
| `/co-promote` | Write ≥6-score candidate back into SKILL.md | `self-correction.md` |
| `/co-loop` | Autonomous cron-driven refinement | `self-correction.md` |
| `/co-compound` | Capture solution → `docs/solutions/` via 4-subagent pipeline | `knowledge-compounding.md` |
| `/co-sessions` | Search prior CC/Codex sessions for similar problems | `knowledge-compounding.md` |

**First-time install** (fresh machine clone):
```bash
bash ~/.claude/skills/claude-codex-orchestration/sub-skills/install.sh
```
Or let Session Start handle it automatically (see below).

**Codex runtime install:** run `bash sub-skills/install-codex.sh [project-root]` from this repo. It copies the skill bundle to `.codex/orchestration/` and inserts an AGENTS.md managed block so Codex can treat `/co-*` tokens as natural-language workflow triggers.

---

## Design Principles

1. **Self-contained** — no mandatory external plugins; optional plugins auto-detected
2. **Plan before execute** — no code without approved Execution Plan
3. **Single writer per file** — hard rule, always
4. **Token-aware** — agent-internal comms compressed; code + user deliverables full
5. **Human-in-loop minimization** — Codex Co-Decision only when available, healthy, and likely to save time; skip it for obvious choices, user-mandated choices, high-risk approval, or cases where asking the user is faster. User decisions stay batched at plan edges
6. **Self-correcting** — 3-layer mechanism with locked evaluator to prevent score-gaming
7. **Cross-harness** — AGENTS.md as universal baseline, CLAUDE.md as pointer
8. **Maintainability over speed** — optimize for 6-month readability, not line count
9. **Progressive loading** — SKILL.md is a router; deep content loads on demand from `references/`
