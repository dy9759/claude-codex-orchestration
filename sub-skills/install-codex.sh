#!/usr/bin/env bash
# Install orchestration skill references into Codex-accessible locations.
# When Codex is the runtime, it reads AGENTS.md but not ~/.claude/skills/.
# This script copies the skill into project-level .codex/orchestration and
# inserts a managed AGENTS.md block so Codex can discover it.
#
# Usage: bash sub-skills/install-codex.sh [project-root]
#   project-root  Defaults to current git repo root

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CODEX_DIR="$PROJECT_ROOT/.codex"
ORCH_DIR="$CODEX_DIR/orchestration"
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"

mkdir -p "$ORCH_DIR/commands" "$ORCH_DIR/bin"

cp "$SKILL_DIR/SKILL.md" "$ORCH_DIR/SKILL.md"
echo "  -> SKILL.md"

# Copy references Codex may need when acting as orchestrator.
REFS=()
while IFS= read -r ref; do
  REFS+=("$ref")
done < <(cd "$SKILL_DIR/references" && printf '%s\n' *.md | sort)

copied=0
for ref in "${REFS[@]}"; do
  src="$SKILL_DIR/references/$ref"
  dst="$ORCH_DIR/$ref"
  if [ -f "$src" ]; then
    cp "$src" "$dst"
    echo "  -> $ref"
    copied=$((copied + 1))
  else
    echo "  WARN: $ref not found in skill references"
  fi
done

commands=0
for src in "$SKILL_DIR"/sub-skills/co-*/SKILL.md; do
  [ -f "$src" ] || continue
  name="$(basename "$(dirname "$src")")"
  cp "$src" "$ORCH_DIR/commands/$name.md"
  commands=$((commands + 1))
done
echo "  -> $commands command equivalent docs"

script_count=0
for src in "$SKILL_DIR"/scripts/*.sh; do
  [ -f "$src" ] || continue
  name="$(basename "$src")"
  cp "$src" "$ORCH_DIR/bin/$name"
  chmod +x "$ORCH_DIR/bin/$name"
  script_count=$((script_count + 1))
  echo "  -> bin/$name"
done

block_file="$(mktemp)"
cat > "$block_file" <<'BLOCK'
<!-- BEGIN CLAUDE-CODEX-ORCHESTRATION -->
## Claude-Codex Orchestration

Codex should use the local orchestration bundle in `.codex/orchestration/`.

- Start by reading `.codex/orchestration/SKILL.md` when the user mentions `claude-codex-orchestration`, asks for Claude/Codex cooperation, requests `/co-*`, or asks for planning/routing/skill self-correction.
- For task routing, read `.codex/orchestration/runtime-routing.md` and `.codex/orchestration/codex-runtime.md`.
- For fuzzy, high-verification-risk, long-running, or external-handoff tasks, read `.codex/orchestration/harness-workflows.md` and use its Run Contract, Route Brief, and Proof Pack patterns.
- To detect runtime/agent availability, run `.codex/orchestration/bin/detect-orchestration-runtime.sh summary` and use `route <task-type>` for concrete routing decisions.
- For cross-agent dispatch monitoring, use `.codex/orchestration/heartbeat-protocol.md`; use `.codex/orchestration/bin/run-with-timeout.sh` instead of assuming GNU `timeout` exists.
- For high-risk work (DB migrations, env/secrets, package manifests, CI/CD/release, destructive git/file ops), do not auto-dispatch. Produce a plan, ask for explicit approval, and keep execution with the current orchestrator unless the user explicitly routes it elsewhere.

Codex command equivalents:

- `/co-think`: read `.codex/orchestration/commands/co-think.md` and follow it as a natural-language workflow.
- `/co-plan-review`: read `.codex/orchestration/commands/co-plan-review.md`.
- `/co-score`: read `.codex/orchestration/commands/co-score.md`.
- `/co-eval`: read `.codex/orchestration/commands/co-eval.md`.
- `/co-review`: read `.codex/orchestration/commands/co-review.md`.
- `/co-promote`: read `.codex/orchestration/commands/co-promote.md`.
- `/co-loop`: read `.codex/orchestration/commands/co-loop.md`; in Codex it is single-run only.
- `/co-compound`: read `.codex/orchestration/commands/co-compound.md`; run subagent phases sequentially in Codex.
- `/co-sessions`: read `.codex/orchestration/commands/co-sessions.md`; use shell search instead of Claude Code Agent.
<!-- END CLAUDE-CODEX-ORCHESTRATION -->
BLOCK

tmp_file="$(mktemp)"
if [ -f "$AGENTS_FILE" ] && grep -q '<!-- BEGIN CLAUDE-CODEX-ORCHESTRATION -->' "$AGENTS_FILE"; then
  awk -v block="$block_file" '
    BEGIN {
      while ((getline line < block) > 0) replacement = replacement line "\n"
    }
    /<!-- BEGIN CLAUDE-CODEX-ORCHESTRATION -->/ {
      printf "%s", replacement
      skip = 1
      next
    }
    skip && /<!-- END CLAUDE-CODEX-ORCHESTRATION -->/ {
      skip = 0
      next
    }
    !skip { print }
  ' "$AGENTS_FILE" > "$tmp_file"
else
  [ -f "$AGENTS_FILE" ] && cat "$AGENTS_FILE" > "$tmp_file" || : > "$tmp_file"
  [ -s "$tmp_file" ] && printf '\n' >> "$tmp_file"
  cat "$block_file" >> "$tmp_file"
fi
mv "$tmp_file" "$AGENTS_FILE"
rm -f "$block_file"
echo "  Updated AGENTS.md managed block"

# Ensure .codex/orchestration is gitignored (user-local, not committed)
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ ! -f "$GITIGNORE" ]; then
  touch "$GITIGNORE"
fi
if ! grep -q '.codex/orchestration' "$GITIGNORE" 2>/dev/null; then
  echo ".codex/orchestration/" >> "$GITIGNORE"
  echo "  Added .codex/orchestration/ to .gitignore"
fi

echo ""
echo "Done: $copied references copied to $ORCH_DIR/"
echo "Codex can now discover this skill through AGENTS.md."
