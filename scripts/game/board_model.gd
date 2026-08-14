extends RefCounted
class_name BoardModel

const WIDTH := 8
const HEIGHT := 8
const EFFECT_LIMITS := {
	"conductive": 6,
	"annihilation": 6,
	"explosive": 10,
	"photo": 10,
	"frost": 3,
	"aero": 3,
}

var catalog: PieceCatalog
var roster_ids: PackedStringArray
var cells: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(piece_catalog: PieceCatalog, ids: PackedStringArray) -> void:
	catalog = piece_catalog
	roster_ids = ids.duplicate()
	if roster_ids.is_empty():
		roster_ids = catalog.get_default_roster()
	rng.randomize()
	_fill_new_board()

func get_cell(pos: Vector2i) -> Variant:
	return cells[pos.y][pos.x]

func set_cell(pos: Vector2i, cell: Variant) -> void:
	cells[pos.y][pos.x] = cell

func swap(a: Vector2i, b: Vector2i) -> void:
	var temp: Variant = get_cell(a)
	set_cell(a, get_cell(b))
	set_cell(b, temp)

func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

func is_immovable(pos: Vector2i) -> bool:
	if not in_bounds(pos) or get_cell(pos) == null:
		return true
	var cell: Dictionary = get_cell(pos)
	return int(cell.get("locked_turns", 0)) > 0 or effect_stacks(cell, "annihilation") >= 6 or effect_stacks(cell, "frost") >= 3

func effect_stacks(cell: Dictionary, effect_id: String) -> int:
	var effects: Dictionary = cell.get("effects", {})
	return int(effects.get(effect_id, 0))

func set_effect_stacks(pos: Vector2i, effect_id: String, amount: int) -> int:
	if not in_bounds(pos) or get_cell(pos) == null or not EFFECT_LIMITS.has(effect_id):
		return 0
	var cell: Dictionary = get_cell(pos)
	var effects: Dictionary = cell.get("effects", {}).duplicate(true)
	var value: int = clamp(amount, 0, int(EFFECT_LIMITS[effect_id]))
	if value <= 0:
		effects.erase(effect_id)
	else:
		effects[effect_id] = value
	cell["effects"] = effects
	set_cell(pos, cell)
	return value

func add_effect_stacks(pos: Vector2i, effect_id: String, amount: int) -> int:
	var cell: Dictionary = get_cell(pos) if in_bounds(pos) else {}
	return set_effect_stacks(pos, effect_id, effect_stacks(cell, effect_id) + amount)

func can_match_cell(pos: Vector2i) -> bool:
	return in_bounds(pos) and get_cell(pos) != null and effect_stacks(get_cell(pos), "annihilation") < 6

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < WIDTH and pos.y >= 0 and pos.y < HEIGHT

func find_matches() -> Array:
	var groups: Array = []
	for y in range(HEIGHT):
		var run: Array = []
		var last_id: String = ""
		for x in range(WIDTH):
			if not can_match_cell(Vector2i(x, y)):
				if run.size() >= 3:
					groups.append(_make_group(run, Vector2i(1, 0)))
				run = []
				last_id = ""
				continue
			var id: String = String(cells[y][x]["piece_id"])
			if id == last_id:
				run.append(Vector2i(x, y))
			else:
				if run.size() >= 3:
					groups.append(_make_group(run, Vector2i(1, 0)))
				run = [Vector2i(x, y)]
				last_id = id
		if run.size() >= 3:
			groups.append(_make_group(run, Vector2i(1, 0)))
	for x in range(WIDTH):
		var run: Array = []
		var last_id: String = ""
		for y in range(HEIGHT):
			if not can_match_cell(Vector2i(x, y)):
				if run.size() >= 3:
					groups.append(_make_group(run, Vector2i(0, 1)))
				run = []
				last_id = ""
				continue
			var id: String = String(cells[y][x]["piece_id"])
			if id == last_id:
				run.append(Vector2i(x, y))
			else:
				if run.size() >= 3:
					groups.append(_make_group(run, Vector2i(0, 1)))
				run = [Vector2i(x, y)]
				last_id = id
		if run.size() >= 3:
			groups.append(_make_group(run, Vector2i(0, 1)))
	return _merge_intersections(groups)

func has_possible_move() -> bool:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			for delta in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other: Vector2i = pos + delta
				if not in_bounds(other) or is_immovable(pos) or is_immovable(other):
					continue
				swap(pos, other)
				var ok: bool = not find_matches().is_empty()
				swap(pos, other)
				if ok:
					return true
	return false

func collect_effect_targets(pos: Vector2i, partner_piece_id: String = "") -> Array:
	var cell: Dictionary = get_cell(pos)
	var effect: SpecialEffectDefinition = catalog.get_effect(String(cell["special_effect_id"]))
	var targets: Array = []
	if effect == null:
		targets.append(pos)
		return targets
	match effect.effect_type:
		"line":
			if String(cell["special_direction"]) == "vertical":
				for y in range(HEIGHT):
					targets.append(Vector2i(pos.x, y))
			else:
				for x in range(WIDTH):
					targets.append(Vector2i(x, pos.y))
		"area":
			for y in range(pos.y - effect.radius, pos.y + effect.radius + 1):
				for x in range(pos.x - effect.radius, pos.x + effect.radius + 1):
					var target: Vector2i = Vector2i(x, y)
					if in_bounds(target):
						targets.append(target)
		"color_clear":
			var target_id: String = partner_piece_id
			if target_id.is_empty():
				target_id = String(cell["piece_id"])
			for y in range(HEIGHT):
				for x in range(WIDTH):
					if String(cells[y][x]["piece_id"]) == target_id:
						targets.append(Vector2i(x, y))
	return targets

func clear_positions(positions: Array) -> void:
	for pos in positions:
		if in_bounds(pos):
			cells[pos.y][pos.x] = null

func collapse_and_refill() -> void:
	for x in range(WIDTH):
		var stack: Array = []
		for y in range(HEIGHT - 1, -1, -1):
			if cells[y][x] != null:
				stack.append(cells[y][x])
		for y in range(HEIGHT - 1, -1, -1):
			if stack.is_empty():
				cells[y][x] = _new_cell(_random_piece_id())
			else:
				cells[y][x] = stack.pop_front()

func replace_piece_id(old_id: String, new_id: String) -> int:
	var count: int = 0
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if String(cells[y][x]["piece_id"]) == old_id:
				cells[y][x]["piece_id"] = new_id
				count += 1
	return count

func lock_random_cells(count: int) -> void:
	for i in range(count):
		var pos: Vector2i = Vector2i(rng.randi_range(0, WIDTH - 1), rng.randi_range(0, HEIGHT - 1))
		cells[pos.y][pos.x]["locked_turns"] = max(1, int(cells[pos.y][pos.x]["locked_turns"]))

func tick_locks() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			cells[y][x]["locked_turns"] = max(0, int(cells[y][x]["locked_turns"]) - 1)

func _fill_new_board() -> void:
	var attempts: int = 0
	while attempts < 200:
		attempts += 1
		cells = []
		for y in range(HEIGHT):
			var row: Array = []
			for x in range(WIDTH):
				row.append(_new_cell(_random_piece_id()))
			cells.append(row)
		if find_matches().is_empty() and has_possible_move():
			return
	if cells.is_empty():
		for y in range(HEIGHT):
			var row: Array = []
			for x in range(WIDTH):
				row.append(_new_cell(_random_piece_id()))
			cells.append(row)

func _new_cell(piece_id: String) -> Dictionary:
	return {
		"piece_id": piece_id,
		"special_effect_id": "",
		"special_direction": "horizontal",
		"locked_turns": 0,
		"effects": {},
	}

func _random_piece_id() -> String:
	return roster_ids[rng.randi_range(0, roster_ids.size() - 1)]

func _make_group(positions: Array, direction: Vector2i) -> Dictionary:
	return {
		"positions": positions.duplicate(),
		"direction": direction,
		"piece_id": String(get_cell(positions[0])["piece_id"]),
	}

func _merge_intersections(groups: Array) -> Array:
	var merged: Array = []
	var used: Dictionary = {}
	for i in range(groups.size()):
		if used.has(i):
			continue
		var positions: Array = groups[i]["positions"].duplicate()
		var directions: Array = [groups[i]["direction"]]
		for j in range(i + 1, groups.size()):
			if used.has(j):
				continue
			if groups[i]["piece_id"] != groups[j]["piece_id"]:
				continue
			var intersects: bool = false
			for pos in groups[j]["positions"]:
				if positions.has(pos):
					intersects = true
					break
			if intersects:
				used[j] = true
				for pos in groups[j]["positions"]:
					if not positions.has(pos):
						positions.append(pos)
				directions.append(groups[j]["direction"])
		merged.append({
			"positions": positions,
			"directions": directions,
			"piece_id": groups[i]["piece_id"],
		})
	return merged
