class_name BlockFactory
extends RefCounted

## Shared by PlacementController (click-to-place) and SaveManager (load from
## file) so there's exactly one place that knows how to turn a BlockData.Type
## into a real scene instance — adding a new block type only means touching
## SCENES_BY_TYPE here, not both callers.

const WOOD_SCENE: PackedScene = preload("res://scenes/blocks/wood_block.tscn")
const WATER_SCENE: PackedScene = preload("res://scenes/blocks/water_block.tscn")
const GEAR_SCENE: PackedScene = preload("res://scenes/blocks/gear_block.tscn")
const BELL_SCENE: PackedScene = preload("res://scenes/blocks/bell_block.tscn")

const SCENES_BY_TYPE: Dictionary = {
	BlockData.Type.WOOD: WOOD_SCENE,
	BlockData.Type.WATER: WATER_SCENE,
	BlockData.Type.GEAR: GEAR_SCENE,
	BlockData.Type.BELL: BELL_SCENE,
}

static func instantiate(type: BlockData.Type) -> Node3D:
	var scene: PackedScene = SCENES_BY_TYPE[type]
	var instance: Node3D = scene.instantiate()
	if type == BlockData.Type.WATER:
		_make_material_unique(instance)
	return instance

## Water blocks share one ShaderMaterial resource in the scene by default —
## duplicate it per instance so BlockMergeManager can set edge_mask on each
## block independently without affecting every other placed water block.
static func _make_material_unique(instance: Node3D) -> void:
	var mesh_instance: MeshInstance3D = instance.get_node("MeshInstance3D")
	var material: Material = mesh_instance.get_surface_override_material(0)
	if material != null:
		mesh_instance.set_surface_override_material(0, material.duplicate())
