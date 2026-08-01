extends SceneTree

## Wires the pixel font (tools/font/gen_font.lua) into the existing theme —
## only default_font changes, the styleboxes stay as authored.
##
##   godot --headless --path . --script tools/apply_pixel_font.gd
##
## Baloo2 stays as project custom_font (TextMesh needs vector outlines) and
## as the per-glyph fallback for anything the small-caps pixel set lacks.

const PIXEL_SRC := "res://assets/fonts/pixel/karakuri_pop.fnt"
const PIXEL_OUT := "res://assets/fonts/pixel/karakuri_pop.tres"
const FALLBACK := "res://assets/fonts/Baloo2.ttf"
const THEME := "res://ui/karakuri_theme.tres"

func _init() -> void:
	var base: FontFile = load(PIXEL_SRC)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.fallbacks = [load(FALLBACK)]
	# An import failure would silently fall back to Baloo2 — verify the bitmap loaded.
	var w: float = fv.get_string_size("PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	print("pixel font check: 'PLAY'@20 = %.1f px -> %s" % [w,
		"OK" if w > 1.0 else "*** EMPTY ***"])
	var err: int = ResourceSaver.save(fv, PIXEL_OUT)
	print("pixel -> %s (%s)" % [PIXEL_OUT, "OK" if err == OK else "ERR %d" % err])

	var theme: Theme = load(THEME)
	theme.default_font = fv
	# 20 is the pixel font's native size — multiples render with no resampling.
	theme.default_font_size = 20
	if theme.has_font_size("font_size", "Label"):
		theme.set_font_size("font_size", "Label", 20)
	err = ResourceSaver.save(theme, THEME)
	print("theme -> %s (%s)" % [THEME, "OK" if err == OK else "ERR %d" % err])
	quit()
