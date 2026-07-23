extends StaticBody3D

## Builds the gear's teeth as children of the spinning MeshInstance3D so the
## whole toothed wheel turns together when GearManager rotates that node.
## Kept as a scene script (not baked into the .tscn) so the tooth ring stays
## parametric — change TOOTH_COUNT and the gear rebuilds itself.

const TOOTH_COUNT: int = 10
const TOOTH_RADIUS: float = 0.42

func _ready() -> void:
	var hub: MeshInstance3D = $MeshInstance3D
	var material: Material = hub.get_surface_override_material(0)
	for i in TOOTH_COUNT:
		var tooth := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.13, 0.2, 0.11)
		tooth.mesh = box
		if material != null:
			tooth.material_override = material
		var a: float = TAU * float(i) / float(TOOTH_COUNT)
		tooth.position = Vector3(cos(a) * TOOTH_RADIUS, 0.0, sin(a) * TOOTH_RADIUS)
		tooth.rotation.y = -a
		hub.add_child(tooth)
