extends RefCounted

const START_ID := "start"

# Build complete walks first, then assign rooms to the resulting shared graph.
# All randomness uses the run RNG so a seed reproduces both routes and rooms.
var rng: RandomNumberGenerator
var rules: Dictionary
var nodes: Dictionary = {}

func generate(map_rules: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	rules = map_rules
	rng = random
	nodes = {}
	for path in range(int(rules.path_count)):
		var start := _choose_start(path < 2)
		var previous := _add_node(1, start.x)
		for row in range(2, int(rules.boss_row) + 1):
			var col := start.y if row == 2 else _choose_next(row - 1, int(nodes[previous].col))
			var id := _add_node(row, col)
			if id not in nodes[previous].next:
				nodes[previous].next.append(id)
			previous = id
	# Stable floor/column order also makes type constraints independent of which
	# walk first discovered a node, and keeps UI keyboard order predictable.
	var ordered: Dictionary = {}
	var available: Array = []
	for row in range(1, int(rules.boss_row) + 1):
		for col in range(int(rules.columns)):
			var id := _id(row, col)
			if nodes.has(id):
				ordered[id] = nodes[id]
				if row == 1:
					available.append(id)
	nodes = ordered
	_assign_rooms()
	# The origin is already occupied; the first encounters stay selectable.
	var with_start: Dictionary = {START_ID: {"id": START_ID, "row": 0, "col": int(rules.columns) / 2, "type": "start", "next": available.duplicate()}}
	with_start.merge(nodes)
	nodes = with_start
	return {"nodes": nodes, "available": available, "current": START_ID}

func _id(row: int, col: int) -> String:
	return "%d_%d" % [row, col]

func _add_node(row: int, col: int) -> String:
	var id := _id(row, col)
	if not nodes.has(id):
		nodes[id] = {"id": id, "row": row, "col": col, "type": "", "next": []}
	return id

func _choose_start(require_new: bool) -> Vector2i:
	var starts: Array = []
	for col in range(int(rules.columns)):
		var id := _id(1, col)
		if nodes.has(id):
			if not require_new:
				starts.append(Vector2i(col, int(nodes[nodes[id].next[0]].col)))
			continue
		for next_col in _candidates(1, col):
			var shared := false
			for node in nodes.values():
				if node.row == 1 and _id(2, next_col) in node.next:
					shared = true
			if not shared:
				starts.append(Vector2i(col, next_col))
	# First two walks use different entrances. Each entrance has one exit and
	# its own second-floor node, avoiding redundant choices at the start.
	assert(not starts.is_empty())
	return starts[rng.randi_range(0, starts.size() - 1)]

func _choose_next(row: int, col: int) -> int:
	var candidates := _candidates(row, col)
	assert(not candidates.is_empty())
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _candidates(row: int, col: int) -> Array[int]:
	var result: Array[int] = []
	var boss_col := int(rules.columns) / 2
	for next_col in range(maxi(0, col - 1), mini(int(rules.columns) - 1, col + 1) + 1):
		# Narrow gradually toward the boss, never clamp an edge across lanes.
		if absi(next_col - boss_col) > int(rules.boss_row) - row - 1:
			continue
		var crosses := false
		for node in nodes.values():
			if node.row != row:
				continue
			for next_id in node.next:
				if (col - int(node.col)) * (next_col - int(nodes[next_id].col)) < 0:
					crosses = true
		if not crosses:
			result.append(next_col)
	return result

func _assign_rooms() -> void:
	var unassigned: Array = []
	var parents: Dictionary = {}
	for id in nodes:
		parents[id] = []
	for node in nodes.values():
		for next_id in node.next:
			parents[next_id].append(node.id)
		if node.row == 1:
			node.type = rules.first_row
		elif node.row == int(rules.boss_row):
			node.type = "boss"
		elif node.row == int(rules.rows_before_boss):
			node.type = rules.last_pre_boss_row
		elif node.row == int(rules.guaranteed_reward_row):
			node.type = "reward"
		else:
			unassigned.append(node.id)
	# Quotas apply to variable rooms only; fixed reward/rest floors are extra.
	var weights: Dictionary = rules.middle_node_weights
	var total_weight := 0.0
	for weight in weights.values():
		total_weight += float(weight)
	var bucket: Array[String] = []
	for kind in ["event", "shop", "rest"]:
		var count := roundi(unassigned.size() * float(weights[kind]) / total_weight)
		for _copy in range(count):
			bucket.append(kind)
	while bucket.size() < unassigned.size():
		bucket.append("battle")
	for index in range(bucket.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var kind := bucket[index]
		bucket[index] = bucket[other]
		bucket[other] = kind
	for id in unassigned:
		for index in range(bucket.size()):
			if _can_assign(id, bucket[index], parents):
				nodes[id].type = bucket[index]
				bucket.remove_at(index)
				break
	# As in the reference algorithm, an impossible quota falls back to battle.
	# Apply after the pass so fallback rooms do not affect sibling selection.
	for id in unassigned:
		if nodes[id].type == "":
			nodes[id].type = "battle"
	# Short maps have fewer legal rest floors than the 15-floor reference.
	# Recover leftover special quotas where a battle can safely be replaced.
	for kind in ["rest", "shop", "event"]:
		for id in unassigned:
			if kind not in bucket:
				break
			if nodes[id].type != "battle" or not _can_assign(id, kind, parents):
				continue
			var repeats_child := false
			for next_id in nodes[id].next:
				if kind in ["shop", "rest"] and nodes[next_id].type == kind:
					repeats_child = true
			if not repeats_child:
				nodes[id].type = kind
				bucket.erase(kind)

func _can_assign(id: String, kind: String, parents: Dictionary) -> bool:
	var node: Dictionary = nodes[id]
	if kind == "rest" and (node.row < int(rules.min_rest_row) or node.row == int(rules.rows_before_boss) - 1):
		return false
	for parent_id in parents[id]:
		var parent: Dictionary = nodes[parent_id]
		if kind in ["shop", "rest"] and parent.type == kind:
			return false
		for sibling_id in parent.next:
			if sibling_id != id and nodes[sibling_id].type == kind:
				return false
	return true
