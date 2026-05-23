# Context Budget + Smart Tool RAG

## Token & Context Budget (Per Session)

**Phase-based context thresholds** — if over limit, act immediately:

| Phase | Context target | Action if over |
|-------|---------------|----------------|
| Phase 0 (planning) | < 20% | Keep plan output shorter |
| Parallel execution | < 60% | Compact between Codex dispatches |
| Integration | < 80% | Delegate review to subagent |
| Final review / push | < 90% | Start fresh session via `/resume` |

## compact-guard (Before `/compact`)

Only 5 files survive compaction. Before calling `/compact`, save these 5:

1. Current task — one sentence
2. Files in progress — which files CC and Codex are editing
3. Active Codex task specs
4. Decisions made this session
5. Next step immediately post-compact

## Identity Re-Injection (Runtime-Aware)

After compaction resumes, orchestrator must reinject identity with runtime context:

**CC as runtime:**
> "You are Claude Code acting as orchestrator for [project]. Current task: [task]. Codex is handling: [scope]. Available agents: [list]. Next: [step]."

**Codex as runtime:**
> "You are Codex acting as orchestrator for [project]. Current task: [task]. CC is handling: [scope]. Available agents: [list]. Next: [step]."

**Generic template:**
> "You are [RUNTIME] acting as orchestrator for [project]. Current task: [task]. [DISPATCH_AGENT] is handling: [scope]. Routing by capability matrix. Next: [step]."

Without re-injection, orchestrator loses context and may duplicate dispatched agent's work or mis-route tasks.

## Token Accounting

End-of-session report:
```
Input tokens saved:  [compress runs estimate]
Output tokens saved: [caveman level × messages]
Total efficiency gain: [rough %]
```
If gain < 30% → switch `full` → `ultra` next session.

---

## Smart Tool RAG (Mid-Session Skill Retrieval)

When CC or Codex hits a wall mid-execution — current approach not working, domain knowledge missing — before asking the user, run a skill retrieval pass.

**Retrieval sources (search both):**
- `~/.claude/skills/` — reusable skill guides
- `docs/solutions/` — project-specific solved problems (see `knowledge-compounding.md`)

**Two-stage pipeline (mirrors OpenSpace SkillRanker):**
1. **BM25 stage** — tokenize task description, score all skills on `name + description + body[:2000]`. Keep top candidates. If total skills ≤ 10, skip to stage 2 directly.
2. **Semantic stage** — re-rank BM25 candidates by concept overlap with the stuck query. Prefer skills with higher quality signals from `.eval-scores.jsonl`.
3. **Quality filter** — if a candidate skill has ≥ 2 error-log entries for `dispatch` or `integration` failures, demote it in ranking.

**Trigger conditions:**
- Codex task spec rejected twice with same error → retrieve skill for that error category
- CC uncertain about worktree setup, context compaction, or integration → retrieve matching skill
- New domain/language/framework in scope → retrieve before dispatching

**Fallback:** If no relevant skill found → proceed, but flag "no skill matched" in the session eval weak_point.
