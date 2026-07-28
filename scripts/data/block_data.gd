class_name BlockData
extends RefCounted

## Houses and their whole shape system are gone on this branch: they were half
## the draw calls in a village and most of the per-click rebuild cost, and this
## build is about a garden that plays itself smoothly in a browser tab.
## New types go on the END — the integer value is what SaveManager writes to
## user://save_data.json, so reordering silently turns every saved bell into a
## drum. Append only.
enum Type { WOOD, WATER, GEAR, BELL, SOURCE, PIPE, PIPE_BEND, JELLY, SHISHI, DRUM, CHIME, MUSIC_BOX, SCOOP, STONE_LANTERN, PINWHEEL, GATE }

var type: Type
var state: Dictionary = {}
var node: Node3D

func _init(p_type: Type, p_node: Node3D = null) -> void:
	type = p_type
	node = p_node
