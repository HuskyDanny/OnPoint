#!/usr/bin/env bash
# Every invariant here was verified to FAIL when broken. A test that can't go red
# proves nothing.
set -euo pipefail
cd "$(dirname "$0")"

n=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { n=$((n+1)); }

STYLE=output-styles/verboseless.md
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# ── the hook ─────────────────────────────────────────────────────────────────
# Plain stdout is CAPPED: past ~10 KB Claude Code spills the payload to a file and
# injects a 2 KB preview instead — silently, with the hook still reported as
# succeeding. Measured on 2.1.234: 10001 B inlines, 10050 B spills. The bodies are
# ~12 KB, so they MUST go out as JSON additionalContext, which has no cap.
bash hooks/inject.sh </dev/null > "$tmp/hook.json" || fail "inject.sh exited non-zero"
python3 - "$tmp/hook.json" <<'HOOKJSON' || fail "inject.sh must emit JSON additionalContext, not raw stdout"
import json, sys
d = json.load(open(sys.argv[1]))["hookSpecificOutput"]
assert d["hookEventName"], "hookEventName is required"
ctx = d["additionalContext"]
for section in ("VERBOSELESS ACTIVE", "Essence first", "i-have-adhd", "Say less"):
    assert section in ctx, f"missing section: {section}"
HOOKJSON
ok

# The per-prompt reinforcement must stay one line — the whole reason
# UserPromptSubmit gets --line instead of the full bodies.
[ "$(bash hooks/inject.sh --line | wc -l | tr -d ' ')" = 1 ] || fail "--line must emit exactly one line"; ok
bash hooks/inject.sh --line | grep -q 'VERBOSELESS ACTIVE' || fail "--line emitted no marker"; ok

# A missing body degrades that axis, never the run.
mkdir -p "$tmp/personas"; cp personas/00-doctrine.md "$tmp/personas/"
CLAUDE_PLUGIN_ROOT="$tmp" bash hooks/inject.sh </dev/null | grep -q 'VERBOSELESS ACTIVE' \
  || fail "a partial personas/ should still emit what it has"; ok
if CLAUDE_PLUGIN_ROOT="$tmp" bash hooks/inject.sh </dev/null | grep -q 'Say less'; then
  fail "an absent body must not appear"
fi; ok
CLAUDE_PLUGIN_ROOT="$tmp/nope" bash hooks/inject.sh </dev/null >/dev/null \
  || fail "a missing personas dir must still exit 0 — a broken install never breaks a session"; ok

# ── the output style: a role statement, never a second copy ───────────────────
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
ok
# All three source personas must be NAMED here — the style is the role statement,
# so naming two and leaving one as a description is how a surface drifts.
for behavior in 'Abstract first' 'i-have-adhd' 'Caveman when you talk' 'Never compressed'; do
  grep -q "$behavior" "$STYLE" || fail "output-style missing behavior: $behavior"; ok
done
style_b=$(wc -c < "$STYLE" | tr -d ' ')
bodies_b=$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["hookSpecificOutput"]["additionalContext"].encode()))' "$tmp/hook.json")
[ "$style_b" -lt $((bodies_b / 2)) ] \
  || fail "output-style is ${style_b}B vs bodies ${bodies_b}B — it became a copy, so the system prompt and the tail now both carry it"; ok

# The ratio above gets EASIER to pass as the bodies grow, so it cannot catch bloat.
# This is the absolute budget: a repo about compression may not ship a fat prompt.
[ "$bodies_b" -lt 12500 ] \
  || fail "bodies are ${bodies_b}B, past the 12500B budget — cut before adding"; ok

# ── generated agent surfaces are in sync with personas/ ──────────────────────
./build.sh "$tmp/build" >/dev/null
stale=0
while read -r f; do
  [ -f "$f" ] || { echo "  missing: $f"; stale=1; continue; }
  cmp -s "$f" "$tmp/build/$f" || { echo "  stale: $f"; stale=1; }
done < <(./build.sh --list)
[ "$stale" = 0 ] || fail "generated surfaces differ from a fresh build — run ./build.sh"; ok
surfaces=$(./build.sh --list | wc -l | tr -d ' ')

# ── manifests and artwork parse ──────────────────────────────────────────────
python3 -c 'import json; [json.load(open(f)) for f in [
  "hooks/hooks.json",".claude-plugin/plugin.json",".claude-plugin/marketplace.json",
  "gemini-extension.json",".codex/hooks.json",
  ".codex-plugin/plugin.json",".devin-plugin/plugin.json",".qoder-plugin/plugin.json"]]' \
  || fail "invalid JSON in a manifest"; ok

# Claude Code auto-loads the standard hooks/hooks.json, so naming it in the manifest
# too is a DUPLICATE and the whole hook load fails:
#   "Duplicate hooks file detected: ./hooks/hooks.json resolves to already-loaded
#    file … manifest.hooks should only reference additional hook files."
# Silent: /plugin shows the plugin enabled, only `claude plugin list --json` errors.
python3 - <<'PY' || fail "a plugin manifest declares hooks wrongly"
import json, os
cc = json.load(open(".claude-plugin/plugin.json"))
assert "hooks" not in cc, (
    "'.claude-plugin/plugin.json' must NOT declare hooks — hooks/hooks.json is "
    "auto-loaded, and naming it again makes Claude Code drop every hook")
assert os.path.isfile("hooks/hooks.json"), "the auto-loaded hooks file is missing"

# Other hosts have no such auto-load convention, so they still need the pointer.
for m in [".codex-plugin/plugin.json", ".devin-plugin/plugin.json",
          ".qoder-plugin/plugin.json"]:
    h = json.load(open(m)).get("hooks")
    assert h, f"{m} has no hooks key — that host would inject nothing"
    assert os.path.isfile(h.removeprefix("./")), f"{m} points at a missing {h}"

# Same silent-no-injection class, one layer down: the hook file's own command, and
# Gemini's context file, must exist too. Valid JSON, zero behavior, no error.
for ev in json.load(open("hooks/hooks.json"))["hooks"].values():
    for group in ev:
        for hook in group["hooks"]:
            script = hook["command"].split("/hooks/")[-1].split()[0]
            assert os.path.isfile("hooks/" + script), f"hook command missing: {script}"
assert os.path.isfile(json.load(open("gemini-extension.json"))["contextFileName"])
PY
ok

# The Codex hook payload has to survive JSON quoting AND shell quoting.
codex_cmd=$(python3 -c 'import json;print(json.load(open(".codex/hooks.json"))["hooks"]["SessionStart"][0]["hooks"][0]["command"])')
eval "$codex_cmd" | grep -q 'VERBOSELESS ACTIVE' || fail "codex hook command does not run in a shell"; ok

for svg in assets/verboseless.svg assets/banner.svg; do
  python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('$svg')" \
    || fail "$svg is not valid XML — GitHub renders nothing, with no error anywhere"; ok
  grep -q '@keyframes' "$svg"            || fail "$svg lost its animation"; ok
  grep -q 'prefers-reduced-motion' "$svg" || fail "$svg must honour reduced-motion"; ok
done
grep -q 'assets/verboseless.svg' README.md || fail "README does not reference the diagram"; ok
grep -q 'assets/banner.svg' README.md      || fail "README does not reference the banner"; ok

# No operator identifiers anywhere in a public repo — the guard that makes the
# republished benchmark safe. The needles are assembled from fragments so that this
# file does not match its own pattern.
needles="$(printf 'mi%s|kha%s|mel%s' 'thra' 'zad' 'lon')"
if grep -rIl -iE "$needles" --exclude-dir=.git . >/dev/null 2>&1; then
  echo "  leaked in: $(grep -rIl -iE "$needles" --exclude-dir=.git . | tr '\n' ' ')" >&2
  fail "operator identifier leaked into the repo"
fi; ok

# LICENSE must hold exactly one license, or GitHub's detector gives up and the repo
# renders "license: not identifiable by github". Upstream texts live elsewhere.
[ "$(grep -c 'MIT License' LICENSE)" = 1 ] \
  || fail "LICENSE contains more than one license — GitHub cannot detect it"; ok
for who in 'Julius Brussee' 'Ayoub Ghriss'; do
  grep -q "$who" LICENSES-THIRD-PARTY.md || fail "LICENSES-THIRD-PARTY.md is missing $who"; ok
done

# ── the installer, which writes into someone else's repo ─────────────────────
proj="$tmp/proj"; mkdir -p "$proj/.cursor"
printf 'MY OWN RULES\nnever delete the database.\n' > "$proj/AGENTS.md"
cp "$proj/AGENTS.md" "$tmp/agents.orig"

before=$(cd "$proj" && find . -type f | sort | xargs shasum | shasum)
./install.sh --target "$proj" --dry-run >/dev/null
[ "$before" = "$(cd "$proj" && find . -type f | sort | xargs shasum | shasum)" ] \
  || fail "--dry-run wrote something"; ok

./install.sh --target "$proj" >/dev/null
[ -f "$proj/.cursor/rules/verboseless.mdc" ] || fail "detected cursor but installed nothing"; ok
if [ -d "$proj/.windsurf" ]; then fail "installed windsurf with no marker present"; fi; ok
grep -q 'never delete the database' "$proj/AGENTS.md" \
  || fail "DESTROYED the user's own AGENTS.md content"; ok
head -1 "$proj/AGENTS.md" | grep -q 'MY OWN RULES' || fail "moved the user's content"; ok

a=$(shasum < "$proj/AGENTS.md"); ./install.sh --target "$proj" >/dev/null
[ "$a" = "$(shasum < "$proj/AGENTS.md")" ] || fail "re-running the installer is not idempotent"; ok
[ "$(grep -c 'verboseless:begin' "$proj/AGENTS.md")" = 1 ] || fail "duplicate spliced blocks"; ok

# The plugin's hook already injects the body; splicing CLAUDE.md too would put the
# same ~12 KB in the cached system prefix as well. A stub `claude` on PATH keeps this
# deterministic instead of depending on what is installed on the machine running it.
stub="$tmp/stub"; mkdir -p "$stub"
printf '#!/bin/sh\necho "[]"\n' > "$stub/claude"; chmod +x "$stub/claude"
dup="$tmp/dup"; mkdir -p "$dup/.claude"; printf 'MY RULES\n' > "$dup/CLAUDE.md"

PATH="$stub:$PATH" HOME="$tmp/nohome" ./install.sh --target "$dup" >/dev/null
grep -q 'verboseless:begin' "$dup/CLAUDE.md" \
  || fail "no plugin present, so CLAUDE.md should carry the block"; ok

mkdir -p "$tmp/withhome/.claude/plugins/cache/verboseless"
printf 'MY RULES\n' > "$dup/CLAUDE.md"
PATH="$stub:$PATH" HOME="$tmp/withhome" ./install.sh --target "$dup" >/dev/null
if grep -q 'verboseless:begin' "$dup/CLAUDE.md"; then
  fail "the plugin is installed — splicing CLAUDE.md doubles the same body"
fi; ok
PATH="$stub:$PATH" HOME="$tmp/withhome" VERBOSELESS_FORCE_CLAUDE=1 ./install.sh --target "$dup" >/dev/null
grep -q 'verboseless:begin' "$dup/CLAUDE.md" || fail "the force override must still install it"; ok

./install.sh --target "$proj" --uninstall >/dev/null
cmp -s "$proj/AGENTS.md" "$tmp/agents.orig" \
  || fail "--uninstall did not restore AGENTS.md byte-for-byte"; ok
if [ -f "$proj/.cursor/rules/verboseless.mdc" ]; then fail "--uninstall left a dedicated file behind"; fi; ok

echo "OK — $n invariants, $surfaces agent surfaces in sync, style is ${style_b}B vs ${bodies_b}B of rules"
