extends Node

## Generative ambient "music" — instead of a fixed looping track, it sprinkles
## soft pentatonic chime notes at slow, irregular intervals on the Music bus.
## Because every note is from the pentatonic scale it always sounds consonant and
## calm, and the randomness means it never repeats or loops audibly — an endless,
## wandering zen soundscape that carries the whole ASMR experience.

const MIN_GAP: float = 2.2
const MAX_GAP: float = 5.5

var _timer: float = 0.0
var _next_gap: float = 1.5   # first note comes in soon after start

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _next_gap:
		_timer = 0.0
		_next_gap = randf_range(MIN_GAP, MAX_GAP)
		AudioManager.play_ambient_note()
