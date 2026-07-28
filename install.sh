#!/usr/bin/env bash
set -euo pipefail

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.claude/skills"
SKILLS=(ultraplan-wave ultracode-wave ultracode-epic)

if ! command -v claude >/dev/null 2>&1; then
  echo "error: 'claude' (Claude Code CLI) not found on PATH." >&2
  echo "Install Claude Code first: https://claude.com/claude-code" >&2
  exit 1
fi

mkdir -p "$SKILLS_DIR"

for skill in "${SKILLS[@]}"; do
  dest="$SKILLS_DIR/$skill"
  src="$SOURCE_DIR/$skill"

  if [ -e "$dest" ] && [ ! -f "$dest/.ultracode-epic-managed" ]; then
    echo "warning: $dest already exists and wasn't installed by this script."
    read -r -p "  Overwrite it? [y/N] " reply
    case "$reply" in
      [yY]|[yY][eE][sS]) ;;
      *) echo "  Skipped $skill."; continue ;;
    esac
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$src/SKILL.md" "$dest/SKILL.md"
  touch "$dest/.ultracode-epic-managed"
  echo "Installed: $skill -> $dest"
done

echo
echo "Done. Installed: ${SKILLS[*]}"
echo "If Claude Code is already running, start a new session to pick these up."
echo
echo "Try it: open a repo, run /ultraplan-wave and describe what you want to build."
