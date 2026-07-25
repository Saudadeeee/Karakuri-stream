extends Node

## The sculpted floating island — replaces the old poker-chip cylinder pair in
## BOTH the menu backdrop and the game scene (this is an autoload, so one mesh
## serves wherever the camera is). Noise-rimmed edge, gently domed top, an
## overhung lip, a jagged underbelly tapering to an off-centre tip, root-rocks
## welded under the rim, and two bobbing rock shards beneath. Deterministic
## seed → identical silhouette every launch. Rebuilt (cheap, ~1.5k tris) on
## theme switch for the theme's island colours.

const SEED := 20260725
const SEGS := 48

var _root: Node3D
var _shards: Array[Node3D] = []
var _heart_gear: MeshInstance3D          # the clockwork heart under the island
var _time := 0.0

func _ready() -> void:
	_root = Node3D.new()
	add_child(_root)
	rebuild()

func _process(delta: float) -> void:
	_time += delta
	for i in _shards.size():
		var s: Node3D = _shards[i]
		if is_instance_valid(s):
			s.position.y = s.get_meta("base_y") + sin(_time * 0.3 + i * 2.1) * 0.3
	if is_instance_valid(_heart_gear):
		_heart_gear.rotate_y(delta * 0.03)   # glacial ~35s/rev

## Wipe + rebuild for the current theme's island colours.
func rebuild() -> void:
	for c in _root.get_children():
		c.queue_free()
	_shards.clear()
	var t: Dictionary = MapThemes.theme()
	var top_col: Color = t["island_top"]
	var base_col: Color = t["island_base"]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	# THE CLOCKWORK HEART: one giant wooden cog turning under the island, wider
	# than the rim so its tooth-tips peek past the silhouette from every angle —
	# the karakuri soul, always visible. Wood colour per theme mechanism.
	var mech: Dictionary = MapThemes.mechanism()
	var wood: Color = mech["wood"]
	# Sized WIDER than the belly at this depth so the tooth-tips poke past the
	# island's silhouette all the way round (belly radius ≈ 7.6 at y=-1.2).
	_heart_gear = MeshInstance3D.new()
	_heart_gear.mesh = GearMesh.build(int(mech["teeth"]), 8.8, 7.7, 2.0, 0.8,
		wood.darkened(0.08), wood.darkened(0.22))
	_heart_gear.material_override = GearMesh.material()
	_heart_gear.rotation.x = -PI / 2.0   # lay the cog flat (axis = world Y)
	_heart_gear.position.y = -1.2
	_root.add_child(_heart_gear)
	if float(mech["glow"]) > 0.0:
		var gm: StandardMaterial3D = _heart_gear.material_override
		gm.emission_enabled = true
		gm.emission = wood
		gm.emission_energy_multiplier = float(mech["glow"]) * 0.5

	# Main body + root rocks + shards.
	_root.add_child(_island_mesh(top_col, base_col, rng, 9.0, Vector3(0.8, -7.0, 0.5)))
	for i in 5:
		var rock := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.7, 1.4), rng.randf_range(0.9, 1.8), rng.randf_range(0.7, 1.4))
		rock.mesh = bm
		var ang: float = rng.randf_range(0.0, TAU)
		var rr: float = rng.randf_range(6.5, 8.6)
		rock.position = Vector3(cos(ang) * rr, rng.randf_range(-1.6, -0.6), sin(ang) * rr)
		rock.rotation = Vector3(rng.randf_range(-0.3, 0.3), ang, rng.randf_range(-0.3, 0.3))
		rock.material_override = _matte(base_col.darkened(0.12))
		_root.add_child(rock)
	for i in 2:
		var shard := Node3D.new()
		var mi := _island_mesh(top_col, base_col, rng, rng.randf_range(0.8, 1.5), Vector3(0, -2.2, 0))
		shard.add_child(mi)
		var ang2: float = rng.randf_range(0.0, TAU)
		var rr2: float = rng.randf_range(5.5, 7.5)
		var base_y: float = rng.randf_range(-8.0, -4.0)
		shard.position = Vector3(cos(ang2) * rr2, base_y, sin(ang2) * rr2)
		shard.set_meta("base_y", base_y)
		_root.add_child(shard)
		_shards.append(shard)

## One island body: domed top cap, noisy rim, overhang lip, jagged underbelly
## to an off-centre tip. Vertex colours lerp top→base by depth.
func _island_mesh(top_col: Color, base_col: Color, rng: RandomNumberGenerator, radius: float, tip: Vector3) -> MeshInstance3D:
	var rim: Array[float] = []
	for i in SEGS:
		rim.append(radius + rng.randf_range(0.0, 0.5))   # only ADDS outward

	# Ring stack: centre-dome → mid top ring → rim (y 0) → lip → 3 under rings → tip.
	var rings: Array = []   # each: {pts: Array[Vector3], col: Color}
	rings.append({"pts": _ring(rim, 0.45, 0.12), "col": top_col})
	rings.append({"pts": _ring(rim, 1.0, 0.0), "col": top_col})
	rings.append({"pts": _ring_scaled(rim, 1.033, -0.4), "col": base_col.lerp(top_col, 0.35)})
	rings.append({"pts": _ring_jitter(rim, 0.72, -2.2, rng, tip)})
	rings.append({"pts": _ring_jitter(rim, 0.42, -4.2, rng, tip)})
	rings.append({"pts": _ring_jitter(rim, 0.16, -5.8, rng, tip)})
	rings[3]["col"] = base_col
	rings[4]["col"] = base_col.darkened(0.1)
	rings[5]["col"] = base_col.darkened(0.2)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Top cap fan: dome centre → first ring.
	var dome := Vector3(0, 0.15, 0)
	var r0: Array = rings[0]["pts"]
	for i in SEGS:
		var j: int = (i + 1) % SEGS
		st.set_color(top_col.lightened(0.05))
		st.add_vertex(dome)
		st.set_color(top_col)
		st.add_vertex(r0[i])
		st.set_color(top_col)
		st.add_vertex(r0[j])
	# Ring strips.
	for k in rings.size() - 1:
		var a: Array = rings[k]["pts"]
		var b: Array = rings[k + 1]["pts"]
		var ca: Color = rings[k]["col"]
		var cb: Color = rings[k + 1]["col"]
		for i in SEGS:
			var j: int = (i + 1) % SEGS
			st.set_color(ca); st.add_vertex(a[i])
			st.set_color(cb); st.add_vertex(b[i])
			st.set_color(ca); st.add_vertex(a[j])
			st.set_color(ca); st.add_vertex(a[j])
			st.set_color(cb); st.add_vertex(b[i])
			st.set_color(cb); st.add_vertex(b[j])
	# Bottom fan to the tip.
	var last: Array = rings[rings.size() - 1]["pts"]
	for i in SEGS:
		var j: int = (i + 1) % SEGS
		st.set_color(base_col.darkened(0.25))
		st.add_vertex(last[i])
		st.add_vertex(tip)
		st.add_vertex(last[j])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mi.material_override = m
	return mi

func _ring(rim: Array[float], scale: float, y: float) -> Array:
	var pts: Array = []
	for i in SEGS:
		var ang: float = TAU * float(i) / SEGS
		pts.append(Vector3(cos(ang) * rim[i] * scale, y, sin(ang) * rim[i] * scale))
	return pts

func _ring_scaled(rim: Array[float], mul: float, y: float) -> Array:
	var pts: Array = []
	for i in SEGS:
		var ang: float = TAU * float(i) / SEGS
		pts.append(Vector3(cos(ang) * rim[i] * mul, y, sin(ang) * rim[i] * mul))
	return pts

## Under-ring converging toward the tip with hash jitter — the jagged belly.
func _ring_jitter(rim: Array[float], scale: float, y: float, rng: RandomNumberGenerator, tip: Vector3) -> Array:
	var pts: Array = []
	for i in SEGS:
		var ang: float = TAU * float(i) / SEGS
		var r: float = rim[i] * scale * rng.randf_range(0.9, 1.1)
		var p := Vector3(cos(ang) * r, y + rng.randf_range(-0.25, 0.25), sin(ang) * r)
		pts.append(p.lerp(Vector3(tip.x, p.y, tip.z), 0.12))
	return pts

func _matte(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
