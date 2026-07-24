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
		"sun_color": Color(1.0, 0.98, 0.92), "sun_energy": 0.9, "ambient_energy": 0.45,
		"island_top": Color(0.55, 0.58, 0.44), "island_base": Color(0.4, 0.3, 0.22),
		"mountain_tint": Color(1, 1, 1),
		"foliage": Color(),  # keep authored greens
		"feature": "sakura",
		"drift": {"color": Color(0.96, 0.72, 0.84), "size": Vector2(0.13, 0.09),
			"gravity": -0.22, "amount": 22, "glow": false},
	},
	{
		"name": "Autumn",
		"sky_top": Color(0.78, 0.55, 0.38), "sky_horizon": Color(0.97, 0.80, 0.55),
		"fog_color": Color(0.95, 0.80, 0.60), "fog_density": 0.008,
		"sun_color": Color(1.0, 0.85, 0.65), "sun_energy": 1.0, "ambient_energy": 0.4,
		"island_top": Color(0.62, 0.50, 0.30), "island_base": Color(0.38, 0.26, 0.18),
		"mountain_tint": Color(1.0, 0.88, 0.76),
		"foliage": Color(0.85, 0.45, 0.18),  # maple orange
		"feature": "maple",
		"drift": {"color": Color(0.85, 0.42, 0.14), "size": Vector2(0.18, 0.18),
			"gravity": -0.35, "amount": 26, "glow": false},
	},
	{
		"name": "Snow",
		"sky_top": Color(0.55, 0.68, 0.82), "sky_horizon": Color(0.88, 0.92, 0.96),
		"fog_color": Color(0.88, 0.92, 0.96), "fog_density": 0.011,
		"sun_color": Color(0.92, 0.96, 1.0), "sun_energy": 0.8, "ambient_energy": 0.55,
		"island_top": Color(0.90, 0.93, 0.95), "island_base": Color(0.52, 0.56, 0.62),
		"mountain_tint": Color(1, 1, 1),
		"foliage": Color(0.80, 0.88, 0.90),  # frosted
		"feature": "pine",
		"drift": {"color": Color(0.98, 0.99, 1.0), "size": Vector2(0.10, 0.10),
			"gravity": -0.28, "amount": 34, "glow": false},
	},
	{
		"name": "Night",
		"sky_top": Color(0.10, 0.12, 0.28), "sky_horizon": Color(0.30, 0.24, 0.42),
		"fog_color": Color(0.22, 0.20, 0.36), "fog_density": 0.010,
		"sun_color": Color(0.72, 0.78, 1.0), "sun_energy": 0.35, "ambient_energy": 0.3,
		"island_top": Color(0.30, 0.36, 0.32), "island_base": Color(0.20, 0.17, 0.15),
		"mountain_tint": Color(0.55, 0.58, 0.75),
		"foliage": Color(0.16, 0.30, 0.28),  # moonlit teal-green
		"feature": "pine",
		"drift": {"color": Color(1.0, 0.92, 0.45), "size": Vector2(0.07, 0.07),
			"gravity": 0.05, "amount": 30, "glow": true},
	},
]

static func theme() -> Dictionary:
	return THEMES[clampi(current, 0, THEMES.size() - 1)]

static func count() -> int:
	return THEMES.size()

static func name_of(i: int) -> String:
	return THEMES[clampi(i, 0, THEMES.size() - 1)]["name"]

## Recolour an Environment + sun in place to the current theme (works on both
## the game scene's baked env and the menu backdrop's code-built env).
static func apply_environment(env: Environment, sun: DirectionalLight3D) -> void:
	var t: Dictionary = theme()
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var sm: ProceduralSkyMaterial = env.sky.sky_material
		sm.sky_top_color = t["sky_top"]
		sm.sky_horizon_color = t["sky_horizon"]
		sm.ground_bottom_color = t["sky_horizon"].darkened(0.06)
		sm.ground_horizon_color = t["sky_horizon"]
	env.fog_light_color = t["fog_color"]
	env.fog_density = t["fog_density"]
	env.ambient_light_energy = t["ambient_energy"]
	if sun != null:
		sun.light_color = t["sun_color"]
		sun.light_energy = t["sun_energy"]

static func save_current() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("map", "theme", current)
	cfg.save(SETTINGS_PATH)

static func load_current() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		current = clampi(int(cfg.get_value("map", "theme", 0)), 0, THEMES.size() - 1)
