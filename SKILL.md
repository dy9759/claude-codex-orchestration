---
name: claude-codex-orchestration
description: Use when coordinating Claude Code + Codex as dual agents with Gemini as frontend/UI specialist consultant (via gemini-cli MCP), delegating parallel implementation of bounded modules to Codex, splitting work by boundary-clarity not domain, controlling token consumption, cross-harness setup (Cursor/Codex/OpenCode), pre-task thinking (/co:think), strategic plan review (/co:plan-review), engineering principles enforcement (Hyrum, Beyoncé, Chesterton, trunk-based, shift-left, feature-flags, deprecation, maintainability harness), UI style standard (shadcn/radix-nova), and knowledge compounding. Self-contained; optional plugins and Gemini MCP auto-detected.
---

# Claude Code + Codex Orchestration

## Overview

CC = Tech Lead + primary executor. Codex = bounded backend/script implementer. Gemini = frontend/UI specialist consultant (optional, via `gemini-cli` MCP).

**Core:** Plan → split cleanly → parallel execute → integrate once. Single writer per file. Gemini consults; CC always implements and verifies.

**Announce at start:** "Using claude-codex-orchestration — acting as Tech Lead. Dispatching to Codex for bounded modules; consulting Gemini on frontend/UI as needed."

---

## Self-Sufficient Core Rules (apply even without matching CLAUDE.md)

These hold regardless of what's in the host machine's CLAUDE.md:

1. **Pre-push gate** — before any `git push`, ask user: `"是否需要触发一次全量代码审核？"`
2. **AGENTS.md write redirect** — all agent instructions / rules / conventions go to **project `AGENTS.md`**, never `CLAUDE.md`. CLAUDE.md stays as single-line `@AGENTS.md` pointer. Exception: modifying the pointer itself.
3. **Token Budget** — agent-internal comms compressed (`full` default: drop articles, fragments OK, short synonyms). Never compress: code blocks, security warnings, user deliverables. User can say "switch to lite/ultra".
4. **Execution Plan required** — never write code without a Plan confirmed by user. Every task has explicit `verify:` step.
5. **Single writer per file** — never assign same file to both agents simultaneously.
6. **Size limits** — new files ≤ 500 lines; functions ≤ 80 lines; nesting ≤ 3 levels. Flag violations at integration.
7. **Session Start (first invocation)** — run `session-start.md` protocol: optional plugin detection + AGENTS.md bootstrap (both one-shot, silent after first effective run).
8. **Post-edit score** — after any commit that modifies `SKILL.md`, `references/*.md`, `README.md`, or `CLAUDE.md.template`, compute the 8-dimension weighted score (see `self-correction.md` Layer 0) and append one line to `.skill-scores.jsonl`. Any single-dim drop ≥3 vs prior commit → justify in the commit message footer.

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
| **Thinking layer** (`/co:think` office-hours + `/co:plan-review` CEO review) | `references/thinking-decision.md` | Ambiguous/novel task before Plan; CEO-mode plan critique |
| **Knowledge compounding** (`/co:compound` 4-subagent pipeline + `/co:sessions` cross-session search) | `references/knowledge-compounding.md` | After resolving non-trivial problem; before complex work to check history |
| **Self-correction** (3-layer eval/capture/promote + `/co:eval` `/co:review` `/co:promote` `/co:loop`) | `references/self-correction.md` | Session end; every 5 sessions; autonomous refinement |
| **Cross-harness setup** (CC/Cursor/Codex/OpenCode config maps + hook translation) | `references/cross-harness.md` | Harness migration; setting up new project |
| **Engineering principles** (Hyrum, Beyoncé, Test Pyramid, Chesterton, Trunk-based, Shift Left, Feature Flags, Deprecation, Change Sizing, Common Rationalizations) | `references/engineering-principles.md` | Integration review; every Codex task gate |
| **Maintainability harness** (20-section spec: file size, function size, nesting, naming, Rule of 3, typed interfaces, error handling, deps, Hard Red Lines) | `references/maintainability-harness.md` | Seeds AGENTS.md Non-Negotiable Rules; enforced at integration |
| **UI style standard** (shadcn/radix-nova default `components.json` + secondary style library + webpage style extraction + frontend Hard Red Lines) | `references/ui-style-standard.md` | Any frontend work; "make it look like [URL]" requests |
| **Context budget** (phase thresholds + compact-guard + identity re-injection + Smart Tool RAG) | `references/context-budget.md` | Context > 60% used; stuck mid-session |

---

## Invocation Prompts (mnemonic, not registered slash commands)

> Type these in chat — CC follows the matching reference file. Not registered Claude Code slash commands; won't appear in command palette.

| Prompt | Purpose | Load |
|--------|---------|------|
| `/co:think` | Pre-task ambiguity resolution (product/technical mode) | `thinking-decision.md` |
| `/co:plan-review` | CEO-mode Plan critique (EXPAND/SELECTIVE/HOLD/REDUCE) | `thinking-decision.md` |
| `/co:score` | Score this skill edit on 8 dims, append to `.skill-scores.jsonl` (auto-fire after skill file commits) | `self-correction.md` |
| `/co:eval` | Session end two-axis score | `self-correction.md` |
| `/co:review` | Every 5 sessions — scan error log, find promotion candidates | `self-correction.md` |
| `/co:promote` | Write ≥6-score candidate back into SKILL.md | `self-correction.md` |
| `/co:loop` | Autonomous cron-driven refinement | `self-correction.md` |
| `/co:compound` | Capture solution → `docs/solutions/` via 4-subagent pipeline | `knowledge-compounding.md` |
| `/co:sessions` | Search prior CC/Codex sessions for similar problems | `knowledge-compounding.md` |

---

## Design Principles

1. **Self-contained** — no mandatory external plugins; optional plugins auto-detected
2. **Plan before execute** — no code without approved Execution Plan
3. **Single writer per file** — hard rule, always
4. **Token-aware** — agent-internal comms compressed; code + user deliverables full
5. **Human-in-loop minimization** — Codex Co-Decision first, escalate only on low confidence; user decisions batched at plan edges
6. **Self-correcting** — 3-layer mechanism with locked evaluator to prevent score-gaming
7. **Cross-harness** — AGENTS.md as universal baseline, CLAUDE.md as pointer
8. **Maintainability over speed** — optimize for 6-month readability, not line count
9. **Progressive loading** — SKILL.md is a router; deep content loads on demand from `references/`
