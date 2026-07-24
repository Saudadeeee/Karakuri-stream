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
var _gear_creak := preload("res://assets/sounds/461166__hisoul__wooden-gear-lq-5-sprocket-rattling.wav")
var _water_flow := preload("res://assets/sounds/249666__tymorafarr__water-stream-looped.ogg")
const JELLY_BOUNCE: AudioStream = preload("res://assets/sounds/463590__mixtos__jellybounce.wav")

# Equal-tempered ratios for C D E G A relative to root note (pentatonic scale).
const PENTATONIC_RATIOS: Array[float] = [1.0, 1.1225, 1.2599, 1.4983, 1.6818]

var _pool: Array[AudioStreamPlayer3D] = []
var _next_index: int = 0

func _ready() -> void:
	_water_flow.loop = true
	_gear_creak.loop_mode = AudioStreamWAV.LOOP_FORWARD
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)

func _get_free_player() -> AudioStreamPlayer3D:
	for player in _pool:
		if not player.playing:
			return player
	var player: AudioStreamPlayer3D = _pool[_next_index]
	_next_index = (_next_index + 1) % _pool.size()
	return player

func play_wood_hit(global_pos: Vector3) -> void:
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = WOOD_HIT
	player.pitch_scale = randf_range(0.94, 1.06)
	player.volume_db = randf_range(-3.0, 0.0)
	player.play()

## Wood knock at an exact pitch — the karakuri percussion palette is all one
## wood sample at different speeds (drum = slow/deep, shishi = bright "cốc").
func play_wood_pitch(global_pos: Vector3, pitch: float, vol_db: float = 0.0) -> void:
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = WOOD_HIT
	player.pitch_scale = pitch * randf_range(0.97, 1.03)
	player.volume_db = vol_db + randf_range(-1.5, 0.0)
	player.play()

## Deep taiko boom.
func play_drum(global_pos: Vector3) -> void:
	play_wood_pitch(global_pos, 0.52, 2.5)

## Shishi-odoshi tipping back: the classic double knock — "cộc… cốc!".
func play_shishi_knock(global_pos: Vector3) -> void:
	play_wood_pitch(global_pos, 1.45, 0.5)
	get_tree().create_timer(0.16).timeout.connect(
		play_wood_pitch.bind(global_pos, 0.85, 2.0))

## Music-box tinkle: the chime an octave up, quiet and delicate.
func play_music_box_note(global_pos: Vector3, note_index: int) -> void:
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = CHIME
	player.pitch_scale = PENTATONIC_RATIOS[note_index % PENTATONIC_RATIOS.size()] * 2.0
	player.volume_db = -9.0
	player.play()

## A soft, springy "boing" for the jelly block — on placement and whenever a
## water stream lands on it. Wide pitch jitter keeps it playful, never annoying.
func play_jelly_bounce(global_pos: Vector3) -> void:
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = JELLY_BOUNCE
	player.pitch_scale = randf_range(0.88, 1.18)
	player.volume_db = randf_range(-5.0, -1.5)
	player.play()

func play_chime(global_pos: Vector3, note_index: int = -1) -> void:
	var index: int = note_index if note_index >= 0 else randi() % PENTATONIC_RATIOS.size()
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = CHIME
	player.pitch_scale = PENTATONIC_RATIOS[index] * randf_range(0.99, 1.01)
	player.volume_db = randf_range(-2.0, 1.0)
	player.play()

## A soft, non-positional pentatonic note for the generative ambient music
## (AmbientMusic). Spans two octaves for a gentle wandering melody.
func play_ambient_note() -> void:
	# A soft low root note, sometimes with a gentle harmony a pentatonic step up —
	# warmer and more musical than a single ping.
	_ambient_one(PENTATONIC_RATIOS.pick_random() * (0.5 if randf() < 0.7 else 0.25), randf_range(-8.0, -4.0))
	if randf() < 0.4:
		_ambient_one(PENTATONIC_RATIOS.pick_random() * 1.0, randf_range(-13.0, -9.0))

func _ambient_one(pitch: float, vol: float) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.stream = CHIME
	player.pitch_scale = pitch * randf_range(0.99, 1.01)
	player.volume_db = vol
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func make_water_loop_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = "SFX"
	player.stream = _water_flow
	player.pitch_scale = randf_range(0.95, 1.05)
	player.volume_db = -4.0
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
	player.volume_db = -19.0
	player.unit_size = 4.0
	player.max_distance = 0.0
	return player
