extends Control

## A little wooden cog bezel drawn behind a hotbar icon (2D, zero 3D cost) — the
## tool strip reads as a rack of interlocking cogs. Only the selected/hovered
## bezel turns (material_ui advances `rot` + calls queue_redraw), matching the
## file's freeze-everything-but-selected perf discipline. Selected = salmon rim.

const TEETH := 10
const WOOD := Color(0.478, 0.353, 0.227)          # #7a5a3a
const RIM := Color(0.792, 0.659, 0.471)           # #caa878
const SALMON := Color(0.878, 0.478, 0.372)

var rot: float = 0.0
var selected: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r_out: float = min(size.x, size.y) * 0.56
	var r_in: float = r_out * 0.82
	var pts := PackedVector2Array()
	var n: int = TEETH * 3
	for i in n:
		var seg: int = i % 3
		var rr: float = r_out if seg == 1 else (r_out if seg == 2 else r_in)
		var a: float = rot + TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, WOOD)
	# rim highlight ring
	draw_arc(c, r_in * 0.9, 0.0, TAU, 20, SALMON if selected else RIM, 2.0, true)
	# hub
	draw_circle(c, r_in * 0.34, RIM if selected else WOOD.lightened(0.1))
