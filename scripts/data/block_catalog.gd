class_name BlockCatalog
extends RefCounted

## THE ONE PLACE A BLOCK IS REGISTERED.
##
## Adding a block used to mean editing five files and eight separate lists —
## scene preload, scene dictionary, hotbar order, hotbar hint, keyboard
## shortcut — and forgetting any one of them produced a block that half
## existed. Everything now comes from `ALL`; the factory, the hotbar and the
## keyboard all read it.
##
## To add a block: build `scenes/blocks/<name>_block.tscn`, then add ONE entry
## below. See docs/MAINTAIN.md for the full walkthrough.
##
##   type    the enum value from BlockData.Type (append there first — the
##           integer is what save files store, so never reorder that enum)
##   scene   the scene to instance when placed or loaded
##   hotbar  false = playable and saveable, but not offered in the palette
##           (decoration, or a legacy type kept only so old saves still load)
##   key     keyboard shortcut, or KEY_NONE for "no shortcut"
##   hint    the one line shown when hovering its hotbar icon
##
## ORDER MATTERS: hotbar entries appear in the order listed here.

const ALL: Array[Dictionary] = [
	{"type": BlockData.Type.WOOD, "hotbar": true, "key": KEY_1,
	 "scene": preload("res://scenes/blocks/wood_block.tscn"),
	 "hint": "Earth — the building block. Click again for Moss/Stone/Wood"},
	{"type": BlockData.Type.HOUSE, "hotbar": true, "key": KEY_Q,
	 "scene": preload("res://scenes/blocks/house_block.tscn"),
	 "hint": "House — stack and line them up, they merge into one building"},
	{"type": BlockData.Type.WATER, "hotbar": true, "key": KEY_2,
	 "scene": preload("res://scenes/blocks/water_block.tscn"),
	 "hint": "Still pond — powers any gear touching it"},
	{"type": BlockData.Type.SOURCE, "hotbar": true, "key": KEY_3,
	 "scene": preload("res://scenes/blocks/source_block.tscn"),
	 "hint": "Spout — pours a stream straight down"},
	{"type": BlockData.Type.PIPE, "hotbar": true, "key": KEY_4,
	 "scene": preload("res://scenes/blocks/pipe_block.tscn"),
	 "hint": "Self-connecting pipe — click again for closed/open"},
	{"type": BlockData.Type.GEAR, "hotbar": true, "key": KEY_5,
	 "scene": preload("res://scenes/blocks/gear_block.tscn"),
	 "hint": "Spins when touching water — chain them to transfer power"},
	{"type": BlockData.Type.BELL, "hotbar": true, "key": KEY_6,
	 "scene": preload("res://scenes/blocks/bell_block.tscn"),
	 "hint": "Rings when a stream hits it or a gear strikes it"},
	{"type": BlockData.Type.JELLY, "hotbar": true, "key": KEY_7,
	 "scene": preload("res://scenes/blocks/jelly_block.tscn"),
	 "hint": "Bouncy jelly — boings when water lands on it"},
	{"type": BlockData.Type.SHISHI, "hotbar": true, "key": KEY_8,
	 "scene": preload("res://scenes/blocks/shishi_block.tscn"),
	 "hint": "Fills with water, then TIPS: pours onward + knock!"},
	{"type": BlockData.Type.DRUM, "hotbar": true, "key": KEY_9,
	 "scene": preload("res://scenes/blocks/drum_block.tscn"),
	 "hint": "Drum — beaten by streams or a gear next to it"},
	{"type": BlockData.Type.CHIME, "hotbar": true, "key": KEY_0,
	 "scene": preload("res://scenes/blocks/chime_block.tscn"),
	 "hint": "Each colour is a note, shorter tube = higher — line them up = a melody"},
	{"type": BlockData.Type.MUSIC_BOX, "hotbar": true, "key": KEY_MINUS,
	 "scene": preload("res://scenes/blocks/music_box_block.tscn"),
	 "hint": "Put beside a SPINNING gear → plays a tune"},
	{"type": BlockData.Type.SCOOP, "hotbar": true, "key": KEY_EQUAL,
	 "scene": preload("res://scenes/blocks/scoop_block.tscn"),
	 "hint": "Beside a POND + spinning gear → ladles a new stream"},
	{"type": BlockData.Type.GATE, "hotbar": true, "key": KEY_G,
	 "scene": preload("res://scenes/blocks/gate_block.tscn"),
	 "hint": "Sluice gate — CLICK it in the world to open/close the flow"},

	# Off the palette: still placeable by save/load and by the starter garden,
	# just not offered to the player. Decoration with no mechanic, and one
	# legacy pipe kept so old save files still open.
	{"type": BlockData.Type.STONE_LANTERN, "hotbar": false, "key": KEY_NONE,
	 "scene": preload("res://scenes/blocks/stone_lantern_block.tscn"),
	 "hint": "Glowing lantern — prettiest on the Night map"},
	{"type": BlockData.Type.PINWHEEL, "hotbar": false, "key": KEY_NONE,
	 "scene": preload("res://scenes/blocks/pinwheel_block.tscn"),
	 "hint": "Pinwheel — spins when a stream hits it"},
	{"type": BlockData.Type.PIPE_BEND, "hotbar": false, "key": KEY_NONE,
	 "scene": preload("res://scenes/blocks/pipe_bend_block.tscn"),
	 "hint": "Legacy elbow pipe — the plain pipe bends itself now"},
]

static var _by_type: Dictionary = {}

static func entry(type: int) -> Dictionary:
	if _by_type.is_empty():
		for e in ALL:
			_by_type[int(e["type"])] = e
	return _by_type.get(int(type), {})

## The hotbar's contents, in listed order.
static func palette_types() -> Array:
	var out: Array = []
	for e in ALL:
		if bool(e.get("hotbar", false)):
			out.append(e["type"])
	return out

static func hint(type: int) -> String:
	return String(entry(type).get("hint", ""))

## The type a keycode selects, or -1 for a key that isn't a shortcut.
static func type_for_key(keycode: int) -> int:
	if keycode == KEY_NONE:
		return -1
	for e in ALL:
		if int(e.get("key", KEY_NONE)) == keycode:
			return int(e["type"])
	return -1
