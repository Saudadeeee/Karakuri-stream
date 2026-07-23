class_name BlockMeshBuilder
extends RefCounted

## Builds a unit-cube mesh that skips faces facing a same-type neighbor, so
## adjacent same-type blocks read as one continuous mass instead of showing
## an internal seam (Townscaper-style merging, without full greedy meshing).

const HALF: float = 0.5

static func build(hidden_dirs: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_face_if_visible(st, hidden_dirs, Vector3i(1, 0, 0))
	_add_face_if_visible(st, hidden_dirs, Vector3i(-1, 0, 0))
	_add_face_if_visible(st, hidden_dirs, Vector3i(0, 1, 0))
	_add_face_if_visible(st, hidden_dirs, Vector3i(0, -1, 0))
	_add_face_if_visible(st, hidden_dirs, Vector3i(0, 0, 1))
	_add_face_if_visible(st, hidden_dirs, Vector3i(0, 0, -1))

	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _add_face_if_visible(st: SurfaceTool, hidden_dirs: Dictionary, dir: Vector3i) -> void:
	if hidden_dirs.has(dir):
		return

	var h := HALF
	var corners: Array[Vector3] = []
	if dir == Vector3i(1, 0, 0):
		corners = [Vector3(h, -h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(h, -h, h)]
	elif dir == Vector3i(-1, 0, 0):
		corners = [Vector3(-h, -h, h), Vector3(-h, h, h), Vector3(-h, h, -h), Vector3(-h, -h, -h)]
	elif dir == Vector3i(0, 1, 0):
		corners = [Vector3(-h, h, -h), Vector3(-h, h, h), Vector3(h, h, h), Vector3(h, h, -h)]
	elif dir == Vector3i(0, -1, 0):
		corners = [Vector3(-h, -h, h), Vector3(-h, -h, -h), Vector3(h, -h, -h), Vector3(h, -h, h)]
	elif dir == Vector3i(0, 0, 1):
		corners = [Vector3(h, -h, h), Vector3(h, h, h), Vector3(-h, h, h), Vector3(-h, -h, h)]
	elif dir == Vector3i(0, 0, -1):
		corners = [Vector3(-h, -h, -h), Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, -h, -h)]

	var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
