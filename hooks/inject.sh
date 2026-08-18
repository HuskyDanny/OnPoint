#!/usr/bin/env bash
# Claude Code hook.
#
# Plain stdout works as context, but it is CAPPED: past ~10 KB Claude Code writes
# the payload to a file and injects a 2 KB preview in its place, so most of the
# rules never reach the model — silently, with the hook still reported as
# succeeding. The bodies are ~12 KB, so the cat form has never delivered them.
# The JSON hookSpecificOutput.additionalContext form has no such cap (verified
# to 40 KB), and SessionStart and SubagentStart both honour it.
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
body="$(cat "$root"/personas/*.md 2>/dev/null || true)"
[ -n "$body" ] || exit 0

# The event name has to match the firing event, so read it off the hook's own
# stdin payload. No stdin (a manual run, a test) falls back to SessionStart.
stdin_json=""
if [ ! -t 0 ]; then stdin_json="$(cat)"; fi

# json.dump does the escaping. Without python3 the cat still runs — a truncated
# injection beats a broken session, which is the same trade the missing-body path
# above makes.
if command -v python3 >/dev/null 2>&1; then
  BODY="$body" HOOK_STDIN="$stdin_json" python3 -c '
import json, os, sys
event = "SessionStart"
try:
    event = json.loads(os.environ["HOOK_STDIN"]).get("hook_event_name") or event
except Exception:
    pass
json.dump({"hookSpecificOutput": {"hookEventName": event,
                                  "additionalContext": os.environ["BODY"]}}, sys.stdout)
sys.stdout.write("\n")
'
else
  printf '%s\n' "$body"
fi
