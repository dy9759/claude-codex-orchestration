# Knowledge Compounding (`/co-compound` + `/co-sessions`)

**Why:** First time solving a problem = research. Document it → next occurrence = minutes. Knowledge compounds exponentially across sessions, repos, and agents.

**Trigger:** After any orchestration session that resolves a non-trivial coordination problem, Codex failure pattern, or integration challenge — capture it while context is fresh.

---

## `/co-compound` — Two Modes

Ask user before proceeding (never pre-select):
```
1. Full — parallel subagents, session history cross-reference, overlap detection
2. Lightweight — single pass, faster, fewer tokens. Best for simple fixes or near context limit.
```

## Full Mode Phases

*(These are internal phases of `/co-compound` — unrelated to the main orchestration Phase 0.)*

**Compound Step A: Auto Memory Scan**
Check MEMORY.md for entries relevant to the problem. Pass any matches as supplementary context to Step B agents (not primary evidence — conversation history takes priority).

**Compound Step B (parallel subagents, all return text — no file writes):**

| Agent | Job |
|-------|-----|
| Context Analyzer | Extract problem type (bug vs knowledge), classify track, suggest filename `[slug]-[date].md`, map to `docs/solutions/[category]/` |
| Solution Extractor | Bug track: Problem → Symptoms → What Didn't Work → Solution → Why → Prevention. Knowledge track: Context → Guidance → Why It Matters → When to Apply → Examples |
| Related Docs Finder | Search `docs/solutions/` for overlap. Score: High (4-5 dims match), Moderate (2-3), Low (0-1). Flag stale docs |
| Session Historian | Search `~/.claude/projects/`, `~/.codex/sessions/` for prior investigations of this problem. Return: prior approaches, dead ends, key decisions. Dispatch foreground (accesses files outside working dir) |

**Compound Step C: Assembly**

Overlap decision:
- **High** → update existing doc (not duplicate). Preserve path, add `last_updated:`
- **Moderate** → create new, flag for consolidation review
- **Low** → create new normally

Write to `docs/solutions/[category]/[slug]-[date].md` with YAML frontmatter:
```yaml
---
title: [problem title]
date: YYYY-MM-DD
problem_type: bug|knowledge
module: [affected module]
tags: [relevant tags]
---
```

**Compound Step D: Selective Refresh Check** (inline, no external plugin)
If the new solution contradicts an older doc → refresh it inline. Only trigger when evidence is clear.

Steps:
1. Read the conflicting doc
2. Identify the contradicted section (quote the exact paragraph)
3. Mark it with `> **Superseded YYYY-MM-DD** — see [new-slug-date.md]`
4. Append a "Changelog" entry at the bottom: date, what changed, why
5. Do NOT rewrite the whole doc — narrow scope only

**Discoverability Check (always runs)**
After writing: verify AGENTS.md or CLAUDE.md points agents to `docs/solutions/`. If not, add one line:
```
docs/solutions/  # solved problems (bugs, patterns, workflow), organized by category with YAML frontmatter
```

---

## `/co-sessions` — Session History Search

Before starting complex work: search prior Claude/Codex sessions for the same repo.

Dispatch via built-in Agent tool (`subagent_type: general-purpose`, `run_in_background: true`) with this brief:
```
Search prior sessions for "[specific problem description — not generic topic]".
Scope: ~/.claude/projects/ (CC sessions) and ~/.codex/sessions/ (Codex sessions).
Filter: current repo path matches working directory, or branch name matches current branch.
Return: prior approaches tried, dead ends + why they failed, key decisions + rationale,
        related context. < 300 words. Include session date + file path for each finding.
```
Use to avoid repeating failed approaches from prior sessions.
