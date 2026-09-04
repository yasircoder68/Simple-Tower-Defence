# Final — Paid Release on Steam

**Audience:** paying customers.

**Content:** everything. All levels, all towers, all enemies.

**Share of remaining work: 20%. Cumulative: 100%.**

---

## Why this stage is only 20%

By the time beta ships, the game looks finished and plays well — it is simply smaller than the
full release. Final is mostly **filling in content using systems that already exist** and doing
the unglamorous work of actually shipping a commercial product.

The risk here is not technical. It is that the last 20% is boring, and boring work is what
stalls projects that are nearly done.

---

## What final contains

### Content completion · 10%

- **Remaining levels**, bringing the total to 12–15.
- **The towers and enemies held back from the demo**, now revealed.

Levels are cheaper here than they sound — the systems exist, so this is design and layout rather
than engineering.

### Full-game balance · 4%

Harder than it sounds, and worth protecting time for.

The economy grants permanent upgrades that carry across every level, so a player arriving at
level 12 is vastly stronger than one at level 3. Early levels stop being content and become
farms. Every level has to be tuned against an *assumed upgrade level*, not against a fresh save,
and getting that curve wrong is the difference between a satisfying grind and a pointless one.

This is the single most important quality item in the stage.

### Steam release features · 2%

- Achievements.
- Cloud saves.

### Store assets · 2%

- Trailer, capsule art, screenshots.

These are **additional commissions** beyond in-game art and need their own slot in the artist's
schedule. Book them early — a trailer needed in launch week and requested in launch week does
not exist.

### Settings and accessibility · 1%

- Resolution and fullscreen, audio sliders, keybinds.
- Colourblind considerations and a reduced-motion option.

### Final polish · 1%

Visual and audio juice — impact feedback, screen shake, transitions. The difference between a
game that works and one that feels good.

### Release engineering and housekeeping · <1%

- Export pipeline, testing on clean machines, minimum-spec validation — especially of the horde
  renderer, which is the most hardware-sensitive part of the game.
- The standing known-issues list in `CLAUDE.md`.
- Credits, plus asset and font licences.

### Launch bug-fix pass · <1%

Demo feedback turned into fixes. Reserve real time for this; it is not optional and it always
takes longer than planned.

---

## Exit criteria

A build that can be sold without embarrassment.

---

## One honest note on the whole plan

Three commitments sit underneath this roadmap: **an engine rewrite** for massive battles, **a
paid art commission**, and **12–15 levels** of content. Each is individually reasonable. Together
they are ambitious for a solo project, and they fail in different ways — the rewrite fails
technically, the commission fails on someone else's schedule, the content fails through
attrition.

The roadmap is built so none of them is fatal on its own:

- The engine rewrite is **timeboxed with the current engine kept as a fallback** — worst case,
  the game has smaller battles.
- The art commission is **briefed during alpha**, so slippage eats into schedule rather than
  blocking a release.
- Content is **back-loaded into final**, where the systems are proven and levels are the
  cheapest thing to add.

If something has to give, give on scale first, content second, and art last — because art is
what sells a demo, and the demo is what sells the game.
