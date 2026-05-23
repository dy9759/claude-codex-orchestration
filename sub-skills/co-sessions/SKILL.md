---
name: co-sessions
description: Cross-session history search for claude-codex-orchestration. Before starting complex work, dispatch a general-purpose subagent to search ~/.claude/projects/ and ~/.codex/sessions/ for prior investigations of the same problem. Returns prior approaches tried, dead ends and why they failed, key decisions + rationale, related context. Avoids repeating failed paths from past sessions. Delegates to claude-codex-orchestration references/knowledge-compounding.md.
---

# /co-sessions — Cross-Session History Search

Full protocol: `~/.claude/skills/claude-codex-orchestration/references/knowledge-compounding.md` §/co-sessions.

## Quick run

**CC runtime:** Dispatch via built-in Agent tool (`subagent_type: general-purpose`, `run_in_background: true`):

```
Search prior sessions for "<specific problem — not generic topic>".
Scope:   ~/.claude/projects/ (CC sessions) + ~/.codex/sessions/ (Codex sessions)
Filter:  current repo path matches working directory, or branch name matches
Return:  prior approaches tried, dead ends + why failed, key decisions +
         rationale, related context. < 300 words. Include session date +
         file path for each finding.
```

**Codex runtime (no Agent tool):** Direct shell search fallback:

```bash
# Search CC session transcripts
grep -rl "<problem keywords>" ~/.claude/projects/ 2>/dev/null | head -20

# Search Codex session history
grep -rl "<problem keywords>" ~/.codex/sessions/ 2>/dev/null | head -20

# Read top matches
for f in $(grep -rl "<keywords>" ~/.claude/projects/ ~/.codex/sessions/ 2>/dev/null | head -5); do
  echo "=== $f ===" && head -50 "$f"
done
```

Output: same summary format regardless of runtime. Use to avoid repeating failed approaches.
