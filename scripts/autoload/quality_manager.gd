extends Node

## Platform quality profiles. The WEB build is the LITE edition — browsers
## (especially on laptops/phones) choke on the expensive gl_compatibility
## passes, so on web we trade the costliest effects for smoothness:
##   - shadows OFF (the single biggest WebGL cost)
##   - glow/bloom OFF (fullscreen post pass)
##   - the cool fill light OFF (each directional light re-draws every mesh)
##   - particle amounts halved, cloud sea subdivision halved
## Native desktop/Android keep the FULL look (native GL is far faster).

var lite: bool = false

func _ready() -> void:
	# `--  lite` forces the web profile on a desktop run. Not a convenience: this
	# autoload is second in the list, so it decides BEFORE every other autoload
	# builds its materials, and a tool that flips the flag from its own _ready is
	# already too late — it measures the FULL profile and reports it as the web
	# one. Which is exactly what happened while counting shader variants.
	lite = OS.has_feature("web") or OS.get_cmdline_user_args().has("lite")

## Called by each scene root after it builds its environment/lights.
func apply(root: Node, env: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D = null) -> void:
	if not lite:
		return
	if sun != null:
		sun.shadow_enabled = false
	if fill != null:
		fill.visible = false
	if env != null:
		env.glow_enabled = false
	# NOTE: no scaling_3d here — on WebGL compatibility it forces an offscreen
	# render target + upscale pass and is SLOWER than native-res direct-to-canvas
	# (measured: 65fps full vs 44fps with 0.85 scaling in headless Chrome).

## Scale a particle amount for the current profile.
func particles(amount: int) -> int:
	return maxi(amount / 2, 4) if lite else amount
