extends Node

## Generative ambient composer on the Music bus. Four layers into the Master
## reverb: chill pad bed, quiet rain, a harmonic-clock drone, and a phrase
## melody engine.
##
## Everything (drone, melody, player instruments) shares ONE pentatonic
## collection {C D E G A}; the harmonic clock moves the tonal centre between
## its five modal rotations. Same pitch set → the colour shifts major/minor
## but nothing the player strikes can clash. Melody: stepwise-biased random
## walk in 2-5-note phrases with call-and-response; a minutes-long sine
## swells the phrase density.

const CHILL_BEDS: Array[AudioStream] = [
	preload("res://assets/sounds/chill_ambient.ogg"),
]
const RAIN_LAYER: AudioStream = preload("res://assets/sounds/rain_loop.ogg")
const CHIME: AudioStream = preload("res://assets/sounds/517660__samuelgremaud__chimes-5.wav")
const TINE: AudioStream = preload("res://assets/sounds/music_box_tine.ogg")

## Pentatonic degree ratios within one octave (C D E G A).
const P: Array[float] = [1.0, 1.1225, 1.2599, 1.4983, 1.6818]
## Tonal centres ordered so adjacent entries are gentle moves (relative
## minor / fifths); the harmonic clock only steps to a neighbour.
const ROOT_CIRCLE: Array[int] = [0, 4, 2, 3, 1]   # degrees: C A E G D

## Melody step distribution, favouring neighbours.
const STEPS: Array[int] = [-2, -1, -1, -1, 1, 1, 1, 2]
const DEGREE_SPAN: int = 10          # two octaves of pentatonic degrees
const CHAPTER_MIN: float = 24.0      # seconds between tonal-centre moves
const CHAPTER_MAX: float = 44.0
const PHRASE_REST_MIN: float = 2.6
const PHRASE_REST_MAX: float = 6.5
const NOTE_GAP_MIN: float = 0.4
const NOTE_GAP_MAX: float = 1.05
const DENSITY_PERIOD: float = 173.0  # slow breath over ~3 minutes
const ANSWER_CHANCE: float = 0.35    # phrase echoes the previous, shifted
const ECHO_CHANCE: float = 0.2      # single note repeats softly after a beat

var _rain: AudioStreamPlayer

# Harmonic clock state
var _circle_pos: int = 0             # index into ROOT_CIRCLE
var _chapter_timer: float = 0.0
var _chapter_len: float = 8.0        # first chapter turns over quickly

# Melody state
var _degree: int = 4                 # where the walk currently stands
var _phrase: Array[int] = []         # degrees still to play in this phrase
var _prev_phrase: Array[int] = []    # for call-and-response
var _note_timer: float = 0.0
var _next_note_in: float = 3.0
var _clock: float = 0.0              # for the density breath

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
	_clock += delta

	# Harmonic clock: step to an adjacent tonal centre, announce with a low
	# drone (+ sometimes a fifth: 3 pentatonic steps up).
	_chapter_timer += delta
	if _chapter_timer >= _chapter_len:
		_chapter_timer = 0.0
		_chapter_len = randf_range(CHAPTER_MIN, CHAPTER_MAX)
		_circle_pos = wrapi(_circle_pos + (1 if randf() < 0.5 else -1), 0, ROOT_CIRCLE.size())
		var root: int = ROOT_CIRCLE[_circle_pos]
		_spawn_note(CHIME, P[root] * 0.25, randf_range(-16.0, -13.0))
		if randf() < 0.6:
			_spawn_note(CHIME, _degree_pitch(root + 3) * 0.25, -19.0)

	# -- melody engine
	_note_timer += delta
	if _note_timer < _next_note_in:
		return
	_note_timer = 0.0

	if _phrase.is_empty():
		_phrase = _plan_phrase()
		# The rest before a phrase carries the density breathing.
		var breath: float = 1.0 + 0.5 * sin(TAU * _clock / DENSITY_PERIOD)
		_next_note_in = randf_range(PHRASE_REST_MIN, PHRASE_REST_MAX) * breath
		return

	var degree: int = _phrase.pop_front()
	_degree = degree
	# Phrase lead is louder and sometimes brighter (chime instead of tine).
	var lead: bool = _phrase.size() >= 1
	var vol: float = randf_range(-11.0, -8.0) if lead else randf_range(-15.0, -12.0)
	var bright: bool = lead and randf() < 0.35
	var pitch: float = _degree_pitch(degree) * (1.0 if bright else 0.5)
	_spawn_note(CHIME if bright else TINE, pitch, vol)
	if randf() < ECHO_CHANCE:
		get_tree().create_timer(0.34).timeout.connect(
			_spawn_note.bind(TINE, pitch, vol - 7.0))
	_next_note_in = randf_range(NOTE_GAP_MIN, NOTE_GAP_MAX)

## Either an answer to the previous phrase (same contour, shifted a step) or
## a fresh walk opening on a chord tone of the current centre.
func _plan_phrase() -> Array[int]:
	var out: Array[int] = []
	if not _prev_phrase.is_empty() and randf() < ANSWER_CHANCE:
		var shift: int = 1 if randf() < 0.5 else -1
		for d in _prev_phrase:
			out.append(clampi(d + shift, 0, DEGREE_SPAN - 1))
	else:
		var root: int = ROOT_CIRCLE[_circle_pos]
		var start: int = root + (0 if randf() < 0.6 else 2)
		# Open in the octave nearest the walk's current position.
		if absi(start + 5 - _degree) < absi(start - _degree):
			start += 5
		var d: int = clampi(start, 0, DEGREE_SPAN - 1)
		out.append(d)
		for i in randi_range(1, 4):
			if randf() < 0.15:
				d = clampi(root + (5 if d < 5 else 0), 0, DEGREE_SPAN - 1)
			else:
				d = clampi(d + STEPS.pick_random(), 0, DEGREE_SPAN - 1)
			out.append(d)
	_prev_phrase = out.duplicate()
	return out

## Degree index (0..9, two octaves) -> pitch ratio.
func _degree_pitch(degree: int) -> float:
	var d: int = clampi(degree, 0, DEGREE_SPAN - 1)
	return P[d % 5] * (2.0 if d >= 5 else 1.0)

func _spawn_note(stream: AudioStream, pitch: float, vol: float) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.stream = stream
	player.pitch_scale = pitch * randf_range(0.995, 1.005)
	player.volume_db = vol
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
