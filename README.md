<p align="center">
  <img src="assets/banner.svg" alt="verboseless — big idea, next action, fewer words" width="720">
</p>

<p align="center">
  <strong>say the big thing first, then the one next action, then say less</strong>
</p>

<p align="center">
  Two axes on one switch, for any AI agent.<br>
  The idea lands, the move is obvious, and nothing in between is padding.<br>
  Substance, security and exact errors: byte-for-byte untouched.
</p>

<p align="center">
  <a href="https://github.com/HuskyDanny/verboseless-all-in-one/stargazers"><img src="https://img.shields.io/github/stars/HuskyDanny/verboseless-all-in-one?style=flat&color=yellow" alt="Stars"></a>
  <a href="#install"><img src="https://img.shields.io/badge/works_with-12%2B_agents-orange?style=flat" alt="12+ agents"></a>
  <a href="https://github.com/HuskyDanny/verboseless-all-in-one/commits/main"><img src="https://img.shields.io/github/last-commit/HuskyDanny/verboseless-all-in-one?style=flat" alt="Last commit"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat" alt="License: MIT"></a>
</p>

<p align="center">
  <a href="#before--after">See it</a> ·
  <a href="#install">Install</a> ·
  <a href="#the-two-axes">Axes</a> ·
  <a href="#how-it-works">How</a> ·
  <a href="#benchmarks">Benchmarks</a> ·
  <a href="#why-29-and-not-65">Why not 65%</a>
</p>

---

verboseless is a skill/plugin for [Claude Code](https://code.claude.com/docs), Codex,
Gemini CLI, Cursor, Windsurf, Cline, Copilot, Kiro, Qoder, OpenCode, OpenClaw, Devin,
and anything that reads `AGENTS.md`. Install once. The agent opens with the point
instead of the mechanism, puts the one thing you can do next directly under it, and
drops every word in between — while code, commands and error strings stay
byte-for-byte exact.

> Everything can be abstract. Einstein could state relativity in one sentence; a
> person who truly knows a thing explains it simply.

## Before / after

Token counts are real, measured with `o200k_base`.

**detail less** — the answer that was already correct, but made you assemble the point yourself.

<table>
<tr><th width="50%">Normal agent — 92 tokens</th><th width="50%">verboseless — 21 tokens</th></tr>
<tr valign="top"><td>

The reason your job is stuck is that the predicate `last_event_at > COALESCE(last_retried_at, deadline_at)` evaluates false, so the sweep never claims it. Concretely, per stalled candidate we CAS-claim it time-gated, stamp `last_retried_at = now()`, increment attempts, publish the token to the queue write-ahead-then-publish, and the scaler spawns a worker which resumes and takes another look.

</td><td>

The job is waiting for an event that can no longer exist — a deadlock, not a delay.

</td></tr>
</table>

Every fact on the left is true. The reader still had to reconstruct "deadlock vs delay"
out of three steps of mechanism. **−77%**, and the point arrives first.

**say less** — same fix, a third of the words.

<table>
<tr><th width="50%">Normal agent — 63 tokens</th><th width="50%">verboseless — 21 tokens</th></tr>
<tr valign="top"><td>

The reason your React component is re-rendering is likely because you're creating a new object reference on each render cycle. When you pass an inline object as a prop, React's shallow comparison sees it as a different object every time, which triggers a re-render. I'd recommend using useMemo to memoize the object.

</td><td>

New object ref each render. Inline object prop = new ref = re-render. Wrap in `useMemo`.

</td></tr>
</table>

**−67%**. Nothing technical lost.

**then the action** — the half that doesn't save words. It saves the round-trip.

<table>
<tr><th width="50%">Normal agent — 98 tokens</th><th width="50%">verboseless — 83 tokens</th></tr>
<tr valign="top"><td>

Now that we've walked through the auth flow, the next thing to consider is getting the token verification updated. The jsonwebtoken package you have is on an older major, so you'll want to bring that in first, and then the verifyToken function in your auth file will need reworking to match the new API surface. Once that's done it'd be worth running the auth test suite to confirm nothing regressed. By the way, a few of your other dependencies are stale too. Hope this helps!

</td><td>

Your token check is calling an API that no longer exists in the installed major — a version mismatch, not a logic bug.

1. `npm install jsonwebtoken@latest`
2. Replace `verifyToken` in `src/auth.ts:42-58` with the snippet below
3. `npm test -- auth.spec.ts`

~10 minutes. Separately: other deps are stale. Want that next?

</td></tr>
</table>

Only **−15%**, and that is the honest number — this axis is not a compressor. The
left column contains every fact the right one does; it just leaves the reader to
extract the commands from prose, which is where "got it" fails to become "done
it". Knowing the answer is not doing the answer.

## Install

**Claude Code** — the full plugin: hooks, a skill, an optional output style.

```
/plugin marketplace add HuskyDanny/verboseless-all-in-one
/plugin install verboseless@verboseless
```

**Every other agent** — clone and let the installer detect what your project uses:

```bash
git clone https://github.com/HuskyDanny/verboseless-all-in-one
cd your-project && /path/to/verboseless-all-in-one/install.sh
```

It looks for `.cursor/`, `.windsurf/`, `.clinerules/`, `.kiro/`, `.qoder/`,
`.opencode/`, `.openclaw/`, `.codex/`, `.claude/`, `.github/`, `AGENTS.md`,
`CLAUDE.md`, `GEMINI.md` and installs only for what's there. `--all` for everything,
`--dry-run` to look first, `--uninstall` to undo.

**Your own instruction files are never overwritten.** `AGENTS.md`, `CLAUDE.md`,
`GEMINI.md` and `.github/copilot-instructions.md` usually already hold your rules, so
the block is spliced between markers — re-running replaces only our block, and
`--uninstall` restores the file byte-for-byte.

<details>
<summary>Or drop in one file by hand</summary>

| agent | file |
|---|---|
| Codex, Amp, Jules, anything AGENTS.md | `AGENTS.md` |
| Claude Code | `CLAUDE.md`, or `skills/verboseless/SKILL.md` |
| Gemini CLI | `GEMINI.md` + `gemini-extension.json` |
| Cursor | `.cursor/rules/verboseless.mdc` |
| Windsurf | `.windsurf/rules/verboseless.md` |
| Cline | `.clinerules/verboseless.md` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Kiro | `.kiro/steering/verboseless.md` |
| Qoder | `.qoder/rules/verboseless.md` |
| OpenCode | `.opencode/command/verboseless.md` |
| OpenClaw | `.openclaw/skills/verboseless/SKILL.md` |
| Devin | `.devin-plugin/plugin.json` |

Every one of those is **generated** from `personas/*.md` by `./build.sh`. Edit the
personas, never the generated file; `./test.sh` fails if any copy is stale.

</details>

## The two axes

| governs | behave like | body |
|---|---|---|
| the **shape** of any answer — its first line, then its next line | abstract first, then i-have-adhd | `personas/01-detail-less.md` |
| everything you **say** | caveman | `personas/02-say-less.md` |

Order is load-bearing: you cannot compress an idea you have not named, and you cannot
name the right next action for a problem you have not stated simply. Altitude, then
the move, then the words.

Three source personas, two bodies. The first body merges two of them because they
answer the same question from opposite ends — **abstract first** names the idea,
**i-have-adhd** names the move the idea implies — and each is weak exactly where the
other is strong. Abstract first updates your mental model and then leaves you at the
top of a hill with no path down; adhd hands you step 1 of 5 without ever telling you
what you are climbing. Merged, the altitude line owns the opening and the action owns
the line directly beneath it. **Caveman** then runs over both: it works word by
word and never restructures an answer, which is why it composes rather than
competes — it may shorten a numbered step, never delete it.

The upstream inversion is deliberate and worth naming: i-have-adhd puts the action on
the *first* line. Here it moves to the second, because an action whose purpose you
cannot state is how you end up efficiently doing the wrong thing.

`personas/00-doctrine.md` holds the never-compress list — substance, exact errors,
code, trust-boundary validation, data-loss handling, security, accessibility, anything
asked for in full. Compression that drops information isn't verboseless, it's wrong.

## How it works

<p align="center">
  <img src="assets/verboseless.svg" alt="Three persona bodies on disk, cat'd by one hook into the tail of the context on every prompt, where two axes govern the shape of the answer and the words inside it" width="100%">
</p>

Hook events `SessionStart`, `UserPromptSubmit` and `SubagentStart` accept **plain
stdout** as context. So the mechanism is a `cat`:

```bash
cat "$root"/personas/*.md
```

Glob order is the axis order. Rename to reorder, delete to disable. No config, no env
var, no state file, no interpreter.

**Hook, not `CLAUDE.md`** — same words, different position. `CLAUDE.md` sits in the
cached system prefix: said once at the head, decaying as the transcript grows past it.
A hook lands at the **tail**, beside the live turn, re-fired every prompt and after
every compaction. The repetition is the forcing function.

`UserPromptSubmit` gets one line, not the bodies — a full copy per prompt would stack
into the re-sent context, which is the pool this exists to shrink. `SubagentStart`
gets the full bodies: a subagent's report *is* the parent's context, so compressing it
pays twice. Neither upstream injects into subagents at all; that reads as an omission,
not a decision.

### Two surfaces, two altitudes

```
OUTPUT STYLE  4.5 KB  end of system prompt    the ROLE  — which behavior, what surface
HOOK BODIES  11.7 KB  tail of the transcript  the RULES — and here is every one
```

Different content, so they never duplicate. Enable the style with `/config` →
**Output style** → `Verboseless`. It's exclusive (one at a time, so it replaces
yours), and `force-for-plugin` is deliberately unset so installing never hijacks your
choice. It's hand-written, never generated: the moment the same text sits in both the
system prompt and the tail you pay twice for one instruction, and `test.sh` fails if
the style grows past half the bodies.

## Benchmarks

**Read this first: the arm that was measured is not the arm that ships.** The
numbers below are for `ponytail + caveman`, an earlier cut of this repo whose
second axis was an anti-over-engineering persona. That axis has been replaced by
`i-have-adhd`, which shapes an answer rather than shrinking a diff, so the −29%
does **not** transfer. It is kept here because deleting an inconvenient
measurement is worse than scoping it.

Autonomous coding swarm (Claude Agent SDK, GLM-5.2), identical task every arm,
**n=3 per arm**, cost metered off the wire rather than estimated:

| | baseline | ponytail + caveman | Δ |
|---|---|---|---|
| cost per delivery | $4.74 ± 0.89 | **$3.37 ± 0.08** | **−29%** |
| output tokens | 132.5k | 89.5k | −32% |
| run-to-run variance | ±$0.89 | **±$0.08** | tightest of 9 arms |
| correct deliveries | 3/3 | 3/3 | — |

The variance column matters as much as the cost one: that combo was the most
*predictable* arm in the field, which is what you want from a default.

**What this does not show.** Two tasks, one model (GLM-5.2), Claude-tuned persona
prompts — one upstream benchmark saw a terseness persona go net-negative on a
small model. And nothing here measures the current axes at all: caveman's own
**8.5%** on long-horizon runs is the closest honest floor, and the action half is
not a compressor, so expect it to move correctness and round-trips rather than
cost. Re-running the harness against the shipped pair is open work.

**[Read the full report →](docs/BENCHMARK.md)** — two studies, nine
configurations, 44 runs, ~$205 of model spend. Harness design, full
threats-to-validity, and the base-merge failure that invalidated an entire round.
Per-run pull-request links are omitted because they point into private
repositories — stated plainly in the report rather than hidden.

## Why 29% and not 65%

Caveman advertises "cuts 65% of output tokens (measured)", and measures it honestly —
on a one-shot reply, where the reply **is** the bill. On an agentic run it isn't:

```
baseline run cost = $5.66
  fresh input     $0.52    9.1%
  cache-read      $4.47   79.1%   ← re-sent context
  output          $0.67   11.8%   ← all a terseness persona can touch
```

Output is the **ceiling**, and it's 11.8%. Cut 65% of it → save 7.7%. Cut *all* of it
— every token the model emits, leaving an agent that does the work in total silence —
→ save 11.8%.

The measured saving on that arm is **29%**. That is **2.4× the entire output pool**, so at minimum
17 percentage points of it cannot have come from terser messages at all. Terseness is
not the mechanism; it is a side effect. The mechanism is fewer turns, and each avoided
turn deletes a full re-send of the cached context at roughly $0.03–0.04 a go.

Two
compressions stack to explain the gap: terseness only compresses **prose**, and prose
is a minority of output (reasoning alone ~⅔); output is in turn a minority of cost.
Sixty-five percent off a slice of a slice lands in single digits — which is why
caveman's own README now reports **8.5%** on long-horizon agentic runs, and that number
is the honest one for a single terseness axis.

The uncomfortable corollary: **the axis that deleted work carried most of that 29%,
not the axis that deleted words.** Not building the speculative thing removes whole
turns, and turns are what the bill is made of. Dropping it is a deliberate trade — this
repo is now cut around how an answer is *shaped*, not how a diff is *sized* — and the
cost claim goes with it.

Judge any future optimization by whether it **shortens the run**. An input-command
compressor tested alongside these landed dead-even with baseline for exactly that
reason. By that test, `i-have-adhd` earns its place only if a correct first action
avoids a corrective round-trip; that is the hypothesis, and it is not yet measured.

## Test

```
./build.sh    # regenerate every agent surface from personas/
./test.sh     # 40 invariants, all RED-verified
```

Axes emit, the per-prompt line stays one line, an absent `personas/` degrades instead
of breaking a session, the output style stays a role statement, every generated agent
surface is byte-identical to a fresh build, manifests and diagrams parse. Each
invariant was verified to actually fail when broken — a test that can't go red proves
nothing.

## Left out

Intensity levels, slash-command level switching, a statusline, a mode-tracker state
file, a `VERBOSELESS` env var, an SDK injector. All exist upstream; all are knobs
nobody turns twice. Deleting a `personas/*.md` file is already the off switch.

## Credit

`say less` from [caveman](https://github.com/JuliusBrussee/caveman) by Julius Brussee
(MIT). The action half of `detail less` from
[i-have-adhd](https://github.com/ayghri/i-have-adhd) by Ayoub Ghriss (MIT). The
abstract-first half is original. An earlier `write less` axis came from
[ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert (MIT) and no
longer ships. Reducing each plugin to its single
injectable body is a pattern borrowed from a private agent-runtime codebase, which did
the same reduction to inject both into a Claude Agent SDK worker. See
[`NOTICE`](NOTICE) for what changed and
[`LICENSES-THIRD-PARTY.md`](LICENSES-THIRD-PARTY.md) for the upstream license texts.
