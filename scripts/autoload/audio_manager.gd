extends Node

## Central sound. Everything routes through the "SFX" bus (ambient music uses
## the "Music" bus) which both feed the Master bus's Reverb — so every knock,
## chime and trickle rings out with the spacious, floating-island ASMR wash.
## Two humanisation tricks keep repeated sounds from fatiguing the ear:
##  - small random pitch + volume jitter on every one-shot;
##  - the bell is pitched to a PENTATONIC scale, so any rhythm the player taps
##    out stays consonant and relaxing (never sour), Eastern-flavoured.

const POOL_SIZE: int = 24

const WOOD_HIT: AudioStream = preload("res://assets/sounds/218460__thomasjaunism__wood-block-hit.wav")
const CHIME: AudioStream = preload("res://assets/sounds/517660__samuelgremaud__chimes-5.wav")
var _gear_creak := preload("res://assets/sounds/461166__hisoul__wooden-gear-lq-5-sprocket-rattling.ogg")
var _water_flow := preload("res://assets/sounds/249666__tymorafarr__water-stream-looped.ogg")
const JELLY_BOUNCE: AudioStream = preload("res://assets/sounds/463590__mixtos__jellybounce.wav")
# Synthesized in-house (rfxgen + ffmpeg) — see CREDITS.md.
const TAIKO: AudioStream = preload("res://assets/sounds/taiko_boom.ogg")
const TINE: AudioStream = preload("res://assets/sounds/music_box_tine.ogg")
const SPLASH: AudioStream = preload("res://assets/sounds/splash_soft.ogg")
const PLOP: AudioStream = preload("res://assets/sounds/water_plop.ogg")
const UI_POP: AudioStream = preload("res://assets/sounds/ui_pop.ogg")
const FLUTTER: AudioStream = preload("res://assets/sounds/paper_flutter.ogg")

# Equal-tempered ratios for C D E G A relative to root note (pentatonic scale).
const PENTATONIC_RATIOS: Array[float] = [1.0, 1.1225, 1.2599, 1.4983, 1.6818]

var _pool: Array[AudioStreamPlayer3D] = []
var _next_index: int = 0
## Anti-machine-gun: identical one-shots landing within a few ms fuse into a
## loud phasey burst. Track the last start per sound kind and skip repeats
## inside the window (a third simultaneous knock adds nothing but mud).
var _last_start: Dictionary = {}   # kind -> msec
const DEDUPE_MS: int = 35

func _ready() -> void:
	_water_flow.loop = true
	_gear_creak.loop = true
	# NOTE: the UI pop is wired in CuteButton, not here. A tree-wide node_added
	# hook used to connect every Button as well, so each button had TWO paths into
	# play_ui_pop and only the 35 ms dedupe hid it — and the blunt hook could not
	# know that a grid of small icons should hover quietly.
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = "SFX"
		# 3D feel: a touch more stereo panning and a gentler distance curve, so
		# knocks across the island stay audible but clearly placed left/right.
		player.panning_strength = 1.4
		player.unit_size = 8.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		add_child(player)
		_pool.append(player)

## Alt-tabbing away used to leave the garden playing into an empty desktop. The
## Master bus ducks instead of muting so coming back is a fade, not a click, and
## the player's own volume is untouched — the offset is applied on top of it.
##
## Off by default is wrong for a game people leave running on purpose, so it is a
## setting; on by default because a background window that keeps making noise is
## the more common complaint.
const UNFOCUSED_DUCK_DB: float = -32.0
const SETTINGS_PATH: String = "user://settings.cfg"

var _ducked: bool = false

func duck_when_unfocused() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return true
	return bool(cfg.get_value("audio", "duck_unfocused", true))

func set_duck_when_unfocused(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "duck_unfocused", on)
	cfg.save(SETTINGS_PATH)
	if not on and _ducked:
		_set_duck(false)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if duck_when_unfocused():
				_set_duck(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_set_duck(false)

func _set_duck(on: bool) -> void:
	if on == _ducked:
		return
	_ducked = on
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	# Relative, so a player who set Master to 30% comes back to 30%.
	var db: float = AudioServer.get_bus_volume_db(idx)
	AudioServer.set_bus_volume_db(idx, db + (UNFOCUSED_DUCK_DB if on else -UNFOCUSED_DUCK_DB))

func _can_start(kind: String) -> bool:
	var now: int = Time.get_ticks_msec()
	if now - int(_last_start.get(kind, -1000)) < DEDUPE_MS:
		return false
	_last_start[kind] = now
	return true

func _get_free_player() -> AudioStreamPlayer3D:
	for player in _pool:
		if not player.playing:
			return player
	var player: AudioStreamPlayer3D = _pool[_next_index]
	_next_index = (_next_index + 1) % _pool.size()
	return player

## Wood knock at an exact pitch — the karakuri percussion palette is all one
## wood sample at different speeds (drum = slow/deep, shishi = bright "cốc").
func play_wood_pitch(global_pos: Vector3, pitch: float, vol_db: float = 0.0) -> void:
	if not _can_start("wood%.1f" % pitch):
		return
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = WOOD_HIT
	player.pitch_scale = pitch * randf_range(0.97, 1.03)
	player.volume_db = vol_db + randf_range(-1.5, 0.0)
	player.play()

## Marimba-island note: a wood knock pitched to a pentatonic degree (placement
## maps the cell's HEIGHT to the degree, so stacking plays an ascending run).
## Clamped — wood past ~2.2× goes chipmunk-thin.
func play_wood_note(global_pos: Vector3, degree: int, octave_up: bool, base_pitch: float = 1.0, vol_db: float = 0.0) -> void:
	var p: float = base_pitch * PENTATONIC_RATIOS[degree % PENTATONIC_RATIOS.size()] * (2.0 if octave_up else 1.0)
	play_wood_pitch(global_pos, clampf(p, 0.6, 2.2), vol_db)

## Deep taiko boom.
func play_drum(global_pos: Vector3) -> void:
	if not _can_start("drum"):
		return
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = TAIKO
	player.pitch_scale = randf_range(0.92, 1.06)
	player.volume_db = randf_range(-2.0, -0.5)
	player.play()

## Shishi-odoshi tipping back: the classic double knock — "cộc… cốc!".
func play_shishi_knock(global_pos: Vector3) -> void:
	play_wood_pitch(global_pos, 1.45, -0.5)
	get_tree().create_timer(0.16).timeout.connect(
		play_wood_pitch.bind(global_pos, 0.85, 0.5))

## Music-box tine, pitched to the pentatonic degree. The sample is already the
## high root — no octave shift.
func play_music_box_note(global_pos: Vector3, note_index: int) -> void:
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = TINE
	player.pitch_scale = PENTATONIC_RATIOS[note_index % PENTATONIC_RATIOS.size()]
	player.volume_db = -5.5
	player.play()

## A soft, springy "boing" for the jelly block — on placement and whenever a
## water stream lands on it. Wide pitch jitter keeps it playful, never annoying.
func play_jelly_bounce(global_pos: Vector3) -> void:
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = JELLY_BOUNCE
	player.pitch_scale = randf_range(0.88, 1.18)
	player.volume_db = randf_range(-11.0, -7.5)
	player.play()

## Watery "bloop" for placing a water block.
func play_water_plop(global_pos: Vector3) -> void:
	if not _can_start("plop"):
		return
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = PLOP
	player.pitch_scale = randf_range(0.9, 1.12)
	player.volume_db = randf_range(-17.5, -15.5)
	player.play()

## Soft splash: stream on open water, koi re-entry, water landing on ground.
## `deep` pitches it down into a low plop — for sounds that repeat on the beat
## forever, where any brightness turns abrasive.
func play_splash(global_pos: Vector3, vol_db: float = -8.0, deep: bool = false) -> void:
	if not _can_start("splash"):
		return
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = SPLASH
	player.pitch_scale = randf_range(0.7, 0.9) if deep else randf_range(0.9, 1.15)
	player.volume_db = vol_db + randf_range(-1.5, 0.0)
	player.play()

## Paper flutter for the pinwheel.
func play_flutter(global_pos: Vector3) -> void:
	if not _can_start("flutter"):
		return
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = FLUTTER
	player.pitch_scale = randf_range(0.95, 1.2)
	player.volume_db = randf_range(-10.0, -7.0)
	player.play()

## UI pop, non-positional (a 3D player would pan/fade with the camera).
## `up` = brighter hover pitch.
func play_ui_pop(up: bool = false) -> void:
	if not _can_start("ui%s" % ("u" if up else "d")):
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = UI_POP
	player.pitch_scale = (1.3 if up else 1.0) * randf_range(0.985, 1.015)
	player.volume_db = -31.5 if up else -23.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_chime(global_pos: Vector3, note_index: int = -1, pitch_mul: float = 1.0) -> void:
	var index: int = note_index if note_index >= 0 else randi() % PENTATONIC_RATIOS.size()
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = CHIME
	player.pitch_scale = PENTATONIC_RATIOS[index] * pitch_mul * randf_range(0.99, 1.01)
	player.volume_db = randf_range(-1.5, 1.5)
	player.play()

func make_water_loop_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = "SFX"
	player.stream = _water_flow
	player.pitch_scale = randf_range(0.95, 1.05)
	player.volume_db = -13.0
	player.unit_size = 6.0
	player.max_distance = 0.0
	return player

## A looping wooden gear rattle ("kẽo kẹt"), positional, quiet — one per driven
## gear group (managed by GearManager). Slight pitch jitter so several don't phase.
func make_gear_loop_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = "SFX"
	player.stream = _gear_creak
	# Slower + quieter than the raw rattle so it reads as a gentle wooden creak,
	# not a noisy sprocket. Pitch jitter keeps several gears from phasing.
	player.pitch_scale = randf_range(0.62, 0.82)
	player.volume_db = -25.0
	player.unit_size = 4.0
	player.max_distance = 0.0
	return player
