# Tower Removal & Moving — Implementation Work Order

**Status: implemented and verified.** See `CLAUDE.md`'s Round lifecycle section for the shipped
design. Two things landed beyond what's specified below, both real fixes found during
implementation, not scope creep:

1. `finish_move()`/`cancel_move()` are self-contained — they clear `dragging_type` and hide the
   ghost themselves, rather than leaving that to each caller as originally sketched here. A
   direct-call test that invoked `cancel_move()` without following up caught this: the caller
   contract was easy to get wrong, and getting it wrong for a real call site (not just a test)
   would leave a real player stuck mid-drag.
2. `input_simulate`'s mouse `position`/`world_position` coordinate modes did not reliably drive
   `get_global_mouse_position()` in this environment — verification of the drag-to-a-specific-cell
   path used direct calls to `begin_move()`/`finish_move()`/`cancel_move()` (which exercise the
   real logic) plus `click_node` for the Start/Play Again/Upgrade buttons (which exercises real
   dispatch) instead. See CLAUDE.md's Gotchas section before attempting to calibrate this further.

**Scope:** `map1.gd`, `round_ui.gd`, `CLAUDE.md`. No new scenes, no new autoloads, no save-format
change — all held.

Read [CLAUDE.md](CLAUDE.md) first — especially *Round lifecycle*, *Economy*, and *Known issues*.
This document assumes that context and only covers what's new.

---

## Why this exists

Towers now persist between rounds (a deliberate change — see CLAUDE.md's Round lifecycle). That
created a gap: **there is currently no way to remove a tower.** A misplaced tower permanently
occupies one of your `PlayerData.slot_count` slots (default 4) with no recourse short of
restarting the app. Before persistence, a bad placement self-corrected next round.

So removal isn't a nice-to-have; it's the missing half of the change that was already made.
Moving is the same machinery with one extra step, which is why both are in one work order.

---

## Decisions already made — do not re-litigate

**1. Removal refunds nothing, because placement costs nothing.**
Towers are free to place. The constraint is `slot_count` (bought with gold), not currency.
Removing a tower frees a slot; that *is* the refund. Do **not** add a silver refund, a sell
price, or a percentage return. `implementation_plan.md` §2.3 once described a "sell tower for
60% refund" — that section is already marked `[REWRITTEN]` and that mechanic is gone. Don't
resurrect it from tower-defense muscle memory.

**2. Moving repositions the existing node. It does not destroy and recreate.**
Destroy+recreate would also work (towers hold no per-instance state — all stats come from
`TowerStats`), but repositioning is chosen because **a bug in the restore path cannot lose a
tower.** Given the whole point of this work is tower durability, that failure mode is
unacceptable. Reposition, and cancel/invalid-drop become trivially correct.

**3. Both operations are `PRE_ROUND` only**, same rule as placement and upgrades.

**4. Moving is free and unlimited** during `PRE_ROUND`. No cooldown, no cost.

---

## Data model change (do this first)

Today there are **two** parallel collections tracking the same towers:

```gdscript
var occupied_cells: Dictionary = {}  # Vector2i -> bool
var placed_towers: Array = []        # tower nodes
```

Removal and moving have to update both on every operation, and any desync between them is a
silent bug (a ghost-occupied cell you can never build on, or a slot leak). **Collapse them into
one:**

```gdscript
## Vector2i cell -> tower Node2D. Single source of truth for what is placed and
## where. Replaces the old occupied_cells + placed_towers pair — two collections
## tracking one fact desynced too easily once towers became editable.
var towers_by_cell: Dictionary = {}
```

Then:

| Old | New |
|---|---|
| `occupied_cells.has(cell)` | `towers_by_cell.has(cell)` |
| `placed_towers.size()` | `towers_by_cell.size()` |
| `placed_towers.append(tower)` + `occupied_cells[cell] = true` | `towers_by_cell[cell] = tower` |
| `for tower in placed_towers` (in `_clear_placed_towers`) | `for tower in towers_by_cell.values()` |

Call sites to update: `map1.gd` lines ~25, ~59, ~243–248 (`_clear_placed_towers`), ~288, ~294,
~313, ~315. `round_ui.gd` does **not** reference either collection. `CLAUDE.md`'s state-boundary
table names `map1.placed_towers` — update that row too.

Keep `_clear_placed_towers()`. It's unused today but is the documented hook for an in-place map
change that doesn't reload the scene.

---

## Input model

`_input()` currently early-returns when `dragging_type == ""`, so nothing happens on a click
unless a drag is already in flight. That guard has to go, replaced with explicit branching.

| Input | Condition | Behaviour |
|---|---|---|
| **LMB press** | not dragging, cursor over an occupied cell | **Pick up** that tower — begin a move |
| **LMB release** | dragging | Drop: place if valid, else restore/cancel |
| **RMB release** | dragging | Cancel — restore a picked-up tower to its origin cell |
| **RMB release** | not dragging, cursor over an occupied cell | **Remove** that tower |
| anything | `round_state != PRE_ROUND` | Ignore entirely |

This deliberately reuses the existing sidebar drag pipeline: the sidebar's `button_down` →
`_on_start_drag()` → ghost-follows-mouse → LMB-release-to-place flow is already
press-somewhere/release-elsewhere. Picking up a placed tower just enters that same pipeline from
a different starting point.

Press-and-release on the same cell picks up and re-drops in place — a harmless no-op. That's
acceptable; don't add special-casing for it.

---

## New state on `map1.gd`

```gdscript
## The tower currently being moved, or null. Non-null only between pick-up and
## drop/cancel. While set, the node is hidden and its origin cell is free, so the
## ghost previews correctly and the origin reads as a valid drop target.
var moving_tower: Node2D = null
## Cell the in-flight tower came from, so cancel and invalid drops can restore it.
var moving_from_cell = null  # Vector2i or null
```

---

## Implementation steps

### 1. `_cell_at(world_pos) -> Vector2i`
Extract the repeated `tile_map.local_to_map(tile_map.to_local(world_pos))` into one helper.
`is_valid_placement()`, `place_tower()`, and all the new functions need it.

### 2. `remove_tower(cell) -> bool`
- Guard: `round_state != PRE_ROUND` → return false.
- Guard: `not towers_by_cell.has(cell)` → return false.
- `towers_by_cell[cell].queue_free()`, then `towers_by_cell.erase(cell)`.
- Return true.

Erase from the dict in the same call — `queue_free()` is deferred, so the node is still valid
this frame and would otherwise be handed out by a lookup.

### 3. `begin_move(cell) -> bool`
- Guards: `PRE_ROUND`, cell occupied, and `moving_tower == null`.
- `moving_tower = towers_by_cell[cell]`, `moving_from_cell = cell`.
- `towers_by_cell.erase(cell)` — frees the origin so it previews as a valid drop target.
- `moving_tower.hide()` — otherwise the real tower and the ghost both render, which reads as
  two towers.
- `dragging_type = <the tower's type>`, `ghost.set_tower(that type)`.

**Determining the type:** `archer_tower.tscn` and `wizard_tower.tscn` produce different node
structures. Don't string-match node names — they're auto-generated (`@Node2D@10`). Instead have
each tower expose its type. The unit scripts already declare `const TOWER_TYPE`; add a
`tower_type` to the *tower root* (`archer_tower.gd`), and give `wizard_tower.tscn` a tiny script
so it can declare one too — **or**, simpler and preferred, record it at placement:

```gdscript
towers_by_cell[cell] = tower
tower.set_meta("tower_type", type)   # in place_tower()
```
then read `moving_tower.get_meta("tower_type")`. One line, no new scripts, no scene changes.

### 4. `finish_move(cell) -> void` and `cancel_move() -> void`
- **finish:** `moving_tower.global_position = <cell centre>`, `towers_by_cell[cell] =
  moving_tower`, `moving_tower.show()`, clear both move vars.
- **cancel:** `towers_by_cell[moving_from_cell] = moving_tower`, `moving_tower.show()`, clear
  both move vars. The node never moved, so there's nothing to undo.

### 5. Slot accounting — **this is the trap**

`is_valid_placement()` rejects when `towers_by_cell.size() >= PlayerData.slot_count`. During a
move the tower is out of the dict, so the count is one *lower* — that direction is safe.

But if you chose destroy+recreate instead, or if you ever keep the moving tower in the dict, the
count reads full and **every drop is rejected, silently, with the ghost showing red**. Whoever
debugs that will lose an hour. With the design above it's already correct; just don't "fix" the
count by adding the moving tower back early.

### 6. Round start must resolve an in-flight move

`_start_round()` sets `dragging_type = ""` and hides the ghost. If a move is in flight when the
player clicks Start, the picked-up tower is left **hidden and untracked** — invisible, occupying
no cell, unreachable. Add to the top of `_start_round()`:

```gdscript
if moving_tower != null:
    cancel_move()
```

### 7. `round_ui.gd` — discoverability

Nothing tells the player these controls exist. Add one hint `Label` near the status readout:

```
Pre-round: drag a tower to move it · right-click to remove
```

Keep it crude and unstyled like the rest of `round_ui.gd` — it's thrown away at UI-0/UI-1.
Optionally grey it while `round_state != PRE_ROUND`.

---

## Edge cases that must work

1. Remove a tower at the slot cap → a new placement immediately becomes possible.
2. Move a tower while at the slot cap → succeeds (a move must not need a free slot).
3. Cancel a move with RMB → tower reappears at its **origin** cell, still functional.
4. Drop on an invalid cell (wall-less, occupied, off-map) → tower restored to origin, **not
   destroyed and not left floating**.
5. Drop on the origin cell → no-op success.
6. Click Start mid-move → move cancelled, tower restored, round starts clean (step 6 above).
7. Remove or move attempted during `IN_ROUND` / `ROUND_WON` / `ROUND_LOST` → rejected.
8. A moved tower still fires next round, with **current** upgrade stats — it keeps `tower_unit`
   group membership because the node survives, so `_start_round()`'s
   `call_group("tower_unit", "refresh_stats")` still reaches it.
9. After any sequence of removes/moves, `towers_by_cell.size()` equals the number of visible
   towers. No orphans, no leaked cells.

---

## Test checklist

Verify **in the running game via MCP**, not by reading the code. Two lessons from this project,
both learned the hard way:

- **A passing unit test is not integration.** `PlayerData.save_data()` was fully tested and
  worked, but nothing in the game called it — all progress was lost on quit and the tests
  didn't notice, because they called it by hand.
- **`input_simulate`'s `click_node` emits `pressed` directly and bypasses a Button's `disabled`
  flag.** A disabled button will still run its handler under that tool. Test guards by checking
  state after the forced action, not by trusting the widget.

Concretely:

| Check | How |
|---|---|
| Remove frees a slot | Place to cap → `is_valid_placement()` false → remove one → true |
| Move keeps count | `towers_by_cell.size()` identical before and after a completed move |
| Cancel restores | Pick up, RMB, assert tower at origin cell and `visible == true` |
| Invalid drop restores | Pick up, drop on a non-wall cell, assert same |
| Round gating | Start a round, attempt remove/move via direct call, assert nothing changed |
| Stats after move | Move a tower, buy an upgrade, start round, assert its `damage` reflects the upgrade |
| No orphans | After ~10 mixed operations, `towers_by_cell.size()` == on-screen tower count |
| Start mid-move | Pick up, click Start, assert tower visible and round in `IN_ROUND` |

Finish with `lsp_project_diagnostics` (expect 17/17 clean) and a screenshot of a completed
move.

---

## Files touched

| File | Change |
|---|---|
| `game/scripts/map1.gd` | Data-model collapse, `_cell_at()`, `remove_tower()`, `begin_move()`/`finish_move()`/`cancel_move()`, `_input()` rewrite, `_start_round()` guard, `set_meta` in `place_tower()` |
| `game/scripts/round_ui.gd` | Hint label |
| `CLAUDE.md` | State-boundary row (`placed_towers` → `towers_by_cell`), a Round-lifecycle note on the new controls and the slot-accounting trap |

**Not touched:** `PlayerData` (towers aren't saved — they live in the scene, so a map change or
app restart clears them, which is intended), `TowerStats`, any `.tscn`, any autoload
registration.

---

## Out of scope

- Selling for currency (see Decision 1)
- Undo/redo history
- Multi-select or drag-select
- Moving during a round
- Any styling beyond the one hint label — UI work is UI-0/UI-4 in `ui_plan.md`
