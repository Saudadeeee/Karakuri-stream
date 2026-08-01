extends SceneTree

## Wires the hand-drawn pixel font (tools/font/gen_font.lua, rendered by
## Aseprite) into this branch's EXISTING theme without regenerating it — the
## styleboxes stay exactly as authored; only the face changes.
##
##   godot --headless --path . --script tools/apply_pixel_font.gd
##
## Baloo2 stays as the project-wide custom_font because TextMesh (the 3D
## wordmark) needs vector outlines a bitmap font cannot provide — and it rides
## along as the per-glyph fallback for anything the small-caps pixel set lacks.

const PIXEL_SRC := "res://assets/fonts/pixel/karakuri_pop.fnt"
const PIXEL_OUT := "res://assets/fonts/pixel/karakuri_pop.tres"
const FALLBACK := "res://assets/fonts/Baloo2.ttf"
const THEME := "res://ui/karakuri_theme.tres"

func _init() -> void:
	var base: FontFile = load(PIXEL_SRC)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.fallbacks = [load(FALLBACK)]
	# Prove the bitmap actually loaded (an import failure would silently fall
	# back to Baloo2 and nobody would notice the pixel font is missing).
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
