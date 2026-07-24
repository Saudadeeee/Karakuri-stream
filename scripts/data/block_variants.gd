class_name BlockVariants
extends RefCounted

## Every block type can have several VARIANTS the player cycles through when the
## material is selected (click the icon again to advance). A variant is a small
## dictionary describing how that block looks:
##   color : hex  → tints isosurface blocks (wood/water) and model blocks (jelly)
##   model : name → swaps the glb for model blocks (gear vs mill)
##   open  : bool → pipe with an open top so the water is visible flowing through
## The chosen variant index lives in BlockData.state["variant"] and is saved.

const V: Dictionary = {
	BlockData.Type.WOOD: [
		{"name": "Wood", "color": "#D4A373"},
		{"name": "Dirt", "color": "#8B5E3C"},
		{"name": "Moss", "color": "#8CB369"},
		{"name": "Stone", "color": "#BDBDBD"},
	],
	BlockData.Type.WATER: [
		{"name": "Teal water", "color": "#48CAE4"},
		{"name": "Pink water", "color": "#F49CC4"},
		{"name": "Lilac water", "color": "#B39DE0"},
		{"name": "Mint water", "color": "#7BE0C0"},
	],
	BlockData.Type.JELLY: [
		{"name": "Cyan jelly", "color": "#48CAE4"},
		{"name": "Pink jelly", "color": "#F49CC4"},
		{"name": "Sunny jelly", "color": "#F2D06B"},
		{"name": "Lilac jelly", "color": "#B39DE0"},
	],
	BlockData.Type.PIPE: [
		{"name": "Closed pipe", "open": false},
		{"name": "Open pipe", "open": true},
	],
	BlockData.Type.GEAR: [
		{"name": "Gear", "model": "gear"},
		{"name": "Water mill", "model": "mill"},
	],
	BlockData.Type.BELL: [{"name": "Bell"}],
	# Spout TEMPO variants — the rhythm section. tempo multiplies the base beat
	# (0.55s): steady = every beat, slow = half-time, quick = double-time. All
	# spouts snap to one shared beat grid, so machines stay in time with each
	# other and layered tempos become real polyrhythm. Leaf tint marks the pace.
	BlockData.Type.SOURCE: [
		{"name": "Spout — steady", "tempo": 1.0, "color": "#A7C957"},
		{"name": "Spout — slow", "tempo": 2.0, "color": "#7BAFD4"},
		{"name": "Spout — quick", "tempo": 0.5, "color": "#E07A5F"},
	],
	BlockData.Type.PIPE_BEND: [{"name": "Bend pipe"}],
	# Phong linh: each variant is a FIXED pentatonic note (C D E G A) so a row
	# of chimes becomes a playable melody. note = index into PENTATONIC_RATIOS.
	# Saturated, clearly-separated note colours — pastel versions washed out to
	# near-white under the game sun, losing the "read the melody by colour" idea.
	BlockData.Type.CHIME: [
		{"name": "Chime C", "note": 0, "color": "#2FA89A"},
		{"name": "Chime D", "note": 1, "color": "#3E7EC6"},
		{"name": "Chime E", "note": 2, "color": "#7C5BBF"},
		{"name": "Chime G", "note": 3, "color": "#D14E8A"},
		{"name": "Chime A", "note": 4, "color": "#E08A2E"},
	],
	BlockData.Type.SHISHI: [{"name": "Shishi-odoshi"}],
	BlockData.Type.STONE_LANTERN: [{"name": "Stone lantern"}],
	BlockData.Type.PINWHEEL: [
		{"name": "Pink pinwheel", "color": "#F49CC4"},
		{"name": "Orange pinwheel", "color": "#F2A65E"},
		{"name": "Blue pinwheel", "color": "#7BD1E8"},
	],
	BlockData.Type.DRUM: [{"name": "Wooden drum"}],
	BlockData.Type.MUSIC_BOX: [{"name": "Music box"}],
	BlockData.Type.SCOOP: [{"name": "Water scoop"}],
}

static func list_for(type: int) -> Array:
	return V.get(type, [{}])

static func count(type: int) -> int:
	return list_for(type).size()

static func get_variant(type: int, index: int) -> Dictionary:
	var l: Array = list_for(type)
	return l[index % l.size()] if not l.is_empty() else {}

## Convenience: the display colour of a variant, or a fallback per base type.
static func color_of(type: int, index: int) -> Color:
	var v: Dictionary = get_variant(type, index)
	if v.has("color"):
		return Color(v["color"])
	return Color("#D4A373")
