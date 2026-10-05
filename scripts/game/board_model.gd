extends RefCounted
class_name BoardModel

signal cell_unlocked(pos: Vector2i)
signal cell_thawed(pos: Vector2i)

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
	if is_echo_cell(cell):
		var echo: EchoDefinition = catalog.get_echo(String(cell.get("echo_id", "")))
		return echo == null or not echo.can_swap
	return int(cell.get("locked_turns", 0)) > 0 or effect_stacks(cell, "annihilation") >= 6 or effect_stacks(cell, "frost") >= 3

func is_piece_cell(cell: Variant) -> bool:
	return cell != null and String(cell.get("entity_kind", "piece")) == "piece" and not String(cell.get("piece_id", "")).is_empty()

func is_echo_cell(cell: Variant) -> bool:
	return cell != null and String(cell.get("entity_kind", "piece")) == "echo" and not String(cell.get("echo_id", "")).is_empty()

func effect_stacks(cell: Dictionary, effect_id: String) -> int:
	var effects: Dictionary = cell.get("effects", {})
	return int(effects.get(effect_id, 0))

func set_effect_stacks(pos: Vector2i, effect_id: String, amount: int) -> int:
	if not in_bounds(pos) or not is_piece_cell(get_cell(pos)) or not EFFECT_LIMITS.has(effect_id):
		return 0
	var cell: Dictionary = get_cell(pos)
	var effects: Dictionary = cell.get("effects", {}).duplicate(true)
	var value: int = clamp(amount, 0, int(EFFECT_LIMITS[effect_id]))
	var thawed: bool = effect_id == "frost" and int(effects.get("frost", 0)) >= 3 and value < 3
	if effect_id == "frost":
		if value >= 3 and int(effects.get("frost", 0)) < 3:
			cell["frost_vfx_started_msec"] = Time.get_ticks_msec()
		elif value < 3:
			cell.erase("frost_vfx_started_msec")
	if value <= 0:
		effects.erase(effect_id)
	else:
		effects[effect_id] = value
	cell["effects"] = effects
	set_cell(pos, cell)
	if thawed:
		cell_thawed.emit(pos)
	return value

func add_effect_stacks(pos: Vector2i, effect_id: String, amount: int) -> int:
	var cell: Dictionary = get_cell(pos) if in_bounds(pos) else {}
	return set_effect_stacks(pos, effect_id, effect_stacks(cell, effect_id) + amount)

func can_match_cell(pos: Vector2i) -> bool:
	if not in_bounds(pos) or not is_piece_cell(get_cell(pos)):
		return false
	return not is_locked(pos) and effect_stacks(get_cell(pos), "annihilation") < 6

func is_locked(pos: Vector2i) -> bool:
	return in_bounds(pos) and get_cell(pos) != null and int(get_cell(pos).get("locked_turns", 0)) > 0

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
			var id: String = String(cells[y][x].get("piece_id", ""))
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
			var id: String = String(cells[y][x].get("piece_id", ""))
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
	if not is_piece_cell(cell):
		return []
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
					if is_piece_cell(cells[y][x]) and String(cells[y][x].get("piece_id", "")) == target_id:
						targets.append(Vector2i(x, y))
	return targets

func clear_positions(positions: Array) -> void:
	# Snapshot actual removals before unlocking: a locked piece hit by this same
	# batch survives, even when a neighbour is removed and unlocks it.
	var cleared: Array = []
	for pos in positions:
		if in_bounds(pos) and get_cell(pos) != null and not is_locked(pos) and not cleared.has(pos):
			cleared.append(pos)
	for pos in cleared:
		cells[pos.y][pos.x] = null
	for pos in cleared:
		for delta in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbour: Vector2i = pos + delta
			if is_locked(neighbour):
				cells[neighbour.y][neighbour.x]["locked_turns"] = 0
				cells[neighbour.y][neighbour.x].erase("lock_vfx_started_msec")
				cell_unlocked.emit(neighbour)

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
			if is_piece_cell(cells[y][x]) and String(cells[y][x].get("piece_id", "")) == old_id:
				cells[y][x]["piece_id"] = new_id
				count += 1
	return count

func lock_random_cells(count: int) -> int:
	var candidates: Array[Vector2i] = []
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell: Variant = cells[y][x]
			if is_piece_cell(cell) and int(cell.get("locked_turns", 0)) <= 0:
				candidates.append(Vector2i(x, y))
	var locked_count: int = min(max(0, count), candidates.size())
	# Select without replacement so every successful draw locks a new cell.
	for index in range(locked_count):
		var selected_index: int = rng.randi_range(index, candidates.size() - 1)
		var selected_pos: Vector2i = candidates[selected_index]
		candidates[selected_index] = candidates[index]
		candidates[index] = selected_pos
		cells[selected_pos.y][selected_pos.x]["locked_turns"] = 1
		cells[selected_pos.y][selected_pos.x]["lock_vfx_started_msec"] = Time.get_ticks_msec()
	return locked_count

func tick_locks() -> void:
	# Compatibility with older callers. locked_turns is now a persistent flag.
	pass

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
		"entity_kind": "piece",
		"piece_id": piece_id,
		"echo_id": "",
		"rune_id": "",
		"special_effect_id": "",
		"special_direction": "horizontal",
		"locked_turns": 0,
		"effects": {},
	}

func new_echo_cell(echo_id: String) -> Dictionary:
	return {
		"entity_kind": "echo",
		"piece_id": "",
		"echo_id": echo_id,
		"rune_id": "",
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
		"piece_id": String(get_cell(positions[0]).get("piece_id", "")),
	}

func _merge_intersections(groups: Array) -> Array:
	var merged: Array = []
	var used: Dictionary = {}
	for i in range(groups.size()):
		if used.has(i):
			continue
		used[i] = true
		var positions: Array = groups[i]["positions"].duplicate()
		var directions: Array = [groups[i]["direction"]]
		var pending: Array[int] = [i]
		while not pending.is_empty():
			pending.pop_front()
			for j in range(groups.size()):
				if used.has(j) or groups[i]["piece_id"] != groups[j]["piece_id"]:
					continue
				var intersects: bool = false
				for pos in groups[j]["positions"]:
					if positions.has(pos):
						intersects = true
						break
				if not intersects:
					continue
				used[j] = true
				pending.append(j)
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
