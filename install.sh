#!/usr/bin/env bash
set -euo pipefail

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.claude/skills"
SKILLS=(ultraplan-wave ultracode-wave ultracode-epic)

ASSUME_YES=0
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=1 ;;
    --uninstall) UNINSTALL=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [ "$UNINSTALL" = "1" ]; then
  for skill in "${SKILLS[@]}"; do
    dest="$SKILLS_DIR/$skill"
    if [ -f "$dest/.ultracode-epic-managed" ]; then
      rm -rf "$dest"
      echo "Removed: $skill"
    elif [ -e "$dest" ]; then
      echo "Skipped $skill: exists but wasn't installed by this script."
    fi
  done
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "error: 'claude' (Claude Code CLI) not found on PATH." >&2
  echo "Install Claude Code first: https://claude.com/claude-code" >&2
  exit 1
fi

# Validate every source exists before touching the destination at all —
# fail up front on a partial clone rather than mid-install.
for skill in "${SKILLS[@]}"; do
  if [ ! -f "$SOURCE_DIR/$skill/SKILL.md" ]; then
    echo "error: missing $SOURCE_DIR/$skill/SKILL.md — is this clone complete?" >&2
    exit 1
  fi
done

mkdir -p "$SKILLS_DIR"

for skill in "${SKILLS[@]}"; do
  dest="$SKILLS_DIR/$skill"
  src="$SOURCE_DIR/$skill"

  if [ -e "$dest" ] && [ ! -f "$dest/.ultracode-epic-managed" ]; then
    if [ "$ASSUME_YES" != "1" ]; then
      echo "warning: $dest already exists and wasn't installed by this script."
      read -r -p "  Overwrite it? [y/N] " reply
      case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "  Skipped $skill."; continue ;;
      esac
    fi
  fi

  # Back up rather than delete-then-copy: if cp fails partway, the previous
  # working version is still recoverable instead of gone.
  backup=""
  if [ -e "$dest" ]; then
    backup="${dest}.bak.$$"
    mv "$dest" "$backup"
  fi

  if mkdir -p "$dest" && cp "$src/SKILL.md" "$dest/SKILL.md"; then
    touch "$dest/.ultracode-epic-managed"
    [ -n "$backup" ] && rm -rf "$backup"
    echo "Installed: $skill -> $dest"
  else
    echo "error: failed installing $skill, restoring previous version." >&2
    rm -rf "$dest"
    [ -n "$backup" ] && mv "$backup" "$dest"
    exit 1
  fi
done

echo
echo "Done. Installed: ${SKILLS[*]}"
echo "If Claude Code is already running, start a new session to pick these up."
echo
echo "Smoke test: in the new session, type /ultraplan-wave and confirm it shows up."
echo "Then try it: cd into the repo you want to build in, and run /ultraplan-wave there."
echo
echo "To uninstall later: ./install.sh --uninstall"
