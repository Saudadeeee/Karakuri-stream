extends Node

const POOL_SIZE: int = 20

const WOOD_HIT: AudioStream = preload("res://assets/sounds/218460__thomasjaunism__wood-block-hit.wav")
const CHIME: AudioStream = preload("res://assets/sounds/517660__samuelgremaud__chimes-5.wav")
var _water_flow := preload("res://assets/sounds/249666__tymorafarr__water-stream-looped.ogg")

# Equal-tempered ratios for C D E G A relative to root note (pentatonic scale).
const PENTATONIC_RATIOS: Array[float] = [1.0, 1.1225, 1.2599, 1.4983, 1.6818]

var _pool: Array[AudioStreamPlayer3D] = []
var _next_index: int = 0

func _ready() -> void:
	_water_flow.loop = true
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = "Master"
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
	player.pitch_scale = randf_range(0.95, 1.05)
	player.volume_db = randf_range(-2.0, 1.0)
	player.play()

func play_chime(global_pos: Vector3, note_index: int = -1) -> void:
	var index: int = note_index if note_index >= 0 else randi() % PENTATONIC_RATIOS.size()
	var player: AudioStreamPlayer3D = _get_free_player()
	player.global_position = global_pos
	player.stream = CHIME
	player.pitch_scale = PENTATONIC_RATIOS[index] * randf_range(0.98, 1.02)
	player.volume_db = randf_range(-2.0, 1.0)
	player.play()

func make_water_loop_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = "Master"
	player.stream = _water_flow
	player.pitch_scale = randf_range(0.95, 1.05)
	player.volume_db = -3.0
	player.unit_size = 6.0
	player.max_distance = 0.0
	return player
