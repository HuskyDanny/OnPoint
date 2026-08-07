#!/usr/bin/env bash
# Install verboseless into whichever agents a project actually uses.
#
#   ./install.sh                 detect agents in the current directory, install those
#   ./install.sh --all           install every surface regardless of detection
#   ./install.sh --dry-run       print what would change, touch nothing
#   ./install.sh --target DIR    install into DIR instead of the current directory
#   ./install.sh --uninstall     remove what this installed
#
# Two classes of destination, handled differently on purpose:
#
#   DEDICATED  .cursor/rules/verboseless.mdc, .clinerules/verboseless.md, …
#              Ours alone. Written whole.
#
#   SHARED     AGENTS.md, CLAUDE.md, GEMINI.md, .github/copilot-instructions.md
#              Usually already full of the user's own instructions. NEVER
#              overwritten — spliced between markers, idempotently, so a re-run
#              replaces our block and leaves everything else byte-identical.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
TARGET="$PWD"
MODE=detect
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --all) MODE=all ;;
    --uninstall) MODE=uninstall ;;
    --dry-run|-n) DRY=1 ;;
    --target) TARGET="$2"; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

[ -d "$TARGET" ] || { echo "no such directory: $TARGET" >&2; exit 1; }
[ -f "$SRC/personas/00-doctrine.md" ] || { echo "run this from a verboseless checkout" >&2; exit 1; }

# agent | marker that says "this project uses it" | source in checkout | destination
# src and dest differ where an agent wants the file somewhere else (claude-code).
AGENTS="
cursor|.cursor|.cursor/rules/verboseless.mdc|.cursor/rules/verboseless.mdc
windsurf|.windsurf|.windsurf/rules/verboseless.md|.windsurf/rules/verboseless.md
cline|.clinerules|.clinerules/verboseless.md|.clinerules/verboseless.md
kiro|.kiro|.kiro/steering/verboseless.md|.kiro/steering/verboseless.md
qoder|.qoder|.qoder/rules/verboseless.md|.qoder/rules/verboseless.md
opencode|.opencode|.opencode/command/verboseless.md|.opencode/command/verboseless.md
openclaw|.openclaw|.openclaw/skills/verboseless/SKILL.md|.openclaw/skills/verboseless/SKILL.md
claude-code|.claude|skills/verboseless/SKILL.md|.claude/skills/verboseless/SKILL.md
codex|.codex|.codex/config.toml|.codex/config.toml
codex-hooks|.codex|.codex/hooks.json|.codex/hooks.json
"
# shared files: agent | marker | destination | which generated file supplies the body
SHARED="
agents-md|AGENTS.md|AGENTS.md|AGENTS.md
claude-md|CLAUDE.md|CLAUDE.md|CLAUDE.md
gemini|GEMINI.md|GEMINI.md|GEMINI.md
copilot|.github|.github/copilot-instructions.md|.github/copilot-instructions.md
"

BEGIN="<!-- verboseless:begin — generated, edit personas/ upstream instead -->"
END="<!-- verboseless:end -->"

say() { printf '  %-12s %s\n' "$1" "$2"; }

splice() { # splice <destfile> <bodyfile>
  BEGIN="$BEGIN" END="$END" python3 - "$1" "$2" <<'PY'
import os, sys, pathlib
dest, body_src = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
b, e = os.environ["BEGIN"], os.environ["END"]
block = f"{b}\n{body_src.read_text(encoding='utf-8').strip()}\n{e}\n"
old = dest.read_text(encoding="utf-8") if dest.exists() else ""
if b in old and e in old:                      # idempotent replace
    head, rest = old.split(b, 1)
    _, tail = rest.split(e, 1)
    new = head + block + tail.lstrip("\n")
else:                                          # append, never clobber
    new = (old.rstrip("\n") + "\n\n" if old.strip() else "") + block
if new != old:
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(new, encoding="utf-8")
    print("changed")
else:
    print("unchanged")
PY
}

unsplice() { # unsplice <destfile>
  BEGIN="$BEGIN" END="$END" python3 - "$1" <<'PY'
import os, sys, pathlib
dest = pathlib.Path(sys.argv[1])
b, e = os.environ["BEGIN"], os.environ["END"]
if not dest.exists(): print("absent"); raise SystemExit
old = dest.read_text(encoding="utf-8")
if b not in old or e not in old: print("absent"); raise SystemExit
head, rest = old.split(b, 1)
_, tail = rest.split(e, 1)
new = (head.rstrip("\n") + "\n" + tail.lstrip("\n")).strip()
dest.write_text(new + "\n" if new else "", encoding="utf-8")
print("removed")
PY
}

echo "verboseless → $TARGET"
[ "$DRY" = 1 ] && echo "  (dry run — nothing will be written)"
n=0

# ── dedicated files ──────────────────────────────────────────────────────────
while IFS='|' read -r name marker src dest; do
  [ -n "$name" ] || continue
  if [ "$MODE" = detect ] && [ ! -e "$TARGET/$marker" ]; then continue; fi
  if [ "$MODE" = uninstall ]; then
    if [ -e "$TARGET/$dest" ]; then
      [ "$DRY" = 1 ] || rm -f "$TARGET/$dest"
      say "$name" "removed $dest"; n=$((n+1))
    fi
    continue
  fi
  [ -f "$SRC/$src" ] || { say "$name" "SKIP — $src missing from checkout (run ./build.sh)"; continue; }
  if [ "$DRY" = 1 ]; then say "$name" "would write $dest"
  else
    mkdir -p "$TARGET/$(dirname "$dest")"
    cp "$SRC/$src" "$TARGET/$dest"
    say "$name" "wrote $dest"
  fi
  n=$((n+1))
done <<< "$AGENTS"

# ── shared files: splice, never overwrite ────────────────────────────────────
while IFS='|' read -r name marker dest body; do
  [ -n "$name" ] || continue
  if [ "$MODE" = detect ] && [ ! -e "$TARGET/$marker" ]; then continue; fi
  if [ "$MODE" = uninstall ]; then
    r=$([ "$DRY" = 1 ] && echo "would unsplice" || unsplice "$TARGET/$dest")
    [ "$r" = absent ] || { say "$name" "$r block from $dest"; n=$((n+1)); }
    continue
  fi
  [ -f "$SRC/$body" ] || { say "$name" "SKIP — $body missing (run ./build.sh)"; continue; }
  if [ "$DRY" = 1 ]; then
    say "$name" "would splice block into $dest$([ -f "$TARGET/$dest" ] && echo ' (existing file preserved)')"
  else
    r=$(splice "$TARGET/$dest" "$SRC/$body")
    say "$name" "$r $dest"
  fi
  n=$((n+1))
done <<< "$SHARED"

if [ "$n" = 0 ]; then
  echo "  no agents detected here. Use --all to install every surface,"
  echo "  or --help to see the list."
else
  echo "  $n surface(s). Re-run any time — shared files are spliced, not overwritten."
fi
