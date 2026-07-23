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
		{"name": "Gỗ", "color": "#D4A373"},
		{"name": "Đất", "color": "#8B5E3C"},
		{"name": "Rêu", "color": "#8CB369"},
		{"name": "Đá", "color": "#BDBDBD"},
	],
	BlockData.Type.WATER: [
		{"name": "Nước ngọc", "color": "#48CAE4"},
		{"name": "Nước hồng", "color": "#F49CC4"},
		{"name": "Nước tím", "color": "#B39DE0"},
		{"name": "Nước bạc hà", "color": "#7BE0C0"},
	],
	BlockData.Type.JELLY: [
		{"name": "Jelly xanh", "color": "#48CAE4"},
		{"name": "Jelly hồng", "color": "#F49CC4"},
		{"name": "Jelly vàng", "color": "#F2D06B"},
		{"name": "Jelly tím", "color": "#B39DE0"},
	],
	BlockData.Type.PIPE: [
		{"name": "Ống kín", "open": false},
		{"name": "Ống hở", "open": true},
	],
	BlockData.Type.GEAR: [
		{"name": "Bánh răng", "model": "gear"},
		{"name": "Cối xay", "model": "mill"},
	],
	BlockData.Type.BELL: [{"name": "Chuông"}],
	BlockData.Type.SOURCE: [{"name": "Vòi tre"}],
	BlockData.Type.PIPE_BEND: [{"name": "Ống cong"}],
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
