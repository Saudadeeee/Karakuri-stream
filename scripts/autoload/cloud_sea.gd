extends Node

## The sea of clouds below the floating island — a single vertex-animated
## plane (one draw call) that makes the island finally read as FLOATING:
## waterfalls plunge into it, the backdrop mountains rise out of it. Theme-
## tinted (pink dawn / golden haze / white / moonlit indigo).

const SHADER: Shader = preload("res://shaders/cloudsea.gdshader")

var _mat: ShaderMaterial
var _mesh: MeshInstance3D

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	var subdiv: int = 20 if QualityManager.lite else 40
	plane.subdivide_width = subdiv
	plane.subdivide_depth = subdiv
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = -1   # transparent streams must sort above the sea
	_mesh = MeshInstance3D.new()
	_mesh.mesh = plane
	_mesh.material_override = _mat
	_mesh.position = Vector3(0, -14.5, 0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	apply_theme()

## Called wherever the theme changes (menu cards / game load).
func apply_theme() -> void:
	var t: Dictionary = MapThemes.theme()
	_mat.set_shader_parameter("cloud_color", t.get("cloud_sea", Color(0.96, 0.85, 0.88)))
