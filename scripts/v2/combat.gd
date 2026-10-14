extends RefCounted

const Catalog = preload("res://scripts/v2/catalog.gd")
const Board = preload("res://scripts/v2/board.gd")
var catalog = Catalog.new()
var board = Board.new()
var rng := RandomNumberGenerator.new()
var phase := "board"
var result := ""
var hp := 60
var max_hp := 60
var level := 1
var xp := 0
var guard := 0
var attack_bonus := 0
var mana: Dictionary = {}
var hand: Array = []
var draw_pile: Array = []
var discard: Array = []
var relics: Array = []
var enemy: Dictionary = {}
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_guard := 0
var intent: Dictionary = {}
var intent_index := 0
var turn := 0
var played := 0
var next_damage := 0.0
var next_guard := 0
var next_pierce := false
var refill_triggered := false
var auto_hint_used := false
var log_lines: Array[String] = []

func to_snapshot() -> Dictionary:
	var snapshot := {"version": 1, "rng": {"seed": rng.seed, "state": rng.state}, "board": board.to_snapshot()}
	for key in ["mana", "hand", "draw_pile", "discard", "relics", "enemy", "intent", "log_lines"]:
		snapshot[key] = get(key).duplicate(true)
	for key in ["phase", "result", "hp", "max_hp", "level", "xp", "guard", "attack_bonus", "enemy_hp", "enemy_max_hp", "enemy_guard", "intent_index", "turn", "played", "next_damage", "next_guard", "next_pierce", "refill_triggered", "auto_hint_used"]:
		snapshot[key] = get(key)
	return snapshot

func restore_snapshot(snapshot: Dictionary) -> Error:
	if not _valid_snapshot(snapshot):
		return ERR_INVALID_DATA
	var restored_board = Board.new()
	if restored_board.restore_snapshot(snapshot.board) != OK:
		return ERR_INVALID_DATA
	if (snapshot.phase == "resolving") != restored_board.resolving:
		return ERR_INVALID_DATA
	board = restored_board
	rng.seed = snapshot.rng.seed
	rng.state = snapshot.rng.state
	for key in ["mana", "hand", "draw_pile", "discard", "relics", "enemy", "intent"]:
		set(key, snapshot[key].duplicate(true))
	log_lines.assign(snapshot.log_lines)
	for key in ["phase", "result", "hp", "max_hp", "level", "xp", "guard", "attack_bonus", "enemy_hp", "enemy_max_hp", "enemy_guard", "intent_index", "turn", "played", "next_damage", "next_guard", "next_pierce", "refill_triggered"]:
		set(key, snapshot[key])
	auto_hint_used = snapshot.get("auto_hint_used", false)
	return OK

func _valid_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.get("version") != 1 or typeof(snapshot.get("rng")) != TYPE_DICTIONARY or typeof(snapshot.get("board")) != TYPE_DICTIONARY:
		return false
	if typeof(snapshot.rng.get("seed")) != TYPE_INT or typeof(snapshot.rng.get("state")) != TYPE_INT:
		return false
	for key in ["hp", "max_hp", "level", "xp", "guard", "attack_bonus", "enemy_hp", "enemy_max_hp", "enemy_guard", "intent_index", "turn", "played", "next_guard"]:
		if typeof(snapshot.get(key)) != TYPE_INT or snapshot[key] < 0:
			return false
	for key in ["next_pierce", "refill_triggered"]:
		if typeof(snapshot.get(key)) != TYPE_BOOL:
			return false
	if snapshot.has("auto_hint_used") and typeof(snapshot.auto_hint_used) != TYPE_BOOL:
		return false
	for key in ["mana", "enemy", "intent"]:
		if typeof(snapshot.get(key)) != TYPE_DICTIONARY:
			return false
	for key in ["hand", "draw_pile", "discard", "relics", "log_lines"]:
		if typeof(snapshot.get(key)) != TYPE_ARRAY:
			return false
	if typeof(snapshot.get("next_damage")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(snapshot.next_damage)) or snapshot.next_damage < 0:
		return false
	if snapshot.get("phase") not in ["board", "resolving", "play", "ended"] or typeof(snapshot.get("result")) != TYPE_STRING:
		return false
	if snapshot.phase == "ended":
		if snapshot.result not in ["victory", "defeat"]:
			return false
	elif snapshot.result != "" or snapshot.hp == 0 or snapshot.enemy_hp == 0:
		return false
	if snapshot.level < 1 or snapshot.level > 10 or snapshot.max_hp != 60 + (snapshot.level - 1) * 5 or snapshot.hp > snapshot.max_hp or snapshot.xp >= snapshot.level + 2 or (snapshot.level == 10 and snapshot.xp != 0) or snapshot.turn < 1:
		return false
	if snapshot.enemy_hp > snapshot.enemy_max_hp or snapshot.enemy_max_hp <= 0 or not catalog.enemies.has(snapshot.enemy.get("id")) or typeof(snapshot.enemy.get("name")) != TYPE_STRING or snapshot.enemy.get("hp") != snapshot.enemy_max_hp:
		return false
	if typeof(snapshot.enemy.get("pattern")) != TYPE_ARRAY or snapshot.enemy.pattern.is_empty():
		return false
	for step in snapshot.enemy.pattern:
		if not _valid_intent(step):
			return false
	if not _valid_intent(snapshot.intent) or (snapshot.phase != "ended" and snapshot.intent != snapshot.enemy.pattern[snapshot.intent_index % snapshot.enemy.pattern.size()]):
		return false
	if snapshot.mana.size() != Catalog.ATTRIBUTES.size():
		return false
	for kind in Catalog.ATTRIBUTES:
		if typeof(snapshot.mana.get(kind)) != TYPE_INT or snapshot.mana[kind] < 0:
			return false
	var seen: Dictionary = {}
	for key in ["hand", "draw_pile", "discard"]:
		for card in snapshot[key]:
			if typeof(card) != TYPE_DICTIONARY or not catalog.cards.has(card.get("id")) or typeof(card.get("uid")) != TYPE_INT or card.uid <= 0 or typeof(card.get("upgraded")) != TYPE_BOOL or seen.has(card.uid):
				return false
			seen[card.uid] = true
	seen.clear()
	for id in snapshot.relics:
		if typeof(id) != TYPE_STRING or not catalog.relics.has(id) or seen.has(id):
			return false
		seen[id] = true
	if snapshot.log_lines.size() > 50:
		return false
	for line in snapshot.log_lines:
		if typeof(line) != TYPE_STRING:
			return false
	return true

func _valid_intent(step: Variant) -> bool:
	if typeof(step) != TYPE_DICTIONARY:
		return false
	match step.get("type"):
		"attack": return _whole_number(step.get("damage"), 0) and _whole_number(step.get("hits"), 1)
		"guard": return _whole_number(step.get("amount"), 0)
		"charge": return typeof(step.get("description")) == TYPE_STRING
	return false

func _whole_number(value: Variant, minimum: int) -> bool:
	# Catalog JSON produces floats even for integral enemy parameters.
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= minimum and float(value) == floorf(float(value))

func setup(deck: Array, attributes: Array, owned_relics: Array, enemy_data: Dictionary, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	board.setup(attributes, rng.randi())
	relics = owned_relics.duplicate()
	enemy = enemy_data.duplicate(true)
	enemy_hp = int(enemy.hp)
	enemy_max_hp = enemy_hp
	draw_pile = deck.duplicate(true)
	_shuffle(draw_pile)
	for kind in Catalog.ATTRIBUTES:
		mana[kind] = 0
	if "r01" in relics:
		mana.condensation += 1
	_start_turn()

func _shuffle(items: Array) -> void:
	for i in range(items.size()-1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = items[i]
		items[i] = items[j]
		items[j] = temp

func note(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 50:
		log_lines.pop_front()

func attack() -> int:
	return 6 + level - 1 + attack_bonus

func draw_cards(count: int) -> int:
	var drawn := 0
	for _i in range(count):
		if draw_pile.is_empty() and not discard.is_empty():
			draw_pile = discard.duplicate()
			discard.clear()
			_shuffle(draw_pile)
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn

func _start_turn() -> void:
	turn += 1
	auto_hint_used = false
	guard = 0
	played = 0
	attack_bonus = 0
	next_damage = 0.0
	next_guard = 0
	next_pierce = false
	intent = enemy.pattern[intent_index % enemy.pattern.size()].duplicate(true)
	phase = "board"
	draw_cards(5)
	note("第 %d 回合：先消除，再出牌。" % turn)

func start_swap(a: int, b: int) -> bool:
	if phase != "board" or not board.start_swap(a, b):
		return false
	phase = "resolving"
	return true

func start_activate(index: int) -> bool:
	if phase != "board" or not board.start_activate(index):
		return false
	phase = "resolving"
	return true

func advance_board() -> Dictionary:
	if phase != "resolving":
		return {}
	var step: Dictionary = board.advance()
	for kind in step.gained:
		var amount: int = step.gained[kind]
		if kind == "star":
			gain_xp(amount)
		elif kind == "guard":
			guard += amount
		else:
			mana[kind] += amount
	if not board.resolving:
		if "r03" in relics and board.action_yields.get("guard", 0) >= 3:
			guard += 3
		phase = "play"
		var parts: Array[String] = []
		for kind in board.action_yields:
			parts.append("%s +%d" % [Catalog.NAMES[kind], board.action_yields[kind]])
		note("消除完成：" + "，".join(parts))
		if board.reshuffled:
			note("无可用行动，棋盘已免费重排。")
	return step

func gain_xp(amount: int) -> void:
	if level >= 10:
		return
	xp += amount
	while level < 10 and xp >= level + 2:
		xp -= level + 2
		level += 1
		max_hp += 5
		hp = mini(max_hp, hp + 5)
		note("升至 %d 级：攻击 +1，生命上限及当前生命 +5。" % level)
	if level == 10:
		xp = 0

func can_play(index: int) -> bool:
	if phase != "play" or index < 0 or index >= hand.size():
		return false
	for kind in catalog.cost(hand[index]):
		if mana.get(kind, 0) < catalog.cost(hand[index])[kind]:
			return false
	return true

func card_values(card: Dictionary) -> Dictionary:
	# Pure calculation shared by the face preview and the actual play resolution.
	var upgraded: bool = card.get("upgraded", false)
	var initial_guard := guard
	var initial_enemy_guard := enemy_guard
	var multiplier := 0.0
	var flat := 0
	var block := 0
	var guard_first := false
	var attack_gain := 0
	var damage_bonus := 0.0
	var guard_consumed := 0
	var pierce := false
	match card.id:
		"c01", "g11": multiplier = 1.5 if upgraded else 1.0
		"c02": block = 8 if upgraded else 5
		"c03":
			multiplier = 0.75 if upgraded else 0.5
			block = 5 if upgraded else 3
		"c04": multiplier = (1.5 if upgraded else 1.0) + 0.25 * mini(played, 3)
		"c05": multiplier = 1.0 + (1.0 if initial_guard >= (4 if upgraded else 6) else 0.0)
		"c06": multiplier = 2.5
		"g01": attack_gain = 3 if upgraded else 2
		"g02": damage_bonus = 1.0 if upgraded else 0.75
		"g03": multiplier = (1.0 if upgraded else 0.75) * (2 if played >= 2 else 1)
		"g04": multiplier = (2.5 if upgraded else 2.0) + 0.25 * mini(played, 4)
		"g05": block = 9 if upgraded else 6
		"g06": block = 6 if upgraded else 4
		"g07":
			flat = mini(guard, 12 if upgraded else 8)
			guard_consumed = flat
			multiplier = 1.0
		"g08":
			block = 6 if upgraded else 4
			multiplier = 0.75 if upgraded else 0.5
			guard_first = true
		"g09":
			damage_bonus = 0.75 if upgraded else 0.25
			pierce = true
		"g10": block = 12
		"g12":
			multiplier = 1.5 if upgraded else 1.0
			flat = 2 if initial_enemy_guard == 0 else 0
	if block > 0:
		block += next_guard
	var damage := 0
	if multiplier > 0:
		damage = ceili(attack() * (multiplier + next_damage)) + flat
		if "r04" in relics and initial_guard >= 6:
			damage += 2
	return {"damage": damage, "block": block, "guard_first": guard_first,
		"attack_gain": attack_gain, "damage_bonus": damage_bonus,
		"guard_consumed": guard_consumed, "pierce": pierce,
		# Deferred damage joins the next card's multiplier before rounding.
		"extra_damage": attack() * damage_bonus,
		"attacks": multiplier > 0}

func play_card(index: int) -> bool:
	if not can_play(index):
		return false
	var card: Dictionary = hand[index]
	var upgraded: bool = card.get("upgraded", false)
	var values := card_values(card)
	for kind in catalog.cost(card):
		mana[kind] -= int(catalog.cost(card)[kind])
	hand.remove_at(index)
	attack_bonus += int(values.attack_gain)
	next_damage += float(values.damage_bonus)
	next_pierce = next_pierce or bool(values.pierce)
	guard -= int(values.guard_consumed)
	var block := int(values.block)
	if block > 0:
		next_guard = 0
	if values.guard_first:
		guard += block
	var damage := int(values.damage)
	if values.attacks:
		var absorbed: int = 0 if next_pierce else mini(enemy_guard, damage)
		enemy_guard -= absorbed
		enemy_hp = maxi(0, enemy_hp - damage + absorbed)
		next_damage = 0.0
		next_pierce = false
	if not values.guard_first:
		guard += block
	# Register after consuming the previous buff; the setter cannot buff itself.
	if card.id == "g06":
		next_guard += 4 if upgraded else 3
	played += 1
	if "r02" in relics and played == 3:
		guard += 2
	discard.append(card)
	note("%s%s%s" % [catalog.cards[card.id].name, " · 伤害 %d" % damage if damage else "", " · 格挡 +%d" % block if block else ""])
	if enemy_hp <= 0:
		phase = "ended"
		result = "victory"
	elif hand.is_empty():
		var drawn := draw_cards(5)
		if drawn > 0:
			note("手牌用尽，补入 %d 张。" % drawn)
			if "r05" in relics and not refill_triggered:
				mana.condensation += 1
				refill_triggered = true
	return true

func end_turn() -> bool:
	if phase != "play":
		return false
	phase = "enemy"
	discard.append_array(hand)
	hand.clear()
	enemy_guard = 0
	match intent.type:
		"attack":
			for _hit in range(int(intent.hits)):
				var damage: int = intent.damage
				var absorbed: int = mini(guard, damage)
				guard -= absorbed
				hp = maxi(0, hp - damage + absorbed)
			note("敌人攻击 %d × %d。" % [intent.damage, intent.hits])
		"guard":
			enemy_guard = int(intent.amount)
			note("敌人获得 %d 格挡。" % enemy_guard)
		"charge": note("敌人正在蓄力。")
	intent_index += 1
	if hp <= 0:
		phase = "ended"
		result = "defeat"
	else:
		_start_turn()
	return true

func use_supply(id: String, attribute: String = "") -> bool:
	if phase not in ["board", "play"]:
		return false
	match id:
		"healing_vial": hp = mini(max_hp, hp + 20)
		"guard_vial": guard += 10
		"energy_vial":
			if attribute not in Catalog.ATTRIBUTES:
				return false
			mana[attribute] += 3
		_: return false
	note("使用：" + catalog.supplies[id].name)
	return true

func intent_text() -> String:
	match intent.get("type", ""):
		"attack": return "攻击 %d × %d" % [intent.damage, intent.hits]
		"guard": return "获得 %d 格挡" % intent.amount
		"charge":
			var following: Dictionary = enemy.pattern[(intent_index+1) % enemy.pattern.size()]
			return "蓄力 · 下回合 %d × %d" % [following.get("damage", 0), following.get("hits", 1)]
	return ""
