extends Node

## Presses every button in the menus and reports what breaks.
##
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 tools/uitest.tscn
##
## The UI is built entirely in code, so nothing in the scene files can be
## inspected for a broken wire — and a settings toggle that throws only shows up
## when someone clicks it. This clicks all of them, twice, and prints the state
## each one reports afterwards so a toggle that does not actually toggle is
## visible as a repeated value rather than as silence.

func _ready() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for _f in range(20):
		await get_tree().process_frame

	print("=== SETTINGS ===")
	menu.call("_on_settings")
	await _settle()
	await _press_all(menu.get("_settings_panel"))

	print("=== CREDITS ===")
	menu.call("_on_credits")
	await _settle()
	await _press_all(menu.get("_credits_panel"))

	# Play changes scene and Quit ends the run, so they are matched by the method
	# they call rather than by a label that changes with the language — which is
	# how an earlier version of this test managed to press Play in Vietnamese.
	print("=== MENU ROOT (map cards; play/quit skipped) ===")
	await _press_all(menu, ["_on_play", "_on_quit"])

	print("UITEST DONE")
	get_tree().quit()

func _settle() -> void:
	for _f in range(6):
		await get_tree().process_frame

## Press every Button under `root`, twice, skipping any whose text matches
## `skip` (Play changes scene, Quit ends the run).
func _press_all(root: Node, skip: Array = []) -> void:
	if root == null:
		print("  (no panel)")
		return
	var buttons: Array[Button] = []
	_collect(root, buttons)
	print("  %d buttons" % buttons.size())
	for b in buttons:
		if not is_instance_valid(b):
			continue
		# Play swaps the scene out from under this test and Quit ends the run;
		# once either has fired there is nothing left to press, so stop rather
		# than spray "data.tree is null" over the results.
		if not root.is_inside_tree():
			print("  (scene left the tree — stopping)")
			return
		var label: String = b.text.replace("\n", " ")
		if label.to_upper() in skip:
			print("  skip  %s" % label)
			continue
		var before: String = b.text
		b.emit_signal("pressed")
		await _settle()
		var after: String = b.text if is_instance_valid(b) else "<freed>"
		b.emit_signal("pressed")
		await _settle()
		var back: String = b.text if is_instance_valid(b) else "<freed>"
		print("  press %-14s -> %-14s -> %s" % [before.replace("\n", " "),
			after.replace("\n", " "), back.replace("\n", " ")])

func _collect(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)
