class_name BlockData
extends RefCounted

enum Type { WOOD, WATER, GEAR, BELL }

var type: Type
var state: Dictionary = {}
var node: Node3D

func _init(p_type: Type, p_node: Node3D = null) -> void:
	type = p_type
	node = p_node
