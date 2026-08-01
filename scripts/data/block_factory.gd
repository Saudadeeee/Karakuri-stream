class_name BlockFactory
extends RefCounted

## Turns a BlockData.Type into a real scene instance. Shared by
## PlacementController (click-to-place) and SaveManager (load from file) so
## there is exactly one path from type to node.
##
## The scenes themselves live in BlockCatalog — register a new block there,
## not here.

## Returns null for a type this build doesn't know — which happens for real
## once the game ships and a save file written by a newer version comes back.
## Callers must handle null rather than get an "out of bounds" mid-rebuild.
static func instantiate(type: BlockData.Type) -> Node3D:
	var scene: PackedScene = BlockCatalog.entry(int(type)).get("scene")
	if scene == null:
		push_warning("No scene registered for block type %d" % int(type))
		return null
	return scene.instantiate()
