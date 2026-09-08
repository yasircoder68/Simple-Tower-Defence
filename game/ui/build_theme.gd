extends SceneTree

## Generates ui/game_theme.tres from ui/palette.gd. Run it with:
##
##   Godot_v4.6.3-stable_win64.exe --headless --path "<repo>/game" --script res://ui/build_theme.gd
##
## THE THEME IS GENERATED, NEVER HAND-AUTHORED, for three reasons: a palette
## change becomes one command instead of forty inspector clicks; a hand-edited
## .tres is a merge-conflict magnet full of sub-resource ids nobody can review;
## and this file doubles as documentation of what each style actually is, which
## a binary-ish resource cannot be.
##
## **Never edit game_theme.tres directly.** Edit palette.gd and re-run this.
##
## WHY SceneTree AND NOT @tool: ui_plan.md specified a @tool script, which means
## running it from inside the editor. A SceneTree script runs headless from one
## shell command, which is scriptable, reviewable in CI later, and does not
## depend on the editor being open or on an EditorScript being triggered by
## hand. Same output, fewer moving parts.
##
## WHY ui/ AND NOT scripts/tools/: ui_plan.md put it under scripts/tools/, but
## this project has no scripts/ tree — the convention is colocation, and this
## file's only input and only output both live in ui/.

const Palette := preload("res://ui/palette.gd")

const OUT_PATH := "res://ui/game_theme.tres"


func _initialize() -> void:
	var theme := Theme.new()

	_apply_base(theme)
	_apply_panels(theme)
	_apply_buttons(theme)
	_apply_labels(theme)
	_apply_progress(theme)
	_apply_containers(theme)

	var err := ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		push_error("build_theme: failed to write %s (error %d)" % [OUT_PATH, err])
		print("build_theme: FAILED (%d)" % err)
	else:
		print("build_theme: wrote %s" % OUT_PATH)

	quit()


# --- Helpers ----------------------------------------------------------------

## One flat box, since every surface in this design is a flat fill plus a
## hairline. Returning a fresh instance per call matters: StyleBoxes are
## Resources, so a shared one assigned to four Button states would make all four
## states the same box the moment one was tweaked.
func _box(bg: Color, border: Color, border_width: int = Palette.BORDER_WIDTH) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(Palette.CORNER_RADIUS)
	sb.content_margin_left = Palette.PAD_X
	sb.content_margin_right = Palette.PAD_X
	sb.content_margin_top = Palette.PAD_Y
	sb.content_margin_bottom = Palette.PAD_Y
	return sb


## Registers a Label variation, so a HUD can say `theme_type_variation = "H1"`
## instead of scattering add_theme_font_size_override() calls. Variations are
## the Theme system's answer to a type scale; without them every size becomes a
## per-node override and the scale stops being enforceable.
func _label_variation(theme: Theme, name: String, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


# --- Sections ---------------------------------------------------------------

func _apply_base(theme: Theme) -> void:
	# Godot's default is 16. Dropping to 14 as the body size is what makes the
	# larger steps read as headings rather than as "slightly bigger text".
	theme.default_font_size = Palette.FONT_BODY


func _apply_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", _box(Palette.SURFACE, Palette.BORDER))
	theme.set_stylebox("panel", "PanelContainer", _box(Palette.SURFACE, Palette.BORDER))

	# A screen-filling backdrop: no border, no rounding. Used by full-screen
	# overlays (pause, menu, results) where a rounded rectangle floating over
	# the game would read as a dialog rather than as a screen.
	var backdrop := _box(Palette.BG, Palette.BG, 0)
	backdrop.set_corner_radius_all(0)
	theme.set_type_variation("Backdrop", "PanelContainer")
	theme.set_stylebox("panel", "Backdrop", backdrop)

	# A raised card: slots, tower entries, upgrade rows.
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", _box(Palette.RAISED, Palette.BORDER))


func _apply_buttons(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", _box(Palette.RAISED, Palette.BORDER))
	theme.set_stylebox("hover", "Button", _box(Palette.RAISED_HOVER, Palette.GOLD))
	theme.set_stylebox("pressed", "Button", _box(Palette.RAISED_PRESSED, Palette.GOLD))
	theme.set_stylebox("disabled", "Button", _box(Palette.DISABLED_BG, Palette.BORDER))
	# The focus ring is drawn ON TOP of the state box, so it must be fill-free
	# or it erases whichever state is underneath it.
	var focus := _box(Color(0, 0, 0, 0), Palette.FOCUS, 2)
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Palette.GOLD)
	theme.set_color("font_pressed_color", "Button", Palette.GOLD)
	theme.set_color("font_focus_color", "Button", Palette.TEXT)
	# Disabled text must stay legible. Greying it into the background is how a
	# player ends up unable to read WHAT they cannot afford.
	theme.set_color("font_disabled_color", "Button", Palette.DISABLED_TEXT)

	# A primary action per screen — Begin Defense, Resume, Play Again.
	theme.set_type_variation("ButtonPrimary", "Button")
	theme.set_stylebox("normal", "ButtonPrimary", _box(Palette.RAISED, Palette.GOLD))
	theme.set_stylebox("hover", "ButtonPrimary", _box(Palette.RAISED_HOVER, Palette.GOLD))
	theme.set_stylebox("pressed", "ButtonPrimary", _box(Palette.RAISED_PRESSED, Palette.GOLD))
	theme.set_stylebox("disabled", "ButtonPrimary", _box(Palette.DISABLED_BG, Palette.BORDER))
	theme.set_stylebox("focus", "ButtonPrimary", focus)
	theme.set_font_size("font_size", "ButtonPrimary", Palette.FONT_H2)
	theme.set_color("font_color", "ButtonPrimary", Palette.GOLD)


func _apply_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.TEXT)

	# The type scale, one variation per step. Any size not on this list is a bug.
	_label_variation(theme, "Display", Palette.FONT_DISPLAY, Palette.TEXT)
	_label_variation(theme, "H1", Palette.FONT_H1, Palette.TEXT)
	_label_variation(theme, "H2", Palette.FONT_H2, Palette.TEXT)
	_label_variation(theme, "Small", Palette.FONT_SMALL, Palette.MUTED)
	_label_variation(theme, "Muted", Palette.FONT_BODY, Palette.MUTED)

	# Semantic variations, so a readout says what it MEANS rather than carrying
	# a colour literal at the call site.
	_label_variation(theme, "Silver", Palette.FONT_BODY, Palette.SILVER)
	_label_variation(theme, "Gold", Palette.FONT_BODY, Palette.GOLD)
	_label_variation(theme, "Blood", Palette.FONT_BODY, Palette.BLOOD)
	_label_variation(theme, "Success", Palette.FONT_BODY, Palette.SUCCESS)

	# Result headlines.
	_label_variation(theme, "ResultWon", Palette.FONT_DISPLAY, Palette.SUCCESS)
	_label_variation(theme, "ResultLost", Palette.FONT_DISPLAY, Palette.BLOOD)


func _apply_progress(theme: Theme) -> void:
	var track := _box(Palette.BG, Palette.BORDER)
	track.content_margin_left = 0
	track.content_margin_right = 0
	track.content_margin_top = 0
	track.content_margin_bottom = 0
	theme.set_stylebox("background", "ProgressBar", track)

	var fill := _box(Palette.GOLD, Palette.GOLD, 0)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	theme.set_stylebox("fill", "ProgressBar", fill)


func _apply_containers(theme: Theme) -> void:
	# Consistent rhythm without a per-container override every time someone adds
	# a VBox. 6px reads as "these belong together", 12 as "these are separate".
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("separation", "HBoxContainer", 6)
