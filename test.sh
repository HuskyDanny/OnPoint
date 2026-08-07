#!/usr/bin/env bash
# The one runnable check. Fails if the hook stops emitting, if --line grows past
# one line, if a missing body kills the run, or if the output-style drifts back
# into being a copy of the bodies instead of a role statement.
set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "FAIL: $*" >&2; exit 1; }

STYLE=output-styles/verboseless.md

# 1. Full injection carries the doctrine and all three axes.
bash hooks/inject.sh | grep -q 'VERBOSELESS ACTIVE' || fail "inject.sh emitted no doctrine"
for axis in 'Detail less' 'Say less' 'Write less'; do
  bash hooks/inject.sh | grep -q "$axis" || fail "inject.sh missing axis: $axis"
done

# 2. The per-prompt reinforcement stays exactly one line. This is the whole reason
#    UserPromptSubmit gets --line instead of the full bodies.
[ "$(bash hooks/inject.sh --line | wc -l | tr -d ' ')" = 1 ] || fail "--line must emit exactly one line"
bash hooks/inject.sh --line | grep -q 'VERBOSELESS ACTIVE' || fail "--line emitted no marker"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 3. A missing body degrades that axis, never the run.
mkdir -p "$tmp/personas"
cp personas/00-doctrine.md "$tmp/personas/"
CLAUDE_PLUGIN_ROOT="$tmp" bash hooks/inject.sh | grep -q 'VERBOSELESS ACTIVE' \
  || fail "a partial personas/ should still emit what it has"
CLAUDE_PLUGIN_ROOT="$tmp" bash hooks/inject.sh | grep -q 'Say less' \
  && fail "absent body should not appear"

# 4. No personas/ at all must still exit 0 — a broken install never breaks a session.
CLAUDE_PLUGIN_ROOT="$tmp/does-not-exist" bash hooks/inject.sh >/dev/null \
  || fail "missing personas dir must exit 0"

# 5. The output-style is a valid, self-contained role statement.
python3 - "$STYLE" <<'PY' || fail "output-style frontmatter is invalid"
import sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
assert lines[0] == "---", "must open with frontmatter"
end = lines.index("---", 1)
keys = dict(l.split(":", 1) for l in lines[1:end] if ":" in l)
assert keys.get("name", "").strip() == "Verboseless", "name must be Verboseless"
assert keys.get("description", "").strip(), "description is required for the /config picker"
# Without this, selecting the style DELETES Claude Code's coding instructions.
assert keys.get("keep-coding-instructions", "").strip() == "true", "keep-coding-instructions must be true"
PY

for behavior in 'Abstract first' 'Caveman when you talk' 'Ponytail when you write' 'Never compressed'; do
  grep -q "$behavior" "$STYLE" || fail "output-style missing behavior: $behavior"
done

# 6. The output-style must stay a SUMMARY, not a second copy of the bodies. If it
#    ever grows past half their size, someone pasted the rulebook into the system
#    prompt and the two surfaces are now duplicating each other.
style_b=$(wc -c < "$STYLE" | tr -d ' ')
bodies_b=$(bash hooks/inject.sh | wc -c | tr -d ' ')
[ "$style_b" -lt $((bodies_b / 2)) ] \
  || fail "output-style is ${style_b}B vs bodies ${bodies_b}B — it is a copy, not a role statement"

# 7. Every manifest is valid JSON.
python3 -c 'import json; [json.load(open(f)) for f in ["hooks/hooks.json",".claude-plugin/plugin.json",".claude-plugin/marketplace.json"]]' \
  || fail "invalid JSON in a manifest"

# 8. The README diagram parses and is actually referenced. A duplicate attribute or
#    stray tag makes GitHub render nothing at all, with no error anywhere.
python3 -c 'import xml.dom.minidom; xml.dom.minidom.parse("assets/verboseless.svg")' \
  || fail "assets/verboseless.svg is not valid XML"
grep -q 'assets/verboseless.svg' README.md || fail "README does not reference the diagram"
grep -q '@keyframes' assets/verboseless.svg || fail "diagram lost its animation"
grep -q 'prefers-reduced-motion' assets/verboseless.svg || fail "diagram must honour reduced-motion"

echo "OK — 3 axes emit, --line is 1 line, degrades safely, style is a ${style_b}B role statement vs ${bodies_b}B rulebook, JSON valid, diagram parses"
