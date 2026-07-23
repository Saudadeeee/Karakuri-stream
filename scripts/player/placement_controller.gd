extends Node3D

signal material_changed(type: BlockData.Type, variant: int)

@export var camera_path: NodePath
@export var collision_mask: int = 1

@onready var camera: Camera3D = get_node(camera_path)
@onready var ghost: MeshInstance3D = $GhostBlock

const WOOD_SHADER: Shader = preload("res://shaders/wood.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")
const PipeBlock := preload("res://scripts/blocks/pipe_block.gd")
const GearBlock := preload("res://scripts/blocks/gear_block.gd")

var _current_type: BlockData.Type = BlockData.Type.WOOD
var _current_variant: int = 0
var _ghost_cell: Vector3i = Vector3i.ZERO
var _ghost_valid: bool = false
var _ghost_normal: Vector3 = Vector3.UP

## Live translucent preview of exactly the block about to be placed (its real
## model, oriented the way it will land). Rebuilt only when the type or the
## resolved shape/orientation actually changes, so it's cheap per frame.
var _ghost_root: Node3D
var _ghost_key: String = ""

func _ready() -> void:
	ghost.visible = false   # old boxmesh ghost retired in favour of _ghost_root
	_ghost_root = Node3D.new()
	add_child(_ghost_root)
	_ghost_root.visible = false

## Selecting the material already in hand CYCLES its variant (click the icon /
## press its key again to flip a pipe open, change wood→dirt, recolour water …).
func select_material(type: BlockData.Type) -> void:
	if type == _current_type:
		_current_variant = (_current_variant + 1) % BlockVariants.count(type)
	else:
		_current_type = type
		_current_variant = 0
	material_changed.emit(type, _current_variant)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			select_material(BlockData.Type.WOOD)
		elif event.keycode == KEY_2:
			select_material(BlockData.Type.WATER)
		elif event.keycode == KEY_3:
			select_material(BlockData.Type.SOURCE)
		elif event.keycode == KEY_4:
			select_material(BlockData.Type.PIPE)
		elif event.keycode == KEY_5:
			select_material(BlockData.Type.GEAR)
		elif event.keycode == KEY_6:
			select_material(BlockData.Type.BELL)
		elif event.keycode == KEY_7:
			select_material(BlockData.Type.JELLY)
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
		_ghost_root.visible = false
		return
	var normal: Vector3 = hit["normal"]
	var hit_cell: Vector3i = GridManager.world_to_cell(hit["position"] - normal * 0.5)
	var place_cell: Vector3i = hit_cell + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	_ghost_cell = place_cell
	_ghost_normal = normal
	_ghost_valid = not GridManager.has_block(place_cell)
	_ghost_root.visible = _ghost_valid
	if _ghost_valid:
		_ghost_root.position = GridManager.cell_to_world(place_cell)
		_refresh_ghost_model()

## Rebuild the ghost's model only when the type or its resolved orientation/shape
## changes (encoded in a small key), then always apply the current basis.
func _refresh_ghost_model() -> void:
	var axis := Vector3i(roundi(_ghost_normal.x), roundi(_ghost_normal.y), roundi(_ghost_normal.z))
	var ports: Array = PipeRouting.connections(_ghost_cell) if _current_type == BlockData.Type.PIPE else []
	var key: String = "%d|%d|%s|%s" % [_current_type, _current_variant, axis, ports]
	if key != _ghost_key:
		_ghost_key = key
		for c in _ghost_root.get_children():
			c.queue_free()
		var vis := _build_ghost_visual(_current_type, axis, ports)
		_ghost_root.add_child(vis)

## The real block visual (model or shader box), tinted translucent, oriented the
## way it will be placed.
func _build_ghost_visual(type: BlockData.Type, axis: Vector3i, ports: Array) -> Node3D:
	var holder := Node3D.new()
	if type == BlockData.Type.WOOD or type == BlockData.Type.WATER:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.9, 0.9)
		mi.mesh = box
		holder.add_child(mi)
	elif type == BlockData.Type.PIPE:
		# Show the same procedural hub+stubs the real pipe builds, connecting
		# toward the current neighbours (ports = connection dirs).
		var dirs: Array = ports if not ports.is_empty() else [Vector3i(0, 1, 0), Vector3i(0, -1, 0)]
		var v: Dictionary = BlockVariants.get_variant(type, _current_variant)
		holder.add_child(PipeBlock.build_visual(dirs, v.get("open", false)))
	else:
		var model: Node3D = BlockFactory.instantiate(type)
		holder.add_child(model)
		if model.has_method("apply_variant"):
			model.apply_variant(BlockVariants.get_variant(type, _current_variant))
		if type == BlockData.Type.GEAR:
			holder.basis = GearBlock._basis_for_axis(axis)
	# CRITICAL: the ghost reuses real block scenes which carry collision — if left
	# active the placement raycast hits the GHOST itself, breaking positioning
	# (the gear/bell/source/pipe "ghost bug"). Strip all collision from the ghost.
	_disable_collision(holder)
	_tint_ghost(holder)
	return holder

func _disable_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for c in node.get_children():
		_disable_collision(c)

func _tint_ghost(node: Node) -> void:
	if node is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.85, 1.0, 0.4)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		(node as MeshInstance3D).material_override = m
	for c in node.get_children():
		_tint_ghost(c)

func _place_block() -> void:
	if not _ghost_valid:
		return
	var instance: Node3D = BlockFactory.instantiate(_current_type)
	add_sibling_block(instance)
	var final_pos: Vector3 = GridManager.cell_to_world(_ghost_cell)
	var block := BlockData.new(_current_type, instance)
	# Chosen variant (pipe open/closed, wood colour, water tint, gear vs mill …).
	block.state["variant"] = _current_variant
	if instance.has_method("apply_variant"):
		instance.apply_variant(BlockVariants.get_variant(_current_type, _current_variant))
	# Gears orient by the face they're placed on (axis = placement normal), so a
	# wheel on a wall stands up like a water wheel. Store the axis so save/load
	# and GearManager keep the same orientation.
	if _current_type == BlockData.Type.GEAR:
		var axis := Vector3i(roundi(_ghost_normal.x), roundi(_ghost_normal.y), roundi(_ghost_normal.z))
		block.state["axis"] = axis
		if instance.has_method("apply_axis"):
			instance.apply_axis(axis)
	elif _current_type == BlockData.Type.PIPE or _current_type == BlockData.Type.SOURCE:
		# Auto-connecting blocks derive orientation/shape from neighbours; set
		# their cell before set_block so the placement signal drives the refresh.
		instance.grid_cell = _ghost_cell
	_animate_drop(instance, final_pos, _current_type)
	GridManager.set_block(_ghost_cell, block)
	if _current_type == BlockData.Type.PIPE:
		instance.refresh_shape()
	elif _current_type == BlockData.Type.SOURCE:
		instance.face_adjacent_water()
	if _current_type == BlockData.Type.WOOD:
		AudioManager.play_wood_hit(final_pos)
	elif _current_type == BlockData.Type.JELLY:
		AudioManager.play_jelly_bounce(final_pos)

func _animate_drop(instance: Node3D, final_pos: Vector3, type: BlockData.Type) -> void:
	instance.position = final_pos + Vector3(0.0, 3.0, 0.0)
	instance.scale = Vector3.ONE
	var tween: Tween = create_tween()
	# Jelly feel: drop in, squash DEEP on impact, then a slow springy
	# overshoot back to rest (ELASTIC) so the block wobbles like soft jelly
	# settling rather than a rigid object snapping into place.
	tween.tween_property(instance, "position", final_pos, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Kick up dust / splash the instant it lands, right at the base of the block.
	tween.tween_callback(_spawn_place_effect.bind(type, final_pos + Vector3(0.0, -0.45, 0.0)))
	tween.tween_property(instance, "scale", Vector3(1.35, 0.55, 1.35), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(instance, "scale", Vector3.ONE, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## A short burst when a block lands: wood kicks up earthy dust, water sprays
## bright droplets, gear/bell throws a couple of metallic sparks.
func _spawn_place_effect(type: BlockData.Type, pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.position = pos
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.25
	mat.direction = Vector3(0.0, 1.0, 0.0)
	var draw_mesh: Mesh
	var particle_mat := StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	match type:
		BlockData.Type.WATER:
			particles.amount = 12
			particles.lifetime = 0.55
			mat.spread = 55.0
			mat.initial_velocity_min = 0.8
			mat.initial_velocity_max = 1.6
			mat.gravity = Vector3(0.0, -4.0, 0.0)
			mat.scale_min = 0.03
			mat.scale_max = 0.06
			var s := SphereMesh.new()
			s.radius = 0.05; s.height = 0.1; s.radial_segments = 6; s.rings = 3
			draw_mesh = s
			particle_mat.albedo_color = Color(0.7, 0.92, 0.95, 0.95)
			particle_mat.emission_enabled = true
			particle_mat.emission = Color(0.6, 0.85, 0.9)
		BlockData.Type.GEAR, BlockData.Type.BELL:
			particles.amount = 8
			particles.lifetime = 0.4
			mat.spread = 60.0
			mat.initial_velocity_min = 0.5
			mat.initial_velocity_max = 1.0
			mat.gravity = Vector3(0.0, -2.0, 0.0)
			mat.scale_min = 0.02
			mat.scale_max = 0.04
			var q := QuadMesh.new()
			q.size = Vector2(0.05, 0.05)
			draw_mesh = q
			particle_mat.albedo_color = Color(1.0, 0.92, 0.6)
			particle_mat.emission_enabled = true
			particle_mat.emission = Color(1.0, 0.85, 0.4)
		_: # WOOD (and default): earthy dust puff
			particles.amount = 14
			particles.lifetime = 0.7
			mat.spread = 80.0
			mat.initial_velocity_min = 0.3
			mat.initial_velocity_max = 0.9
			mat.gravity = Vector3(0.0, -1.2, 0.0)
			mat.scale_min = 0.04
			mat.scale_max = 0.09
			var q := QuadMesh.new()
			q.size = Vector2(0.08, 0.08)
			draw_mesh = q
			particle_mat.albedo_color = Color(0.62, 0.5, 0.34, 0.85)
			particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = scale_curve
	mat.scale_curve = ct
	particles.process_material = mat
	(draw_mesh as PrimitiveMesh).material = particle_mat
	particles.draw_pass_1 = draw_mesh

	add_sibling_block(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)

func add_sibling_block(instance: Node3D) -> void:
	get_parent().add_child(instance)

func _remove_block() -> void:
	var hit: Dictionary = _raycast_from_mouse()
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var hit_cell: Vector3i = GridManager.world_to_cell(hit["position"] - normal * 0.5)
	GridManager.remove_block(hit_cell)
