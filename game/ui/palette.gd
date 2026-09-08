extends RefCounted

## THE ENTIRE RESKIN SURFACE. Every colour in the game's interface resolves from
## this file, so changing the look is editing these constants and re-running the
## generator — not forty inspector clicks across a dozen scenes.
##
## Not an autoload and not a class_name: it holds constants and reads nothing, so
## it is preloaded exactly like systems/enemy_types.gd, which is the established
## precedent here for a numbers-only registry. (class_name would also work, but
## it is invisible to consumers until the editor rescans — a documented gotcha
## this file does not need to inherit.)
##
## Consumed by ui/build_theme.gd. UI scripts should read the generated Theme
## rather than these constants directly; reach in here only for something a
## Theme cannot express, such as a colour passed to _draw().
##
## THE AESTHETIC IS DELIBERATELY A PARAMETER, NOT AN ARCHITECTURE. ui_plan.md
## leaves the restrained-dark-fantasy vs procedural-parchment question open and
## says to decide after seeing UI-0 on screen. This is the restrained option; if
## it reads wrong, the answer is different values here, not different code.

# --- Ground tones -----------------------------------------------------------
#
# Neutrals are biased WARM toward the gold rather than sitting on pure grey, and
# the darkest tone is never pure black. Both choices are what stop a zero-asset
# UI reading as "programmer default" — pure #000 and pure #808080 are the two
# most recognisable tells.

## Deepest ground. Behind everything.
const BG := Color("#14110f")
## Panels and screens that sit on BG.
const SURFACE := Color("#1e1a17")
## Anything that should read as lifted off the surface: buttons, cards, slots.
const RAISED := Color("#2a2420")
## Hairline separation. Low contrast on purpose — borders that shout make a
## dark UI look like a spreadsheet.
const BORDER := Color("#3a322b")

# --- Interactive states -----------------------------------------------------
#
# Explicit constants rather than RAISED.lightened(0.1) at each call site, so the
# hover and pressed steps can be tuned independently of the resting colour. A
# pressed control going DARKER than its resting state is what makes a click feel
# like a press rather than a flash.

const RAISED_HOVER := Color("#372f2a")
const RAISED_PRESSED := Color("#1a1613")
const DISABLED_BG := Color("#1a1714")
const DISABLED_TEXT := Color("#5c554c")
## Focus ring. Keyboard and controller navigation are invisible without it, and
## it is the single most-skipped accessibility affordance in game UI.
const FOCUS := Color("#c9a227")

## Scrim behind a modal overlay: BG at ~82% alpha. Dimming the game rather than
## hiding it is what makes a pause screen read as "on top of" rather than "instead
## of" — the player keeps their spatial context.
##
## Not in the Theme, because a Theme styles Controls by type and this is one
## specific node's colour. Set from here in code.
const SCRIM := Color("#14110fd1")

# --- Semantic colours -------------------------------------------------------
#
# Named for MEANING, not for hue. A later palette could make SILVER warm or
# BLOOD purple without any consumer becoming a lie.

## Gold currency, and the general accent: trim, headings, focus.
const GOLD := Color("#c9a227")
## Silver currency. The game has TWO currencies and silver is the one the player
## actually watches tick up, so it needs a colour of its own — ui_plan.md's
## original palette predates the silver/gold split and had only one.
const SILVER := Color("#b9c2c9")
## Damage, lives lost, loss states.
const BLOOD := Color("#b8453f")
## Round won, upgrade affordable, anything affirmative. Desaturated on purpose:
## a saturated green in a warm dark palette reads as a system notification.
const SUCCESS := Color("#7a9a5b")

# --- Text -------------------------------------------------------------------

## Body text. Warm off-white — pure white on a warm dark ground looks blue.
const TEXT := Color("#e6ddd0")
## Secondary text: hints, costs, units, anything supporting.
const MUTED := Color("#9a8f80")

# --- Type scale -------------------------------------------------------------
#
# Five steps, no in-between values. A scale is only worth having if it is
# obeyed; "just this once at 16" is how a project ends up with eleven sizes and
# no hierarchy.

const FONT_DISPLAY := 32
const FONT_H1 := 24
const FONT_H2 := 18
const FONT_BODY := 14
const FONT_SMALL := 11

# --- Metrics ----------------------------------------------------------------

const CORNER_RADIUS := 3
const BORDER_WIDTH := 1
const PAD_X := 12
const PAD_Y := 7
