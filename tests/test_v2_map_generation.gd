extends SceneTree

const Run = preload("res://scripts/v2/run.gd")
const ATTRS = ["condensation", "thermal", "conductive", "aero"]
var checks := 0
var failures := 0
var seed_under_test := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MAP_GENERATION seed %d: %s" % [seed_under_test, message])

func _initialize() -> void:
	var entrances: Dictionary = {}
	var branching_maps := 0
	for seed_value in range(1000):
		seed_under_test = seed_value
		var run_state = Run.new()
		run_state.setup(ATTRS, seed_value)
		_check_graph(run_state)
		_check_rooms(run_state)
		entrances[str(run_state.available)] = true
		var branches := 0
		for node in run_state.nodes.values():
			if node.next.size() > 1:
				branches += 1
		if branches > 0:
			branching_maps += 1
		if seed_value % 50 == 0:
			var copy = Run.new()
			copy.setup(ATTRS, seed_value)
			check(copy.to_snapshot() == run_state.to_snapshot(), "Same seed reproduces the map and RNG state")
			check(copy.restore_snapshot(run_state.to_snapshot()) == OK and copy.to_snapshot() == run_state.to_snapshot(), "Generated map survives save restoration unchanged")
	check(entrances.size() >= 10, "Seeds vary the available starting positions")
	check(branching_maps >= 950, "Most maps offer meaningful branches after the starting choice")
	_check_start_transition()
	_check_legacy_save()
	print("V2_MAP_GENERATION: %d checks, %d failures; 1000 seeds, %d entrance sets, %d branching maps" % [checks, failures, entrances.size(), branching_maps])
	quit(1 if failures else 0)

func _check_graph(run_state) -> void:
	var nodes: Dictionary = run_state.nodes
	check(run_state.current == "start" and run_state.visited == ["start"] and run_state.phase == "map", "New exploration is already at its origin")
	check(nodes.start.row == 0 and nodes.start.col == 2 and nodes.start.type == "start" and nodes.start.next == run_state.available, "Origin connects to every initial route")
	check(run_state.available.size() >= 2 and run_state.available.size() <= 5, "Two or more usable entrances")
	var second_floor: Array = []
	for id in run_state.available:
		check(nodes[id].row == 1 and nodes[id].next.size() == 1, "Each entrance has exactly one exit")
		for next_id in nodes[id].next:
			check(next_id not in second_floor, "Entrances do not immediately merge")
			second_floor.append(next_id)
	var reachable: Dictionary = {}
	var pending: Array = [run_state.current]
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if reachable.has(id):
			continue
		reachable[id] = true
		pending.append_array(nodes[id].next)
	check(reachable.size() == nodes.size(), "No orphan nodes")
	var bosses := 0
	for node in nodes.values():
		check(node.col >= 0 and node.col < 5 and node.row >= 0 and node.row <= 11, "Nodes stay within the map bounds including the origin")
		if node.type == "boss":
			bosses += 1
			check(node.row == 11 and node.col == 2 and node.next.is_empty(), "One central terminal boss")
		else:
			check(not node.next.is_empty(), "No dead ends before the boss")
		var unique: Dictionary = {}
		for next_id in node.next:
			check(not unique.has(next_id), "No duplicate edges")
			unique[next_id] = true
			var target: Dictionary = nodes[next_id]
			check(target.row == node.row + 1 and (node.type == "start" or absi(target.col - node.col) <= 1), "All edges advance one floor; only the origin fans out across lanes")
			for other in nodes.values():
				if other.row != node.row or other.col <= node.col:
					continue
				for other_next in other.next:
					check(target.col <= nodes[other_next].col, "Independent edges never cross")
	check(bosses == 1, "Exactly one boss reachable from every node")

func _check_rooms(run_state) -> void:
	var variable_count := 0
	var counts := {"battle": 0, "event": 0, "shop": 0, "rest": 0}
	for node in run_state.nodes.values():
		match int(node.row):
			0: check(node.type == "start", "Floor zero is the origin")
			1: check(node.type == "battle", "First floor is battle")
			5: check(node.type == "reward", "Every path passes the reward floor")
			10: check(node.type == "rest", "Every path rests before the boss")
			11: check(node.type == "boss", "Final floor is boss")
			_:
				variable_count += 1
				check(counts.has(node.type), "Variable rooms have a supported type")
				counts[node.type] += 1
		if node.type == "rest":
			check(node.row >= 4 and node.row != 9, "No early rests or rests immediately before the fixed rest floor")
		var child_types: Array = []
		for next_id in node.next:
			var child: Dictionary = run_state.nodes[next_id]
			check(not (node.type in ["shop", "rest"] and node.type == child.type), "All parents respect the no-consecutive-shop/rest rule")
			if child.row not in [5, 10, 11] and child.type != "battle":
				check(child.type not in child_types, "Branches never repeat a special room outside fixed floors")
			child_types.append(child.type)
	for kind in ["event", "shop", "rest"]:
		var quota := roundi(variable_count * float(run_state.catalog.data.map.middle_node_weights[kind]) / 100.0)
		check(counts[kind] <= quota, "Special rooms do not exceed their quota: " + kind)
	check(counts.event > 0 and counts.shop > 0 and counts.rest > 0, "Every map contains all variable room types")

func _check_start_transition() -> void:
	var run_state = Run.new()
	run_state.setup(ATTRS, 34)
	var initial: Dictionary = run_state.to_snapshot()
	check(not run_state.enter_node("start") and not run_state.complete_node() and run_state.to_snapshot() == initial, "Origin cannot be re-entered or settled for rewards")
	var first: String = run_state.available[0]
	check(not run_state.enter_node(run_state.nodes[first].next[0]) and run_state.to_snapshot() == initial, "Origin cannot skip the first encounter")
	check(run_state.enter_node(first) and run_state.current == first and run_state.phase == "battle", "Choosing the first encounter moves the player off the origin")
	check(run_state.visited == ["start"] and run_state.shells == initial.shells and run_state.lives == initial.lives, "Leaving the origin grants no rewards and consumes no resources")
	var copy = Run.new()
	check(copy.restore_snapshot(run_state.to_snapshot()) == OK and copy.current == first, "Saving after departure preserves the actual position")
	var invalid: Dictionary = initial.duplicate(true)
	invalid.nodes.start.row = 1
	check(copy.restore_snapshot(invalid) == ERR_INVALID_DATA, "Origin cannot masquerade as an encounter floor")
	invalid = initial.duplicate(true)
	invalid.available.append("start")
	check(copy.restore_snapshot(invalid) == ERR_INVALID_DATA, "Origin cannot be offered as a selectable encounter")

func _check_legacy_save() -> void:
	var run_state = Run.new()
	run_state.setup(ATTRS, 7)
	var old: Dictionary = run_state.to_snapshot()
	# Old generation allowed crossing edges and rests on floor two. Loading
	# must preserve that graph and RNG, not apply the new generation rules.
	old.nodes = {
		"1_0": {"id": "1_0", "row": 1, "col": 0, "type": "battle", "next": ["2_1"]},
		"1_1": {"id": "1_1", "row": 1, "col": 1, "type": "battle", "next": ["2_0"]},
		"2_0": {"id": "2_0", "row": 2, "col": 0, "type": "rest", "next": ["3_1"]},
		"2_1": {"id": "2_1", "row": 2, "col": 1, "type": "rest", "next": ["3_1"]},
	}
	for row in range(3, 12):
		var id := "%d_1" % row
		old.nodes[id] = {"id": id, "row": row, "col": 1, "type": "boss" if row == 11 else "battle", "next": [] if row == 11 else ["%d_1" % (row + 1)]}
	old.available = ["1_0", "1_1"]
	old.current = ""
	old.visited = []
	check(run_state.restore_snapshot(old) == OK and run_state.to_snapshot() == old, "Legacy routes and RNG load without regeneration")
