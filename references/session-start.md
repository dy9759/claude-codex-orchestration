# Session Start — Plugin Detection + AGENTS.md Bootstrap

Two one-shot checks that run at the first invocation of the skill in a new session/project. Both are idempotent and silent after their first effective run.

---

## Part 1: Optional Plugin Detection

Scan `~/.claude/plugins/installed_plugins.json` for optional enhancements. Show hints **once per user** via a sentinel file — subsequent sessions stay silent.

```bash
REGISTRY=~/.claude/plugins/installed_plugins.json
SENTINEL=~/.claude/.orch-plugin-hints-shown

[ -f "$SENTINEL" ] && exit 0

check() { grep -q "\"$1\"" "$REGISTRY" 2>/dev/null; }

MISSING=()
check "caveman"              || MISSING+=("caveman")
check "compound-engineering" || MISSING+=("compound-engineering")
check "superpowers@"         || MISSING+=("superpowers")

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "[Orchestration] Optional plugins not detected: ${MISSING[*]}"
  echo "  Skill works without them. Install guides (external):"
  for p in "${MISSING[@]}"; do
    case "$p" in
      caveman)              echo "    caveman              → https://github.com/JuliusBrussee/caveman" ;;
      compound-engineering) echo "    compound-engineering → https://github.com/EveryInc/compound-engineering-plugin" ;;
      superpowers)          echo "    superpowers          → /plugin install superpowers@claude-plugins-official" ;;
    esac
  done
  echo "  This hint shows once per user."
  touch "$SENTINEL"
fi
```

**What each plugin adds** (all optional):

| Plugin | Enhancement |
|--------|-------------|
| `caveman` | Heavier output token compression (`caveman:compress`) + `/caveman lite\|full\|ultra` levels |
| `compound-engineering` | Richer knowledge-compounding subagents (replaces inline 4-subagent pattern) |
| `superpowers` | `superpowers:using-git-worktrees`, brainstorming, dispatching-parallel-agents |

**Re-trigger:** `rm ~/.claude/.orch-plugin-hints-shown`. **Never block:** skill proceeds regardless.

---

## Part 2: AGENTS.md Bootstrap

Check project root for `AGENTS.md` and `CLAUDE.md`. AGENTS.md is the cross-harness source of truth; `CLAUDE.md` becomes `@AGENTS.md` pointer so Claude Code reads the same file as Cursor / Codex / OpenCode.

Claude Code officially supports `@filename` imports in CLAUDE.md ([code.claude.com/docs/en/memory.md](https://code.claude.com/docs/en/memory.md)) — AGENTS.md content loads into CC session context automatically.

```bash
agents_bootstrap() {
  local project_root has_agents has_claude pointer='@AGENTS.md'
  project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  cd "$project_root" 2>/dev/null || return 0

  has_agents=$([ -f AGENTS.md ] && echo yes || echo no)
  has_claude=$([ -f CLAUDE.md ] && echo yes || echo no)

  is_pointer() {
    [ -f CLAUDE.md ] && \
    [ "$(grep -vE '^\s*$' CLAUDE.md | tr -d '[:space:]')" = "@AGENTS.md" ]
  }

  case "$has_agents:$has_claude" in
    yes:yes)
      if ! is_pointer; then
        echo "[AGENTS] WARN — both CLAUDE.md and AGENTS.md have content."
        echo "         Suggested: merge into AGENTS.md, reduce CLAUDE.md to '@AGENTS.md'."
      fi
      ;;
    yes:no)
      printf '%s\n' "$pointer" > CLAUDE.md
      echo "[AGENTS] Created CLAUDE.md → @AGENTS.md pointer"
      ;;
    no:yes)
      cp CLAUDE.md CLAUDE.md.bak
      mv CLAUDE.md AGENTS.md
      printf '%s\n' "$pointer" > CLAUDE.md
      echo "[AGENTS] Migrated CLAUDE.md → AGENTS.md (backup: CLAUDE.md.bak)"
      ;;
    no:no)
      cat > AGENTS.md <<'TEMPLATE'
# Agents

### Non-Negotiable Rules

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

### Role Definitions

- **Claude Code** — Tech Lead / Orchestrator + primary executor. Owns architecture, cross-module decisions, integration, frontend work (UI components, pages, interactions, styling), anything needing repo-wide context (migrations, CI/CD, release coordination).
- **Codex** — Parallel Implementer. Owns bounded backend/script modules with clear boundaries and independent verifiability (isolated features, self-contained scripts, parallel solution attempts, diff review).
- **Gemini** — Frontend/UI specialist consultant (via `gemini-cli` MCP, optional). Advises on design direction, CSS audits, a11y, multi-file consistency. Never executes — CC always implements and verifies.

### Blocked File Patterns (Codex never writes these)

- Database migrations (ALTER/DROP/CREATE TABLE)
- `.env`, secrets, API keys
- Package manifests (package.json, requirements.txt, go.mod, Cargo.toml)
- CI/CD pipelines (.github/workflows/, Dockerfile, Makefile)
- `rm -rf` / force-delete operations
- Git history rewrites (rebase -i, reset --hard, push --force)

### Workflow

1. Plan → split CC/Codex ownership cleanly
2. Parallel execute in worktrees if needed (`feature/<agent>-<desc>`)
3. Integrate once — single writer per file at any moment
4. Verify: tests + lint + type check before push

### Next-Step Decision Flow (between tasks)

After each task completes, run priority cascade:
1. **Run tests first** — always, no exceptions
2. **If tests fail:**
   - *Blocking* (feature test / was-green regression / build / type / lint in modified files) → fix immediately
   - *Non-blocking* (unrelated module / flaky / pre-existing / warning) → create `gh issue create --label "todo,non-blocking"`, continue
3. **If tests pass** → next task from Execution Plan
4. **When Plan complete** → End-of-plan consolidated review (queued decisions + open issues + milestone menu in ONE prompt, then push)

### Consolidated Decision Protocol (minimize mid-execution interruptions)

- **Pre-flight batch:** at Plan confirmation, CC presents all anticipated decisions (security high-risk, UI theme changes, planned deletions, Gemini consultation) in ONE prompt. User approves in one reply.
- **Mid-execution:** only BLOCKING events interrupt (security-blocked / data-loss / off-limits / task-invalidating). Everything else queues to `.decisions-pending` with safe default applied.
- **End of plan:** ONE consolidated prompt merging queued decisions + open issues + milestone menu. User answers all in one round.

### Frontend/UI consultation

- Small UI change → CC does it directly, no Gemini
- Large revamp / 2–3 variants / CSS audit / a11y review → consult Gemini via `mcp__gemini-cli__*`; CC implements and verifies in browser
- Gemini unavailable → CC continues, never blocks

### UI Style (Frontend Default)

- Default: shadcn/ui + `"style": "radix-nova"` + `baseColor: neutral` + `iconLibrary: lucide`
- See `~/.claude/skills/claude-codex-orchestration/references/ui-style-standard.md` for full `components.json`, webpage style extraction workflow, and secondary style library
- **Do not introduce a second UI library alongside shadcn.** No hardcoded hex colors in components — use CSS variables. Use Tailwind scale, not arbitrary `p-[13px]`.

### Referenced Docs

- Skill: `~/.claude/skills/claude-codex-orchestration/SKILL.md`
- Maintainability harness: `~/.claude/skills/claude-codex-orchestration/references/maintainability-harness.md`
- UI style standard: `~/.claude/skills/claude-codex-orchestration/references/ui-style-standard.md`
- Gemini integration (frontend specialist): `~/.claude/skills/claude-codex-orchestration/references/gemini-integration.md`
- Solved problems (if present): `docs/solutions/`
TEMPLATE
      printf '%s\n' "$pointer" > CLAUDE.md
      echo "[AGENTS] Created AGENTS.md (template) and CLAUDE.md → @AGENTS.md pointer"
      ;;
  esac
}

agents_bootstrap
```

**Safety notes:**
- Migration creates `CLAUDE.md.bak` before overwriting — original never lost
- If both files have content, do NOT auto-merge; warn and let user decide
- Template seeds AGENTS.md with Non-Negotiable Rules — Codex/Cursor/OpenCode read these automatically
- `@AGENTS.md` pointer syntax is Claude Code's file reference — loads AGENTS.md into CC context

---

## Data File Lifecycle (informational)

Per-user session state — auto-created on first use, `.gitignore`d, never committed.

| File | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `.eval-scores.jsonl` | `/co:eval` at session end | `/co:review`, Smart Tool RAG quality filter | Two-axis score history, anti-inflation detection |
| `.error-log.jsonl` | Codex failure / integration rejection / Learn-Rule fast path | `/co:review`, Smart Tool RAG quality filter | Error capture, recurrence detection for Layer 3 promotion |
| `.codex-quality.jsonl` | Every Codex dispatch result | Quality tracking (rolling 20-window), auto-evolve trigger | Dispatch success rate, penalty factor, hard-stop gate |
| `.decisions-approved` | Pre-flight Decision Batching | Mid-execution (skip re-asking) | Plan-cycle approvals, cleared at Plan completion |
| `.decisions-pending` | Mid-execution queue | End-of-Plan Consolidated Review | Queued decisions for batch resolution |
| `.tasks/*.json` | CC before parallel Codex dispatch | Both agents during execution; CC at integration audit | Atomic task claiming, owner field prevents double-writes |

**First session:** files don't exist yet. Quality filters silent no-op when empty.
**Reset:** `rm ~/.claude/skills/claude-codex-orchestration/.{eval-scores,error-log,codex-quality}.jsonl`
