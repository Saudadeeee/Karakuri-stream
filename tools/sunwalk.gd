extends Node

## `U` walks the sun 30 degrees. Twelve presses is a full circle, so twelve
## presses must put it back exactly where it started. Reported: hammer `U` and
## the light never comes back.
##
## Presses it and prints the sun's forward vector, so drift can be seen rather
## than argued about.
##   godot --headless --path . tools/sunwalk.tscn

func _ready() -> void:
	var game: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	for _f in range(10):
		await get_tree().process_frame

	var sun: DirectionalLight3D = game.get_node("DirectionalLight3D")
	var start: Vector3 = -sun.global_transform.basis.z
	print("SUN start  dir=(%.6f, %.6f, %.6f)" % [start.x, start.y, start.z])

	# Drive it the way a keyboard does, through _unhandled_input, so the echo
	# guard is exercised too rather than bypassed.
	var real := InputEventKey.new()
	real.keycode = KEY_U
	real.pressed = true
	var echo := InputEventKey.new()
	echo.keycode = KEY_U
	echo.pressed = true
	echo.echo = true

	game._unhandled_input(echo)
	game._unhandled_input(echo)
	game._unhandled_input(echo)
	var after_echo: Vector3 = -sun.global_transform.basis.z
	print("SUN three ECHO events moved it by %.6f (must be 0)" % after_echo.distance_to(start))

	for press in range(1, 121):
		game._unhandled_input(real)
		if press % 12 != 0:
			continue
		var d: Vector3 = -sun.global_transform.basis.z
		var b: Basis = sun.global_transform.basis
		# How far from the start, and how far the basis has drifted from being a
		# clean rotation (orthonormal, unit scale).
		var err: float = d.distance_to(start)
		var scale: Vector3 = b.get_scale()
		var ortho: float = absf(b.x.dot(b.y)) + absf(b.x.dot(b.z)) + absf(b.y.dot(b.z))
		print("SUN after %3d presses  dir=(%.6f, %.6f, %.6f)  off_by=%.6f  scale=(%.5f, %.5f, %.5f)  non_ortho=%.6f"
				% [press, d.x, d.y, d.z, err, scale.x, scale.y, scale.z, ortho])
	print("SUN DONE")
	get_tree().quit()
