class_name MapThemes
extends RefCounted

## Map theme registry. One sandbox gameplay, several MAPS — each theme recolours
## the whole diorama (sky, fog, sun, island, mountains, foliage, drifting
## particles, feature tree) so a player can tell them apart at a glance:
##   0 Vườn Xuân   — pastel pink sky, sakura, pink petals (the original)
##   1 Rừng Thu    — warm amber sky, orange foliage, falling maple leaves
##   2 Đồi Tuyết   — cold blue-white, snowy island, drifting snow
##   3 Đêm Đom Đóm — indigo night, warm lanterns, glowing fireflies
## Chosen on the main menu, persisted in user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"

static var current: int = 0

const THEMES: Array = [
	{
		"name": "Spring",
		"sky_top": Color(0.42, 0.72, 0.71), "sky_horizon": Color(0.92, 0.78, 0.79),
		"fog_color": Color(0.9, 0.82, 0.85), "fog_density": 0.006,
		"sun_color": Color(1.0, 0.98, 0.92), "sun_energy": 0.9, "ambient_energy": 0.28,
		"island_top": Color(0.55, 0.58, 0.44), "island_base": Color(0.4, 0.3, 0.22),
		"mountain_tint": Color(1, 1, 1),
		"foliage": Color(),  # keep authored greens
		"feature": "sakura",
		"drift": {"color": Color(0.96, 0.72, 0.84), "size": Vector2(0.13, 0.09),
			"gravity": -0.22, "amount": 22, "glow": false},
		"cloud_sea": Color(0.96, 0.85, 0.88),
		"mechanism": {"wood": Color("d4a373"), "glow": 0.0, "teeth": 20, "mech_strength": 0.55},
	},
	{
		"name": "Autumn",
		"sky_top": Color(0.78, 0.55, 0.38), "sky_horizon": Color(0.97, 0.80, 0.55),
		"fog_color": Color(0.95, 0.80, 0.60), "fog_density": 0.008,
		"sun_color": Color(1.0, 0.85, 0.65), "sun_energy": 1.0, "ambient_energy": 0.25,
		"island_top": Color(0.62, 0.50, 0.30), "island_base": Color(0.38, 0.26, 0.18),
		"mountain_tint": Color(1.0, 0.88, 0.76),
		"foliage": Color(0.85, 0.45, 0.18),  # maple orange
		"feature": "maple",
		"drift": {"color": Color(0.85, 0.42, 0.14), "size": Vector2(0.18, 0.18),
			"gravity": -0.35, "amount": 26, "glow": false},
		"cloud_sea": Color(0.95, 0.82, 0.58),
		"mechanism": {"wood": Color("6e4a2e"), "glow": 0.0, "teeth": 20, "mech_strength": 0.7},
	},
	{
		"name": "Snow",
		"sky_top": Color(0.55, 0.68, 0.82), "sky_horizon": Color(0.88, 0.92, 0.96),
		"fog_color": Color(0.88, 0.92, 0.96), "fog_density": 0.011,
		"sun_color": Color(0.92, 0.96, 1.0), "sun_energy": 0.8, "ambient_energy": 0.34,
		"island_top": Color(0.90, 0.93, 0.95), "island_base": Color(0.52, 0.56, 0.62),
		"mountain_tint": Color(1, 1, 1),
		"foliage": Color(0.80, 0.88, 0.90),  # frosted
		"feature": "pine",
		"drift": {"color": Color(0.98, 0.99, 1.0), "size": Vector2(0.10, 0.10),
			"gravity": -0.28, "amount": 34, "glow": false},
		"cloud_sea": Color(0.95, 0.97, 1.0),
		"mechanism": {"wood": Color("bdbdbd"), "glow": 0.0, "teeth": 22, "mech_strength": 0.0},
	},
	{
		"name": "Night",
		"sky_top": Color(0.10, 0.12, 0.28), "sky_horizon": Color(0.30, 0.24, 0.42),
		"fog_color": Color(0.22, 0.20, 0.36), "fog_density": 0.010,
		"sun_color": Color(0.72, 0.78, 1.0), "sun_energy": 0.35, "ambient_energy": 0.19,
		"island_top": Color(0.30, 0.36, 0.32), "island_base": Color(0.20, 0.17, 0.15),
		"mountain_tint": Color(0.55, 0.58, 0.75),
		"foliage": Color(0.16, 0.30, 0.28),  # moonlit teal-green
		"feature": "pine",
		"drift": {"color": Color(1.0, 0.92, 0.45), "size": Vector2(0.07, 0.07),
			"gravity": 0.05, "amount": 30, "glow": true},
		"cloud_sea": Color(0.20, 0.20, 0.34),
		"mechanism": {"wood": Color("b08d57"), "glow": 0.35, "teeth": 18, "mech_strength": 0.5},
	},
]

static func theme() -> Dictionary:
	return THEMES[clampi(current, 0, THEMES.size() - 1)]

static func mechanism() -> Dictionary:
	return THEMES[clampi(current, 0, THEMES.size() - 1)].get("mechanism",
		{"wood": Color("d4a373"), "glow": 0.0, "teeth": 20, "mech_strength": 0.5})

static func count() -> int:
	return THEMES.size()

static func name_of(i: int) -> String:
	return THEMES[clampi(i, 0, THEMES.size() - 1)]["name"]

## Recolour an Environment + sun in place to the current theme (works on both
## the game scene's baked env and the menu backdrop's code-built env).
##
## This ALSO applies the colour grade, and it is the only place that does. The
## menu used to build its own environment with different glow and adjustment
## values from the ones baked into main.tscn, so the two screens were graded
## differently and pressing Play visibly shifted the picture. One function now
## owns the grade; the THEMES table owns only colours.
static func apply_environment(env: Environment, sun: DirectionalLight3D) -> void:
	var t: Dictionary = theme()
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var sm: ProceduralSkyMaterial = env.sky.sky_material
		sm.sky_top_color = t["sky_top"]
		sm.sky_horizon_color = t["sky_horizon"]
		# The island floats, so the camera spends most of its time looking DOWN and
		# the lower half of the sky sphere is most of the backdrop. Ground bottom
		# was only 6% darker than the horizon, which made that whole half a flat
		# wall of one colour with no depth to it. A real falloff gives the drop
		# below the island somewhere to recede into.
		sm.ground_horizon_color = t["sky_horizon"]
		sm.ground_bottom_color = t["sky_horizon"].darkened(0.26).lerp(t["sky_top"], 0.18)
		sm.ground_curve = 0.12
		sm.sky_curve = 0.22
	env.fog_light_color = t["fog_color"]
	env.fog_density = t["fog_density"]
	env.ambient_light_energy = t["ambient_energy"]
	if sun != null:
		sun.light_color = t["sun_color"]
		sun.light_energy = t["sun_energy"]
		# The floating mountains are large meshes hanging over the island, so at
		# full opacity their shadows land on the lawn as hard black ellipses that
		# read as dirt rather than shade. Soft and partial keeps the depth cue
		# without punching holes in a pastel picture.
		sun.shadow_opacity = 0.55
		sun.shadow_blur = 3.2
		sun.directional_shadow_blend_splits = true
	apply_grade(env)

## The picture was washing out to near-white: pale mountains, a bleached island,
## almost no contrast. Three things were stacking up, and none of them is wrong
## on its own — together they blew the whole frame out:
##
##   glow_bloom 0.15   Bloom that low starts bleeding from MID-TONES, not just
##                     highlights. In a pastel palette almost everything is a
##                     bright mid-tone, so the glow pass smeared white over the
##                     entire image. This was the biggest single cause.
##   ambient 0.45 +    Sun 0.9 plus fill 0.22 plus a 0.45 grey ambient puts total
##   sun 0.9 + fill    illumination well over 1.0, so pale albedos (island 0.55,
##                     house plaster 0.95) clip before the tonemapper sees them.
##   FILMIC            Rolls highlights off softly but desaturates as it does,
##                     which is the opposite of what already-pale colours need.
##
## Fix: bloom off with a threshold above 1.0 so ONLY genuinely overbright things
## glow (night lanterns still do), less ambient, and AGX, which holds hue and
## saturation into the highlights far better than FILMIC.
const GLOW_THRESHOLD := 1.05
const EXPOSURE := 1.02

static func apply_grade(env: Environment) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = EXPOSURE
	env.tonemap_white = 6.0
	# Keep the glow pass — the night lanterns and the water sparkle need it — but
	# gate it above white so it stops treating pastel daylight as a light source.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_hdr_scale = 1.6
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.34
	env.ssao_enabled = false          # gl_compatibility has no SSAO; make it explicit

static func save_current() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("map", "theme", current)
	cfg.save(SETTINGS_PATH)

static func load_current() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		current = clampi(int(cfg.get_value("map", "theme", 0)), 0, THEMES.size() - 1)
