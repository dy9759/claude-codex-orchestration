# Gemini Integration — Frontend/UI Specialist Consultant

Gemini (via `mcp__gemini-cli__*` tools, NOT API key) acts as a **specialist consultant** for frontend and UI work. It is neither the primary executor nor an independent co-agent.

---

## Relationship Model

```
CC orchestrator ──► Gemini specialist ──► CC fallback

- CC is always primary: reads code, writes code, runs commands, verifies in browser
- Gemini is consulted for specific frontend/UI judgment, never for execution
- CC makes every final decision, every patch landing, every verification
```

**Anti-pattern to avoid:** "Gemini main executor, CC fallback". Gemini is an advisor, not a replacement.

---

## Fact Priority (conflict resolution)

When Gemini's suggestion conflicts with other signals, resolve in this order:

```
Browser runtime behavior > Local code context > Gemini suggestion
```

Console output, network trace, DOM inspection, screenshot, actual interaction — all beat a Gemini opinion. Use Gemini for ideation and review, not for ground truth.

---

## When to Call Gemini

Consult Gemini when the task value justifies the round-trip cost:

| Scenario | Why Gemini helps |
|----------|------------------|
| New page / new module / large UI revamp | Wide context scan, multi-direction ideation |
| Need 2–3 visual/interaction variants | Divergent thinking, design direction comparison |
| Component hierarchy / info architecture unclear | Structure review from outside perspective |
| Multi-file UI/style consistency audit | Pattern detection across codebase |
| Code-level design review (a11y, responsive, semantic HTML) | Design-aware code review |
| "Not ugly but not good enough" second opinion | Aesthetic refinement without rebuild |

---

## When NOT to Call Gemini

Do **not** consult Gemini for:

| Scenario | Why CC alone is better |
|----------|------------------------|
| Small style fixes, copy tweaks, obvious bugfixes | Round-trip cost > value |
| Rapid trial-and-error runtime issues | Browser verification is the tool, not an advisor |
| Console / network / DOM debugging | Live inspection > pre-trained model |
| Urgent blocking tasks | Never wait on Gemini for a critical path |
| Tasks CC can finish in < 2 minutes | Overhead dominates |

---

## Invocation

Gemini is accessed via MCP tools only — `mcp__gemini-cli__*`. Never via direct API key. Hook configuration lives on the CC side (`~/.claude/settings.json`), never on Gemini's side.

**Prompts for Gemini** (natural language, NOT XML — Gemini is a collaborator, not a Codex operator):

```
use gemini to analyze the current repository and summarize the architecture
ask gemini to review the current diff for bugs
ask gemini to research the latest official docs for X and cite sources
ask gemini to propose 3 visual variants for [component] prioritizing [criterion]
ask gemini to audit the CSS architecture for inconsistencies across [paths]
```

Key difference from Codex:
| Agent | Prompt style | Output expectation |
|-------|-------------|-------------------|
| Codex | XML structured (`<task>` + `<structured_output_contract>` + `<verification_loop>`) | Code diffs, test results, risk flags |
| Gemini | Natural language request + explicit deliverable | Ideas, reviews, structured recommendations |

---

## Standard Workflow

### Stage 1 — Understand (CC only)
CC reads relevant code, constraints, existing patterns. Classifies task:
- **A** Direct implementation (no Gemini) — small, clear, bounded
- **B** Consult Gemini first — ambiguous design, large scope, aesthetic judgment needed

### Stage 2 — Gemini Consultation (only if value justifies)
Before invoking, CC prepares minimal necessary context:
- Current goal (one sentence)
- Relevant files / components (list, not content dump)
- Existing patterns to respect
- Hard constraints
- Specific output shape requested

Gemini requests must have clear boundaries. Good examples:
- "Propose 2–3 UI variants for the login form, prioritizing accessibility and mobile-first. Recommend one and justify."
- "Review the component structure in `src/components/dashboard/` — identify structural risks and over-abstraction."
- "Audit CSS architecture for responsive breakpoint inconsistencies."
- "Review this diff for frontend issues — naming, accessibility, performance."

Ask Gemini to return structured output:
```
recommendation: <the primary answer>
alternatives: <2–3 other viable paths>
risks: <what could go wrong>
implementation notes: <concrete steps>
```

### Stage 3 — CC Implements
CC implements per project style and constraints. **Does not blindly follow Gemini.** Absorbs only what's valuable. Scope stays focused — no unrelated refactors.

### Stage 4 — Real Verification (mandatory)
CC must perform real verification:
- Start or reuse dev server
- Check browser rendering
- Review console / network / DOM
- Verify responsive behavior and interactions

If the result is still not satisfying, CC may invoke a second Gemini review, but CC decides whether to adopt suggestions.

### Stage 5 — Closure
CC summarizes:
- What changed
- Why this approach
- What was verified
- Residual risks

All Gemini calls are logged by the CC-side hook (see Hook Configuration).

---

## Frontend-Specific Rules (applied by CC, reinforced by Gemini review)

1. Follow existing design system, component patterns, style constraints
2. Do not break consistency to make it "look better"
3. Do not treat Gemini suggestions as design system truth
4. Design suggestions must translate into **verifiable implementation standards**
5. Ultimate arbiters: runtime behavior + code maintainability
6. For visual suggestions, prioritize:
   - Information hierarchy clarity
   - Readability
   - Shorter interaction paths
   - Stable responsive behavior
   - Style consistency

See `references/ui-style-standard.md` for default shadcn + radix-nova compliance.

---

## Execution Strategy

- **Default:** CC implements, Gemini reviews, CC closes
- **Optional:** CC asks Gemini for a plan first, then implements
- **Forbidden:** Fully delegate the frontend task to Gemini without CC verification

---

## Fallback Behavior

If Gemini is unavailable (MCP tool error, timeout, rate limit):
- CC continues without waiting
- Task is never blocked by Gemini unavailability
- Log the fallback in `.error-log.jsonl` with `category: gemini-unavailable` for future pattern detection
- If Gemini failures recur across sessions, surface as a session eval `weak_point`

---

## Integration with Existing Skill Mechanisms

### vs Codex Co-Decision
When CC needs a second opinion, **route by task nature**:

| Question nature | Route to |
|-----------------|----------|
| Code architecture, bug classification, risk triage | Codex Co-Decision |
| Frontend design direction, UI aesthetics, a11y review | Gemini consultation |
| Both applicable | Pick the one closer to the failure mode (code → Codex, visual → Gemini); never ask both on same question |

### vs Next-Step Decision Flow
- Priority 1 (tests first) — Gemini consultation never replaces test-running
- Priority 2 (failure triage) — blocking vs non-blocking is CC's call; Gemini can advise on edge cases
- Priority 4 (issue triage loop) — frontend/UI issues in `todo` queue may warrant Gemini consultation when fixing

### vs Maintainability Harness
- Gemini reviews must flag violations from `maintainability-harness.md` §18 Frontend Hard Red Lines
- Gemini suggestions that would *introduce* a violation (second UI library, hex hardcoding, etc.) must be explicitly rejected by CC

### vs Smart Tool RAG
- If CC is stuck on a UI problem and Smart Tool RAG finds no matching skill → Gemini consultation becomes the next fallback before asking the user

---

## Hook Configuration (one-time setup, CC side)

Every Gemini call is logged by a CC-side hook. Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "mcp__gemini-cli__.*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/chauncey2025/.claude/hooks/after-gemini.sh",
            "async": true,
            "timeout": 120
          }
        ]
      }
    ],
    "PostToolUseFailure": [
      {
        "matcher": "mcp__gemini-cli__.*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/chauncey2025/.claude/hooks/after-gemini-fail.sh",
            "async": true,
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

Minimal hook script (`~/.claude/hooks/after-gemini.sh`):
```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.claude/gemini-hook-logs"
cat > "$HOME/.claude/gemini-hook-logs/$(date +%Y%m%d-%H%M%S).json"
```

Every Gemini invocation lands a JSON payload with full request/response. Use for debugging, quality tracking, and compounding (`/co:compound`).

---

## Shorthand Rules (for CC's working memory)

- CC primary, Gemini specialist, CC fallback
- Small change: just do it. Large revamp: ask Gemini first
- Gemini gives ideas, not verification
- Browser reality beats model opinion
- Hooks only on CC side, never on Gemini side
- Gemini unavailable → CC continues, no blocking
