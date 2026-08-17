#!/usr/bin/env bash
# Claude Code hook. SessionStart, UserPromptSubmit and SubagentStart all accept
# plain stdout as context, so this is a cat — no JSON, no escaping, no interpreter.
#
# Glob order IS the axis order: 00-doctrine, 01-essence-first, 02-say-less.
# Renaming or deleting a file is how you reorder or disable an axis.
# There is no config to read.
#
# --line emits the one-line reinforcement instead of the full bodies. Full bodies
# on every prompt would stack one copy per turn into the re-sent context, which is
# the exact cost pool this repo exists to shrink.
set -uo pipefail

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [ "${1:-}" = "--line" ]; then
  echo "VERBOSELESS ACTIVE — essence first (name the essence, verdict first, then the one next action), say less (terse, no filler). Substance, security and exact errors never compressed."
  exit 0
fi

# A missing or unreadable body degrades that one axis, never the run.
cat "$root"/personas/*.md 2>/dev/null || true
