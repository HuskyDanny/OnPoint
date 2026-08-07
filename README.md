<p align="center">
  <img src="assets/verboseless.svg" alt="verboseless: four persona bodies on disk, cat'd by one hook into the tail of the context on every prompt, where three axes govern the first line, the prose and the code" width="100%">
</p>

# verboseless

Think at altitude, say it terse, build the smallest thing that works. Substance is
never compressed.

> Everything can be abstract. Einstein could state relativity in one sentence; a
> person who truly knows a thing explains it simply.

```
/plugin marketplace add HuskyDanny/verboseless-all-in-one
/plugin install verboseless@verboseless
```

New session → `VERBOSELESS ACTIVE` in context. Off: "stop verboseless".

## Three axes

| governs | behave like | body |
|---|---|---|
| the **first line** of any answer | abstract first | `01-detail-less.md` |
| everything you **say** | caveman | `02-say-less.md` |
| everything you **write** | ponytail | `03-write-less.md` |

Order is load-bearing: you cannot compress an idea you have not named. Altitude,
then words, then code.

`00-doctrine.md` holds the never-compress list — substance, exact errors, code,
trust-boundary validation, data-loss handling, security, accessibility, anything
asked for in full.

## How

`SessionStart`, `UserPromptSubmit` and `SubagentStart` accept **plain stdout** as
context. So the mechanism is a `cat`:

```bash
cat "$root"/personas/*.md
```

Glob order is the axis order. Rename to reorder, delete to disable. No config, no
env var, no state file, no interpreter.

**Hook, not `CLAUDE.md`** — same words, different position. `CLAUDE.md` sits in the
cached system prefix: said once at the head, decaying as the transcript grows past
it. A hook lands at the **tail**, beside the live turn, re-fired every prompt and
after every compaction. The repetition is the forcing function.

`UserPromptSubmit` gets one line, not the bodies — a full copy per prompt would
stack into the re-sent context, which is the pool this exists to shrink.
`SubagentStart` gets the full bodies: a subagent's report *is* the parent's context,
so compressing it pays twice. Ponytail injects into subagents upstream, caveman does
not; that reads as an omission, not a decision.

## Two surfaces, two altitudes

```
OUTPUT STYLE  3.7 KB  end of system prompt    the ROLE  — which behavior, what surface
HOOK BODIES  12.1 KB  tail of the transcript  the RULES — and here is every one
```

Different content, so they never duplicate. Enable the style with `/config` →
**Output style** → `Verboseless`.

- **Exclusive** — one style at a time, so it replaces yours. `force-for-plugin` is
  deliberately unset, so installing never hijacks your choice.
- **Hand-written, never generated** — the moment the same text sits in both the
  system prompt and the tail, you pay twice for one instruction. `test.sh` fails if
  the style grows past half the bodies.

## Measured

Agentic coding worker (Claude Agent SDK, GLM-5.2), identical task both arms:

| | baseline | verboseless | Δ |
|---|---|---|---|
| total tokens | 252,039 | 194,829 | **−22.7%** |
| cost | $3.26 | $2.48 | **−23.9%** |
| turns | 330 | 303 | −8.2% |
| `Read` calls | 30 | 16 | −47% |

**n=1 per arm.** Within-arm spread on a repeated identical task was $3.23–$5.52,
wider than this pair's $0.78 gap. Direction reproduced across three studies; the
magnitude is suggestive, not settled.

## Why 23% and not 60%

Caveman's ~60% headline is honestly measured — on a one-shot CLI reply, where the
reply **is** the bill. On an agentic run it is not:

```
baseline run cost = $5.66
  fresh input     $0.52    9.1%
  cache-read      $4.47   79.1%   ← re-sent context
  output          $0.67   11.8%   ← all a terseness persona can touch
```

Output is the ceiling, and it is 11.8%. Cut 60% of it → save 7.1%. Cut *all* of it →
save 11.8%. So 23% cannot come from terser messages; it exceeds the ceiling. It
comes from the run being shorter:

```
output tokens   87,563 → 66,319   −24.3%
input  tokens  164,476 → 128,510  −21.9%   ← the real saving
turns              330 → 303       −8.2%
Read calls          30 →  16      −46.7%
```

Every avoided turn deletes a full re-send of the cached context, ~$0.03–0.04 each.
Two compressions stack to explain the gap: terseness only compresses **prose**, and
prose is a minority of output (reasoning alone ~⅔); output is a minority of cost.
Sixty percent off a slice of a slice lands in single digits.

The uncomfortable corollary: **ponytail carries most of this, not caveman.** Ponytail
removes whole turns — don't build the speculative thing, don't re-read what you
already read. Turns are what the bill is made of.

Judge any future optimization by whether it **shortens the run**. An input-command
compressor tested alongside these landed dead-even with baseline for exactly that
reason.

## Test

```
./test.sh
```

Ten invariants — axes emit, the per-prompt line stays one line, an absent
`personas/` degrades instead of breaking a session, the style stays a role
statement, manifests and the diagram parse. All ten RED-verified.

## Left out

Intensity levels, slash commands, a statusline, a mode-tracker state file, an
installer, a `VERBOSELESS` env var, an SDK injector, other-agent rule files, a build
step. All exist upstream; all are knobs nobody turns twice. Deleting a
`personas/*.md` file is already the off switch.

## Credit

`say less` from [caveman](https://github.com/JuliusBrussee/caveman) by Julius
Brussee (MIT). `write less` from
[ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert (MIT).
`detail less` is original. Reducing each plugin to its single injectable body is the
pattern MithraAI/khazad used to inject both into an SDK worker. See `NOTICE`.
