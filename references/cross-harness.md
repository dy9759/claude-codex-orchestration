# Cross-Harness Environment Layer

The orchestration pattern works across Claude Code, Cursor, Codex, and OpenCode. Different harnesses have different config formats — use this map to stay portable.

## Harness Detection

At session start, detect active harness:
```bash
if ls ~/.claude/skills/ &>/dev/null; then echo "HARNESS=claude-code"
elif [[ -d .cursor || -f .cursorrules ]]; then echo "HARNESS=cursor"
elif [[ -f .opencode/opencode.json ]]; then echo "HARNESS=opencode"
elif command -v codex &>/dev/null; then echo "HARNESS=codex"
fi
```

Announce harness once: `"Detected harness: [harness]. Applying matching config."` Then proceed.

## Configuration Map

| Concept | Claude Code | Cursor | Codex | OpenCode |
|---------|-------------|--------|-------|----------|
| Global rules | `~/.claude/CLAUDE.md` | `.cursorrules` | `AGENTS.md` | `.opencode/opencode.json` |
| Project rules | `CLAUDE.md` (local) | `.cursor/rules/*.mdc` | `AGENTS.md` | `.opencode/instructions/` |
| Skills/workflows | `~/.claude/skills/*.md` | `.cursor/skills/` | No native equivalent | `.opencode/prompts/` |
| Hooks | `settings.json` hooks | `.cursor/hooks.json` | `.codex/config.toml` approval | `.opencode/` events |
| Slash commands | `/skill-name` via Skill tool | Not supported | Not supported | Commands in config |
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
3. **Codex** → AGENTS.md covers most; add orchestration config to `.codex/config.toml`
4. **OpenCode** → extract to `.opencode/instructions/orchestration.txt`

**Environment variable gating** (from ECC pattern): `HOOK_PROFILE=minimal|standard|strict` to switch hook intensity without editing files. `DISABLED_HOOKS` to gate specific hooks at runtime.

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
# Copy AGENTS.md to project root
# Add orchestration config to .codex/config.toml:
# [profiles.orchestrate] sandbox_mode = "workspace-write"
```

**OpenCode** (native agent config):
```bash
# Follow .opencode/INSTALL.md
# Define orchestrator agent in opencode.json with appropriate tool permissions
```
