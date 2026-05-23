---
name: co-compound
description: Knowledge compounding for claude-codex-orchestration. Capture a solved non-trivial problem to docs/solutions/[category]/[slug]-[date].md with YAML frontmatter. Two modes: Full (4 parallel subagents — Context Analyzer / Solution Extractor / Related Docs Finder / Session Historian; overlap detection; Phase 2.5 selective refresh of older docs; discoverability check) or Lightweight (single pass). Delegates to claude-codex-orchestration references/knowledge-compounding.md.
---

# /co-compound — Knowledge Compounding

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/knowledge-compounding.md`.

## Quick run

**Ask user first** (Question Format Standard):
```
Q: Which mode?
Options:
  Full.  4 parallel subagents, session history cross-ref, overlap detection
  Light. Single pass, faster, fewer tokens

Recommendation: Full (if non-trivial problem + user has time)
               Light (if simple fix or near context limit)
```

**Full mode phases (4 parallel subagents — CC runtime; sequential in Codex runtime):**
1. Context Analyzer — problem_type, track, filename slug, category
2. Solution Extractor — Problem/Symptoms/Fix/Why for bug track; Context/Guidance/When for knowledge track
3. Related Docs Finder — overlap score (High 4-5 dims / Moderate 2-3 / Low 0-1) vs existing `docs/solutions/`
4. Session Historian — search `~/.claude/projects/` + `~/.codex/sessions/` for prior investigations

**Codex runtime adaptation:** No Agent tool available. Run phases 1-4 sequentially as inline reasoning + shell searches instead of parallel subagents. Output format unchanged.

**Phase 2 overlap decision:**
- High → update existing (add `last_updated`)
- Moderate → new + flag for consolidation
- Low → new normally

**Phase 2.5 selective refresh** if new solution contradicts older doc.
**Discoverability check:** ensure AGENTS.md/CLAUDE.md points to `docs/solutions/`.
