extends Node

## Records the game's OWN master bus while it plays each sound through the real
## AudioManager call, so the numbers include the bus volumes, the 3D attenuation
## and the pitch shifts — not just what the files measure on disk.
##
##   godot --path . --rendering-driver opengl3 --resolution 320x200 tools/audiotest.tscn
##   ffmpeg -i "<user>/audio_probe.wav" -af astats=metadata=1:reset=1 ...
##
## Needs a real audio driver, so it cannot run headless: --headless installs the
## dummy driver and records silence.
##
## Every sound is fired from the same distance from the listener and separated by
## GAP seconds, so the recording can be cut into one segment per sound and each
## measured on its own.

const GAP: float = 1.4
const DIST: float = 10.0        # a normal play-camera distance from the block
const OUT := "user://audio_probe.wav"

func _ready() -> void:
	# A listener where the game camera would be.
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, DIST)
	add_child(cam)
	cam.make_current()

	var idx: int = AudioServer.get_bus_index("Master")
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(idx, rec)
	var slot: int = AudioServer.get_bus_effect_count(idx) - 1

	# Order matters only for reading the log next to the recording.
	var at := Vector3.ZERO
	var script: Array = [
		["wood note (marimba)", func() -> void: AudioManager.play_wood_note(at, 0, false)],
		["drum (taiko)", func() -> void: AudioManager.play_drum(at)],
		["shishi knock", func() -> void: AudioManager.play_shishi_knock(at)],
		["chime", func() -> void: AudioManager.play_chime(at, 0)],
		["music box tine", func() -> void: AudioManager.play_music_box_note(at, 0)],
		["jelly bounce", func() -> void: AudioManager.play_jelly_bounce(at)],
		["water plop", func() -> void: AudioManager.play_water_plop(at)],
		["splash", func() -> void: AudioManager.play_splash(at)],
		["bird flutter", func() -> void: AudioManager.play_flutter(at)],
		["ui hover", func() -> void: AudioManager.play_ui_pop(true)],
		["ui press", func() -> void: AudioManager.play_ui_pop(false)],
	]

	# The two LOOPS are beds, not events, and they are what a player hears the
	# whole time — so they get measured under the same listener as everything else.
	var loops: Array = [
		["water stream loop", AudioManager.make_water_loop_player()],
		["gear creak loop", AudioManager.make_gear_loop_player()],
	]

	await get_tree().create_timer(0.5).timeout
	rec.set_recording_active(true)
	await get_tree().create_timer(GAP * 0.5).timeout
	for step in script:
		(step[1] as Callable).call()
		print("SEG %s" % step[0])
		await get_tree().create_timer(GAP).timeout
	for l in loops:
		var pl: AudioStreamPlayer3D = l[1]
		add_child(pl)
		pl.global_position = at
		pl.play()
		print("SEG %s" % l[0])
		await get_tree().create_timer(GAP).timeout
		pl.stop()
		pl.queue_free()
	rec.set_recording_active(false)

	var clip: AudioStreamWAV = rec.get_recording()
	if clip == null:
		print("PROBE FAILED (no recording — is the audio driver real?)")
		get_tree().quit(1)
		return
	clip.save_to_wav(OUT)
	print("PROBE %s  %d segments, %.1fs apart" % [
		ProjectSettings.globalize_path(OUT), script.size(), GAP])
	AudioServer.remove_bus_effect(idx, slot)
	get_tree().quit()
