extends SceneTree

## Regenerates ui/karakuri_theme.tres. The theme is a committed .tres so the
## editor and the game just load it, but it is GENERATED — hand-editing 200 lines
## of StyleBox resource is how the four button states drift apart.
##
##   godot --headless --path . --script tools/gen_theme.gd
##
## Design brief: soft rubber toy. Big corner radii, thick warm borders, and a
## chunky offset drop shadow that COLLAPSES on press so the button reads as
## physically sinking. The four states differ only in fill, border and shadow —
## never in content margins, because changing those would reflow the text and
## make the button jitter as you hover it.

const OUT := "res://ui/karakuri_theme.tres"
const FONT_SRC := "res://assets/fonts/Fredoka.ttf"
const FONT_OUT := "res://assets/fonts/fredoka_chunky.tres"
const WEIGHT := 600     # SemiBold: bubbly without turning into a blob
## The hand-drawn pixel font (tools/font/gen_font.lua, rendered by Aseprite).
## It becomes the THEME font for all 2D UI; Fredoka stays as the project-wide
## custom_font because TextMesh (the 3D wordmark) needs vector outlines a
## bitmap font cannot provide, and as the per-glyph fallback for anything the
## small-caps pixel set lacks.
const PIXEL_SRC := "res://assets/fonts/pixel/karakuri_pop.fnt"
const PIXEL_OUT := "res://assets/fonts/pixel/karakuri_pop.tres"

## Fredoka is a VARIABLE font, and Godot instantiates a variable font at its
## default axis position — which for Fredoka is Light. Pointing the project at
## the .ttf directly therefore gives thin, wiry letters: the exact opposite of
## why we chose it. A FontVariation pins the weight axis instead.
##
## The axis key is an OpenType TAG as an INTEGER, not the string "wght". Writing
## the string into a .tres is silently ignored — it parses fine and changes
## nothing, which is a very easy way to think you fixed this and ship Light.
func _make_font() -> FontVariation:
	var base: FontFile = load(FONT_SRC)
	var fv := FontVariation.new()
	fv.base_font = base
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("weight")
	fv.variation_opentype = {tag: WEIGHT}
	# Prove the axis actually moved rather than trusting it: a heavier weight is
	# measurably wider. If these come out equal, the variation did not apply.
	var light := FontVariation.new()
	light.base_font = base
	light.variation_opentype = {tag: 300}
	var sample := "Settings"
	var w_light: float = light.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var w_bold: float = fv.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	print("font weight check: light=%.2f  w%d=%.2f  -> %s" % [w_light, WEIGHT, w_bold,
		"APPLIED" if w_bold > w_light + 0.5 else "*** NOT APPLIED ***"])
	var err: int = ResourceSaver.save(fv, FONT_OUT)
	print("font  -> %s (%s)" % [FONT_OUT, "OK" if err == OK else "ERR %d" % err])
	return fv

func _make_pixel_font(fredoka: FontVariation) -> FontVariation:
	var base: FontFile = load(PIXEL_SRC)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.fallbacks = [fredoka]
	# Prove the bitmap actually loaded (an import failure would silently fall
	# back to Fredoka and nobody would notice the pixel font is missing).
	var w: float = fv.get_string_size("PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	print("pixel font check: 'PLAY'@20 = %.1f px -> %s" % [w,
		"OK" if w > 1.0 else "*** EMPTY ***"])
	var err: int = ResourceSaver.save(fv, PIXEL_OUT)
	print("pixel -> %s (%s)" % [PIXEL_OUT, "OK" if err == OK else "ERR %d" % err])
	return fv

const CREAM := Color("f4efe2")
const PAPER := Color("eae5da")
const INK := Color("4a3f35")
const WOOD := Color("d9b48a")
const WOOD_EDGE := Color("a97c4e")
const SALMON := Color("e07a5f")
const BAMBOO := Color("8cb369")

const RADIUS := 20
const BORDER := 3
const SHADOW := Color(0.35, 0.25, 0.18, 0.28)

func _init() -> void:
	var font := _make_font()
	var pixel := _make_pixel_font(font)
	var theme := Theme.new()
	# 20 is the pixel font's native size — every multiple-of-native size renders
	# with no resampling at all.
	theme.default_font_size = 20
	theme.default_font = pixel

	# --- Button: the star. Four states, same box, different skin. ---
	theme.set_stylebox("normal", "Button", _button(WOOD, WOOD_EDGE, 7, Vector2(0, 5)))
	theme.set_stylebox("hover", "Button", _button(WOOD.lightened(0.1), WOOD_EDGE, 9, Vector2(0, 6)))
	# Pressed: shadow almost gone and pulled under the button — with the squash
	# tween in CuteButton this is what sells "it went down".
	theme.set_stylebox("pressed", "Button", _button(WOOD.darkened(0.1), WOOD_EDGE.darkened(0.1), 2, Vector2(0, 1)))
	theme.set_stylebox("disabled", "Button", _button(PAPER, WOOD_EDGE.lightened(0.35), 0, Vector2.ZERO))
	# Focus ring in bamboo, so keyboard focus is visible without a blue system box.
	var focus := _button(Color(0, 0, 0, 0), BAMBOO, 0, Vector2.ZERO)
	focus.border_width_left = 3
	focus.border_width_top = 3
	focus.border_width_right = 3
	focus.border_width_bottom = 3
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK.darkened(0.15))
	theme.set_color("font_pressed_color", "Button", CREAM)
	theme.set_color("font_disabled_color", "Button", INK.lightened(0.55))
	theme.set_font_size("font_size", "Button", 20)

	# --- Panels: soft paper cards ---
	theme.set_stylebox("panel", "Panel", _panel(CREAM))
	theme.set_stylebox("panel", "PanelContainer", _panel(CREAM))
	theme.set_stylebox("panel", "Window", _panel(CREAM))
	theme.set_stylebox("embedded_border", "Window", _panel(CREAM.darkened(0.05)))
	theme.set_color("title_color", "Window", INK)

	theme.set_color("font_color", "Label", INK)
	theme.set_font_size("font_size", "Label", 20)

	# --- Sliders: bamboo rail, round salmon grabber ---
	var rail := StyleBoxFlat.new()
	rail.bg_color = PAPER.darkened(0.08)
	rail.set_corner_radius_all(8)
	rail.content_margin_top = 7.0
	rail.content_margin_bottom = 7.0
	theme.set_stylebox("slider", "HSlider", rail)
	var filled := StyleBoxFlat.new()
	filled.bg_color = BAMBOO
	filled.set_corner_radius_all(8)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	var filled_hi: StyleBoxFlat = filled.duplicate()
	filled_hi.bg_color = BAMBOO.lightened(0.12)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled_hi)
	theme.set_icon("grabber", "HSlider", _knob(SALMON, 11))
	theme.set_icon("grabber_highlight", "HSlider", _knob(SALMON.lightened(0.14), 12))

	var err: int = ResourceSaver.save(theme, OUT)
	print("theme -> %s (%s)" % [OUT, "OK" if err == OK else "ERR %d" % err])
	quit()

func _button(fill: Color, edge: Color, shadow_size: int, shadow_offset: Vector2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(BORDER)
	s.set_corner_radius_all(RADIUS)
	s.corner_detail = 10          # smooth curve at this radius, not a faceted arc
	s.shadow_color = SHADOW
	s.shadow_size = shadow_size
	s.shadow_offset = shadow_offset
	# Identical on every state ON PURPOSE: differing margins reflow the label and
	# the text visibly jumps as the mouse crosses the button.
	s.content_margin_left = 22.0
	s.content_margin_right = 22.0
	s.content_margin_top = 12.0
	s.content_margin_bottom = 12.0
	return s

func _panel(fill: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = WOOD_EDGE.lightened(0.3)
	s.set_border_width_all(2)
	s.set_corner_radius_all(22)
	s.corner_detail = 10
	s.shadow_color = SHADOW
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 20.0
	s.content_margin_right = 20.0
	s.content_margin_top = 16.0
	s.content_margin_bottom = 16.0
	return s

## Round slider knob, drawn once into a texture (an antialiased disc is cheaper
## as an image than as a StyleBox the slider re-renders every frame).
func _knob(col: Color, r: int) -> ImageTexture:
	var size: int = r * 2 + 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a: float = clampf(float(r) - d + 0.5, 0.0, 1.0)
			if a <= 0.0:
				continue
			var edge: bool = d > float(r) - 2.5
			var px: Color = col.darkened(0.22) if edge else col
			img.set_pixel(x, y, Color(px.r, px.g, px.b, a))
	return ImageTexture.create_from_image(img)
