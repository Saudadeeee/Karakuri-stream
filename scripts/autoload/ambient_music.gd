extends Node

## Ambient soundscape director on the Music bus. Three layers, all feeding the
## Master reverb for the floating-island wash:
##  1. a soft looping CHILL MUSIC bed (a real relaxing track, low in the mix);
##  2. a very quiet RAIN layer for cosy texture;
##  3. generative pentatonic chime notes sprinkled on top at slow, irregular
##     gaps — consonant and non-repeating, so the melody never loops audibly.

const MIN_GAP: float = 2.2
const MAX_GAP: float = 5.5

# CC0 (public domain, OpenGameArt). Only the still ambient PAD is used as the
# bed — the synth/percussion track proved too lively and fought the water,
# knocks and chimes that ARE the game. The bed sits far below them.
const CHILL_BEDS: Array[AudioStream] = [
	preload("res://assets/sounds/chill_ambient.ogg"),
]
const RAIN_LAYER: AudioStream = preload("res://assets/sounds/rain_loop.ogg")

var _timer: float = 0.0
var _next_gap: float = 1.5   # first note comes in soon after start
var _rain: AudioStreamPlayer

## Rain sits differently in each map's soundscape: cosy and present in autumn,
## a whisper in spring/night, muted under snow (snow "absorbs" the world).
const RAIN_DB_BY_THEME: Array[float] = [-28.0, -18.0, -44.0, -24.0]

func _ready() -> void:
	_start_bed(CHILL_BEDS.pick_random(), -24.0)   # quiet pad, far under the toy
	_rain = _start_bed(RAIN_LAYER, -25.0)         # faint rain texture
	apply_theme_mix()

## Retune the ambience mix to the current map theme (menu calls this when the
## player switches cards; the game scene applies it on load).
func apply_theme_mix() -> void:
	if is_instance_valid(_rain):
		var tw := create_tween()
		tw.tween_property(_rain, "volume_db",
			RAIN_DB_BY_THEME[clampi(MapThemes.current, 0, RAIN_DB_BY_THEME.size() - 1)], 1.2)

## Start one looping ambience layer on the Music bus. Loops the stream in place
## (ogg/mp3 both expose `loop`) so it never gaps.
func _start_bed(stream: AudioStream, vol: float) -> AudioStreamPlayer:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.stream = stream
	player.volume_db = vol
	add_child(player)
	player.play()
	return player

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _next_gap:
		_timer = 0.0
		_next_gap = randf_range(MIN_GAP, MAX_GAP)
		AudioManager.play_ambient_note()
