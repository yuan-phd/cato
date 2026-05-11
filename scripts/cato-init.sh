#!/usr/bin/env bash
# cato-init.sh — deploy Cato into a target project directory.
#
# Usage: cato-init.sh /path/to/target
#
# Copies Cato's workflow definition (.claude/agents/ and CLAUDE.md) and,
# when the target has no .gitignore, the .gitignore. Refuses to overwrite
# any existing .claude/ or CLAUDE.md in the target. See ADR 014 for the
# per-project deployment model.

set -euo pipefail

# --- Locate the cato repo (script lives in <cato>/scripts/) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATO_ROOT="$(dirname "$SCRIPT_DIR")"

# --- Validate arguments ---
if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") /path/to/target" >&2
  echo "Deploys Cato (.claude/, CLAUDE.md, .gitignore) into the target." >&2
  exit 1
fi

TARGET="$1"

if [[ ! -e "$TARGET" ]]; then
  echo "Error: target path does not exist: $TARGET" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target path is not a directory: $TARGET" >&2
  exit 1
fi

# --- Verify cato source files are present ---
SRC_AGENTS="$CATO_ROOT/.claude"
SRC_CLAUDE_MD="$CATO_ROOT/CLAUDE.md"
SRC_GITIGNORE="$CATO_ROOT/.gitignore"

for src in "$SRC_AGENTS" "$SRC_CLAUDE_MD" "$SRC_GITIGNORE"; do
  if [[ ! -e "$src" ]]; then
    echo "Error: cato source missing: $src" >&2
    echo "Is this script being run from a complete cato repo?" >&2
    exit 1
  fi
done

if [[ ! -d "$SRC_AGENTS" ]]; then
  echo "Error: $SRC_AGENTS is not a directory" >&2
  exit 1
fi

# --- Conflict check (refuse on conflict for .claude and CLAUDE.md) ---
CONFLICTS=()
[[ -e "$TARGET/.claude" ]]   && CONFLICTS+=("$TARGET/.claude")
[[ -e "$TARGET/CLAUDE.md" ]] && CONFLICTS+=("$TARGET/CLAUDE.md")

if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
  echo "Error: target already contains Cato file(s):" >&2
  for c in "${CONFLICTS[@]}"; do
    echo "  $c" >&2
  done
  echo "Refusing to overwrite. Remove or back up these files and rerun." >&2
  exit 1
fi

# --- Deploy ---
cp -R "$SRC_AGENTS"   "$TARGET/.claude"
cp    "$SRC_CLAUDE_MD" "$TARGET/CLAUDE.md"

GITIGNORE_MODE=""
if [[ -e "$TARGET/.gitignore" ]]; then
  GITIGNORE_MODE="append"
else
  cp "$SRC_GITIGNORE" "$TARGET/.gitignore"
  GITIGNORE_MODE="copied"
fi

# --- Post-deploy guidance ---
echo "Cato deployed into: $TARGET"
echo
echo "Files written:"
echo "  $TARGET/.claude/"
echo "  $TARGET/CLAUDE.md"
if [[ "$GITIGNORE_MODE" == "copied" ]]; then
  echo "  $TARGET/.gitignore"
fi
echo
echo "Next steps:"
echo "  1. Edit $TARGET/CLAUDE.md and replace the 'Project Context'"
echo "     section with this project's name, description, stack, and"
echo "     lint/test/build commands."

if [[ "$GITIGNORE_MODE" == "append" ]]; then
  echo
  echo "  2. The target already had a .gitignore; not overwritten."
  echo "     Append the following Cato-required entry to it:"
  echo
  echo "     # Cato workflow state (ephemeral; not source-controlled)"
  echo "     .cato/"
  echo
  echo "  3. Start (or restart) Claude Code from $TARGET to use Cato."
else
  echo "  2. Start (or restart) Claude Code from $TARGET to use Cato."
fi
