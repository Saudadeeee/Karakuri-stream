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
const SOURCE_SCENE: PackedScene = preload("res://scenes/blocks/source_block.tscn")
const PIPE_SCENE: PackedScene = preload("res://scenes/blocks/pipe_block.tscn")
const PIPE_BEND_SCENE: PackedScene = preload("res://scenes/blocks/pipe_bend_block.tscn")
const JELLY_SCENE: PackedScene = preload("res://scenes/blocks/jelly_block.tscn")
const SHISHI_SCENE: PackedScene = preload("res://scenes/blocks/shishi_block.tscn")
const DRUM_SCENE: PackedScene = preload("res://scenes/blocks/drum_block.tscn")
const CHIME_SCENE: PackedScene = preload("res://scenes/blocks/chime_block.tscn")
const MUSIC_BOX_SCENE: PackedScene = preload("res://scenes/blocks/music_box_block.tscn")
const SCOOP_SCENE: PackedScene = preload("res://scenes/blocks/scoop_block.tscn")
const STONE_LANTERN_SCENE: PackedScene = preload("res://scenes/blocks/stone_lantern_block.tscn")
const PINWHEEL_SCENE: PackedScene = preload("res://scenes/blocks/pinwheel_block.tscn")

const SCENES_BY_TYPE: Dictionary = {
	BlockData.Type.WOOD: WOOD_SCENE,
	BlockData.Type.WATER: WATER_SCENE,
	BlockData.Type.GEAR: GEAR_SCENE,
	BlockData.Type.BELL: BELL_SCENE,
	BlockData.Type.SOURCE: SOURCE_SCENE,
	BlockData.Type.PIPE: PIPE_SCENE,
	BlockData.Type.PIPE_BEND: PIPE_BEND_SCENE,
	BlockData.Type.JELLY: JELLY_SCENE,
	BlockData.Type.SHISHI: SHISHI_SCENE,
	BlockData.Type.DRUM: DRUM_SCENE,
	BlockData.Type.CHIME: CHIME_SCENE,
	BlockData.Type.MUSIC_BOX: MUSIC_BOX_SCENE,
	BlockData.Type.SCOOP: SCOOP_SCENE,
	BlockData.Type.STONE_LANTERN: STONE_LANTERN_SCENE,
	BlockData.Type.PINWHEEL: PINWHEEL_SCENE,
}

static func instantiate(type: BlockData.Type) -> Node3D:
	var scene: PackedScene = SCENES_BY_TYPE[type]
	return scene.instantiate()
