# A3 — "Big Battles" — Implementation Work Order

**Status: M-0 built in A2. M-1, P-2 and S-1 COMPLETE (2026-09-06).**

> [!CAUTION]
> **THE TRIPWIRE HAS FIRED. Stop and re-plan before spending another rung.**
>
> This plan's own rule: *"Two consecutive rungs missing their prediction by more than 50% means the
> cost model is wrong — stop and re-measure rather than keep spending against it."*
>
> - **P-2** predicted separation time would drop by roughly half. Measured: **−3.9%, inside noise.**
> - **S-1** predicted up to ~18 µs/enemy. Measured: **0, possibly slightly negative.**
>
> Both were aimed at the two largest measured costs, and both remedies were refuted while the costs
> themselves were confirmed. The *measurements* are sound; the *explanations* were wrong. See
> *P-2 result* and *S-1 result* before building anything else.

> [!WARNING]
> **Everything in this section below the M-1 results is superseded.** The 59.3 / 60.6 rows and the
> attribution built on them predate A2 and were measured with a protocol now known to be invalid
> (see *The harness degrades within a process*). **Read *M-1 results* first;** the older text is
> kept only because its *reasoning* about scaffolding was correct even where its numbers were not.

## Where A3 actually stands, and what went wrong

Written at the point the tripwire fired, so the next person starts from the real state rather than
from the plan's optimism.

### Rung status

| Rung | State | Result |
|---|---|---|
| M-0 bench harness | shipped (A2) | works, but see *the instrument* below |
| **M-1** attribution | **done** | full cost breakdown; corrected CLAUDE.md's diagnosis |
| **P-2** single-probe dicts | **done, kept** | **−3.9%, inside noise. Refutes G-1's premise** |
| **S-1** retire physics | **done, kept** | **0 gain.** Refutes the 12.2's attribution |
| P-1 cached cell conversion | not started | target now ~9 µs/enemy, not "the largest" |
| T-1 TileMapLayer | not started | still needed (Known issue 5), unaffected by any of this |
| P-3 registry + buckets | not started | target 11.5 µs/enemy |
| P-4 offsets + probe | not started | small |
| G-1 flatten grid | **do not build as written** | premise measured and refuted |
| G-2 manager loop | not started | bounded at ~10%, cannot be the fix |
| X-\* de-nodify + MultiMesh | not started | **now the only rung aimed at what was actually measured** |
| A3-ship overlapping waves | not started | |

Current baseline: **~54–57 µs/enemy** at 600 packed. Target for 1500 enemies: **≤ 11.1**.

### SOLVED (2026-09-07) — the "degradation" was never real: the monitor lags

**`Performance.TIME_PHYSICS_PROCESS` updates far more slowly than once per frame, and the harness
samples it once per frame.** Every run's early samples therefore carry the *previous* run's value.

Caught by dumping `_phys_samples` from a V5 run taken immediately after a V0 run:

```
46.229  x 33 samples    <- V0's value, frozen
3.76    x ~120 samples  <- V5's actual value
4.214   x ~19 samples
```

Thirty-three of 180 samples are a frozen 46.229 — V0's leftover reading, held through V5's entire
60-frame warm-up **and** 33 sampling frames before the monitor finally updated. That is 93+ frames
of stale data. In an earlier V5-after-V0 run more than half the samples were contaminated and the
reported p50 came out at **48.65 ms while the run was doing essentially no work** — higher than V0
itself.

**This explains the whole "within-process degradation" story, and inverts its conclusion:**

| Run | What precedes it | Residue | Effect on p50 |
|---|---|---|---|
| 1st in a process | an idle game | **low** | biased **DOWN** |
| 2nd, 3rd... | the previous heavy run | **high** | biased **UP** |

So the observed 67.5 → 98.3 → 94.3 was not the machine getting slower. It was **run 1 being
under-reported** because an idle game's cheap physics frames bled into its warm-up, and later runs
being over-reported by the preceding run's expensive ones.

> **The documented protocol was exactly backwards.** "Only the first run after a game start is
> trustworthy" made the *most* contaminated run the reference. It also explains why idling never
> "recovered" it (idle frames are cheap, so idling only reloads the low residue) and why S-1
> emptying the broadphase changed nothing (there was no physics effect to remove).

**The contamination is proportional to how fast the run is**, because a fixed number of stale
frames is a larger share of a short run:

| Variant | run length | stale share |
|---|---|---|
| V0 | ~35 s | small |
| V1 | ~10 s | moderate |
| V4 | ~4 s | large |
| V5 | ~2 s | **very large** |

**That is why V4 and V5 looked "flat" back-to-back** — they are so short that their samples are
dominated by residue either way, so consecutive runs simply agree with each other. It was never
evidence that the light variants behave differently.

### What this invalidates

- **The ±8% "noise floor" is mostly this artefact.** The real instrument, once fixed, is likely far
  more precise — which may put the rungs that predict 10–20% back within reach. **The tripwire
  should not be treated as final until the ladder is re-measured on a fixed harness.**
- **The M-1 attribution table is distorted and must be re-measured.** Every variant was taken as
  the first run of a fresh process, i.e. every one biased **down** toward idle — and biased by a
  *different amount*, since the stale share scales inversely with run length. The light variants
  (V4, V5) are pulled hardest, so **the subtractions that produced the cost breakdown are not
  trustworthy in detail**, even though the broad shape (separation dominant) is probably right.
- **P-2's and S-1's "no measurable gain" verdicts are weakened but probably survive**, because both
  compared before/after runs of similar duration under the same protocol, so the bias largely
  cancels. They should be re-confirmed cheaply once the harness is fixed rather than re-litigated.

### The fix — shipped and verified, `BENCH_TAG` now `M-0b`

Sampling is counted in **distinct monitor updates, never in frames**: a value is recorded only when
it differs from the previous reading, and a run ends after `SAMPLE_UPDATES` (40) genuine updates.
Warm-up requires both `WARMUP_FRAMES` (60) **and** `WARMUP_UPDATES` (3) observed changes, because a
frame count cannot promise the previous run's value has flushed. `MAX_SAMPLE_FRAMES` (6000) stops a
run that would otherwise hang if the monitor stalled, and `push_error`s rather than reporting a
number it cannot stand behind.

**`BENCH_TAG` bumped `M-0` -> `M-0b`.** Every row above tagged `M-0` was produced by the buggy
sampler and must never be compared against an `M-0b` row.

**Self-test — the exact experiment that exposed the bug:**

| V5 run straight after a V0 run | reading |
|---|---|
| Old harness | **48.65**, then **81.1** (p95 35.81) |
| **Fixed harness** | **5.2** (p95 4.84) |
| Fresh-process V5, for reference | 5.1 / 5.3 |

V5-after-V0 is now indistinguishable from a fresh V5. The residue is gone.

**And the "degradation" is gone with it.** Six V0 runs back-to-back in one process:

| Harness | runs | shape |
|---|---|---|
| Old | 67.5 / 98.3 / 94.3 | **+45%, monotonic** |
| **Fixed** | 60.2 / 58.3 / 54.4 / 53.3 / 58.8 / 50.5 | **no trend, bounces** |

### What the instrument is actually worth now

Mean **55.9**, spread 50.5-60.2, standard deviation ~3.7 -> **about ±7% on a single run, ~±4% on a
three-run mean.**

**The raw spread did not shrink much. That is not the win.** The win is that the error is now
*random rather than systematic*: it averages out over repeats, it does not depend on what ran
before, and it cannot invert an ablation table. Three practical consequences:

- **Back-to-back runs are valid.** No game restart per measurement, which roughly halves the cost
  of every future measurement session.
- **The old protocol is retired.** "Only the first run is trustworthy" was an artefact of the bug
  and is now simply wrong.
- **Rungs predicting 10%+ are measurable again** on a three-run mean. P-3's 11.5 µs/enemy is ~20%
  of 55.9; P-1's ~9 is ~16%. **The tripwire fired against a broken instrument, so the ladder is
  back in play** — but only after the attribution is re-derived, because the numbers those targets
  come from were themselves produced by the buggy sampler.

**Next measurement work, in order:** re-run the V0-V5 ladder on `M-0b` (one variant per run,
back-to-back is fine now, three runs each) to rebuild the cost table; then re-confirm P-2 and S-1
cheaply, since both verdicts rest on `M-0` numbers.

---

### Problem 1 — the instrument is far noisier than the effects being measured

Three independent variance layers, all discovered during M-1, none of them in the original plan:

| Layer | Size | Mitigation |
|---|---|---|
| Degradation **within a process** | up to **+45%** by the third run | Restart the game between every single run |
| Spread between **first runs** | **±8%** | Three runs minimum per data point |
| Drift **across sessions** | **~14%** | Only compare runs from one sitting; re-measure "before" immediately |

Net effect: **nothing below roughly a 15% change can be distinguished from noise.** Most rungs on
this ladder predict less than that individually. This is the single biggest practical obstacle to
finishing A3 as designed, and it is not a code problem.

**The within-process degradation is narrowed but not solved.** Not thermal (an idle gap does not
recover it), not leaked nodes (`node_count` is constant), not positional drift (the lattice is
frozen), and not physics — S-1 emptied the broadphase and the degradation survived.

**Measured 2026-09-06, back-to-back runs within one process, by variant:**

| Variant | run 1 | run 2 | run 3 | trend |
|---|---|---|---|---|
| V0 (full) | 67.5 | 98.3 | 94.3 | **+45%** |
| V0 (full, second process) | 62.6 | 78.3 | 85.9 | **+37%** |
| V4 (return immediately, grid rebuild ON) | 20.6 | 16.9 | 19.2 | **none** |
| V5 (return immediately, grid rebuild OFF) | 5.1 | 5.7 | 5.7 | **none** |

**This kills both of the standing hypotheses.** V4 and V5 spawn and tear down the same 600 nodes
per run as V0, so **allocator fragmentation from node churn and editor-side accumulation are both
excluded** — they would degrade every variant equally, and they degrade none of them. V4 also runs
the full per-frame grid rebuild, so **the rebuild's array churn is excluded too**.

**What remains:** the degradation appears only when enemies run their actual `_physics_process`
body — separation, the flow lookup, `is_wall`, and the move. In absolute terms it is roughly
**+18 ms per frame at 600 enemies by the third run**, which is close to separation's entire
measured cost (~15 ms). It behaves like separation getting dramatically more expensive over a
process's lifetime, with the lattice frozen and every position identical between runs.

That is a strange result and it is not yet explained. **It is also the most interesting lead A3 has
left**, because whatever makes the *same work on the same positions* cost 45% more after a few
minutes is a real effect — and if it happens in the bench it plausibly happens in a long play
session too, where nobody has ever looked for it.

### Problem 2 — the cost model has been wrong twice, the same way both times

| Cost | Measured | Proposed cause | Verdict |
|---|---|---|---|
| Separation, 25.5 µs/enemy | solid | dictionary hashing | **refuted by P-2** |
| `global_position` write, 12.2 µs/enemy | solid | PhysicsServer2D sync (Area2D) | **refuted by S-1** |

**In both cases the measurement was right and the explanation was wrong**, and in both cases the
explanation was the obvious first guess. What survives both refutations is the same thing:
**per-node engine overhead** — the transform-set path, Variant boxing on reads out of untyped
containers, and the inner-loop arithmetic. None of it is removable while each enemy is a Node.

That points at **X-\*** and away from everything cheaper. It is also why the remaining "cheap
wins" should be treated as suspect rather than merely unproven: each rests on a specific mechanism
claim, and the last two such claims were both false.

### Problem 3 — the plan's own procedure would have produced an inverted table

Running the ablation ladder V0→V5 back-to-back, as *Sequencing* specifies, confounds the
within-process degradation with the variant. V5 does the least work and, measured sixth, would
have come out **slowest**. The natural reading — "the ablation seam is expensive" — would have been
confidently, unrecoverably wrong. **Every variant must be the first run of its own process.**

### Problem 4 — behaviour regressions here are invisible to review

S-1 introduced two, both of which passed `script_check`, read correctly, and were caught only by a
full-round acceptance test with per-wave silver reconciliation:

- A single hit radius, forgetting that area-vs-area collision sums **both** shapes. Cost: a round
  that had comfortably won was lost outright.
- Losing opportunistic projectile hits, because `area_entered` used to damage whatever a projectile
  overlapped. Its signature was diagnostic: **waves 1-3 matched the old build exactly while 4-5
  regressed**, because only dense waves have several archers converging on one enemy.

**Per-wave silver is the instrument that found both.** It reconciles exactly (`count x reward`), so
a single missed kill shows up as a number. Use it on every gameplay-touching rung; a "the round
still wins" check would have passed the first bug and shipped it.

### Problem 5 — the game itself is stochastic

Tower fire intervals are jittered +/-5%, initial delays are random, and target selection is
`randi()`. Round outcomes vary by several lives run to run (12/20 and 16/20 both observed on the
same pre-S-1 build). **A single round is weak evidence**; compare per-wave totals, which are far
tighter, and prefer two rounds.

### The honest strategic position

A3's cheap half is largely spent: two rungs done, both bought nothing measurable, and two more
(G-1, G-2) are now bounded or refuted before being built. The measured costs are real but appear to
be inherent to the node-per-enemy architecture, which only X-\* changes.

**The alternative worth weighing is A4.** The game currently wins, is error-free, holds ~250
enemies, and has an unshipped Windows export. A4 (MVP UI, ~6%) is what actually blocks an itch
release. A3's remaining value is the 1500-enemy target, which now looks like it requires the
largest and riskiest rung rather than the accumulation of small ones.

---

## First measurements — M-0, `BENCH_TAG "M-0"`

One machine, editor-hosted playtest, `packed` config (20 px lattice), 600 enemies.

| Tag | V | n | config | frame p50 | frame p95 | phys p50 | phys p95 | **µs/enemy** | pairs | nodes |
|---|---|---|---|---|---|---|---|---|---|---|
| M-0 | V1 | 600 | packed | 16.67 | 50.00 | 15.77 | 21.79 | **26.3** | 180 | 1843 |
| M-0 | V0 | 600 | packed | 133.33 | 144.51 | 35.59 | 52.38 | **59.3** | 180 | 1843 |
| M-0 · post-E-1 | V0 | 600 | packed | 133.33 | 142.85 | 36.38 | 52.39 | **60.6** | 180 | 1843 |
| M-0 · post-A2 | V0 | 600 | packed | 133.33 | 144.88 | 40.00 | 52.24 | **66.7** | 180 | 1843 |

**The post-A2 row is the current baseline** (2026-09-06, after E-2..E-5 and A-1). Everything below
that quotes 59.3 or 60.6 is arithmetic against a build that no longer exists — **M-1 re-derives the
whole table before any optimisation lands.** Note the frame figures barely moved while `phys_ms`
rose 10%: exactly the vsync-quantisation trap this plan was written to avoid, visible in its own
data.

**On the post-E-1 row: +1.3 µs/enemy (+2.2%) against the pre-E-1 baseline, and I cannot honestly
call that noise, because the noise floor was never established** (M-0 called for three identical
runs; two were taken). E-1 did add two real operations to the hot path — a `not
ignore_separation` test and a `* separation_weight` multiply — so a small genuine cost is expected
and acceptable at this stage. **Establish the noise floor before M-1**, or every subsequent
"no change" is the same unbounded claim that cost this project five previous attempts.

**The harness reproduces both of the numbers this project already trusted**, which is the
self-test it had to pass before being believed:

- `16600 / 59.3` = **280 enemies** at 60 FPS — CLAUDE.md's "practical budget ~200–250". ✅
- `16600 / 26.3` = **631 enemies** with separation off — CLAUDE.md's "60 FPS at 600". ✅

## M-1 results — measured 2026-09-06, `BENCH_TAG "M-0"`, 600 enemies, `packed`

**Protocol: one run per game process, always the first run.** That is not a stylistic preference —
see the next section.

| Variant | µs/enemy | phys p50 | Isolates (by subtraction) | Cost | Share |
|---|---|---|---|---|---|
| V0 | **65.6** | ~39 | — | — | 100% |
| V1 | 40.1 | 24.06 | **separation** | **25.5** | **39%** |
| V2 | 36.3 | 21.80 | flow lookup + its 2 `tile_map.` calls | 3.8 | 6% |
| V3 | 18.8 | 11.29 | **`is_wall()` + the move** | **17.5** | **27%** |
| V4 | 18.0 | 10.79 | script entry residual | 0.8 | 1% |
| V5 | **6.5** | 3.92 | **grid rebuild** | **11.5** | **18%** |
| — | — | — | dispatch + Area2D transform sync + group scan **floor** | 6.5 | 10% |

The parts sum to **65.6**, exactly V0. V0 is the mean of three first-runs (62.6 / 66.7 / 67.5).

### The harness degrades within a process — and it would have inverted the whole table

Three identical V0 runs back-to-back gave **67.5 → 98.3 → 94.3**. A second process gave
**62.6 → 78.3 → 85.9**. Monotonic degradation, ~+45% by the third run, and **an idle gap did not
recover it**, which rules out thermal. Node count is constant at 1845 and the lattice is frozen, so
it is neither leaked nodes nor positional drift.

**First runs, across three separate processes: 62.6 / 66.7 / 67.5 — a ±3.7% spread.** Any run that
is not the first in its process is not usable at all.

**That ±3.7% was optimistic, and a second triple corrected it.** Three first-run V0-nw measurements
gave **58.3 / 50.2 / 51.7 — a 15% range (±7.6%)**, twice as wide. Taking the wider of the two, the
working first-run noise floor is **±8%**, not ±4%. Recorded because the narrower figure was quoted
in this document within the hour of being measured, and a noise floor derived from one triple is
exactly the unbounded claim this plan exists to prevent. **Any rung predicting less than ~15%
improvement needs three runs, not one.**

**This is the finding that saves the stage.** Had the ladder been run V0→V5 back-to-back as this
plan specified, the degradation would have been **perfectly confounded with the variant**: V5 does
the least work, and being sixth it would have measured *slowest*. The resulting table would have
said "removing work makes it slower", and the natural reading — "the ablation seam itself is
expensive" — would have been completely wrong. A methodology that produces a confidently inverted
answer is worse than no measurement at all, which is the exact hazard this plan was written to
avoid, reproduced by the plan's own procedure.

**Root cause is not yet identified.** Not thermal, not node leakage, not drift. Remaining
candidates: allocator fragmentation from creating and destroying 600 nodes per run, PhysicsServer2D
broadphase state not compacting across teardowns, or editor-side accumulation in the hosted
process. **S-1 tests the physics hypothesis for free** — if retiring the Area2D presence also
removes the degradation, that is the answer.

**Two harness defects worth fixing before the matrix grows:**

1. `_phys_samples` contains long runs of identical values, because
   `Performance.TIME_PHYSICS_PROCESS` updates less often than once per frame. The effective sample
   count is well below the 180 reported, so `p95` is softer than it looks.
2. `node_count` drifted 1845 → 1860 mid-session, so the harness is not perfectly isolated from
   whatever else the scene is doing.

### V0-nw — splitting "is_wall + the move"

M-1 left 17.5 µs/enemy (27%) attributed to "`is_wall()` + the move" without saying which. A new
ablation answers it: `Enemy.bench_skip_position_write`, deliberately **orthogonal** to the ordinal
V0–V5 ladder, because it must do *more* than V3 (it keeps `is_wall`) while doing *less* than V0
(it skips the position write) — something no ordinal rung can express.

| Measurement | µs/enemy |
|---|---|
| V0 (mean of 62.6 / 66.7 / 67.5) | 65.6 |
| V0-nw (mean of 58.3 / 50.2 / 51.7) | 53.4 |
| **Position write → PhysicsServer2D transform sync** | **12.2 (19%)** |
| Remainder of the 17.5: `is_wall` + normalize + call overhead | ~5.3 (8%) |

**The `global_position` assignment on an Area2D costs 12.2 µs/enemy — 19% of the entire frame**,
comparable to the whole grid rebuild. Note the enemies are *frozen* in the bench (`speed = 0`), so
the step is a zero vector and the assignment is writing the same value it already holds. **It is
not the arithmetic; it is the transform sync the assignment forces.**

### P-2 result — G-1's premise is REFUTED

P-2 was specced as a four-line, revertible **test of G-1's premise**, with an explicit rule
attached: *if halving the probes does not roughly halve separation-attributable time, then hashing
is not dominant, the flatten will not pay.* It was run exactly that way, and **the answer is no.**

| | runs | mean |
|---|---|---|
| Before P-2 | 54.0 / 54.6 / 60.2 | **56.3** |
| After P-2 | 58.2 / 52.6 / 51.4 | **54.1** |

**−2.2 µs/enemy (−3.9%), with the ranges overlapping almost entirely** (54.0–60.2 vs 51.4–58.2).
Separation costs 25.5 µs/enemy; if hashing dominated it, removing ~11 redundant hashes per enemy
per frame should have shown 5–10. It did not.

**Therefore: do not build G-1 as written.** Flattening the grid to eliminate hashing is aimed at a
cost that has now been measured and is not there. That is a whole commit — rung 7 — saved by four
lines, which is precisely the trade P-2 was designed to make.

**Be careful what this does and does not refute.** It refutes *hashing* as separation's dominant
cost. It does **not** refute every benefit of a flat grid: flattening would also remove the nine
`Vector2i` constructions per enemy per frame and allow typed or packed storage, which kills the
Variant boxing on every `other_pos` read. **Those are now the prime suspects for separation's
25.5** — the inner-loop arithmetic and Variant unboxing, not the dictionary. If G-1 is revived it
must be re-justified against those, with its own prediction, and not by citing hashing.

**P-2 is kept rather than reverted.** It is a strict reduction in work that cannot be slower, and
the code is clearer. But its benefit is **unmeasurable**, and it must not be cited later as a win.

*Correctness verified before measuring:* grid buckets populate identically (Array reference
semantics preserved through `get()`), `get_enemies_in_radius` returns the same members,
`get_flow_direction` returns real vectors on-field and `Vector2.ZERO` off it,
`flow_field.size()`/`walls_dict.size()` unchanged at 154/104, and a live round paths and separates
normally with zero errors.

### S-1 result — the structure changed, the cost did not

S-1 landed in full: `Area2D` → `Node2D` on all three enemy scenes, towers switched from
`get_overlapping_areas()` to the map's spatial grid, projectiles from `area_entered` to distance
tests. It verifiably did what it claimed **structurally**:

| | before | after |
|---|---|---|
| `phys_pairs` (broadphase) | 180 | **0** |
| `node_count` at 600 enemies | 1845 | **1250** (−595, exactly one CollisionShape2D per enemy) |
| **`us_per_enemy`** | 58.2 / 52.6 / 51.4 → **54.1** | 61.2 / 57.6 / 52.9 → **57.2** |

**No improvement.** The physics presence is provably gone and the frame cost did not move.

**This refutes M-1's attribution of the 12.2, not the 12.2 itself.** V0-nw measured that *skipping
the `global_position` write* saves 12.2 µs/enemy, and that stands. What was wrong was the
explanation — this document (and CLAUDE.md) claimed the cost was "the PhysicsServer2D transform
sync an Area2D forces". S-1 removed the physics entirely and the cost stayed. Therefore:

> **Assigning `global_position` costs ~12 µs/enemy on a plain Node2D too.** It is the engine's
> transform-set path — dirty flags, notification propagation, the property setter — not physics.
> **No node-type change can remove it. Only writing the transform less often, or not owning a node
> at all, can.** That is the X-* rung, and nothing before it.

**I recommended promoting S-1 to a first-class rung on the strength of that attribution.** The
recommendation was wrong, and the experiment is what caught it. Recorded rather than quietly
amended, because the same reasoning ("it must be physics, enemies are Area2D") is the obvious
first guess and someone will make it again.

**S-1 is KEPT, and must not be cited as a performance win.** It is kept because it is a
prerequisite for X-*: enemies that own no physics presence are far easier to convert to plain data.
It also retires collision layer 2 and 595 nodes. But it bought **nothing measurable at 600**, and
whether an empty broadphase matters at 1500 is untested.

**Two regressions it caused on the way, both found by the acceptance round rather than by review:**

1. **A single 18px hit radius.** The old test was area-vs-area, which sums BOTH shapes: an arrow
   (r=20.2) against a goblin (half-extent 16) connected at ~36px, and against an ogre (35) at ~55.
   Using 18 for everything made towers miss enough to lose a round that had comfortably won.
   Fixed by moving the geometry into the enemy registry as `hit_radius` and adding the
   projectile's own radius to it.
2. **Arrows stopped hitting anything but their original target.** `area_entered` damaged whatever
   the projectile physically overlapped, so an arrow whose target died mid-flight still connected
   with the enemy behind it. The replacement returned early and wasted the shot. **Waves 1-3
   matched the old build exactly while 4-5 regressed** — the signature of a bug that only appears
   when several archers converge on one enemy. Fixed by scanning the grid for an opportunistic hit
   on the dead-target branch only.

**Acceptance (the plan's criterion: kills and lives within noise):** two full rounds, both **won**
at 7/20 and 12/20 lives for +862 and +884 silver, against a pre-S-1 comparable round of 12/20 and
+890. Waves 1-3 reproduce the old silver totals **exactly** (+64 / +96 / +154) and wave 4 is now
**better** (+238 with zero leaks, twice, versus +236 with one leak). Zero errors.

### A third source of variance: across sessions

The pre-P-2 triple (mean **56.3**) was taken minutes before the post triple. An earlier V0 triple
the same day, on effectively identical code, meaned **65.6** — **14% higher**.

So there are three variance layers, not one: within-process degradation (~+45%, fatal, avoided by
restarting), first-run spread (±8%), and **session-level drift (~14%)**. The practical rule:

> **Only compare measurements taken close together in the same sitting.** A number quoted from an
> earlier session is context, not a baseline. Re-measure the "before" immediately before every
> change, however recently it was measured.

### What the measurement changes about the ladder

**The manager loop is confirmed as *not* the fix — now with a bound.** Everything G-2 can remove
lives inside V5's 6.5 µs/enemy floor, and it cannot remove all of it. **G-2 is worth at most ~10%**,
against a target needing 83%.

**P-1 is over-ranked.** It was predicted "likely the largest". The entire flow lookup *including*
its two cross-object `tile_map.` calls is **3.8 µs/enemy — 6%**. Its other two calls sit inside
`is_wall`, so P-1's real ceiling is a fraction of the 17.5 below.

**S-1 is the largest non-separation win, and this document files it as a "parallel track".**
Measured, not predicted: the position write alone is **12.2 µs/enemy (19%)**, and S-1 additionally
removes the Area2D from the broadphase entirely, which is part of V5's 6.5 floor. **S-1's total
target is therefore up to ~18 µs/enemy (27%)** — second only to separation. It should be promoted
from side track to a first-class rung.

**P-1 is worth ~14%, and not where the plan thought.** The flow lookup it was scoped around is only
3.8; the rest of its value is inside `is_wall`'s conversion, ~5.3 including the normalize and call
overhead that P-1 cannot remove. So P-1's real ceiling is under 9 µs/enemy, and **an implementation
that only caches the conversion in `get_flow_direction` captures less than half of it** — it must
cover `is_wall` too, which is the opposite emphasis to how P-1 is currently written.

**P-3 is well-placed and well-quantified:** the grid rebuild is **11.5 µs/enemy (18%)**, the
second-largest single item.

**Re-ranked by measured cost, not prediction:**

| Rank | Target | µs/enemy | Rung |
|---|---|---|---|
| 1 | separation | 25.5 | ~~G-1~~ — **P-2 refuted the hashing premise**; re-target at Variant boxing + `Vector2i` construction before committing to a flatten |
| 2 | ~~Area2D presence~~ — **S-1 shipped and bought nothing.** The 12.2 is the engine's transform-set path, not physics | 12.2, **only X-\* can take it** | X-\* |
| 3 | grid rebuild | 11.5 | P-3 |
| 4 | cell conversion — `is_wall` ~5.3 + flow 3.8 | ~9 | P-1 (must cover `is_wall`, not just the flow lookup) |
| 5 | remaining dispatch floor | small | G-2 |

**The target is still hard.** Even with separation made *entirely free*, V1 sits at 40.1 — and 1500
enemies needs **≤ 11.1**. The non-separation path alone still needs a **3.6× reduction**, which
confirms this plan's central finding rather than softening it.

---

### What the first attribution says

**Separation costs 33.0 µs/enemy** (59.3 − 26.3) — 56% of physics time. That much was expected.

**Caveat, and it matters:** that subtraction pairs a **V1 row measured pre-E-1** against a V0 row
from the same era. Both halves are now stale, and V1 has never been re-measured at all. The 33.0
figure is indicative, not established — M-1 re-runs both variants on the current build before
anything is attributed to separation.

**The other 26.3 µs/enemy was not.** At 600 enemies that is 15.77 ms of a 16.67 ms physics
budget — **95% of the frame, before separation runs at all.** Even if separation were made
completely free, 600 enemies would sit exactly at the edge.

**This changes the shape of the target.** 1500 enemies needs `us_per_enemy ≤ 11.1` — a **5.3×**
reduction from 59.3, or **6.0×** from the current post-A2 baseline of 66.7. Driving separation to
literally zero only reaches 26.3 — less than halfway.
**A3 must attack the non-separation baseline too**, and the items that do that are P-1 (cached cell
conversion), P-3 (registry + persistent buckets) and G-2 (the manager loop). The plan below already
contains them; what changed is that they are now known to be *load-bearing* rather than
supporting.

### Two harness caveats, recorded rather than hidden

- **`frame_ms` is vsync-quantised; `phys_ms` and `us_per_enemy` are not.** The frame figures land on
  exact multiples of 16.67 (16.67, 50.00, 133.33) despite `VSYNC_DISABLED` being requested, so
  treat them as secondary. `Performance.TIME_PHYSICS_PROCESS` measures CPU work directly and is
  unaffected — which is why the headline metric is the one derived from it.
- **A run is ~4 s at 60 FPS but ~45 s in the 7 FPS regime**, because sampling is frame-bounded
  (60 warm-up + 180 samples). Consider making it time-bounded before M-1's full matrix, which is
  6 variants × 4 counts × 2 configs.

---

~~Blocked on A2~~ — **A2 is complete** (see [a2_plan.md](a2_plan.md)), so every rung after M-0 is
now unblocked.

**Target: 1500 concurrent enemies at p95 < 16.6 ms**, ~6× today's ceiling. De-nodify and MultiMesh
are in scope from the start (decided with the user). The ladder below is about **attribution
order**, not scope.

**Scope:** `level_controller.gd`, `enemy.gd`, `systems/bench.gd` (built in A2), the two towers, the
two projectiles, **all three enemy scenes** (`goblin.tscn`, `skeleton.tscn`, `ogre.tscn` — S-1
changes the root type of each), `level_01.tscn`, `my_tiles.tscn`. Bundles the deprecated-TileMap →
TileMapLayer migration (CLAUDE.md Known issue 5) and, as its final step, overlapping waves
(deferred here by [a1_plan.md](a1_plan.md)).

Read [CLAUDE.md](CLAUDE.md) first — *Separation (the perf-critical path)*, *Performance*, *Known
issues* 1b and 5, and *Gotchas*.

---

## The finding that reshapes this stage

CLAUDE.md's *Performance* section currently says:

> **Recommended next attempt:** stop giving every enemy its own `_physics_process`. Move the whole
> horde into a single manager loop... which is the largest remaining structural cost.

**That is wrong, and following it would have produced a sixth consecutive "no change" result.**

Per enemy, per physics frame, in the common open-ground case:

| Cost | Count | Removed by a manager loop? |
|---|---|---|
| `Vector2i`-keyed Dictionary operations | **16–25** | **No — zero removed** |
| `Vector2i` constructions | ~11 | **No** |
| Cross-object `tile_map.` calls | 4 | **No** — same calls, different caller |
| Cross-object `map.` calls | 3 | Softened to self-calls, not removed |
| `_physics_process` Callable dispatch | 1 | **Yes** |
| PhysicsServer2D area transform sync | 1 | **No** — still an Area2D assigning `global_position` |

At 600 enemies that is roughly **10,800 dictionary probes and 6,600 `Vector2i` constructions per
frame**. A manager loop removes one dispatch out of that. It is a real win and a *prerequisite* for
later rungs, but it is not the fix.

**This also explains the project's most confusing datum.** CLAUDE.md records that capping
candidates at 24 per frame produced "no change at all". The reason: the nine-cell scaffolding
(9 `has()` probes, 9 `Vector2i` builds, 2 `range()` setups) is paid **in full by an enemy with zero
neighbours**. No inner-loop cap can touch it. The cost is fixed per-enemy overhead, not
per-neighbour work.

Where the probes come from, precisely:

- `_separation()` — **9** `_grid.has(key)`, always, plus up to **9** `_grid[key]`. The
  `has()`-then-`[]` idiom hashes every key **twice**.
- `get_flow_direction()` — 2 (same double-probe), plus 2 cross-object `tile_map.` calls.
- `is_wall()` — 1, plus 2 more `tile_map.` calls.
- `_rebuild_enemy_grid()` — ~4 more per enemy, and it hashes each key **three** times
  (`has`, then `enemy_grid[key]`, then `enemy_grid_nodes[key]`).

**Correcting that CLAUDE.md paragraph, backed by measured arithmetic, is a deliverable of M-1.**
Leave it and the next person spends a week re-confirming it.

---

## Why measurement comes first

Six optimisations have been attempted on this loop. **Five produced "no change."** The only
measurement that ever produced a number was deleting the feature entirely (600 enemies, separation
off, 60 FPS). The acceptance criterion for the largest item in the roadmap is currently *a
screenshot of an FPS label*.

**FPS is the wrong instrument**, for three reasons that have each already cost this project data:

1. **It is vsync-quantised.** Anything from 3 ms to 16.6 ms of work reports "60". Every
   optimisation on the flat part of the curve reads as "no change" **whether it worked or not**.
   Only two rows of CLAUDE.md's table (57 FPS at 200, 4 FPS at 600) carry information at all.
2. **It is a reciprocal, so it is not additive.** Halving cost at 4 FPS gives 8; the same halving
   at 55 gives 57.5. You cannot say "that removed 3 ms" and predict what the next change buys.
   Frame *time* is linear in work — that is what makes a ladder possible.
3. **Mean hides the tail.** Hitching is what a player feels at the ceiling.

**The tooling constraint that shapes the solution:** MCP's `execute_code` runs through Godot's
`Expression` class and **cannot reach `Engine` or `Performance`**, and rejects statements (no
`var`, no loops). But `runtime_get_script_vars` reads any script member variable off a live node.
**So the game must measure itself into member vars**, and MCP reads them back.

---

## Scope change to A2

**Build the bench harness (M-0) during A2, not A3.** It is purely additive and touches only a hook
in `level_controller`. Three reasons:

- A2's own checks want it — E-1's "a round is numerically identical", E-4's and E-5's "FPS holds
  at peak" are currently screenshot-reads.
- It gets validated on real work before A3 depends on it.
- **The per-enemy numbers above are pre-E-1 and will be stale.** A2 added `enemy_types.gd`, three
  enemy types, **two** ability payloads (boulder plus A-1's Rain of Arrows — Divine Smite and
  Dragon Fire moved to A5), `ignore_separation`, `separation_weight` and `life_cost`.
  The harness re-baselines for free.

**This section is history now** — M-0 shipped in A2 as planned, and the prediction it makes above
was correct: the numbers did go stale, twice.

---

## The ladder

```
M-0/M-1   measure + attribute          ← blocks everything
P-1..P-4  cheap wins, one commit each, each measured
T-1       TileMapLayer migration       ← after P-1, before G-2
G-1       flatten the grid             (kills hashing)
S-1       retire the physics presence  (parallel track)
G-2       single manager loop          (kills dispatch; enables X)
M-2       checkpoint — measured vs 1500
X-*       de-nodify + MultiMesh        (branch)
A3-ship   overlapping waves + re-tune
```

---

## M-0 · The bench harness

`systems/bench.gd`, a round-scoped child of `level_controller` named `Bench`, addressable at
`/root/map1/Bench`.

### What it records — frame time, not FPS

| Field | Source | Why |
|---|---|---|
| `frame_ms_p50/p95/max` | `delta` in `_process`, vsync off | What the player feels |
| `phys_ms_p50/p95` | `Performance.TIME_PHYSICS_PROCESS` | Includes the physics server step |
| **`us_per_enemy`** | `phys_ms_p50 * 1000 / enemy_count` | **The headline number** |
| `phys_pairs` | `PHYSICS_2D_COLLISION_PAIRS` | Proves S-1 did what it claims |
| `node_count` | `OBJECT_NODE_COUNT` | Proves X did what it claims |
| `result_line: String` | preformatted | One `runtime_get_script_vars` returns a paste-ready row |
| `history: Array` | | Several configs per session without re-polling |

**`us_per_enemy` is the only statistic that predicts.** At 60 Hz the physics budget is 16.6 ms, so
`16600 / us_per_enemy` *is* the enemy ceiling. Every rung becomes "27 µs → 11 µs, ceiling
600 → 1500" instead of "felt faster".

**`DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)` and `Engine.max_fps = 0` at bench start.**
One line, and the highest-value line in the harness — it turns "60 / 60 / 57 / 4" into a
continuous curve.

### Determinism — do not benchmark through the wave machine

It uses `randf()` scatter, takes 2.5 minutes, the population decays as enemies escape (destroying
the denominator of `us_per_enemy`), and tower fire is jittered.

`bench.run(count: int, config: String)`:

1. Clear the board and towers; set `round_state` so nothing scores.
2. Spawn `count` enemies on a **fixed lattice — no RNG at all**. A lattice beats a seeded RNG: it
   reproduces across engine versions and machines, and it makes **density an explicit parameter**.
3. `speed = 0`. The horde freezes but **the entire measured cost still runs** — separation runs
   before the move, the flow lookup runs, `is_wall(pos + ZERO)` still fires once, the grid still
   rebuilds. Only positional drift is removed, which is the variance you are trying to eliminate.
4. Discard **60 warm-up frames** (instantiation, `_ready()`, texture upload, the physics server
   registering n areas), then sample 180.
5. Compute p50/p95/max, fill `result_line`, append to `history`. Total ~4 seconds — under one MCP
   round trip.

**Two standard configs:**

- **`loose`** (45 px spacing) — most enemies have zero in-radius neighbours. **This is the case the
  scaffolding analysis says dominates, and the case where the 24-cap changed nothing.** Primary.
- **`packed`** (20 px, tighter than `SEPARATION_RADIUS = 32`) — every enemy has ~8 neighbours.
  Bounds the inner loop.

**Density has never been a controlled variable in this project's measurements**, despite CLAUDE.md
stating the falloff is super-linear in density rather than count. That is the largest gap in the
existing data.

Plus **one `live` cross-check per rung** — a real wave-5 board with the real tower loadout — so the
synthetic bench cannot silently drift from the game.

### The harness must pass its own self-test before it is trusted

With separation disabled it must reproduce **~60 FPS / p95 well under 16.6 ms at 600 enemies** —
the one number this project already believes. If it doesn't, the harness is wrong, not the game.
This is A2's "verify the net by breaking it" applied to instrumentation, and it is not optional: a
benchmark that has never reproduced a known result is worth nothing.

**Second self-test:** measure V0 with the ablation branch present versus a build without it. If one
int compare per enemy per frame is detectable, the harness distorts what it measures — and you need
to know that on day one.

**Record a noise floor** from three identical runs; report three significant figures maximum.
Anything smaller than the spread is not a result. Had this existed, "capping at 24: no change at
all" would have been recorded as "no change, ±0.4 ms" — a bounded statement instead of an ambiguous
one.

### Comparability

One machine only; say so in the table header. The game runs as a child of the editor under
`game_start`, and an exported build measures differently — make every claim on the same harness.
Pin `Engine.time_scale = 1`, assert the physics tick is 60, and record it, so a project-setting
change cannot silently invalidate the table. `const BENCH_TAG` bumped per step, with the commit
hash recorded beside it in this file. **Never `FileAccess.open("res://…", WRITE)`** — the table
lives in markdown, in git.

---

## M-1 · Attribution, without touching the inner loop

A single static int checked **once per enemy per frame** at the top of `_physics_process`,
early-returning at successive stages:

| Variant | Behaviour | Isolates, by subtraction from the row above |
|---|---|---|
| V0 | Full | — |
| V1 | Skip `_separation()` | **All of separation** |
| V2 | V1 + skip flow lookup | `get_flow_direction` + its 2 `tile_map.` calls |
| V3 | V2 + skip wall test / move | `is_wall` + its 2 `tile_map.` calls |
| V4 | Return immediately | Script dispatch + the Area2D transform sync |
| V5 | V4 + grid rebuild disabled | Group scan + n Array reallocations |

Six runs give the entire cost breakdown in milliseconds, in one commit, with **zero instrumentation
in any inner loop**.

**Deliverables of this commit:** the baseline table (variants × {200, 400, 600, 900} × {loose,
packed} + one live cross-check), the noise floor, and **the CLAUDE.md correction** — landed with
arithmetic behind it rather than argument.

---

## P-1..P-4 · The cheap wins, ranked by expected value

Predictions. The whole point of M-0/M-1 is that these get replaced by numbers.

**P-1 — Cached cell conversion. Likely the largest, and not previously on anyone's list.**
`get_flow_direction` and `is_wall` each call `tile_map.to_local()` then `tile_map.local_to_map()` —
**4 cross-object calls into an engine node per enemy per frame**, plus transform math. But
`my_tiles` is `scale = (50,50)`, at origin, unrotated, with 1×1 tiles: the entire conversion is
`Vector2i(floori(x/50), floori(y/50))`.

Capture `_cell_size` / `_cell_origin` / `_inv_cell` once in `_ready()` from the TileMap's actual
transform and `tile_set.tile_size`, `assert` no rotation or skew, and compute inline. **Four engine
calls become two integer divisions — and this *deletes* the four hot-path TileMap sites rather than
migrating them** (see T-1).

**P-2 — The `has()` + `[]` double-probe.** Nine redundant re-hashes per enemy per frame in
`_separation`, two more in `get_flow_direction`, and a triple-hash in the rebuild.
`var cell = _grid.get(key)` / `if cell == null: continue` halves dictionary work in the hottest
function.

G-1 throws this away — **do it anyway, because that is precisely its value.** It is a four-line,
revertible **test of G-1's premise**. If halving the probes does not roughly halve
separation-attributable time, then hashing is *not* dominant, the flatten will not pay, and you
have learned that for four lines instead of for two commits.

**P-3 — Enemy registry + persistent buckets.** `enemy_grid.clear()` destroys every per-cell Array
and they are all reallocated every frame; `get_tree().get_nodes_in_group()` allocates a fresh
n-element Array every frame; `enemy_grid_nodes` duplicates the whole structure.

Clear buckets **in place** (iterate values, `.clear()` each) rather than clearing the dictionary —
the map is bounded, so persistent empty buckets are correct and cheaper. Give `level_controller` its
own `_enemies: Array[Node]`, registered from `Enemy._ready()` and deregistered in `_exit_tree()`.
The group stays for towers, `call_group` and `_clear_all_enemies` — purely additive.

**Highest-leverage item on the list, because it is also the architectural seam G-1, G-2 and X all
need.** This is the A1-Step-0 pattern applied to A3: additive, nothing observable changes, so the
risky commits land against a foundation already proven not to move.

**P-4 — The nine rebuilt `Vector2i` offsets and the per-frame `has_method`.**
`const NEIGHBOR_OFFSETS: Array[Vector2i]` with nine entries removes nine constructions per enemy per
frame. And `enemy.gd`'s `map.has_method("get_flow_direction")` is asked **every frame** for an
answer fixed at `_ready()` — probe once into `_has_flow`, exactly as R-0 already did for the round
contract eleven lines above it.

*Caveat:* GDScript specialises `for i in range(<consts>)` into an integer loop, so the `range()`
allocations are probably **already free**. Don't spend a commit on that half without measuring.

*Low confidence:* untyped Arrays cause Variant boxing per candidate read. `Array[Vector2]` is **not**
`PackedVector2Array` and is **not** copy-on-write — say so in the commit message or someone will
revert it citing CLAUDE.md's packed-array rule, which is about a different thing. But a typed Array
retrieved from an untyped Dictionary returns as a Variant anyway, which may eat the gain. Measure;
expect a wash. G-1 fixes this properly.

---

## T-1 · TileMapLayer migration

**Slots immediately after P-1, and before G-2.** P-1 changes the migration's shape: it **deletes**
the four hot-path call sites rather than migrating them. What remains is 11 cold-path sites, all in
`level_controller.gd` — a self-contained commit.

Do not run a deprecation migration and a hot-path rewrite over the same lines in the same window.

- `get_used_cells(0)` → `get_used_cells()`. An arg-count error, so it fails loudly. Safe.
- **`level_01.tscn`'s `layer_0/tile_data` → `tile_map_data` is the real risk** — the entire level
  geometry is one `PackedInt32Array` line. Use Godot 4.3+'s editor conversion action on the selected
  node, then `editor_save_scene`. **Never hand-edit.**
- **Verify by integers, not by looking at it.** `generate_flow_field()` already prints
  `flow field %d cells` under `debug_logging`. Compare **`flow_field.size()`, `walls_dict.size()`
  and `get_used_rect()` as exact integers, pre and post.** A level that loses six tiles looks fine
  and paths wrong.
- **`my_tiles.tscn`'s `scale = Vector2(50,50)` is load-bearing** — it is why one cell = 50 world px,
  and P-1 reads it. The editor conversion may produce a *child* layer node, changing the path.
  **End state must be a single `TileMapLayer` named `my_tiles`, a direct child of `map1`, carrying
  `scale = (50,50)`** — otherwise `$my_tiles`, `place_tower()` and `_cell_at()` all move.
- **Free bonus: delete the TileSet's physics layer.** It generates collision polygons nothing uses
  (movement is manual point-testing) — CLAUDE.md Known issue 6 — and it takes the wall bodies out of
  the same broadphase S-1 is cleaning up. It never gets cheaper than this moment.

---

## G-1 · Flatten the grid

> **Note added after A2:** `get_enemies_in_radius()` has more callers than when this plan was
> written — A-1's Rain of Arrows queries it once per tick (12 per cast), and S-1 converts both
> towers onto it. Flattening the grid changes that function's internals, so re-verify **every**
> consumer, not just separation: boulder, fire, rain, and post-S-1 the two towers.

Replace `Dictionary[Vector2i] → Array[Vector2]` (and its duplicate `enemy_grid_nodes`) with a
**counting sort into flat packed arrays**.

Bounds derived once in `generate_flow_field()` from `get_used_rect().grow(15)`, converted to 32 px
grid coordinates, **plus a one-cell apron** so any in-bounds enemy's 3×3 scan stays in range.
Cell index is `(gy - origin.y) * _grid_w + (gx - origin.x)` — a plain int. **All hashing
disappears.**

```
_counts / _starts / _fill : PackedInt32Array
_positions                : PackedVector2Array   bucket-sorted
_indices                  : PackedInt32Array     parallel, index into _enemies
```

Rebuild is three linear passes with zero allocation and zero hashing: count, prefix-sum, place.
All arrays `resize()`d once when capacity grows, never reallocated per frame.

**The payoff:** because cells within a row are consecutive indices and the prefix sum lays buckets
out in index order, **the three cells of a row occupy one contiguous range of `_positions`**. Nine
dictionary probes and nine `Vector2i` constructions become **six `PackedInt32Array` reads and three
tight loops over cache-linear memory** — finally the shape the ruled-out "capping at 24" experiment
assumed it already was.

**This is not the ruled-out packed-array case.** CLAUDE.md's rule is that packed arrays are
copy-on-write and **appending** to one stored in a Dictionary can copy it per append. Here the array
is a **member, written by index, never appended**, resized only on growth. The precise rule to write
into the code:

> **Write through the member (`_positions[i] = p`). Never take a local alias for writing** —
> `var a := _positions` creates a second reference and the next write copies. A local alias for
> *reading* in the inner loop is fine and is faster than repeated member lookup.

Getting this vague rather than precise is what produced the blanket ban that would otherwise block
this design.

**Fallback, named now so it is a decision rather than an improvisation under pressure:** int-keyed
Dictionary (`gy * _grid_w + gx`) with persistent in-place-cleared buckets. Keeps hashing, drops
`Vector2i` construction, ~60% of the benefit for a fraction of the change.

**Rejected: fixed-capacity buckets.** One pass, no prefix sum — but they **silently drop enemies**
past capacity, and at 32 px cells a dense cluster blows past 8 easily. Silent dropping is exactly
the failure class A1 and A2 spent their budgets building nets against.

**Out-of-bounds:** clamp the index and skip separation, with a `push_error` **once per round**.
"Loud once, then correct" beats "loud every frame".

---

## S-1 · Retire the physics presence (parallel track)

`Area2D` → `Node2D`, **keeping the node**. ~30 lines across four scripts and one `.tscn`.

- Towers: `get_overlapping_areas()` + group filter → `map.get_enemies_in_radius(pos, range_px)`.
  That function already exists and answers the same question off the grid, and towers fire at ~2 Hz,
  not per frame.
- Projectiles: `area_entered` → a distance test against the already-homed `target`. Both already
  track a specific target and both already tolerate a dead one.
- `goblin.tscn`: root → `Node2D`, `CollisionShape2D` removed.

**Buys** the per-enemy PhysicsServer2D transform sync (paid today despite `monitoring = false` and
`collision_mask = 0`, because towers need the broadphase) and takes n areas out of the broadphase
entirely. Collision layer 2 (`tower_range`) becomes unused — note it in CLAUDE.md's table rather
than renumbering.

**Keeps** sprites, `.tscn`-per-type, `is_instance_valid`, `take_damage`, `queue_free`, groups,
`call_group`, and A2's entire contract net.

**Risk:** the hit test stops being the enemy's 32-world-px box and becomes a tunable `HIT_RADIUS`
(start ~18). **Acceptance is numeric, not visual:** same round, kill count and lives lost within the
noise floor.

Nearly disjoint from P-1..G-1 — one line of overlap (`extends`). Run it concurrently.

---

## G-2 · Single manager loop

`level_controller` iterates `_enemies` inline; `enemy.gd::_physics_process` is retired. Removes the
per-node Callable dispatch and converts the three cross-object `map.` calls into self-calls.

**The testbed decision is made here, not discovered.** `clean_area.gd` drives enemies through its own
duck-typed `get_flow_direction`/`is_wall` contract. Either it gets a minimal manager or it is
formally retired.

---

## X-* · De-nodify + MultiMesh (branch)

The only rung that cannot be partially landed, so it goes on a branch while trunk keeps shipping the
G-2 engine.

- **Handles become `(slot, generation)`.** Get the generation counter wrong and a stale arrow damages
  a **fresh** enemy occupying a recycled slot — no crash, no error, in a project whose entire A2 R-0
  was about eliminating exactly that class of bug.
- **Six consumers today, eight if A5 lands first** — archer, wizard, arrow, fire, boulder, plus
  A2's `rain_of_arrows`, which ticks its query **12 times per cast** rather than once. `divine_smite`
  (picks highest-HP from a query) and `dragon_fire` moved to A5, so whether they are X's problem
  depends on stage order. **If A5 ships before A3, budget for eight.**
- **A2's contract net must be re-formed for the index model, not deleted.** `Enemy.GROUP`,
  `ROUND_CONTRACT` and `_assert_enemy_contract()` were all built around nodes and groups. Budget for
  this explicitly — it is the thing most likely to be quietly skipped.
- **Known cost to A2's promise.** "A new enemy is a `.tscn` and a registry entry" degrades: per-type
  sprites need **one MultiMesh per type** (recommended — the type count is small and bounded) or an
  atlas with per-instance custom data (a second unknown stacked on the first). The `.tscn` stops
  being *instantiated* and becomes *read as data* (texture, scale, modulate pulled once at registry
  build). **Record this as a decision now rather than discovering it later.**
- **Free win:** this retires Known issue 1b (freed-node access through the grid) outright — an index
  plus generation cannot dangle.
- **Smoke-test MultiMesh under `gl_compatibility`** (this project's renderer) in the first hour, not
  in week three.

---

## A3-ship · Overlapping waves + re-tune

**A bigger sequential wave is the same fight bigger; overlap is what makes it overwhelming.** This is
the actual A3 headline, and a1_plan deferred it here explicitly.

a1_plan already priced it: a wave tag per enemy and per-wave decrements — *"a real deferred cost, not
a dodged one."* Waves are strictly sequential today precisely so one counter suffices; overlap breaks
that, and `wave_remaining` / `enemies_to_resolve` must become per-wave.

Plus a re-tuned `WAVE_TABLE` and `difficulty_scale` against the measured ceiling, and the measured
600+ screenshot CLAUDE.md demands.

---

## Sequencing

| # | Commit | Done when |
|---|---|---|
| 0 | **M-0** bench harness + ablation seam *(lands in A2)* | `run(600,"loose")` returns a `result_line`. **V1 reproduces ~60 FPS at 600.** Noise floor recorded; variant-branch overhead below it |
| 1 | **M-1** baseline + CLAUDE.md correction | Scaffolding claim confirmed or refuted in ms; the 24-cap null result explained arithmetically |
| 2 | **P-1** cached cell conversion | 20 sampled positions map to identical cells pre/post. Δms recorded vs prediction |
| 3 | **T-1** TileMapLayer migration | `flow_field.size()`, `walls_dict.size()`, `get_used_rect()` **identical integers** pre/post. Towers still place only on walls |
| 4 | **P-2** single-probe dicts | **Separation ms (V0−V1) drops ≈half.** *If it doesn't, re-plan G-1 before building it* |
| 5 | **P-3** enemy registry + persistent buckets | Manager-side ms (V4−V5) drops. Round **numerically identical** |
| 6 | **P-4** offset table + `has_method` probe | Δms recorded. Testbed and level_01 both run |
| 7 | **G-1** flatten the grid | Separation ms drops sharply. Same lattice yields the same separation vector pre/post |
| 8 | **S-1** retire physics presence *(parallel)* | `PHYSICS_2D_COLLISION_PAIRS` collapses. Kills and lives within noise floor |
| 9 | **G-2** single manager loop | Dispatch ms (V3−V4) → ~0. Testbed either works or is formally retired |
| 10 | **M-2** checkpoint | Full matrix vs the 1500 target. Decision recorded either way |
| 11 | **X-\*** de-nodify + MultiMesh *(branch)* | Target met, or branch abandoned and trunk ships rung 9 |
| 12 | **A3-ship** overlapping waves + re-tune | A played round feels overwhelming. CLAUDE.md's table carries real numbers, not a cliff |

**Ordering rules:**

- **M-0 and M-1 block everything.** No optimisation lands without a before/after pair. This is the
  rule the previous six attempts lacked.
- **T-1 must follow P-1** (which deletes four of its sites) and **precede G-2** (which rewrites the
  same neighbourhood).
- **P-3 is the A1-Step-0 pattern** — the additive seam that G-1, G-2 and X all build on.
- **S-1 runs concurrently** with 2–7.
- **The tripwire that actually protects the timebox:** after each rung, compare measured µs/enemy
  against the target **and against that rung's own prediction**. **Two consecutive rungs missing
  their prediction by more than 50% means the cost model is wrong — stop and re-measure rather than
  keep spending against it.** That is the discipline the "capping at 24" episode should have
  triggered and didn't, because there was no prediction to miss.
- **Every rung is independently shippable**, so running out of budget means shipping at whatever rung
  you reached — not abandoning work. That is materially stronger than alpha_plan's current "keep the
  current GDScript horde as a fallback", which implies maintaining two engines.

---

## Verification

Per CLAUDE.md's *Gotchas*: **runtime errors go to `debugger_get_log`, not `editor_get_console`**;
`execute_code` with `scope_path` `/root/map1` (it cannot reach `Engine`/`Performance` — hence the
self-measuring harness); `click_node` by runtime-resolved path. Confirm via state, never
`dispatched: true`.

**No perf claim without both a measured screenshot and a `us_per_enemy` figure.**

---

## Out of scope — named so they are not drifted into

- **GDExtension / C#.** If X misses the target, that is a *post-alpha* conversation, not a rescue.
- **Per-type separation radius or mass** — a2_plan reserves this deliberately, and G-1 does not
  enable it.
- **The Chebyshev flow-field wart** (Known issue 2) — unrelated, and touching the BFS during a
  hot-path rewrite is how you get a path regression you cannot attribute.
- **Tower targeting priority** — a2_plan's answer is Divine Smite.
- **`is_wall()` centre-point testing** (Known issue 3) — same reasoning as the flow field.
