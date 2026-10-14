extends RefCounted

const Catalog = preload("res://scripts/v2/catalog.gd")
const MapGenerator = preload("res://scripts/v2/map_generator.gd")
var catalog = Catalog.new()
var rng := RandomNumberGenerator.new()
var attributes: Array = []
var deck: Array = []
var relics: Array = []
var supplies: Array = ["healing_vial"]
var lives := 3
var shells := 20
var nodes: Dictionary = {}
var available: Array = []
var visited: Array = []
var current := ""
var phase := "map"
var outcome := ""
var rewards: Array = []
var stock: Array = []
var event_id := ""
var next_card_uid := 0
var battles_won := 0
var battles_lost := 0
var stats_written := false

func to_snapshot() -> Dictionary:
	var snapshot := {"version": 1, "rng": {"seed": rng.seed, "state": rng.state}}
	for key in ["attributes", "deck", "relics", "supplies", "nodes", "available", "visited", "rewards", "stock"]:
		snapshot[key] = get(key).duplicate(true)
	for key in ["lives", "shells", "current", "phase", "outcome", "event_id", "next_card_uid", "battles_won", "battles_lost", "stats_written"]:
		snapshot[key] = get(key)
	return snapshot

func restore_snapshot(snapshot: Dictionary) -> Error:
	if not _valid_snapshot(snapshot):
		return ERR_INVALID_DATA
	rng.seed = snapshot.rng.seed
	rng.state = snapshot.rng.state
	for key in ["attributes", "deck", "relics", "supplies", "nodes", "available", "visited", "rewards", "stock"]:
		set(key, snapshot[key].duplicate(true))
	for key in ["lives", "shells", "current", "phase", "outcome", "event_id", "next_card_uid", "battles_won", "battles_lost", "stats_written"]:
		set(key, snapshot[key])
	return OK

func _valid_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.get("version") != 1 or typeof(snapshot.get("rng")) != TYPE_DICTIONARY:
		return false
	if typeof(snapshot.rng.get("seed")) != TYPE_INT or typeof(snapshot.rng.get("state")) != TYPE_INT:
		return false
	for key in ["attributes", "deck", "relics", "supplies", "available", "visited", "rewards", "stock"]:
		if typeof(snapshot.get(key)) != TYPE_ARRAY:
			return false
	for key in ["lives", "shells", "next_card_uid", "battles_won", "battles_lost"]:
		if typeof(snapshot.get(key)) != TYPE_INT or snapshot[key] < 0:
			return false
	for key in ["current", "phase", "outcome", "event_id"]:
		if typeof(snapshot.get(key)) != TYPE_STRING:
			return false
	if typeof(snapshot.get("stats_written")) != TYPE_BOOL or typeof(snapshot.get("nodes")) != TYPE_DICTIONARY:
		return false
	if snapshot.lives > 3 or snapshot.attributes.size() != 4 or not _unique_ids(snapshot.attributes, Catalog.ATTRIBUTES):
		return false
	if snapshot.phase not in ["map", "battle", "boss", "rest", "shop", "event", "rewards", "ended"]:
		return false
	if snapshot.phase == "ended":
		if snapshot.outcome not in ["victory", "defeat", "abandoned"]:
			return false
	elif snapshot.outcome != "" or snapshot.lives == 0:
		return false
	if snapshot.nodes.is_empty() or snapshot.nodes.size() > 56:
		return false
	for id in snapshot.nodes:
		var node: Variant = snapshot.nodes[id]
		if typeof(id) != TYPE_STRING or typeof(node) != TYPE_DICTIONARY or node.get("id") != id:
			return false
		if typeof(node.get("row")) != TYPE_INT or typeof(node.get("col")) != TYPE_INT or node.row < 0 or node.row > 11 or node.col < 0 or node.col > 4:
			return false
		if node.get("type") not in ["start", "battle", "boss", "rest", "shop", "event", "reward"] or typeof(node.get("next")) != TYPE_ARRAY or not _unique_ids(node.next, snapshot.nodes.keys()):
			return false
		if node.row == 0 or node.type == "start":
			if id != MapGenerator.START_ID or node.type != "start" or node.row != 0 or node.col != 2 or node.next.is_empty():
				return false
		for next_id in node.next:
			if typeof(snapshot.nodes[next_id]) != TYPE_DICTIONARY or snapshot.nodes[next_id].get("row") != node.row + 1:
				return false
	if not _unique_ids(snapshot.available, snapshot.nodes.keys()) or not _unique_ids(snapshot.visited, snapshot.nodes.keys()):
		return false
	for id in snapshot.available:
		if id in snapshot.visited or snapshot.nodes[id].type == "start":
			return false
	if snapshot.current != "" and not snapshot.nodes.has(snapshot.current):
		return false
	if snapshot.phase not in ["map", "ended"] and snapshot.current == "":
		return false
	if snapshot.phase in ["battle", "boss", "rest", "shop", "event"] and snapshot.nodes[snapshot.current].type != snapshot.phase:
		return false
	if snapshot.phase != "map" and snapshot.phase != "ended" and snapshot.current in snapshot.visited:
		return false
	if snapshot.phase not in ["rewards", "ended"] and not snapshot.rewards.is_empty():
		return false
	var card_uids: Dictionary = {}
	for card in snapshot.deck:
		if not valid_card(card) or card.uid > snapshot.next_card_uid or card_uids.has(card.uid):
			return false
		card_uids[card.uid] = true
	if not _unique_ids(snapshot.relics, catalog.relics.keys()) or snapshot.supplies.size() > 3:
		return false
	for id in snapshot.supplies:
		if typeof(id) != TYPE_STRING or not catalog.supplies.has(id):
			return false
	for reward in snapshot.rewards:
		if not _valid_reward(reward):
			return false
	for item in snapshot.stock:
		if typeof(item) != TYPE_DICTIONARY or typeof(item.get("price")) != TYPE_INT or item.price < 0 or typeof(item.get("sold")) != TYPE_BOOL:
			return false
		var lookup: Dictionary = catalog.cards if item.get("type") == "card" else (catalog.relics if item.get("type") == "relic" else (catalog.supplies if item.get("type") == "supply" else {}))
		if not lookup.has(item.get("id")):
			return false
	if snapshot.phase == "event":
		var known := false
		for event in catalog.data.events:
			known = known or event.id == snapshot.event_id
		if not known:
			return false
	return true

func valid_card(card: Variant) -> bool:
	return typeof(card) == TYPE_DICTIONARY and catalog.cards.has(card.get("id")) and typeof(card.get("uid")) == TYPE_INT and card.uid > 0 and typeof(card.get("upgraded")) == TYPE_BOOL

func _unique_ids(values: Array, valid_ids: Array) -> bool:
	var seen: Dictionary = {}
	for id in values:
		if typeof(id) != TYPE_STRING or id not in valid_ids or seen.has(id):
			return false
		seen[id] = true
	return true

func _valid_reward(reward: Variant) -> bool:
	if typeof(reward) != TYPE_DICTIONARY:
		return false
	match reward.get("type"):
		"notice": return typeof(reward.get("text")) == TYPE_STRING and typeof(reward.get("requires_ack", false)) == TYPE_BOOL
		"card": return typeof(reward.get("options")) == TYPE_ARRAY and not reward.options.is_empty() and reward.options.size() <= 3 and _unique_ids(reward.options, catalog.cards.keys())
		"relic", "supply", "choice": return not _reward_choices(reward).is_empty()
	return false

func _reward_choices(reward: Dictionary) -> Array:
	# Normalize only reward descriptors, without changing the pending queue.
	var choices: Array = []
	var kind: String = str(reward.get("type", ""))
	if kind in ["relic", "supply"]:
		if reward.has("options"):
			if reward.has("id") or typeof(reward.options) != TYPE_ARRAY or reward.options.is_empty() or reward.options.size() > 3:
				return []
			for id in reward.options:
				choices.append({"type": kind, "id": id})
		else:
			choices.append({"type": kind, "id": reward.get("id")})
	elif kind == "choice":
		if reward.has("id") or typeof(reward.get("options")) != TYPE_ARRAY or reward.options.is_empty() or reward.options.size() > 3:
			return []
		choices = reward.options.duplicate(true)
	else:
		return []
	var seen: Dictionary = {}
	for option in choices:
		if typeof(option) != TYPE_DICTIONARY or option.get("type") not in ["relic", "supply"] or typeof(option.get("id")) != TYPE_STRING:
			return []
		var lookup: Dictionary = catalog.relics if option.type == "relic" else catalog.supplies
		if not lookup.has(option.id) or seen.has(option.id):
			return []
		seen[option.id] = true
	return choices

func setup(chosen: Array, seed_value: int = -1) -> void:
	assert(chosen.size() == 4)
	attributes = chosen.duplicate()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for entry in catalog.data.starter_deck:
		for _copy in range(int(entry.copies)):
			add_card(entry.id)
	_generate_map()

func add_card(id: String) -> void:
	next_card_uid += 1
	deck.append({"id": id, "uid": next_card_uid, "upgraded": false})

func _generate_map() -> void:
	var generated := MapGenerator.new().generate(catalog.data.map, rng)
	nodes = generated.nodes
	available = generated.available
	current = generated.current
	visited = [current]

func enter_node(id: String) -> bool:
	if phase != "map" or id not in available or id in visited:
		return false
	current = id
	phase = nodes[id].type
	if phase == "shop":
		_generate_shop()
	elif phase == "event":
		event_id = catalog.data.events[rng.randi_range(0, catalog.data.events.size()-1)].id
	elif phase == "reward":
		_generate_node_reward()
	return true

func _generate_node_reward() -> void:
	phase = "rewards"
	var rules: Dictionary = catalog.data.rewards.node
	var options: Array = sample(unowned_relics(), int(rules.relic_options))
	var money := int(rules.shells)
	var description := "本节点提供一组藏品二选一奖励。"
	if options.is_empty():
		money += int(rules.all_relics_shells)
		description = "藏品已集齐，已改为额外贝币。"
	elif options.size() == 1:
		description = "本节点提供最后一件未拥有藏品。"
	shells += money
	rewards.append({"type": "notice", "text": "奖励节点 · 无需战斗\n贝币 +%d\n%s" % [money, description], "requires_ack": true})
	if not options.is_empty():
		rewards.append({"type": "relic", "options": options})

func complete_node() -> bool:
	if current == "" or current in visited or phase not in ["rest", "shop", "event", "rewards"] or not rewards.is_empty():
		return false
	visited.append(current)
	available = nodes[current].next.duplicate()
	phase = "map"
	return true

func enemy_for_node() -> Dictionary:
	var id: String = "boss" if phase == "boss" else ["patrol", "shell", "charger", "striker"][rng.randi_range(0, 3)]
	var enemy: Dictionary = catalog.enemies[id].duplicate(true)
	if id != "boss":
		var row: int = nodes[current].row
		var tier: int = 0 if row <= 3 else (1 if row <= 6 else 2)
		enemy.hp = ceili(float(enemy.hp) * (1.0 + tier * 0.2))
		for step in enemy.pattern:
			if step.type == "attack":
				step.damage += tier
			elif step.type == "guard":
				step.amount += tier * 2
	return enemy

func finish_battle(won: bool) -> bool:
	if phase not in ["battle", "boss"]:
		return false
	var boss: bool = phase == "boss"
	if won:
		battles_won += 1
	else:
		battles_lost += 1
		lives = 0 if boss else maxi(0, lives-1)
	if lives == 0 or (boss and won):
		end_run("victory" if won else "defeat")
		return true
	phase = "rewards"
	var rules: Dictionary = catalog.data.rewards["victory" if won else "defeat"]
	var money := rng.randi_range(int(rules.shells[0]), int(rules.shells[1]))
	shells += money
	rewards.append({"type": "notice", "text": ("战斗胜利" if won else "战斗失败 · 探索生命 -1") + "\n贝币 +%d" % money})
	if rng.randf() < rules.card_chance:
		rewards.append({"type": "card", "options": sample(catalog.cards.keys(), 3)})
	if rng.randf() < rules.relic_chance:
		queue_relic()
	if rng.randf() < rules.supply_chance:
		rewards.append({"type": "supply", "id": sample(catalog.supplies.keys(), 1)[0]})
	return true

func sample(pool: Array, count: int) -> Array:
	var choices: Array = pool.duplicate()
	var picked: Array = []
	while not choices.is_empty() and picked.size() < count:
		var index := rng.randi_range(0, choices.size()-1)
		picked.append(choices[index])
		choices.remove_at(index)
	return picked

func unowned_relics() -> Array:
	var pool: Array = catalog.relics.keys()
	for id in relics:
		pool.erase(id)
	# Reserve every pending alternative so later drops cannot duplicate it.
	for reward in rewards:
		if typeof(reward) != TYPE_DICTIONARY:
			continue
		for option in _reward_choices(reward):
			if option.type == "relic":
				pool.erase(option.id)
	return pool

func queue_relic() -> void:
	var pool := unowned_relics()
	if pool.is_empty():
		shells += 15
		rewards.append({"type": "notice", "text": "藏品已集齐，转为 15 贝币。"})
	else:
		var id: String = sample(pool, 1)[0]
		rewards.append({"type": "relic", "id": id})

func accept_reward(choice: String = "", replace_index: int = -1) -> bool:
	return accept_reward_at(0, choice, replace_index)

func accept_reward_at(index: int, choice: String = "", replace_index: int = -1) -> bool:
	if phase != "rewards" or index < 0 or index >= rewards.size() or not _valid_reward(rewards[index]):
		return false
	var reward: Dictionary = rewards[index]
	match reward.type:
		"notice":
			if choice != "":
				return false
		"card":
			if choice != "":
				if choice not in reward.options:
					return false
				add_card(choice)
		"relic", "supply", "choice":
			if choice != "":
				var chosen: Dictionary = {}
				for option in _reward_choices(reward):
					if option.id == choice:
						chosen = option
						break
				if chosen.is_empty():
					return false
				if chosen.type == "relic":
					if choice in relics:
						return false
					relics.append(choice)
				elif not add_supply(choice, replace_index):
					return false
	rewards.remove_at(index)
	return true

func add_supply(id: String, replace_index: int = -1) -> bool:
	if not catalog.supplies.has(id):
		return false
	if supplies.size() < 3:
		supplies.append(id)
		return true
	if replace_index < 0 or replace_index >= supplies.size():
		return false
	supplies[replace_index] = id
	return true

func _generate_shop() -> void:
	stock.clear()
	for id in sample(catalog.cards.keys(), 4):
		stock.append({"type": "card", "id": id, "price": 20, "sold": false})
	for id in sample(unowned_relics(), 2):
		stock.append({"type": "relic", "id": id, "price": 45, "sold": false})
	for id in sample(catalog.supplies.keys(), 2):
		stock.append({"type": "supply", "id": id, "price": int(catalog.supplies[id].price), "sold": false})

func buy(index: int, replace_index: int = -1) -> bool:
	if phase != "shop" or index < 0 or index >= stock.size():
		return false
	var item: Dictionary = stock[index]
	if item.sold or shells < item.price:
		return false
	match item.type:
		"card": add_card(item.id)
		"relic":
			if item.id in relics:
				return false
			relics.append(item.id)
		"supply":
			if not add_supply(item.id, replace_index):
				return false
	shells -= int(item.price)
	item.sold = true
	return true

func modify_deck(index: int, upgrade: bool, price: int = 0) -> bool:
	if phase not in ["rest", "event"] or index < 0 or index >= deck.size() or shells < price:
		return false
	if upgrade:
		if deck[index].upgraded:
			return false
		deck[index].upgraded = true
	else:
		deck.remove_at(index)
	shells -= price
	complete_node()
	return true

func rest_heal() -> bool:
	if phase != "rest" or lives >= 3:
		return false
	lives = mini(3, lives+1)
	return complete_node()

func event_choice(choice: int) -> bool:
	if phase != "event" or not rewards.is_empty():
		return false
	match event_id:
		"cache":
			if choice == 0:
				shells += 10
			else:
				rewards.append({"type": "supply", "id": sample(catalog.supplies.keys(), 1)[0]})
		"workbench":
			if choice == 0:
				return false # Selection is committed atomically by modify_deck.
		"trade_life":
			if choice == 0:
				lives -= 1
				if lives <= 0:
					end_run("defeat")
					return true
				queue_relic()
		"prune":
			if choice == 0:
				return false
			shells += 8
	if rewards.is_empty():
		complete_node()
	else:
		phase = "rewards"
	return true

func end_run(value: String) -> void:
	phase = "ended"
	outcome = value
	available.clear()

func save_statistics(path: String = "user://save.cfg") -> Error:
	if phase != "ended" or stats_written:
		return OK
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error
	for key in ["runs", "wins", "battles_won", "battles_lost"]:
		var added: int = 1 if key == "runs" else (int(outcome == "victory") if key == "wins" else (battles_won if key == "battles_won" else battles_lost))
		config.set_value("gameplay_v2", key, int(config.get_value("gameplay_v2", key, 0)) + added)
	error = config.save(path)
	if error == OK:
		stats_written = true
	return error
