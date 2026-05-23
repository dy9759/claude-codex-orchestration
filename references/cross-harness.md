# Cross-Harness Environment Layer

The orchestration pattern works across Claude Code, Cursor, Codex, and OpenCode. Different harnesses have different config formats — use this map to stay portable.

## Harness Detection

At session start, detect the **active** harness (which agent is currently running this skill), not just what's installed on the machine. Env vars are authoritative; filesystem is a fallback.

```bash
detect_harness() {
  # Stage 1 — env vars set by the harness process itself (authoritative)
  if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_SESSION:-}" ]; then
    echo "claude-code"; return
  fi
  if [ -n "${CODEX_SESSION_ID:-}" ] || [ -n "${CODEX_THREAD_ID:-}" ] || \
     [ -n "${CODEX_CI:-}" ] || [ -n "${CODEX_SHELL:-}" ]; then
    echo "codex"; return
  fi
  if [ -n "${CURSOR_AGENT:-}" ]; then
    echo "cursor"; return
  fi
  if [ -n "${OPENCODE_SESSION:-}" ]; then
    echo "opencode"; return
  fi

  # Stage 2 — filesystem fallback (project-level hints, less reliable)
  [ -f .cursorrules ] || [ -d .cursor ]    && { echo "cursor";   return; }
  [ -f .opencode/opencode.json ]           && { echo "opencode"; return; }
  command -v codex >/dev/null 2>&1         && { echo "codex";    return; }
  [ -d ~/.claude/skills ]                  && { echo "claude-code"; return; }

  echo "unknown"
}

HARNESS="$(detect_harness)"
```

Filesystem detection is a *project-setup* signal (".cursorrules exists → project uses Cursor"), not a runtime signal. If running Codex CLI in a repo that also has a Claude Code setup, env vars disambiguate; without them, the fallback may misclassify.

Announce harness once: `"Detected harness: [harness]. Applying matching config."` Then proceed.

## Configuration Map

| Concept | Claude Code | Cursor | Codex | OpenCode |
|---------|-------------|--------|-------|----------|
| Global rules | `~/.claude/CLAUDE.md` | `.cursorrules` | `AGENTS.md` | `.opencode/opencode.json` |
| Project rules | `CLAUDE.md` (local) | `.cursor/rules/*.mdc` | `AGENTS.md` | `.opencode/instructions/` |
| Skills/workflows | `~/.claude/skills/*.md` | `.cursor/skills/` | `AGENTS.md` + `.codex/orchestration/` managed block | `.opencode/prompts/` |
| Hooks | `settings.json` hooks | `.cursor/hooks.json` | `.codex/config.toml` approval | `.opencode/` events |
| Slash commands | `/skill-name` via Skill tool | Not supported | Not supported; use AGENTS command equivalents for `/co-*` | Commands in config |
| Agent instructions | CLAUDE.md + SKILL.md | `.cursorrules` | `AGENTS.md` | `.opencode/instructions/` |

## AGENTS.md as Universal Baseline

`AGENTS.md` is read by all four harnesses. Use it to document:
- Role definitions (CC = Tech Lead, Codex = Parallel Implementer)
- Tool permissions per agent
- Blocked file patterns (security gate)
- Workflow summary (plan → split → parallel → integrate)
- Maintainability hard rules (see `maintainability-harness.md`)

Skills defined in `SKILL.md` format (CC-only) → distill key rules into `AGENTS.md` for cross-harness reach.

**Official support** ([code.claude.com/docs/en/memory.md](https://code.claude.com/docs/en/memory.md)): Claude Code auto-expands `@AGENTS.md` in CLAUDE.md. So a one-line `CLAUDE.md` containing only `@AGENTS.md` loads full AGENTS.md content into CC session context.

## Hook Translation

| Claude Code | Cursor | Codex | Purpose |
|-------------|--------|-------|---------|
| `PreToolUse` | `beforeShellExecution` | `approval_policy` gate | Validate before action |
| `PostToolUse` | `afterShellExecution` | Post-run analysis | Analyze result |
| `Notification` | `sessionEnd` | — | State persistence |
| `Stop` | `stop` | — | Audit logging |
| `PreCompact` | `preCompact` | — | Save compact-guard state |

**Shared hook scripts** (obra/superpowers pattern): write hooks as standalone scripts, reference from each harness config. One script, multiple callers — no duplication.

## Skill → Cross-Harness Translation

CC skills have no direct equivalent in other harnesses. Translate:

1. **Core rules** → extract into `AGENTS.md` (universal) and `CLAUDE.md` (CC + Cursor)
2. **Cursor** → distill into `.cursor/rules/orchestration.mdc` (MDC format with frontmatter)
3. **Codex** → run `sub-skills/install-codex.sh`; it copies the skill bundle to `.codex/orchestration/` and adds an AGENTS managed block with `/co-*` command equivalents
4. **OpenCode** → extract to `.opencode/instructions/orchestration.txt`

**Environment variable gating** (from ECC pattern): `HOOK_PROFILE=minimal|standard|strict` to switch hook intensity without editing files. `DISABLED_HOOKS` to gate specific hooks at runtime.

## Agent Availability Detection

Detect which agents are available for dispatch from the current runtime. Called at Phase 0 step 0.

**Executable helper:** use `scripts/detect-orchestration-runtime.sh` from this repo, or `.codex/orchestration/bin/detect-orchestration-runtime.sh` after running `sub-skills/install-codex.sh`.

```bash
./scripts/detect-orchestration-runtime.sh summary
# runtime=codex
# available_agents=codex cc

./scripts/detect-orchestration-runtime.sh route bug-fix
# local:codex
```

The shell functions below are the portable fallback/reference implementation. Keep behavior aligned with the script.

```bash
detect_available_agents() {
  local agents=""
  local runtime="$(detect_harness)"

  case "$runtime" in
    claude-code) agents="$agents cc" ;;
    codex) agents="$agents codex" ;;
  esac

  # CC available?
  if command -v claude >/dev/null 2>&1; then
    # Verify claude CLI responds (not just exists)
    claude --version >/dev/null 2>&1 && agents="$agents cc"
  fi

  # Codex available?
  if command -v codex >/dev/null 2>&1; then
    codex --version >/dev/null 2>&1 && agents="$agents codex"
  fi

  # Gemini available? Direct from CC, relayed through CC from other runtimes.
  if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_SESSION:-}" ]; then
    if grep -q "gemini-cli" ~/.claude/settings.json 2>/dev/null || \
       grep -q "gemini-cli" .claude/settings.json 2>/dev/null; then
      agents="$agents gemini"
    fi
  elif echo "$agents" | grep -qw "cc" && \
       { grep -q "gemini-cli" ~/.claude/settings.json 2>/dev/null || \
         grep -q "gemini-cli" .claude/settings.json 2>/dev/null; }; then
    agents="$agents gemini-via-cc"
  fi

  echo "${agents# }"  # trim leading space
}
```

## Capability Routing Resolution

Given runtime identity and available agents, resolve task routing per capability matrix (`runtime-routing.md`).

```bash
resolve_routing() {
  local task_type="$1" runtime="$2" available="$3"
  local runtime_agent="$runtime"
  [ "$runtime" = "claude-code" ] && runtime_agent="cc"

  # High-risk override. Never automatic cross-agent dispatch.
  case "$task_type" in
    migrations|database|db|cicd|ci|release|secrets|env|package-manifest|package|destructive-git|destructive-file|destructive)
      echo "local:$runtime:requires-explicit-approval"; return ;;
  esac

  # Capability matrix lookup (simplified — full matrix in runtime-routing.md)
  local preferred fallback
  case "$task_type" in
    architecture|planning|frontend|cross-cutting)
      preferred="cc"; fallback="self" ;;
    integration|merge)
      preferred="self"; fallback="" ;;
    bounded-backend|isolated-script|parallel-impl|code-review|isolated-fix|bug-fix|detail-change|maintenance-fix|existing-detail)
      preferred="codex"; fallback="cc" ;;
    ui-design-judgment)
      preferred="gemini"; fallback="cc" ;;
    *)
      preferred="self"; fallback="" ;;
  esac

  if [ "$preferred" = "gemini" ]; then
    if [ "$runtime" = "claude-code" ] && echo "$available" | grep -qw "gemini"; then
      echo "consult:gemini"; return
    fi
    if echo "$available" | grep -qw "gemini-via-cc"; then
      echo "dispatch:cc:gemini-relay"; return
    fi
  fi

  # Resolution: preferred == runtime → local
  if [ "$preferred" = "self" ] || [ "$preferred" = "$runtime_agent" ]; then
    echo "local:$runtime"
    return
  fi

  # Preferred available → dispatch
  if echo "$available" | grep -qw "$preferred"; then
    echo "dispatch:$preferred"
    return
  fi

  # Fallback == runtime → local
  if [ "$fallback" = "self" ] || [ "$fallback" = "$runtime_agent" ]; then
    echo "local:$runtime"
    return
  fi

  # Fallback available → dispatch
  if [ -n "$fallback" ] && echo "$available" | grep -qw "$fallback"; then
    echo "dispatch:$fallback"
    return
  fi

  # Graceful degradation
  echo "local:$runtime:degraded"
}
```

**Usage at Phase 0:**
```bash
RUNTIME="$(detect_harness)"
AVAILABLE="$(detect_available_agents)"
echo "Runtime: $RUNTIME | Available agents: $AVAILABLE"

# Per-task example
resolve_routing "frontend" "$RUNTIME" "$AVAILABLE"
# CC runtime, codex+gemini available → "local:cc" (CC preferred for frontend)
# Codex runtime, cc+gemini available → "dispatch:cc" (CC preferred, dispatch)
```

---

## Bootstrap Per Harness

**Claude Code** (full feature set):
```bash
git clone <repo> ~/.claude/skills/claude-codex-orchestration
# Skill auto-available globally via Skill tool
```

**Cursor** (rule-based, no hooks):
```bash
# Distill SKILL.md → .cursor/rules/orchestration.mdc
# MDC frontmatter: description + globs that trigger the rule
```

**Codex** (AGENTS.md-driven):
```bash
bash sub-skills/install-codex.sh /path/to/project
# Adds AGENTS.md managed block + .codex/orchestration/ skill bundle
```

**OpenCode** (native agent config):
```bash
# Follow .opencode/INSTALL.md
# Define orchestrator agent in opencode.json with appropriate tool permissions
```
