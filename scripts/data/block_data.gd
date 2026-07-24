class_name BlockData
extends RefCounted

enum Type { WOOD, WATER, GEAR, BELL, SOURCE, PIPE, PIPE_BEND, JELLY, SHISHI, DRUM, CHIME, MUSIC_BOX, SCOOP, STONE_LANTERN, PINWHEEL }

var type: Type
var state: Dictionary = {}
var node: Node3D

func _init(p_type: Type, p_node: Node3D = null) -> void:
	type = p_type
	node = p_node
