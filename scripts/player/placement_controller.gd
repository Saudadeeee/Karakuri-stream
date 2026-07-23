extends Node3D

signal material_changed(type: BlockData.Type)

@export var camera_path: NodePath
@export var collision_mask: int = 1

@onready var camera: Camera3D = get_node(camera_path)
@onready var ghost: MeshInstance3D = $GhostBlock

var _current_type: BlockData.Type = BlockData.Type.WOOD
var _ghost_cell: Vector3i = Vector3i.ZERO
var _ghost_valid: bool = false

func _ready() -> void:
	ghost.visible = false

func select_material(type: BlockData.Type) -> void:
	_current_type = type
	material_changed.emit(type)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			select_material(BlockData.Type.WOOD)
		elif event.keycode == KEY_2:
			select_material(BlockData.Type.WATER)
		elif event.keycode == KEY_3:
			select_material(BlockData.Type.GEAR)
		elif event.keycode == KEY_4:
			select_material(BlockData.Type.BELL)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_place_block()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_remove_block()

func _process(_delta: float) -> void:
	_update_ghost()

func _raycast_from_mouse() -> Dictionary:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 100.0
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	return space_state.intersect_ray(query)

func _update_ghost() -> void:
	var hit: Dictionary = _raycast_from_mouse()
	if hit.is_empty():
		_ghost_valid = false
		ghost.visible = false
		return
	var normal: Vector3 = hit["normal"]
	var hit_cell: Vector3i = GridManager.world_to_cell(hit["position"] - normal * 0.5)
	var place_cell: Vector3i = hit_cell + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	_ghost_cell = place_cell
	_ghost_valid = not GridManager.has_block(place_cell)
	ghost.visible = _ghost_valid
	ghost.position = GridManager.cell_to_world(place_cell)

func _place_block() -> void:
	if not _ghost_valid:
		return
	var instance: Node3D = BlockFactory.instantiate(_current_type)
	add_sibling_block(instance)
	var final_pos: Vector3 = GridManager.cell_to_world(_ghost_cell)
	_animate_drop(instance, final_pos)
	var block := BlockData.new(_current_type, instance)
	GridManager.set_block(_ghost_cell, block)
	if _current_type == BlockData.Type.WOOD:
		AudioManager.play_wood_hit(final_pos)

func _animate_drop(instance: Node3D, final_pos: Vector3) -> void:
	instance.position = final_pos + Vector3(0.0, 3.0, 0.0)
	instance.scale = Vector3.ONE
	var tween: Tween = create_tween()
	# Jelly feel: drop in, squash DEEP on impact, then a slow springy
	# overshoot back to rest (ELASTIC) so the block wobbles like soft jelly
	# settling rather than a rigid object snapping into place.
	tween.tween_property(instance, "position", final_pos, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(instance, "scale", Vector3(1.35, 0.55, 1.35), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(instance, "scale", Vector3.ONE, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func add_sibling_block(instance: Node3D) -> void:
	get_parent().add_child(instance)

func _remove_block() -> void:
	var hit: Dictionary = _raycast_from_mouse()
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var hit_cell: Vector3i = GridManager.world_to_cell(hit["position"] - normal * 0.5)
	GridManager.remove_block(hit_cell)
