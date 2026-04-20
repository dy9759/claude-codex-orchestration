#!/usr/bin/env bash
# Install the 9 /co-* sub-skills into ~/.claude/skills/ so they become
# real registered Claude Code slash commands. Idempotent.
#
# Usage: bash sub-skills/install.sh [--force]
#   --force  Overwrite existing sub-skills (default: preserve local edits)

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/skills"
FORCE="${1:-}"

SKILLS=(co-eval co-review co-promote co-loop co-compound co-sessions co-think co-plan-review co-score)

installed=0
skipped=0
updated=0

for skill in "${SKILLS[@]}"; do
  src="$SOURCE_DIR/$skill/SKILL.md"
  dst_dir="$TARGET_DIR/$skill"
  dst="$dst_dir/SKILL.md"

  if [ ! -f "$src" ]; then
    echo "WARN: source missing for $skill — skipping"
    continue
  fi

  mkdir -p "$dst_dir"

  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    echo "  ✓ installed $skill"
    ((installed++))
  elif [ "$FORCE" = "--force" ] || ! cmp -s "$src" "$dst"; then
    if [ "$FORCE" = "--force" ]; then
      cp "$src" "$dst"
      echo "  ↻ updated  $skill"
      ((updated++))
    else
      echo "  = $skill (differs from source; use --force to overwrite)"
      ((skipped++))
    fi
  else
    ((skipped++))
  fi
done

echo ""
echo "Done: $installed installed, $updated updated, $skipped unchanged."
echo "Slash commands now available: /co-eval /co-review /co-promote /co-loop /co-compound /co-sessions /co-think /co-plan-review /co-score"
