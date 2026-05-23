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

### Role Definitions (Runtime-Agnostic)

- **Orchestrator** (whoever is runtime — CC or Codex) — Plans, routes tasks by capability matrix, integrates results. The runtime agent is always the orchestrator.
- **Claude Code** — Architecture, cross-module reasoning, frontend/UI, integration support. Best at repo-wide context tasks.
- **Codex** — Bounded backend modules, isolated scripts, parallel candidate implementations, code review. Best at isolated, testable tasks.
- **Gemini** — Frontend/UI specialist consultant (via `gemini-cli` MCP, optional). Advises on design direction, CSS audits, a11y, multi-file consistency. Never executes — orchestrator always implements and verifies.

Task routing follows capability matrix (`runtime-routing.md`), not runtime identity. Same matrix regardless of who orchestrates.

### High-Risk Operations (explicit approval required)

- Database migrations (ALTER/DROP/CREATE TABLE)
- `.env`, secrets, API keys
- Package manifests (package.json, requirements.txt, go.mod, Cargo.toml)
- CI/CD pipelines (.github/workflows/, Dockerfile, Makefile)
- `rm -rf` / force-delete operations
- Git history rewrites (rebase -i, reset --hard, push --force)

Do not auto-dispatch these across agents. The current orchestrator keeps ownership, writes a plan with rollback/verify steps, and asks explicit approval before execution.

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

## Part 3: Global CLAUDE.md §5.2 Auto-Seed + Version-Aware Update

**Intent:** Two responsibilities in one check:
1. If user invoked skill **manually** (no §5.2 in global CLAUDE.md) → offer to add
2. If §5.2 exists but is **outdated** (older version than what skill currently ships) → offer to update surgically

### Version Constant (bump when §5.2 content changes materially)

```bash
CURRENT_CLAUDE_MD_SECTION_VERSION=2
```

**Bump rule:** Increment this whenever the §5.2 block below gets a new trigger, a changed rule, or a structural edit. Do NOT bump for cosmetic changes. Bump goes in the same commit as the block change.

**Version history:**
- `v1` — 8 triggers incl. UI style, knowledge compounding, /co-think, /co-plan-review; "invoke the skill to check when in doubt" rule
- `v2` (current) — hyphen `/co-*` command naming, runtime-agnostic routing, Codex AGENTS install/discovery, heartbeat fallback, unified high-risk approval rule

### Detection + Action Flow

```bash
seed_global_claude_md() {
  local claude_md=~/.claude/CLAUDE.md
  local sentinel=~/.claude/.orch-claude-md-seeded
  local current_version=2  # see Version Constant above

  # Case A: CLAUDE.md missing entirely or doesn't mention skill → offer to add
  if [ ! -f "$claude_md" ] || ! grep -q "claude-codex-orchestration" "$claude_md" 2>/dev/null; then
    [ -f "$sentinel" ] && return 0  # user previously declined
    echo "[Orchestration] No §5.2 in ~/.claude/CLAUDE.md — manual invocation inferred."
    echo "  Add §5.2 'Prefer claude-codex-orchestration Skill' to ~/.claude/CLAUDE.md?"
    echo "  Future sessions will auto-invoke on matching tasks. Reply: y / n / later."
    # y → append §5.2 BLOCK below + touch sentinel
    # n → touch sentinel (never re-ask)
    # later → no sentinel (re-prompt next session)
    return 0
  fi

  # Case B: §5.2 present — check version
  local found_version
  found_version=$(grep -oE 'orch-skill-version:[[:space:]]*[0-9]+' "$claude_md" | head -1 | grep -oE '[0-9]+')

  if [ -z "$found_version" ]; then
    # §5.2 exists but no version marker → ancient or hand-written
    echo "[Orchestration] §5.2 in ~/.claude/CLAUDE.md has no version marker."
    echo "  Current skill ships v${current_version}. Your version predates versioning or is hand-written."
    echo "  Replace §5.2 block with current v${current_version}? (other CLAUDE.md content preserved)"
    echo "  Reply: y / n / later"
    return 0
  fi

  if [ "$found_version" -lt "$current_version" ]; then
    echo "[Orchestration] §5.2 in ~/.claude/CLAUDE.md is v${found_version}; current is v${current_version}."
    echo "  Changes since v${found_version}: <diff summary from Version History above>"
    echo "  Update §5.2 block? (other CLAUDE.md content preserved) Reply: y / n / later"
    return 0
  fi

  # Up-to-date — silent
  return 0
}

seed_global_claude_md
```

### Surgical Replacement Algorithm (when user says `y` to update)

To replace ONLY the §5.2 block without touching the rest of CLAUDE.md:

```bash
update_section_52() {
  local claude_md=~/.claude/CLAUDE.md
  local tmp=$(mktemp)

  # 1. Backup
  cp "$claude_md" "${claude_md}.bak-$(date +%Y%m%d-%H%M%S)"

  # 2. Extract everything BEFORE §5.2 heading
  awk '/^### 5\.2 Prefer/{exit} {print}' "$claude_md" > "$tmp"

  # 3. Append the current canonical §5.2 BLOCK (see below)
  cat >> "$tmp" <<'BLOCK'
  <current §5.2 block content, with version marker>
BLOCK

  # 4. Append everything AFTER the old §5.2 block (next ### heading onward)
  awk '
    /^### 5\.2 Prefer/{skip=1; next}
    skip && /^### /{skip=0}
    !skip {print}
  ' "$claude_md" >> "$tmp"

  mv "$tmp" "$claude_md"
  touch ~/.claude/.orch-claude-md-seeded
}
```

**Safety:** timestamped backup before any write, so user can recover via `cp CLAUDE.md.bak-<ts> CLAUDE.md` if unhappy with the update.

### §5.2 Block (canonical, current version)

When user answers `y` to add or update, write this block (append for Case A, surgical-replace for Case B):

```markdown

### 5.2 Prefer `claude-codex-orchestration` Skill <!-- orch-skill-version: 2 -->

**When a task matches the `claude-codex-orchestration` skill's triggers, invoke it first.**

Triggers (non-exhaustive):
- Dual-agent work (Claude Code + Codex + optional Gemini)
- Parallel implementation of bounded modules
- Cross-harness setup (Cursor / Codex / OpenCode)
- Runtime-agnostic capability routing (Claude Code or Codex as orchestrator)
- Codex project install via `.codex/orchestration/` + AGENTS managed block
- Cross-agent dispatch with heartbeat monitoring and portable timeout fallback
- Pre-task thinking via `/co-think`
- Strategic plan review via `/co-plan-review`
- Engineering principles enforcement (Hyrum, Beyoncé, Chesterton, trunk-based, shift-left, feature flags, deprecation, maintainability harness)
- UI style standard (shadcn/radix-nova)
- Knowledge compounding (`/co-compound`, `/co-sessions`)

Rule:
- If the current work plausibly matches any trigger above, invoke the `claude-codex-orchestration` skill **before** doing other work.
- Do not re-invent its workflows ad hoc. Prefer its `/co-*` invocation prompts and subagent-dispatch patterns.
- High-risk work (DB/env/secrets/package manifests/CI/release/destructive ops) is never auto-dispatched; current orchestrator asks explicit approval first.
- If in doubt whether a task qualifies, invoke the skill to check — cheap to load, expensive to skip.
```

**Key marker:** the HTML comment `<!-- orch-skill-version: N -->` on the heading line is how CC detects version. Keep it on the same line as `### 5.2 Prefer`.

### Safety Rules Summary

- **Append or surgical-replace only** — never overwrite full CLAUDE.md
- **Ask before writing** — user's global config is sacred
- **Timestamped backups** on every update (`CLAUDE.md.bak-YYYYMMDD-HHMMSS`)
- **Idempotent** — up-to-date state is silent; only outdated triggers re-prompt
- **Decline-respected** — `n` touches sentinel so user is never nagged
- **No conflict with AGENTS.md Write Redirect** — that's project CLAUDE.md; this is global `~/.claude/CLAUDE.md` (user personal config)

**Reset:** `rm ~/.claude/.orch-claude-md-seeded` to re-prompt on next session (useful after manual CLAUDE.md edit).

**Order of one-shot checks at Session Start:**
1. Plugin Detection → `~/.claude/.orch-plugin-hints-shown`
2. AGENTS.md Bootstrap → no sentinel; state-based idempotent
3. Global CLAUDE.md §5.2 Auto-Seed → `~/.claude/.orch-claude-md-seeded`
4. Skill Self-Update Check → `~/.claude/.orch-update-last-check` (+ preference files)
5. Escalation Queue Flush → pending `.issue-candidates.jsonl` entries retried when `gh` available (see Part 5)
6. Sub-skill Install Check → seed `/co-*` registered commands on fresh machines (see Part 6)

---

## Part 4: Skill Self-Update Check (git-based)

**Intent:** The skill itself is a git repo cloned from `https://github.com/dy9759/claude-codex-orchestration`. This check detects when the local clone is behind `origin/main` and offers to pull.

**Default cadence:** check every **3 days** (not every session — avoids network round-trip overhead and user nag).

**Three user preferences (persist across sessions):**
- `~/.claude/.orch-auto-update` — always pull silently, no prompt
- `~/.claude/.orch-update-disabled` — never check, fully opt-out
- *(neither set)* — default: check every 3 days, prompt on update

### Detection Flow

```bash
skill_update_check() {
  local skill_dir=~/.claude/skills/claude-codex-orchestration
  local last_check=~/.claude/.orch-update-last-check
  local auto_flag=~/.claude/.orch-auto-update
  local disabled_flag=~/.claude/.orch-update-disabled
  local interval_days=3

  # User opted out
  [ -f "$disabled_flag" ] && return 0

  # Cadence gate — skip if checked recently (ignored when --auto-update is set)
  if [ ! -f "$auto_flag" ] && [ -f "$last_check" ]; then
    local mtime now diff
    mtime=$(stat -f %m "$last_check" 2>/dev/null || stat -c %Y "$last_check" 2>/dev/null)
    now=$(date +%s)
    diff=$(( (now - mtime) / 86400 ))
    [ "$diff" -lt "$interval_days" ] && return 0
  fi

  cd "$skill_dir" 2>/dev/null || return 0

  # Refuse if local uncommitted changes — don't risk user's WIP
  if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    touch "$last_check"
    # Silent skip; user is actively editing
    return 0
  fi

  # Fetch silently; fail gracefully (offline, bad remote, etc.)
  git fetch origin main --quiet 2>/dev/null || { touch "$last_check"; return 0; }

  local local_commit remote_commit behind_count
  local_commit=$(git rev-parse main 2>/dev/null)
  remote_commit=$(git rev-parse origin/main 2>/dev/null)
  [ -z "$local_commit" ] || [ -z "$remote_commit" ] && { touch "$last_check"; return 0; }

  # Up-to-date
  if [ "$local_commit" = "$remote_commit" ]; then
    touch "$last_check"
    return 0
  fi

  # Local is ahead of remote (user is the dev) — skip silently
  if git merge-base --is-ancestor "$remote_commit" "$local_commit" 2>/dev/null; then
    touch "$last_check"
    return 0
  fi

  # Behind — fetch count and show latest changes
  behind_count=$(git rev-list --count "$local_commit..$remote_commit")
  local latest=$(git log --oneline "$local_commit..$remote_commit" | head -5)

  # Auto-pull branch
  if [ -f "$auto_flag" ]; then
    git pull --ff-only origin main --quiet 2>&1 | head -3
    echo "[Orchestration] Auto-pulled $behind_count commits from origin/main."
    touch "$last_check"
    return 0
  fi

  # Interactive branch — use Question Format Standard
  echo "[Orchestration] Skill is $behind_count commit(s) behind origin/main:"
  echo "$latest" | sed 's/^/    /'
  echo ""
  echo "Q: Pull latest skill updates now?"
  echo ""
  echo "Options:"
  echo "  y.      Pull now — fast-forward merge"
  echo "  n.      Skip this time (re-prompt in $interval_days days)"
  echo "  always. Pull automatically on future Session Start (recommended for stable machines)"
  echo "  never.  Disable this check entirely"
  echo ""
  echo "Recommendation: y (confidence: high)"
  echo "  CC: your clone is $behind_count commits behind; pulling keeps rules/references fresh."
  echo "  Codex: not consulted (routine update, no architectural decision)."
  echo "  Gemini: N/A."
  echo ""
  echo "Reply: y / n / always / never"

  # CC reads reply:
  # y     → git pull --ff-only origin main; touch last_check
  # n     → touch last_check (re-prompt after interval)
  # always → touch auto_flag; git pull --ff-only; touch last_check
  # never  → touch disabled_flag
}

skill_update_check
```

### Safety Rules

- **`git pull --ff-only`** — never merge-commit, never rebase; if remote diverges, abort and warn
- **Refuse on dirty worktree** — if user has local uncommitted changes, skip silently (never discard user WIP)
- **Refuse on ahead state** — if local is ahead of remote (user is the dev), skip silently
- **Graceful offline** — `git fetch` failure just touches sentinel and proceeds (skill still works offline)
- **Question Format Standard compliant** — recommendation + agent views + 4-option choice with tradeoffs

### State Files

| File | Purpose | Set by |
|------|---------|--------|
| `~/.claude/.orch-update-last-check` | Last check timestamp (mtime) | Every run of this function |
| `~/.claude/.orch-auto-update` | User chose "always pull" | User answered `always` |
| `~/.claude/.orch-update-disabled` | User chose "never check" | User answered `never` |

**Reset:**
- Re-enable checks: `rm ~/.claude/.orch-update-disabled`
- Switch back to prompted mode: `rm ~/.claude/.orch-auto-update`
- Force check on next session: `rm ~/.claude/.orch-update-last-check`

### Interaction with Layer 0 / §5.2 versioning

After a successful pull:
- Session Start Part 3 will re-run → detect version delta if §5.2 block moved to v2 → offer CLAUDE.md update (surgical replacement)
- Layer 0 rubric didn't move; `.skill-scores.jsonl` from remote is merged (it's git-tracked and append-only, so conflicts are rare)

---

## Part 6: Sub-skill Install Check (`/co-*` commands on fresh machines)

**Intent:** the skill ships 9 `/co-*` sub-skills under `sub-skills/`, but Claude Code only discovers skills at top-level `~/.claude/skills/*/SKILL.md`. On a fresh machine clone, the sub-skills exist in the repo but aren't yet registered as commands.

**Check flow:**

```bash
sub_skill_install_check() {
  local skill_dir=~/.claude/skills/claude-codex-orchestration
  local source_dir=$skill_dir/sub-skills
  local target_dir=~/.claude/skills
  local sentinel=~/.claude/.orch-subskills-installed

  # Fast path: sentinel says we've checked this source state before
  local source_sha
  source_sha=$(cd "$source_dir" 2>/dev/null && find . -name SKILL.md -exec cat {} \; | sha256sum | cut -c1-12)
  [ -f "$sentinel" ] && [ "$(cat "$sentinel" 2>/dev/null)" = "$source_sha" ] && return 0

  # Count how many co-* sub-skills are missing at target
  local missing=0 missing_names=()
  for d in "$source_dir"/co-*/; do
    local name
    name=$(basename "$d")
    if [ ! -f "$target_dir/$name/SKILL.md" ]; then
      missing=$((missing + 1))
      missing_names+=("$name")
    fi
  done

  if [ "$missing" = 0 ]; then
    echo "$source_sha" > "$sentinel"
    return 0
  fi

  # Missing sub-skills found — prompt user (Question Format Standard)
  echo "[Orchestration] $missing /co-* sub-skill(s) not registered on this machine:"
  printf '  - /%s\n' "${missing_names[@]}"
  echo ""
  echo "Q: Install now to enable these as real Claude Code slash commands?"
  echo ""
  echo "Options:"
  echo "  y.   Install — copies sub-skills/co-*/ to ~/.claude/skills/co-*/"
  echo "  n.   Skip — /co-* commands stay as manual chat invocations"
  echo ""
  echo "Recommendation: y (confidence: high)"
  echo "  CC: without installation, /co-eval etc. return 'Unknown command'"
  echo "      (observed failure mode). Install cost: ~9 tiny files, <5KB."
  echo ""
  echo "Reply: y / n"

  # On y: run the install script:
  #   bash $source_dir/install.sh
  # then: echo "$source_sha" > "$sentinel"
}

sub_skill_install_check
```

**Re-run on source update:** sentinel stores a hash of the source sub-skill contents. When `git pull` (Part 4) changes any `sub-skills/co-*/SKILL.md`, the hash changes → install-check fires again offering to update the installed copies.

**Manual install (alternative):**
```bash
bash ~/.claude/skills/claude-codex-orchestration/sub-skills/install.sh
bash ~/.claude/skills/claude-codex-orchestration/sub-skills/install.sh --force  # overwrite local edits
```

**Reset:** `rm ~/.claude/.orch-subskills-installed` to re-run check on next session.

**Design trade-off:** sub-skills duplicated from `sub-skills/` source to `~/.claude/skills/` install location. Chose copy (stable, portable) over symlink (fragile across volumes/cross-machine). The `install.sh --force` path + hash-sentinel handles drift detection.

---

## Part 5: Escalation Queue Flush (Layer 2.5 retry path)

**Intent:** if a previous session captured a skill-level structural signal but `gh` wasn't authenticated at the time, the escalation was queued to `.issue-candidates.jsonl`. This step retries the queue now.

**Preconditions checked:**
- `gh auth status` returns OK
- `~/.claude/.orch-escalation-disabled` does NOT exist

**Flow:**
```bash
flush_escalation_queue() {
  local skill_dir=~/.claude/skills/claude-codex-orchestration
  local candidates=$skill_dir/.issue-candidates.jsonl
  local log=$skill_dir/.issue-log.jsonl
  local repo=dy9759/claude-codex-orchestration

  [ -f ~/.claude/.orch-escalation-disabled ] && return 0
  [ ! -s "$candidates" ] && return 0  # empty or missing
  gh auth status >/dev/null 2>&1 || return 0  # gh not ready

  # For each pending entry: dedup + upload, move to log on success, drop after 5 attempts
  # (see Layer 2.5 dedup flow in self-correction.md)
}

flush_escalation_queue
```

**Safety:**
- Read-only parse of JSONL (no in-place mutation until success confirmed)
- Each entry's `attempts` counter prevents infinite retry loops
- After 5 failed attempts, drop entry with warning to user (not silent)
- Writes are append-only to `.issue-log.jsonl`; candidates removed in batch at end

See `references/self-correction.md` §Layer 2.5 for fingerprint format, dedup logic, and issue body template.

---

## Part 7: Runtime Detection & Routing Setup

**Intent:** Detect which runtime is active and which agents are available for dispatch. Runs once at session start, results cached for session duration. Informs Plan format labels (`[Self]` vs `[Dispatch:CC]` vs `[Dispatch:Codex]`).

```bash
runtime_routing_setup() {
  local harness available
  local helper=".codex/orchestration/bin/detect-orchestration-runtime.sh"

  # 1. Detect current runtime + available agents.
  # Prefer the executable helper installed by install-codex.sh; fallback to
  # cross-harness.md shell functions when the bundle is not installed yet.
  if [ -x "$helper" ]; then
    harness="$("$helper" runtime)"
    available="$("$helper" agents "$harness")"
  else
    harness="$(detect_harness)"
    available="$(detect_available_agents)"
  fi

  # 3. Announce
  echo "[Orchestration] Runtime: $harness | Available agents: $available"
  echo "  Task routing via capability matrix (references/runtime-routing.md)"

  # 4. Cache for session
  export ORCH_RUNTIME="$harness"
  export ORCH_AVAILABLE_AGENTS="$available"

  # 5. Runtime-specific notes
  case "$harness" in
    codex)
      echo "  Codex runtime: dispatching to CC via 'claude -p' for repo-wide tasks"
      echo "  Sub-skills with CC dependency: co-compound (sequential), co-sessions (shell), co-loop (single-exec)"
      ;;
    claude-code)
      echo "  CC runtime: dispatching to Codex via codex:codex-rescue for bounded tasks"
      ;;
    *)
      echo "  Unknown runtime or unavailable peer agents: all tasks execute locally unless the user explicitly routes elsewhere"
      ;;
  esac
}

runtime_routing_setup
```

**Order in Session Start sequence:**
1. Plugin Detection
2. AGENTS.md Bootstrap
3. Global CLAUDE.md §5.2 Auto-Seed
4. Skill Self-Update Check
5. Escalation Queue Flush
6. Sub-skill Install Check
7. **Runtime Detection & Routing Setup** ← new

Part 7 runs after Part 6 because sub-skills must be installed before we can assess which are runtime-compatible.

---

## Data File Lifecycle (informational)

Per-user session state — auto-created on first use, `.gitignore`d, never committed.

| File | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `.eval-scores.jsonl` | `/co-eval` at session end | `/co-review`, Smart Tool RAG quality filter | Two-axis score history, anti-inflation detection |
| `.error-log.jsonl` | Codex failure / integration rejection / Learn-Rule fast path | `/co-review`, Smart Tool RAG quality filter | Error capture, recurrence detection for Layer 3 promotion |
| `.codex-quality.jsonl` | Every Codex dispatch result | Quality tracking (rolling 20-window), auto-evolve trigger | Dispatch success rate, penalty factor, hard-stop gate |
| `.decisions-approved` | Pre-flight Decision Batching | Mid-execution (skip re-asking) | Plan-cycle approvals, cleared at Plan completion |
| `.decisions-pending` | Mid-execution queue | End-of-Plan Consolidated Review | Queued decisions for batch resolution |
| `.tasks/*.json` | CC before parallel Codex dispatch | Both agents during execution; CC at integration audit | Atomic task claiming, owner field prevents double-writes |
| `.issue-candidates.jsonl` | Layer 2.5 when `gh` unavailable | Part 5 flush retry on next session | Pending escalation queue (to skill repo, not project repo) |
| `.issue-log.jsonl` | Layer 2.5 after successful escalation | Historical audit | Uploaded/linked skill-repo issues — **git-tracked** like `.skill-scores.jsonl` |

**First session:** files don't exist yet. Quality filters silent no-op when empty.
**Reset:** `rm ~/.claude/skills/claude-codex-orchestration/.{eval-scores,error-log,codex-quality}.jsonl`
**Disable external escalation:** `touch ~/.claude/.orch-escalation-disabled` (local capture continues).
