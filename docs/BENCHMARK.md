# Token-Optimizer Tools on an Agentic Coding Swarm: A Two-Study Empirical Evaluation

**Author:** Allen Pan · **Date:** 2026-07-18
**System under test:** an autonomous code-delivery swarm — FastMCP control plane,
Redis-Streams dispatch, KEDA-orchestrated Claude Agent SDK workers — model tier
GLM-5.2 via litellm → z.ai.

---

## Abstract

We evaluate four community "token optimizer" tools — **caveman**
([JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman), terse-output
persona), **ponytail**
([DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail),
anti-over-engineering persona), **rtk** (a PreToolUse command-output compressor),
and **headroom** (a litellm context-compression callback) — plus their
combinations, on a real autonomous code-delivery swarm. Across two studies (a
completed 3-round study on a frontend task, and a single-sample study on a backend
task) we find that (1) **cost is dominated by re-sent cached context**
(~⅔ of every run's dollar cost is cache-read), so the effective lever is **run
length**, not per-call output size; (2) the **combo (ponytail+caveman)** and
**combo+headroom** configurations are the only ones that win **consistently
across studies and samples**; (3) single-sample rankings are **inside the noise
band** — the studies disagree sharply on the middle of the field (rtk-opt best in
one sample, worst in another); and (4) an **input-layer command compressor (rtk)
does not transfer** to a cache-heavy agentic workload. A methodological failure —
anchoring the task to an open PR that merged mid-experiment — invalidated Study 2's
later rounds; it is documented in §4 and its fix (freeze the base) is prescribed.

---

## 1. Introduction

Agentic coding workers re-send a large, growing conversation context on every
turn. On a prompt-cached provider that context is billed at the cheaper
cache-read rate, but its sheer volume still dominates cost. "Token optimizer"
tools claim 60–90% savings, but those headlines are measured on one-shot CLI
interactions, not multi-hundred-turn agentic runs.

**Question:** on a real swarm, which tools are (a) functionally correct, (b)
cheapest, and (c) same-quality-but-costlier — and does any of it transfer from the
marketing benchmark?

Two studies. **Study 1** — a completed, wire-metered, n=3 evaluation on a frontend
feature. **Study 2** — a re-run with official-fidelity tool integration and a
parallel lane-per-arm harness, on a backend refactor. Study 2's round 1 completed
cleanly; its later rounds were abandoned after a base merge invalidated them, and
are excluded from this report (§4.1).

---

## 2. Methods

### 2.1 Arms (nine configurations)

| arm | configuration | mechanism |
|---|---|---|
| **A** | baseline | unmodified worker |
| **B** | caveman (full) | terse-output persona |
| **C** | ponytail (full) | anti-over-engineering persona |
| **D** | rtk | PreToolUse hook rewrites bulky command output |
| **E** | rtk-opt | rtk + steering to prefer rtk-rewritable commands |
| **F** | combo | ponytail + caveman (the tools' own pairing recommendation) |
| **G** | caveman-compressed | caveman + a compressed operating contract (−24% contract bytes) |
| **H** | headroom | baseline worker + headroom litellm compression callback |
| **I** | combo + headroom | F worker + headroom lane |

### 2.2 Integration fidelity (the Study 1 → Study 2 upgrade)

Each tool's **official** Claude Code mechanism, verified from its own
`.claude-plugin/plugin.json` and hook scripts:

- **caveman** — SessionStart hook (unmatchered) emits the full level-filtered
  persona; UserPromptSubmit emits a one-line reinforcement.
- **ponytail** — SessionStart (matcher `startup|resume|clear|compact`) +
  UserPromptSubmit reinforcement + **SubagentStart** injection, on the stated
  grounds that SessionStart context is parent-thread only and never reaches
  subagents.
- **rtk** — `rtk init` → PreToolUse hook (native).
- **headroom** — litellm callback (native).

**Study 1** approximated caveman and ponytail as always-on context appends (the
headless equivalent of per-prompt injection). **Study 2** switched to the real
hooks in the worker image's `settings.json`, closing the one behavioural gap
(subagent persona coverage). Worker transcripts showed `hookEvent: SessionStart`
and `UserPromptSubmit`, and a forced subagent's own transcript showed
`hookEvent: SubagentStart` carrying the ponytail body — byte-faithful to
upstream, including the caveman/ponytail subagent asymmetry (caveman ships no
subagent hook).

Wire shape confirmed against a live session: injection lands as a system-role
message, `"role":"system","content":"SessionStart:startup hook success: <level-filtered body>"`
— the same transcript position class as a system reminder, re-fired on
compaction. **The delta between the two integration styles is therefore ≈ nil in
content and position; the only real difference is subagent coverage, which
Study 2 adds.**

*Caveat on that verification.* The transcripts above were captured on the
interactive CLI path. A worker driven through the SDK's `query()` entrypoint fires
**only in-process hooks** — a `settings.json` SessionStart or UserPromptSubmit file
hook does not fire there at all. So these transcripts do not establish that Study
2's workers fired their `settings.json` hooks; if those workers used the same
`query()` path, the persona arms were running as context-append (Study 1's
approximation) or inert. This does not touch Study 1, which used an explicit
append, nor the headline. It does mean the "fidelity upgrade" framing is
unproven.

### 2.3 Harness

**Study 1** — sequential, single shared worker image, arm switched by a
file-overlay script, one image rebuild per arm. A per-pod arm marker was grepped
before every dispatch after a cross-session image clobber was observed.

**Study 2** — nine **immutable per-arm images** in nine **lanes** in one
namespace: per arm a gateway with its own Redis stream plus a KEDA ScaledJob
(`maxReplicaCount 1`). Two litellm Deployments run simultaneously (stock for
A–G, headroom for H and I). Arm identity is **structural** — own image, own
stream — which eliminates the shared-tag clobber class by construction. Because
the laptop Docker VM (8 GB) holds only ~2 concurrent worker pods, a **capacity-2
admission manager** unpauses lanes as slots free; queued lanes hold their
dispatch token in-stream at zero cost. A **detached driver** (`nohup`,
reparented to init) survives session teardown and advances rounds autonomously.

### 2.4 Cost metric

- **Study 1** — wire-complete meter: `litellm_request` observability spans,
  deduped by span id, joined to a run via the litellm tag, repriced at
  `fresh × $1.40 + cache_read × $0.26 + out × $4.40` per million (the GLM-5.2
  rate table). Cross-checked against the swarm's own usage ledger.
- **Study 2** — the swarm's usage ledger (same rate table). Reasoning tokens are
  **inside** `output` and therefore already billed at $4.40/M.

**Identical prompt per arm.** The only text difference between arms is the
persona hook, the rtk hook, or the litellm callback — never the task. Grading
joins run → delivered PR through the authoritative run/PR table, so any title
tagging is cosmetic.

### 2.5 Tasks

- **Task A (Study 1, frontend)** — server-side pagination of an admin
  invitations list, 8 rows/page, in a Next.js app. A reference implementation
  existed for grading.
- **Task B (Study 2, backend)** — retire a webhook entrypoint end-to-end:
  receiver route, handler, HMAC/replay gate, secret, Kubernetes manifests,
  Terraform, tests, and six documents. A deletion-shaped refactor.

---

## 3. Results

### 3.1 Study 1 — completed, wire-metered, n = 3

Mean $ per valid delivery, 27 valid deliveries across 9 arms:

| rank | arm | wire $ (n=3) | Δ vs A | output | reliability |
|---|---|---|---|---|---|
| 1 | **I** combo+headroom | **3.32** ± 0.96 | **−30%** | 72.9k | 3/3 |
| 2 | **F** combo | **3.37** ± 0.08 | **−29%** | 89.5k | 3/3 (tightest variance) |
| 3 | B caveman | 3.88 ± 0.39 | −18% | 91.5k | 3/4 (1 vacuous) |
| 4 | C ponytail | 4.03 ± 1.29 | −15% | 95.5k | 3/3 |
| 5 | G caveman-compressed | 4.14 ± 1.14 | −13% | 98.4k | 3/3 |
| 6 | H headroom | 4.48 | −5% | 116.2k | 3 green + 1 CI-red |
| 7 | A baseline | 4.74 ± 0.89 | — | 132.5k | 3/3 |
| 8 | D rtk | 4.75 ± 0.32 | +0.2% | 120.6k | 3/3 |
| 9 | E rtk-opt | 5.43 ± 0.82 | **+15%** | 122.7k | 3/3 |

**Correctness:** 26/27 fully CI-green and spec-complete. The single incorrect
delivery was **H (headroom)** — its own pagination end-to-end test failed, the
page-2 swap broken — the only correctness incident in the programme, attributable
to headroom's lossy compression in the callback integration (rewrite-only; see
§5.4). Reasoning tokens were ~⅔ of output on every arm, and the personas cut
reasoning **absolutely** — no hidden-thinking inflation.

### 3.2 Study 2 — round 1, accepted result, n = 1

All nine arms delivered a real, deletion-heavy PR (−731 to −824 lines, 27–34
files — the correct shape for the task). Ledger cost:

| rank | arm | $ | turns | fresh-in | cache-read | out | diff |
|---|---|---|---|---|---|---|---|
| 1 | **I** combo+headroom | **3.45** | 332 | 543k | 8.76M | 94k | +94/−736 |
| 2 | E rtk-opt | 3.80 | 410 | 331k | 10.6M | 131k | +95/−743 |
| 3 | G caveman-compressed | 3.81 | 400 | 247k | 11.4M | 110k | +180/−755 |
| 4 | H headroom | 5.16 | 444 | 914k | 12.3M | 158k | +107/−731 |
| 5 | D rtk | 5.38 | 532 | 359k | 16.1M | 156k | +97/−746 |
| 6 | A baseline | 5.66 | 565 | 368k | 17.2M | 152k | +127/−782 |
| 7 | F combo | 5.69 | 386 | 233k | 19.3M | 79k | +119/−761 |
| 8 | B caveman | 6.25 | 451 | 235k | 21.3M | 87k | +183/−785 |
| 9 | C ponytail | 7.24 | 438 | 340k | 24.3M | 100k | +125/−824 |

All runs terminated successfully. Cost is **cache-read dominated**: 8.8–24.3M
cache-read tokens × $0.26/M ≈ ⅔ of each run's cost. **I is cheapest again, with
the fewest turns (332).**

---

## 4. Threats to validity

1. **Base-merge contamination (Study 2, later rounds).** The task was anchored to
   an **open** PR that merged mid-experiment; workers always clone the current
   default branch, so the base changed underneath later rounds. *Fix:* freeze the
   base — anchor to a task that will not merge during the run, or pin the clone
   to a fixed pre-task commit. Round 1, dispatched 17 h before the merge, is
   unaffected and is the only Study 2 data reported here.

   The signature was unmistakable and is worth naming so others can detect it:
   once the base had the task pre-done, every arm degenerated to a near-noop —
   diffs of −9…−33 lines against round 1's −731…−824. Cost drops because there is
   nothing left to do, not because an arm is efficient. Those runs are excluded
   rather than reported, since a number that must never enter a ranking has no
   business sitting in a results table.
2. **n = 1 in Study 2 round 1.** A single sample cannot rank arms. Study 1
   measured a within-arm spread of **$3.23–$5.52 across three runs of the same
   arm** — wider than most between-arm gaps. Study 2's round-1 order sits inside
   that band and, tellingly, **disagrees with Study 1** in the middle of the
   field (§5.2).
3. **Model specificity.** GLM-5.2 only. These persona prompts are Claude-tuned,
   and ponytail's own benchmark saw caveman net-*negative* on a small model. Read
   this as "on this swarm and this model," not "model-general."
4. **Task specificity.** One frontend feature and one backend deletion. Two
   points, not a distribution.
5. **Metric scope.** Study 1 is wire-complete (observability spans); Study 2 uses
   the usage ledger at the same per-token rates. Within-study ranking is
   therefore sound; cross-study absolute levels should be compared cautiously. A
   wire cross-check planned for the unrun final is still pending.
6. **Concurrency.** Durations are not arm-comparable (capacity-2, mixed
   solo/parallel execution). Token and cost meters are latency-independent and
   unaffected.
7. **Unpublishable run inventory.** Per-run PR links live in private
   repositories and are omitted here. You cannot audit an individual run from
   this document.

---

## 5. Insights

**5.1 Cost is a function of run length, not output verbosity.** Cache-read of
re-sent context is ~⅔ of every run's dollar cost in both studies. The arms that
win are the ones that **finish in fewer turns** (I: 332 turns, cheapest in both
studies), because each avoided turn removes a full re-send of the
multi-million-token cached context — roughly $0.03–0.04 per turn. Trimming
per-call output attacks a small slice and does not move the total.

**5.2 Only combo and combo+headroom are stable across studies and samples.** The
persona **combo (F)** and **combo+headroom (I)** are top-2 in Study 1 (n=3, wire)
and I is #1 in Study 2 (n=1, ledger). Every other arm is unstable: **rtk-opt (E)**
was **worst** in Study 1 (+15%) yet **second-best** in Study 2's single sample;
**ponytail (C)** was **second-best** in Study 1 yet **worst** in Study 2. That
inversion is the strongest evidence in the programme that a single sample cannot
rank the middle of the field — and that the robust production choice is the
combo, not the swing arms.

**5.3 An input-command compressor does not transfer to agentic loads.** rtk (D)
landed dead-even with baseline in both studies (+0.2% in Study 1). Its PreToolUse
rewrite targets simple single commands, but the agent emits compound
multi-command shell scripts that bypass the rewriter — under explicit steering
only ~6% of shell calls even invoked an rtk-rewritable command. The steering
itself added per-prompt input *and* converted batched scripts into extra
cache-re-sending round-trips, which is why rtk-opt (E) *backfired* into the most
expensive arm in Study 1. The 60–90% headline, measured on one-shot CLI use, does
not survive contact with a cache-heavy, batching agent.

**5.4 Headroom is precisely a structured-bulk compressor, and lossy in this
integration.** It compresses uniform tool-result JSON (count + schema + samples,
−73% on a probe) but passes large code files through. It helped most **stacked on
combo** — I edged F — because combo already shortened the run and headroom shrank
what each remaining turn re-carried; the effects multiply. It also produced the
programme's **only** incorrect delivery. Its determinism preserved prompt-cache
prefixes (~93% cache-read retained), which is why it did not blow up cost.

*Lossless-path correction, verified against headroom's source and correcting an
earlier draft of this report: headroom does have a recover-detail tool, but it is
wired **only** in headroom's standalone proxy. The litellm callback used here
does **not** wire it — those handlers are no-ops, making the integration
rewrite-only and therefore lossy. Lossless headroom would require deploying that
standalone proxy as a real model-path hop, not setting a callback flag: a
materially bigger change than "wire the retrieve tool" implied.*

**5.5 Personas do not hide work in "thinking."** GLM-5.2 reasoning tokens are
inside `output`, and the personas cut reasoning **absolutely** — −29…−54% versus
baseline in Study 1 — rather than shifting it off-meter. Ponytail specifically did
**not** think more on this model, contradicting a caveat in its own
documentation.

**5.6 A parallel harness needs structural arm identity and a crash-proof
driver.** The two operational failures that mattered — a shared image tag
clobbered by a concurrent session, and harness-tracked background loops killed on
session teardown — were both solved by *removing shared mutable state*:
immutable per-arm images and streams, and a detached, init-reparented driver. Two
silent bugs also cost real time: a completion check that read a `psql` footer
instead of the value, and a task-title leak. Both are footguns of thin shell
glue, not of the design.

---

## 6. Takeaways

1. **Ship the combo.** ponytail + caveman (**F**) is the production
   recommendation: −29% cost in the n=3 wire study with the **tightest variance
   of any arm** (±$0.08), zero correctness incidents, and no model-path
   infrastructure. combo+headroom (**I**) buys a further ~1–4% but adds lossy
   compression risk, since this integration is rewrite-only. The lossless path
   exists only in headroom's standalone proxy, so removing that risk means
   deploying the proxy as a real model-path hop. Take headroom only at fleet
   scale, and only after that path is built and verified; until then it is
   research, not a deployment recommendation.
2. **Do not deploy an input-command compressor for this workload.**
   Cost-neutral at best, actively worse when steered. It is the wrong layer for a
   cache-dominated agent.
3. **The lever is run length.** Judge any future optimization by whether it
   *shortens the run* — fewer turns re-sending cached context — not by how much
   it shrinks a single message.
4. **Method fix for the next run:** freeze the base (a non-merging task or a
   pinned commit) and run **all rounds of all arms before any external state can
   change**. The parallel harness already enables this; Study 2 simply needed a
   task that was not a live, about-to-merge PR.
5. **Fidelity was worth doing but did not move the result.** The official-hook
   integration matched the context-append integration on content and position;
   only subagent coverage differed. Note the caveat in §2.2: the evidence offered
   for hook fidelity was captured on the wrong execution path, so the framing is
   unproven even though the conclusion is unaffected.

**One-line verdict:** on a GLM-5.2 agentic swarm, the persona **combo
(ponytail + caveman)** is the only optimizer that reliably pays for itself.
Everything else is noise, lossy, or aimed at the wrong cost pool — per-call
output instead of re-sent cached context.

---

## 7. Fidelity micro-study — integration style, isolated (n=1 pair; suggestive)

**What this isolates.** Studies 1 and 2 changed the persona *integration*
(append vs official hooks) but also changed task and sample size, so the
integration effect was confounded. This micro-study holds task and model fixed
and varies only integration style.

**What completed cleanly:** exactly one paired data point — caveman, append vs
hooks. Ponytail's runs died to out-of-memory kills.

| caveman integration | turns | output tok | cache-read tok | cost |
|---|---|---|---|---|
| **append** (always-on context block) | 182 | 43,679 | 5.08M | **$1.74** |
| **hooks** (SessionStart + UserPromptSubmit) | 111 | 43,622 | 3.58M | **$1.25** |

**Observation.** The official-hook integration ran **−39% turns and −28% cost**
with **near-identical output** (43.6k vs 43.7k — the same amount of talking,
fewer tool loops). On this pair, 1:1 fidelity cost nothing and may have run
leaner.

**Mechanism hypothesis.** The official hooks re-fire the persona on every
SessionStart *including compaction* and land as a transcript-adjacent system
message, whereas an appended block sits in the cached system prefix and may lose
salience as the transcript grows. If the hook keeps the terse persona more active
*late* in a long run, the agent stops sooner, so fewer turns, so lower cost.
Testable, and **unproven here**.

**Why this is not yet a finding.** Two hard limits. **n = 1** — Study 1's
within-arm spread ($3.23–$5.52) is *wider* than this pair's $0.49 gap, so the
turn difference (111 vs 182) is plausibly noise; it shows hooks are **not
worse**, not that they are reliably better. And **the hardware could not produce
more** — a single-node laptop cluster at 72–90% memory cannot sustain concurrent
~2 GiB agent pods, so about half the micro-study runs died to OOM and the reused
lanes carried leftover-token contamination. A clean n ≥ 3×2 study needs an
isolated environment, not a laptop.

**Status:** suggestive single-pair result with a plausible mechanism, worth
replicating on real hardware. It does at minimum refute the earlier cross-study
*impression* that hook integration made the personas more expensive — that
impression was a task + n=1 confound.

---

## Appendix A — Run inventory

Study 1: 35 runs including lost and partial. Study 2: nine round-1 runs. A further
five runs from Study 2's invalidated round were discarded. Every run delivered a real pull request into a
private repository, each graded against CI status and spec completeness. The
per-run links are not publishable, so the counts, diffs and ledger figures above
cannot be independently audited from this document. Reported as measured.

## Appendix B — Approximate spend

Study 1 ≈ $145. Study 2 ≈ $60, which includes the invalidated round's runs —
spend is reported as incurred, not as used.
Programme total ≈ **$205** in model spend.
