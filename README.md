# verboseless

Three axes of compression on one switch: **think at altitude, say it terse, build
the smallest thing that works.** Substance is never compressed.

> Everything can be abstract. Einstein could state relativity in one sentence; a
> person who truly knows a thing explains it simply.

## Install

```
/plugin marketplace add HuskyDanny/verboseless-all-in-one
/plugin install verboseless@verboseless
```

Then start a new session. You should see `VERBOSELESS ACTIVE` in the SessionStart
context. Turn it off for a turn with "stop verboseless" / "normal mode".

## The three axes

| file | axis | forces |
|---|---|---|
| `personas/01-detail-less.md` | **detail less** | open with the big idea at design altitude; verdict first on a pointed question; no file paths or numbered plans in the first line |
| `personas/02-say-less.md` | **say less** | drop articles, filler, pleasantries, hedging, tool-call narration; exact errors and code stay verbatim |
| `personas/03-write-less.md` | **write less** | YAGNI ladder — does it need to exist, is it already here, does stdlib do it, can it be one line |

The order is load-bearing. You cannot compress an idea you have not named, and
you cannot write the smallest code for a problem you have not stated simply.
Altitude, then words, then code.

`personas/00-doctrine.md` carries the shared preamble and the never-compress list:
technical substance, exact error strings, code, trust-boundary validation, error
handling that prevents data loss, security, accessibility, and anything the user
explicitly asked for in full.

## How it works

Hooks in Claude Code are commands, and for `SessionStart`, `UserPromptSubmit` and
`SubagentStart` **whatever a command prints on stdout becomes context Claude
sees.** So the entire mechanism is a `cat`:

```bash
cat "$root"/personas/*.md
```

Glob order is the axis order. Renaming a file reorders an axis; deleting one turns
it off. There is no config file, no environment variable, no state file, and no
interpreter — nothing to parse means nothing to get wrong.

### Why a hook and not CLAUDE.md

Same words, different position. `CLAUDE.md` sits in the cached system prefix —
stated once at the head, its salience decaying as the transcript grows. A hook's
output lands as a system message at the **tail**, re-fired on every prompt and
again on every compaction. Repetition next to the live turn is what actually
holds the behavior.

### The injection budget

| event | payload | why |
|---|---|---|
| `SessionStart` (`startup\|resume\|clear\|compact`) | full bodies | first turn, and re-fires after compaction |
| `UserPromptSubmit` | one line | the full bodies here would stack one copy per prompt into the re-sent context — the exact cost pool this repo exists to shrink |
| `SubagentStart` | full bodies | a subagent's report *is* the parent's context, so compressing it pays twice |

That last row diverges from upstream on purpose: ponytail injects into subagents,
caveman does not. Caveman's absence there reads as an omission rather than a
decision — a verbose subagent report is billed to the parent for the rest of the
run.

## The output style — the role, not the rules

`output-styles/verboseless.md` is the second surface, and it deliberately carries
**different content at a different altitude**. The output style says *who you are
and which behavior governs which surface*; the hook bodies say *exactly how*.

```
                  OUTPUT STYLE  (role)              HOOK  (rules)
position          end of system prompt, cached       tail, next to the live turn
size              3.7 KB                            12.1 KB
answers           "which behavior, on what"          "and here is every rule"
reinforced        natively, by Claude Code           re-fired on prompt + compaction
reaches subagents no — they run their own prompt     yes, via SubagentStart
```

Enable it with `/config` → **Output style** → `Verboseless`. The whole style is
one routing table plus its consequences:

| surface | behave like | means |
|---|---|---|
| the **first line** of any answer | abstract first | name the big idea, then stop |
| everything you **say** | caveman | terse prose, no filler |
| everything you **write** | ponytail | the laziest code that works |

Two things to know:

- **It is exclusive.** Only one output style is active at a time, so selecting
  this one replaces whatever you had. `force-for-plugin` is deliberately *not*
  set in the frontmatter, so installing this plugin never hijacks your choice.
- **It is hand-written, not generated.** It is not a copy of `personas/`, and it
  must never become one — the moment the same text sits in both the system prompt
  and the tail, you are paying twice for one instruction. `test.sh` enforces this:
  the style must stay under half the size of the bodies.

## Does it actually work

Measured on an agentic coding swarm (Claude Agent SDK worker, GLM-5.2, dev EKS),
combining the say-less and write-less axes against an identical task:

| | baseline | verboseless | Δ |
|---|---|---|---|
| total tokens | 252,039 | 194,829 | **−22.7%** |
| cost | $3.26 | $2.48 | **−23.9%** |
| turns | 330 | 303 | −8.2% |
| `Read` calls | 30 | 16 | −47% |

**The mechanism is not what it looks like.** About two-thirds of every run's cost
is *cache-read of re-sent context*, so the lever is **run length**, not per-message
size. These personas win by finishing in fewer turns, not by making each message
shorter. That is also why an input-command compressor tested alongside them landed
dead-even with baseline: it attacked the wrong cost pool.

Caveats worth stating plainly: n=1 per arm, and within-arm spread on a repeated
identical task was measured at $3.23–$5.52 — wider than this pair's $0.78 gap. The
direction has now reproduced across three studies; treat the magnitude as
suggestive.

## Test

```
./test.sh
```

Checks that all three axes emit, that the per-prompt line stays exactly one line,
that a missing or absent `personas/` degrades gracefully instead of breaking a
session, that the output style has valid frontmatter and stays a role statement
rather than a copy of the bodies, and that every manifest is valid JSON.

## What was deliberately left out

Intensity levels (`lite`/`full`/`ultra`), slash commands, a statusline, a
mode-tracker state file, an installer, a `VERBOSELESS` environment variable, an
SDK injector, and rule files for other agents.

Every one of those exists upstream and every one is a knob nobody turns twice.
Deleting a `personas/*.md` file is already the off switch, so a second selection
mechanism would have bought nothing but the JavaScript needed to parse it. Add
levels back when you actually want to run an ablation.

There is also no build step. The output style was briefly generated from
`personas/` by a `make-style.sh`, which is exactly what made the two surfaces
duplicates of each other. Giving the style its own altitude removed the
generator, the derived file, and the drift check in one move.

## Credit

`say less` derives from [caveman](https://github.com/JuliusBrussee/caveman) by
Julius Brussee (MIT). `write less` derives from
[ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert (MIT).
`detail less` is original. The pattern of reducing each plugin to its single
injectable body comes from MithraAI/khazad, which did it to inject both personas
into an SDK worker. See `NOTICE`.
