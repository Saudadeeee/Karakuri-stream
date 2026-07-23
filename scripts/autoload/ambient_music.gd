extends Node

## Ambient soundscape director on the Music bus. Three layers, all feeding the
## Master reverb for the floating-island wash:
##  1. a soft looping CHILL MUSIC bed (a real relaxing track, low in the mix);
##  2. a very quiet RAIN layer for cosy texture;
##  3. generative pentatonic chime notes sprinkled on top at slow, irregular
##     gaps — consonant and non-repeating, so the melody never loops audibly.

const MIN_GAP: float = 2.2
const MAX_GAP: float = 5.5

# CC0 (public domain, OpenGameArt) — a relaxing bed; one is picked per session
# for a little variety.
const CHILL_BEDS: Array[AudioStream] = [
	preload("res://assets/sounds/chill_ambient.ogg"),
	preload("res://assets/sounds/chill_loop.mp3"),
]
const RAIN_LAYER: AudioStream = preload("res://assets/sounds/rain_loop.ogg")

var _timer: float = 0.0
var _next_gap: float = 1.5   # first note comes in soon after start

func _ready() -> void:
	_start_bed(CHILL_BEDS.pick_random(), -17.0)   # chill music, under the notes
	_start_bed(RAIN_LAYER, -25.0)                 # faint rain texture

## Start one looping ambience layer on the Music bus. Loops the stream in place
## (ogg/mp3 both expose `loop`) so it never gaps.
func _start_bed(stream: AudioStream, vol: float) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.stream = stream
	player.volume_db = vol
	add_child(player)
	player.play()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _next_gap:
		_timer = 0.0
		_next_gap = randf_range(MIN_GAP, MAX_GAP)
		AudioManager.play_ambient_note()
