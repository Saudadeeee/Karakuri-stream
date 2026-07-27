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

## Grounded ghost: a soft contact shadow under the hovered cell + four cream
## corner brackets that snap onto each NEW cell — the preview feels physically
## anchored, and every cell change gives a tiny tactile snap. Built once here,
## reused forever (zero per-frame allocation).
var _ghost_shadow: MeshInstance3D
var _brackets: Node3D
var _bracket_mat: StandardMaterial3D
var _last_bracket_cell := Vector3i(9999, 9999, 9999)
var _bracket_tween: Tween
var _jig: Node3D
var _jig_crank: MeshInstance3D

func _ready() -> void:
	ghost.visible = false   # old boxmesh ghost retired in favour of _ghost_root
	_ghost_root = Node3D.new()
	add_child(_ghost_root)
	_ghost_root.visible = false

	_ghost_shadow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.85, 0.85)
	_ghost_shadow.mesh = quad
	_ghost_shadow.rotation_degrees.x = -90.0
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.1, 0.1, 0.15, 0.16)
	sm.render_priority = 1
	_ghost_shadow.material_override = sm
	_ghost_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_shadow.visible = false
	add_child(_ghost_shadow)

	_brackets = Node3D.new()
	_bracket_mat = StandardMaterial3D.new()
	_bracket_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bracket_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bracket_mat.albedo_color = Color(0.98, 0.94, 0.86, 0.5)
	for corner in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		for axis in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.02, 0.02, 0.02) + axis * 0.18
			bar.mesh = bm
			bar.material_override = _bracket_mat
			bar.position = corner * 0.5 - corner * axis * 0.1 + Vector3(0, -0.47, 0)
			_brackets.add_child(bar)
	_brackets.visible = false
	add_child(_brackets)

	# Karakuri cog-jig: a faint translucent cog-ring seat under the cursor + a
	# tiny idle crank cog, so placing a block feels like fitting a clockwork part.
	_jig = Node3D.new()
	var ring := MeshInstance3D.new()
	ring.mesh = GearMesh.build(12, 0.62, 0.5, 0.0, 0.04, Color("caa878"), Color("caa878"))
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.98, 0.94, 0.86, 0.28)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	ring.rotation.x = -PI / 2.0
	_jig.add_child(ring)
	_jig_crank = MeshInstance3D.new()
	_jig_crank.mesh = GearMesh.build(8, 0.16, 0.12, 0.05, 0.05, Color("a9764a"), Color("caa878"))
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.66, 0.46, 0.29, 0.55)
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_jig_crank.material_override = cm
	_jig_crank.rotation.x = -PI / 2.0
	_jig_crank.position = Vector3(0.42, -0.44, 0.42)
	_jig.add_child(_jig_crank)
	_jig.visible = false
	add_child(_jig)

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
		elif event.keycode == KEY_Q:
			select_material(BlockData.Type.HOUSE)
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
		elif event.keycode == KEY_8:
			select_material(BlockData.Type.SHISHI)
		elif event.keycode == KEY_9:
			select_material(BlockData.Type.DRUM)
		elif event.keycode == KEY_0:
			select_material(BlockData.Type.CHIME)
		elif event.keycode == KEY_MINUS:
			select_material(BlockData.Type.MUSIC_BOX)
		elif event.keycode == KEY_EQUAL:
			select_material(BlockData.Type.SCOOP)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_paint(PAINT_PLACE)
			else:
				_end_paint()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_begin_paint(PAINT_REMOVE)
			else:
				_end_paint()

## DRAG TO BUILD. Townscaper is fast because you sweep the mouse and a street
## appears; clicking once per cell turns building twenty houses into twenty
## separate decisions and the flow never arrives. Holding the button now paints
## continuously, one block per NEW cell the cursor enters.
enum { PAINT_NONE, PAINT_PLACE, PAINT_REMOVE }

var _paint_mode: int = PAINT_NONE
var _painted: Dictionary = {}      # cells touched by the current stroke
var _paint_quiet: bool = false     # deep into a sweep: lay blocks without the fanfare

func _begin_paint(mode: int) -> void:
	_paint_mode = mode
	_painted.clear()
	UndoManager.begin_stroke()
	_paint_step()

func _end_paint() -> void:
	if _paint_mode == PAINT_NONE:
		return
	_paint_mode = PAINT_NONE
	_painted.clear()
	_paint_quiet = false
	UndoManager.end_stroke()

## The occupied cell under the cursor — what a remove-drag would delete. Mirrors
## the lookup in _remove_block so the stroke guard keys on the same cell the
## removal will actually act on.
func _hover_cell() -> Vector3i:
	var hit: Dictionary = _raycast_from_mouse()
	if hit.is_empty():
		return Vector3i(9999, 9999, 9999)
	return GridManager.world_to_cell(hit["position"] - (hit["normal"] as Vector3) * 0.5)

## One block per cell per stroke: without the `_painted` guard a stationary
## cursor would re-place the same cell every frame.
func _paint_step() -> void:
	if _paint_mode == PAINT_NONE:
		return
	if _paint_mode == PAINT_PLACE and not _ghost_valid:
		return
	var cell: Vector3i = _ghost_cell if _paint_mode == PAINT_PLACE else _hover_cell()
	if _painted.has(cell):
		return
	_painted[cell] = true
	# Thin the celebration on a long sweep. Every placement spawns a drop tween
	# and a particle burst; twenty of those in one gesture is both a hitch and
	# visual noise. The first few stay fully juicy — that is where the feedback
	# actually registers — and the rest of the stroke lays quietly.
	_paint_quiet = _painted.size() > 4
	if _paint_mode == PAINT_PLACE:
		_place_block()
	else:
		_remove_block()

func _process(_delta: float) -> void:
	_update_ghost()
	_paint_step()

func _raycast_from_mouse() -> Dictionary:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 100.0
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	return space_state.intersect_ray(query)

## Photo mode (main_scene toggles this): hide the ghost for clean screenshots.
var photo_mode: bool = false

func _update_ghost() -> void:
	if photo_mode:
		_ghost_root.visible = false
		_ghost_shadow.visible = false
		_brackets.visible = false
		_jig.visible = false
		return
	var hit: Dictionary = _raycast_from_mouse()
	if hit.is_empty():
		_ghost_valid = false
		_ghost_root.visible = false
		_ghost_shadow.visible = false
		_brackets.visible = false
		_jig.visible = false
		return
	var normal: Vector3 = hit["normal"]
	var hit_cell: Vector3i = GridManager.world_to_cell(hit["position"] - normal * 0.5)
	var place_cell: Vector3i = hit_cell + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	_ghost_cell = place_cell
	_ghost_normal = normal
	# Keep builds on/near the island: the ground collider is a big 50×50 plane,
	# and a block placed way out would also blow up the merged-surface rebuild
	# (its sample grid spans the AABB of ALL cells). Radius 12 covers the
	# island (r=9) plus a small ledge.
	var on_island: bool = Vector2(place_cell.x, place_cell.z).length() <= 12.0 \
		and place_cell.y >= 0 and place_cell.y <= 24
	_ghost_valid = on_island and not GridManager.has_block(place_cell)
	_ghost_root.visible = _ghost_valid
	_ghost_shadow.visible = _ghost_valid
	_brackets.visible = _ghost_valid
	_jig.visible = _ghost_valid
	if _ghost_valid:
		var world := GridManager.cell_to_world(place_cell)
		_ghost_root.position = world
		# Gentle breathing so the ghost feels alive under the cursor.
		var t: float = Time.get_ticks_msec() / 1000.0
		_ghost_root.scale = Vector3.ONE * (1.0 + sin(t * 5.0) * 0.02)
		# Contact shadow rests on the support surface; brackets frame the cell.
		_ghost_shadow.position = world + Vector3(0, -0.48, 0)
		_brackets.position = world
		_jig.position = world + Vector3(0, -0.46, 0)
		_jig_crank.rotate_z(get_process_delta_time() * 1.6)
		# Snap-pop ONLY when the hovered cell changes (same-cell hover is calm).
		if place_cell != _last_bracket_cell:
			_last_bracket_cell = place_cell
			if _bracket_tween != null and _bracket_tween.is_valid():
				_bracket_tween.kill()
			_brackets.scale = Vector3.ONE * 1.2
			_bracket_mat.albedo_color.a = 0.0
			_bracket_tween = create_tween()
			_bracket_tween.set_parallel(true)
			_bracket_tween.tween_property(_brackets, "scale", Vector3.ONE, 0.12) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_bracket_tween.tween_property(_bracket_mat, "albedo_color:a", 0.5, 0.12)
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
	# Clicking a GATE that already exists TOGGLES it (the conductor's gesture)
	# instead of placing a new block on its face.
	var hit: Dictionary = _raycast_from_mouse()
	if not hit.is_empty():
		var hn: Vector3 = hit["normal"]
		var hcell: Vector3i = GridManager.world_to_cell(hit["position"] - hn * 0.5)
		var hblock: BlockData = GridManager.get_block(hcell)
		if hblock != null and hblock.type == BlockData.Type.GATE and is_instance_valid(hblock.node):
			hblock.node.toggle()
			return
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
	elif _current_type == BlockData.Type.PIPE or _current_type == BlockData.Type.SOURCE \
			or _current_type == BlockData.Type.HOUSE:
		# Auto-connecting blocks derive orientation/shape from neighbours; set
		# their cell before set_block so the placement signal drives the refresh.
		instance.grid_cell = _ghost_cell
	# The ghost visibly condenses into the real thing (afterimage swells+fades
	# while the block drops through it), and the block's VOICE moves to the
	# moment of impact — snapped onto the music's beat grid (see _landing_voice).
	var cell := _ghost_cell
	var click_phase: float = StreamManager.beat_phase()
	if not _paint_quiet:
		_spawn_afterimage()
	# Immediate quiet acknowledgment tick so input never feels swallowed while
	# the landing voice waits for the impact/beat.
	AudioManager.play_wood_pitch(final_pos, 2.0, -14.0)
	_animate_drop(instance, final_pos, _current_type, cell, click_phase)
	GridManager.set_block(_ghost_cell, block)
	UndoManager.record_place(_ghost_cell, block)
	if _current_type == BlockData.Type.PIPE or _current_type == BlockData.Type.HOUSE:
		instance.refresh_shape()
	elif _current_type == BlockData.Type.SOURCE:
		instance.face_adjacent_water()
	PondDecorManager.excite_near(final_pos)
	WildlifeManager.look_near(final_pos)
	# Placing water — or landing a block right beside water — sends a ripple
	# splash through the pond surface.
	if _current_type != BlockData.Type.WATER:
		for dir in GridManager.DIRECTIONS:
			var nb: BlockData = GridManager.get_block(_ghost_cell + dir)
			if nb != null and nb.type == BlockData.Type.WATER:
				StreamManager._spawn_splash(GridManager.cell_to_world(_ghost_cell + dir) + Vector3(0, 0.55, 0))
				break

## Landing voice, played AT impact: if machines are making rhythm, wait for the
## next 16th of the shared beat grid so the click JOINS the song (max wait
## ~0.14s — reads as tightness, not lag).
func _landing_voice(type: BlockData.Type, pos: Vector3, cell: Vector3i) -> void:
	var delay: float = StreamManager.seconds_to_next_sub(4) if StreamManager.is_playing() else 0.0
	if delay <= 0.0:
		_play_place_sound(type, pos, cell)
	else:
		get_tree().create_timer(delay).timeout.connect(_play_place_sound.bind(type, pos, cell))

## Every material lands with its OWN voice — and the wood family is a marimba:
## the cell's HEIGHT picks the pentatonic degree (octave up past y=5), so
## stacking a tower plays an ascending run. Drum/shishi/chime/bell/jelly keep
## their own voices so material identity survives.
func _play_place_sound(type: BlockData.Type, pos: Vector3, cell: Vector3i = Vector3i.ZERO) -> void:
	match type:
		BlockData.Type.WOOD:
			AudioManager.play_wood_note(pos, cell.y % 5, cell.y >= 5)
		BlockData.Type.WATER:
			AudioManager.play_jelly_bounce(pos)          # soft wet plop
		BlockData.Type.JELLY:
			AudioManager.play_jelly_bounce(pos)
		BlockData.Type.BELL:
			AudioManager.play_chime(pos)
		BlockData.Type.CHIME:
			AudioManager.play_chime(pos, int(BlockVariants.get_variant(type, _current_variant).get("note", 0)))
		BlockData.Type.DRUM:
			AudioManager.play_drum(pos)
		BlockData.Type.SHISHI:
			AudioManager.play_shishi_knock(pos)
		BlockData.Type.MUSIC_BOX:
			AudioManager.play_music_box_note(pos, 0)
		BlockData.Type.GEAR:
			AudioManager.play_wood_note(pos, cell.y % 5, cell.y >= 5, 1.25, -1.0)
		_:  # pipe, source, scoop… bamboo-ish knock, still on the marimba
			AudioManager.play_wood_note(pos, cell.y % 5, cell.y >= 5, 1.1, -1.0)

func _animate_drop(instance: Node3D, final_pos: Vector3, type: BlockData.Type, cell: Vector3i = Vector3i.ZERO, click_phase: float = 0.5) -> void:
	# Lower spawn (the ghost afterimage sits at the cell — the block visibly
	# drops THROUGH the condensing promise), pre-stretched along the fall so the
	# deep squash finally has its anticipation partner.
	instance.position = final_pos + Vector3(0.0, 2.2, 0.0)
	instance.scale = Vector3(0.86, 1.24, 0.86)
	instance.set_meta("dropping", true)   # sympathy ripple must not fight this tween
	var tween: Tween = create_tween()
	# Jelly feel: drop in, squash DEEP on impact, then a slow springy
	# overshoot back to rest (ELASTIC) so the block wobbles like soft jelly
	# settling rather than a rigid object snapping into place.
	tween.tween_property(instance, "position", final_pos, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# THE impact instant: dust, ground ring (gold when the click landed on the
	# beat), a soft material-tinted light kiss, the landing voice (beat-snapped),
	# and a sympathy ripple through the neighbours.
	var on_beat: bool = click_phase < 0.12 or click_phase > 0.88
	if not _paint_quiet:
		tween.tween_callback(_spawn_place_effect.bind(type, final_pos + Vector3(0.0, -0.45, 0.0)))
	tween.tween_callback(_spawn_ring.bind(final_pos + Vector3(0.0, -0.48, 0.0), on_beat))
	tween.tween_callback(_spawn_kiss.bind(type, final_pos))
	tween.tween_callback(_landing_voice.bind(type, final_pos, cell))
	tween.tween_callback(_ripple_neighbors.bind(cell))
	tween.tween_property(instance, "scale", Vector3(1.35, 0.55, 1.35), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(instance, "scale", Vector3.ONE, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if is_instance_valid(instance):
			instance.remove_meta("dropping"))

## A short burst when a block lands: wood kicks up earthy dust, water sprays
## bright droplets, gear/bell throws a couple of metallic sparks. `rise` flips
## gravity so removal dust drifts UP after the ascending block.
func _spawn_place_effect(type: BlockData.Type, pos: Vector3, rise: bool = false) -> void:
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

	if rise:
		mat.gravity = Vector3(0.0, 1.0, 0.0)

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

## Removal streak state — repeated removals inside 2s walk DOWN the pentatonic
## scale (the graceful "un-melody" mirror of building).
var _remove_streak: int = 0
var _last_remove_ms: int = 0
var _ascending: int = 0   # concurrent ascension tweens (web cap)

func _remove_block() -> void:
	var hit: Dictionary = _raycast_from_mouse()
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var hit_cell: Vector3i = GridManager.world_to_cell(hit["position"] - normal * 0.5)
	var block: BlockData = GridManager.get_block(hit_cell)
	if block == null:
		return
	UndoManager.record_remove(hit_cell, block)
	var pos: Vector3 = GridManager.cell_to_world(hit_cell)

	# Un-melody: streak walks down the scale; a soft lower echo follows.
	var now: int = Time.get_ticks_msec()
	_remove_streak = mini(_remove_streak + 1, 7) if now - _last_remove_ms < 2000 else 0
	_last_remove_ms = now
	var degree: int = 4 - (_remove_streak % 5)
	AudioManager.play_wood_pitch(pos, AudioManager.PENTATONIC_RATIOS[degree], -3.0)
	if _remove_streak <= 3:
		get_tree().create_timer(0.09).timeout.connect(
			AudioManager.play_wood_pitch.bind(pos, AudioManager.PENTATONIC_RATIOS[maxi(degree - 1, 0)] * 0.5, -1.0))

	if not _paint_quiet:
		_spawn_place_effect(BlockData.Type.WOOD, pos, true)   # dust drifts UP
	_spawn_ring(pos + Vector3(0.0, -0.4, 0.0))
	_ripple_neighbors(hit_cell)
	PondDecorManager.excite_near(pos)

	# Ascension: the block came from the sky and returns to it — pluck, float
	# up, yaw, shrink into a firefly puff. The visual is orphaned from the grid
	# BEFORE removal (UndoManager stores only type/variant/axis, never nodes).
	var visual: Node3D = block.node if is_instance_valid(block.node) else null
	var meshless: bool = block.type == BlockData.Type.WATER or block.type == BlockData.Type.WOOD
	if visual == null or meshless or _ascending >= 6:
		GridManager.remove_block(hit_cell)
		return
	block.node = null
	GridManager.remove_block(hit_cell)
	_disable_collision(visual)   # raycasts must pass through the dying block
	_ascending += 1
	var tw := create_tween()
	tw.tween_property(visual, "scale", visual.scale * Vector3(1.08, 0.9, 1.08), 0.07)  # the pluck
	tw.set_parallel(true)
	tw.tween_property(visual, "position", visual.position + Vector3(0, 1.2, 0), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "rotation:y", visual.rotation.y + 0.7, 0.55)
	tw.tween_property(visual, "scale", Vector3.ONE * 0.001, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.1)
	tw.chain().tween_callback(func():
		FireflyManager.burst_at(pos + Vector3(0, 1.0, 0))
		if is_instance_valid(visual):
			visual.queue_free()
		_ascending -= 1)

## Expanding, fading ground ring — the classic satisfying "impact pulse".
## GOLD when the click landed on the music's beat (the rhythm reward).
var _last_gold_ms: int = 0

func _spawn_ring(pos: Vector3, on_beat: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 6
	mi.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.86, 0.5, 0.8) if on_beat else Color(0.98, 0.94, 0.86, 0.7)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3(0.5, 0.25, 0.5)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	var end_scale := Vector3(1.7, 0.25, 1.7) if on_beat else Vector3(1.5, 0.25, 1.5)
	tw.tween_property(mi, "scale", end_scale, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.38)
	tw.chain().tween_callback(mi.queue_free)
	if on_beat and Time.get_ticks_msec() - _last_gold_ms > 1500:
		_last_gold_ms = Time.get_ticks_msec()
		FireflyManager.burst_at(pos + Vector3(0, 1.0, 0))

## Soft additive shell inflating at the exact contact instant — a pastel light
## kiss tinted by material. Alpha 0.3 / 0.25s is the zen ceiling: a kiss, never
## a pop.
func _spawn_kiss(type: BlockData.Type, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.02
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var tint := Color(0.95, 0.75, 0.5)       # warm amber default
	match type:
		BlockData.Type.WATER, BlockData.Type.SOURCE, BlockData.Type.PIPE:
			tint = Color(0.6, 0.9, 0.95)
		BlockData.Type.BELL, BlockData.Type.CHIME, BlockData.Type.MUSIC_BOX:
			tint = Color(1.0, 0.9, 0.55)
		BlockData.Type.JELLY:
			tint = Color(1.0, 0.75, 0.85)
	m.albedo_color = Color(tint.r, tint.g, tint.b, 0.3)
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.18, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(mi.queue_free)

## The ghost's afterimage: bare-mesh copy (never duplicate the ghost root — its
## block scenes carry scripts) that swells and fades while the real block drops
## through it — the promise visibly condenses into the thing.
func _spawn_afterimage() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_ghost_root, meshes)
	if meshes.is_empty():
		return
	var root := Node3D.new()
	add_sibling_block(root)
	root.global_transform = _ghost_root.global_transform
	var mats: Array[StandardMaterial3D] = []
	for src in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		root.add_child(mi)
		mi.global_transform = src.global_transform
		if src.material_override is StandardMaterial3D:
			var d: StandardMaterial3D = src.material_override.duplicate()
			mi.material_override = d
			mats.append(d)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", root.scale * 1.18, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for m in mats:
		tw.tween_property(m, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(root.queue_free)

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

## Sympathy ripple: the landing's weight travels outward — neighbours within
## Manhattan distance 2 squash 3% and spring back, staggered ~60ms per cell.
## One click makes a dense build shiver like one connected clay body. Wood and
## water skip naturally (their nodes are invisible colliders; visuals live in
## the merged isosurface).
var _flex_base: Dictionary = {}    # instance_id -> Vector3 (scale captured once)
var _flex_tweens: Dictionary = {}  # instance_id -> Tween

func _ripple_neighbors(center: Vector3i) -> void:
	for off in _ripple_offsets():
		var b: BlockData = GridManager.get_block(center + off)
		if b == null or not is_instance_valid(b.node):
			continue
		if b.type == BlockData.Type.WOOD or b.type == BlockData.Type.WATER:
			continue
		var node: Node3D = b.node
		if node.has_meta("dropping"):
			continue
		var now: int = Time.get_ticks_msec()
		if node.has_meta("sympathy_ms") and now - int(node.get_meta("sympathy_ms")) < 500:
			continue
		node.set_meta("sympathy_ms", now)
		var id: int = node.get_instance_id()
		if not _flex_base.has(id):
			_flex_base[id] = node.scale
		if _flex_tweens.has(id) and is_instance_valid(_flex_tweens[id]):
			_flex_tweens[id].kill()
		var base: Vector3 = _flex_base[id]
		var dist: int = absi(off.x) + absi(off.y) + absi(off.z)
		var tw := create_tween()
		tw.tween_interval(0.06 * dist)
		tw.tween_property(node, "scale", base * Vector3(1.03, 0.97, 1.03), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", base, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_flex_tweens[id] = tw

## The 24 offsets at Manhattan distance 1-2, built once.
var _ripple_cache: Array = []
func _ripple_offsets() -> Array:
	if _ripple_cache.is_empty():
		for x in range(-2, 3):
			for y in range(-2, 3):
				for z in range(-2, 3):
					var d: int = absi(x) + absi(y) + absi(z)
					if d >= 1 and d <= 2:
						_ripple_cache.append(Vector3i(x, y, z))
	return _ripple_cache
