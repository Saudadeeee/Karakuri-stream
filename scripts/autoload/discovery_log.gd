extends Node

## THE THINGS THE TOWN DOES THAT NOBODY TOLD YOU ABOUT.
##
## The best ideas in this game are invisible. Stack four storeys on one cell and
## it grows a SPIRE; leave a roof in the shadow of a taller part and it becomes a
## railed TERRACE; ring an empty cell and it plants a COURTYARD; leave one cell
## of air between two equal rooftops and BUNTING is strung across it. All of it
## is deterministic — build the shape again and you get it again — and none of it
## was findable without reading the README, which is the same as not existing.
##
## This is the smallest thing that fixes that: notice the first time a garden
## produces one, say so once, quietly, and keep a list. No score, no completion
## bar chasing the player, no timer. The list is a reason to come back and try a
## shape, which is what this game was missing between session one and session two.
##
## Detection is a poll rather than a signal from the geometry: the surprises are
## PROPERTIES OF A SHAPE, computed on demand by HouseShape, and nothing announces
## them. The poll is throttled, only looks while the grid is dirty, and drops
## each rule as soon as it has been found — an old garden with everything already
## discovered costs nothing at all.

signal discovered(id: String)

const SETTINGS_PATH: String = "user://settings.cfg"
const SCAN_INTERVAL: float = 0.7

## `note` is the ONLY place the how-to is written down, and it is shown after the
## fact — the point is to explain what just happened, never to hand out a recipe
## in advance.
const ENTRIES: Array[Dictionary] = [
	{"id": "spire", "title": "A spire",
	 "note": "Four storeys on one cell and the tower grows a spire."},
	{"id": "terrace", "title": "A roof terrace",
	 "note": "A roof in the shadow of a taller part flattens into a railed deck."},
	{"id": "courtyard", "title": "A courtyard",
	 "note": "Ring an empty cell with houses and the gap becomes a planted court."},
	{"id": "bunting", "title": "Bunting",
	 "note": "Leave one cell of air between two rooftops of equal height."},
	{"id": "arch", "title": "An arch",
	 "note": "A house cell bridging open ground grows an arch instead of legs."},
	{"id": "dormer", "title": "A dormer window",
	 "note": "A long roof opens a dormer to light the attic under it."},
	{"id": "roof_garden", "title": "A roof garden",
	 "note": "A big building's flat roof earns pots and greenery."},
	{"id": "stilts", "title": "Stilts",
	 "note": "A house built over open air walks down to whatever is beneath it."},
	{"id": "bird", "title": "Birds",
	 "note": "Houses bring birds — and a bird landing on a bell, chime or drum plays it."},
	{"id": "cat", "title": "A cat",
	 "note": "Two houses are enough for a cat to move in and walk the rooftops."},
	{"id": "duck", "title": "Ducks",
	 "note": "Three open water cells make a pond a duck will paddle."},
	{"id": "deer", "title": "A deer",
	 "note": "A deer only comes out when the machine is quiet. Switch the garden off."},
]

var _found: Dictionary = {}
var _pending: Array[String] = []
var _grid_dirty: bool = true
var _since_scan: float = 0.0

func _ready() -> void:
	_load()
	GridManager.block_placed.connect(func(_c: Vector3i) -> void: _grid_dirty = true)
	GridManager.block_removed.connect(func(_c: Vector3i) -> void: _grid_dirty = true)

func _process(delta: float) -> void:
	_since_scan += delta
	if _since_scan < SCAN_INTERVAL:
		return
	_since_scan = 0.0
	# Wildlife arrives on its own schedule, so those rules are checked even when
	# the grid has not moved. The house rules cannot change without an edit.
	_scan_wildlife()
	if _grid_dirty:
		_grid_dirty = false
		_scan_houses()

func has(id: String) -> bool:
	return _found.has(id)

func count_found() -> int:
	return _found.size()

func entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if String(e["id"]) == id:
			return e
	return {}

## Takes the next un-shown discovery, or "" — the game scene drains this so cards
## appear one at a time rather than four stacked on top of each other.
func take_pending() -> String:
	if _pending.is_empty():
		return ""
	return _pending.pop_front()

func mark(id: String) -> void:
	if _found.has(id):
		return
	_found[id] = true
	_pending.append(id)
	_save()
	discovered.emit(id)

# ------------------------------------------------------------------ scanning
func _scan_houses() -> void:
	# Everything house-shaped already found? Then there is nothing to look at, no
	# matter how big the town gets.
	var want: Array[String] = []
	for id in ["spire", "terrace", "courtyard", "bunting", "arch", "dormer",
			"roof_garden", "stilts"]:
		if not _found.has(id):
			want.append(id)
	if want.is_empty():
		return

	for cell in GridManager.get_all_cells_of_type(BlockData.Type.HOUSE):
		for id in want.duplicate():
			if _house_has(id, cell):
				mark(id)
				want.erase(id)
		if want.is_empty():
			return

func _house_has(id: String, cell: Vector3i) -> bool:
	match id:
		"spire": return HouseShape.has_spire(cell)
		"terrace": return HouseShape.is_terrace(cell)
		"courtyard": return HouseShape.courtyard_dir(cell) != Vector3i.ZERO
		"bunting": return HouseShape.bunting_dir(cell) != Vector3i.ZERO
		"arch": return HouseShape.arch_axis(cell) != Vector3i.ZERO
		"dormer": return HouseShape.dormer_side(cell) != Vector3i.ZERO
		"roof_garden": return HouseShape.has_roof_garden(cell)
		"stilts": return HouseShape.support_drop(cell) > 0 and not HouseShape.is_overhang(cell)
	return false

func _scan_wildlife() -> void:
	var wl: Node = get_node_or_null("/root/WildlifeManager")
	if wl == null:
		return
	for pair in [["bird", "_birds"], ["cat", "_cats"], ["duck", "_ducks"], ["deer", "_deer"]]:
		var id: String = pair[0]
		if _found.has(id):
			continue
		var herd: Variant = wl.get(pair[1])
		if herd is Array and not (herd as Array).is_empty():
			mark(id)

# ------------------------------------------------------------------ storage
## Kept in settings.cfg, not in the save file: what a player has SEEN belongs to
## the player, not to one garden. Clearing a build must not un-discover anything.
func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for e in ENTRIES:
		if bool(cfg.get_value("discovered", String(e["id"]), false)):
			_found[String(e["id"])] = true

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep the audio and display sections
	for id in _found:
		cfg.set_value("discovered", String(id), true)
	cfg.save(SETTINGS_PATH)
