extends SceneTree

const Catalog = preload("res://scripts/v2/catalog.gd")
const Board = preload("res://scripts/v2/board.gd")
const Combat = preload("res://scripts/v2/combat.gd")
const Run = preload("res://scripts/v2/run.gd")
var catalog = Catalog.new()
var failures := 0
var checks := 0
const ATTRS = ["condensation", "thermal", "conductive", "aero"]

func _initialize() -> void:
	_test_board()
	_test_combat()
	_test_content()
	_test_run()
	_test_save()
	print("GAMEPLAY_V2: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func fresh_combat(ids: Array, relics: Array = []):
	var battle = Combat.new()
	var deck: Array = []
	for i in range(ids.size()):
		deck.append({"id": ids[i], "uid": i, "upgraded": false})
	var enemy: Dictionary = catalog.enemies.patrol.duplicate(true)
	enemy.hp = 1000
	battle.setup(deck, ATTRS, relics, enemy, 123)
	battle.hand = deck.duplicate(true)
	battle.draw_pile.clear()
	battle.discard.clear()
	battle.phase = "play"
	return battle

func fill_board(board) -> void:
	board.cells.clear()
	for y in range(8):
		for x in range(8):
			board.cells.append(board.piece(board.kinds[(x+y*2) % 6]))

func finish_board(board) -> int:
	var steps := 0
	var automatic := true
	while board.resolving and steps < 1000:
		board.advance()
		automatic = automatic and not board.pending_rainbow
		steps += 1
	check(steps < 1000, "Board resolver must terminate")
	check(automatic, "New board actions resolve every rainbow without a choice pause")
	return steps

func rainbow_board(seed_value: int = 123):
	var board = Board.new()
	board.setup(ATTRS, seed_value)
	fill_board(board)
	return board

func target_cells(board, target_kinds: Array, extra: Array = []) -> Array:
	var result: Array = extra.duplicate()
	for i in range(board.cells.size()):
		if board.cells[i] != null and board.cells[i].kind in target_kinds and i not in result:
			result.append(i)
	return result

func check_first_clear(board, expected: Array, description: String) -> Dictionary:
	# Examine only the queued removal step. Random refill/cascades are a later step.
	var before: Array = board.cells.duplicate(true)
	var counts: Dictionary = {}
	for index in expected:
		var kind: String = before[index].kind
		counts[kind] = int(counts.get(kind, 0)) + 1
	var step: Dictionary = board.advance()
	var actual: Array = step.removed.duplicate()
	var ordered: Array = expected.duplicate()
	actual.sort()
	ordered.sort()
	check(actual == ordered, description + ": exact cleared cells")
	check(step.gained == counts and board.action_yields == counts, description + ": each removed cell yields its own resource once")
	var intact := true
	for i in range(board.cells.size()):
		intact = intact and (board.cells[i] == null if i in expected else board.cells[i] == before[i])
	check(intact, description + ": no refill or unrelated deletion in the clear step")
	check(not board.pending_rainbow and board.queue.is_empty(), description + ": all chained specials resolve without a pause")
	return step

func _test_board() -> void:
	for seed_value in range(40):
		var board = Board.new()
		board.setup(ATTRS, seed_value)
		check(board.matches().is_empty(), "Initial board has no matches")
		check(board.has_action(), "Initial board has a legal action")
		check(board.action_yields.is_empty(), "Initialization emits no resources")
		var move: Array = board.hint()
		check(board.start_swap(move[0], move[1]), "Hint gives legal swap")
		finish_board(board)
		check(board.matches().is_empty(), "Finished board stable")
		check(board.has_action(), "Finished board playable")
	var board = Board.new()
	board.setup(ATTRS, 7)
	fill_board(board)
	var original: Array = board.cells.duplicate(true)
	check(not board.start_swap(0, 1), "Invalid swap rejected")
	check(board.cells == original and not board.resolving, "Invalid swap restores board and action")
	check(not board.start_swap(7, 8), "Row wrapping is not adjacency")
	for i in range(4):
		board.cells[i] = board.piece("condensation")
	board._begin()
	board._queue_matches(board.matches())
	var step: Dictionary = board.advance()
	check(board.cells[0].special == "stripe", "Four match retains stripe")
	check(step.gained.get("condensation", 0) == 3, "Retained stripe gives no resource")
	check(board.cells[0].kind == "condensation", "Special keeps underlying kind")
	fill_board(board)
	for i in range(5):
		board.cells[i] = board.piece("star")
	board._begin()
	board._queue_matches(board.matches())
	board.advance()
	check(board.cells[0].special == "rainbow", "Five match makes rainbow including stars")
	fill_board(board)
	for i in [18, 19, 20, 11, 27]:
		board.cells[i] = board.piece("guard")
	board._begin()
	board._queue_matches(board.matches())
	var bombs := 0
	for cell in board.cells:
		if cell.special == "bomb":
			bombs += 1
	check(bombs == 1, "Cross shape forms one bomb")
	fill_board(board)
	board.cells[27] = board.piece("condensation", "bomb")
	board.cells[28] = board.piece("thermal", "bomb")
	board.resolving = false
	check(board.start_activate(27), "Manual special activation")
	step = board.advance()
	check(step.removed.size() == 12, "Overlapping 3x3 bombs remove union of 12 cells")
	var total := 0
	for amount in step.gained.values():
		total += amount
	check(total == 12, "Overlapping effects yield each cell once")
	fill_board(board)
	board.cells[0] = board.piece("condensation", "stripe", "h")
	board.cells[8] = board.piece("thermal", "stripe", "v")
	board.resolving = false
	check(board.start_swap(0, 8), "Two specials swap without match")
	step = board.advance()
	check(step.removed.size() == 15, "Two stripes trigger at swapped positions")
	fill_board(board)
	board.cells[0].special = "bomb"
	check(board.has_action(), "Special prevents false deadlock")
	_test_rainbows()

func _test_rainbows() -> void:
	for rainbow_index in [27, 28]:
		for reverse in [false, true]:
			var board = rainbow_board()
			var other: int = 55 - rainbow_index
			board.cells[rainbow_index] = board.piece("condensation", "rainbow")
			board.cells[other] = board.piece("thermal")
			check(board.start_swap(28 if reverse else 27, 27 if reverse else 28), "Rainbow swap works in either argument direction and either slot")
			var expected: Array = target_cells(board, ["thermal"], [other])
			var step := check_first_clear(board, expected, "Rainbow swaps with the other ball's thermal kind")
			check(step.gained.get("condensation", 0) == 1, "Swapping rainbow removes its own ball without clearing every ball of its own kind")
			check(not board.choose_rainbow("star"), "New rainbow action rejects manual target selection")
	for target in ["star", "guard"]:
		var board = rainbow_board()
		board.cells[27] = board.piece("condensation", "rainbow")
		board.cells[28] = board.piece(target)
		check(board.start_swap(27, 28), "Rainbow swaps with an experience or guard ball")
		check_first_clear(board, target_cells(board, [target], [28]), "Rainbow targets " + target + " from its swap partner")
	for kind in ["condensation", "star", "guard"]:
		var board = rainbow_board()
		board.cells[27] = board.piece(kind, "rainbow")
		check(board.start_activate(27), "Direct rainbow activation is legal")
		check_first_clear(board, target_cells(board, [kind]), "Direct rainbow clears its own " + kind + " kind")
	for partner in ["stripe", "bomb"]:
		for reverse in [false, true]:
			var board = rainbow_board()
			board.cells[27] = board.piece("condensation", "rainbow")
			board.cells[28] = board.piece("thermal", partner, "h")
			check(board.start_swap(28 if reverse else 27, 27 if reverse else 28), "Rainbow swaps with " + partner + " in either processing order")
			var area: Array = range(24, 32) if partner == "stripe" else [18, 19, 20, 26, 27, 28, 34, 35, 36]
			check_first_clear(board, target_cells(board, ["thermal"], area), "Swapped rainbow retains the partner kind when also struck by " + partner)
	for effect in ["stripe", "bomb"]:
		var board = rainbow_board()
		var source: int = 24 if effect == "stripe" else 27
		board.cells[source] = board.piece("thermal", effect, "h")
		board.cells[28] = board.piece("guard", "rainbow")
		check(board.start_activate(source), "Activate a " + effect + " that reaches a rainbow")
		var area: Array = range(24, 32) if effect == "stripe" else [18, 19, 20, 26, 27, 28, 34, 35, 36]
		check_first_clear(board, target_cells(board, ["guard"], area), "Rainbow hit by " + effect + " clears its own guard kind")
	var board = rainbow_board()
	for i in [16, 17, 18]:
		board.cells[i] = board.piece("condensation", "rainbow" if i == 17 else "")
	check(board.matches().size() == 1 and board.matches()[0].indices.size() == 3, "Rainbow match fixture contains exactly one ordinary triple")
	board._begin()
	board._queue_matches(board.matches())
	check_first_clear(board, target_cells(board, ["condensation"]), "An existing rainbow included in a triple clears its own kind")
	for reverse in [false, true]:
		board = rainbow_board()
		board.cells[0] = board.piece("condensation", "rainbow")
		board.cells[1] = board.piece("thermal", "rainbow")
		check(board.start_swap(1 if reverse else 0, 0 if reverse else 1), "Two different-kind rainbows swap in either direction")
		check_first_clear(board, target_cells(board, ["condensation", "thermal"]), "Each swapped rainbow targets the other rainbow's kind")
	board = rainbow_board()
	board.cells[0] = board.piece("condensation", "rainbow")
	board.cells[1] = board.piece("condensation", "rainbow")
	check(board.start_swap(0, 1), "Two same-kind rainbows can swap")
	check_first_clear(board, target_cells(board, ["condensation"]), "Same-kind swapped rainbows count their overlapping clear only once")
	board = rainbow_board()
	for i in [0, 12, 27]:
		board.cells[i] = board.piece("condensation", "rainbow")
	check(board.start_activate(0), "Activate one of several same-kind rainbows")
	check_first_clear(board, target_cells(board, ["condensation"]), "A rainbow hit by another rainbow resolves itself without double-counting resources")
	board = rainbow_board()
	board.cells[0] = board.piece("condensation", "rainbow")
	board.cells[8] = board.piece("condensation", "stripe", "h")
	board.cells[9] = board.piece("thermal", "rainbow")
	board.cells[28] = board.piece("thermal", "bomb")
	board.cells[27] = board.piece("aero", "rainbow")
	check(board.start_activate(0), "Begin a three-kind recursive rainbow chain")
	var area: Array = range(8, 16)
	for i in [19, 20, 21, 27, 28, 29, 35, 36, 37]:
		if i not in area:
			area.append(i)
	check_first_clear(board, target_cells(board, ["condensation", "thermal", "aero"], area), "Rainbow to stripe to rainbow to bomb to rainbow resolves every kind in one clear step")
	board = rainbow_board(7)
	for i in range(64):
		board.cells[i] = board.piece("condensation", "rainbow" if i == 0 else "")
	check(board.start_activate(0), "An all-kind rainbow can clear the full board")
	check_first_clear(board, range(64), "Full-board rainbow clearing yields exactly 64 resources before refill")
	var serial_before: int = board.serial
	var refill: Dictionary = board.advance()
	check(refill.removed.is_empty() and refill.gained.is_empty(), "Refill adds balls without emitting resources before cascade clears")
	check(board.cells.all(func(cell): return cell != null) and board.serial > serial_before, "A fully cleared board refills all 64 cells")
	check(not board.pending_rainbow, "Full-board refill does not request a rainbow target")
	finish_board(board)
	check(board.matches().is_empty() and board.has_action(), "Full-board clear and following cascades finish stable and playable")
	board = rainbow_board()
	board.cells[56] = board.piece("thermal", "stripe", "h")
	for i in [48, 49, 50]:
		board.cells[i] = board.piece("star", "rainbow" if i == 49 else "")
	check(board.start_activate(56), "Start a clear that drops an existing rainbow into a later match")
	check_first_clear(board, range(56, 64), "The first stripe clears only the bottom row before gravity")
	board.advance()
	check(board.cells[57].special == "rainbow" and board.cells[57].kind == "star", "Gravity moves the existing rainbow into a queued star triple")
	var star_count: int = target_cells(board, ["star"]).size()
	var cascade: Dictionary = board.advance()
	check(cascade.gained.get("star", 0) == star_count and not board.pending_rainbow, "Rainbow triggered by a gravity cascade clears all current stars automatically")
	finish_board(board)

func _test_combat() -> void:
	var battle = fresh_combat(["g01", "g02", "g03", "c04", "c01"])
	battle.mana = {"condensation": 2, "thermal": 1, "conductive": 1, "aero": 1, "diffraction": 0, "annihilation": 0}
	for _i in range(5):
		check(battle.play_card(0), "Chain example card playable")
	check(battle.enemy_hp == 960, "Chain example deals exactly 40")
	check(battle.hand.size() == 5 and battle.played == 5, "Empty hand refills immediately")
	check(not battle.play_card(0), "Insufficient mana cannot play")
	battle = fresh_combat(["g06", "g05", "c05", "g07", "c03"])
	battle.mana = {"condensation": 2, "thermal": 0, "conductive": 1, "aero": 0, "diffraction": 1, "annihilation": 1}
	for _i in range(5):
		battle.play_card(0)
	check(battle.enemy_hp == 971 and battle.guard == 8, "Guard example deals 29 and leaves 8 block")
	battle = fresh_combat(["g06", "g06", "c02"])
	battle.mana.conductive = 2
	battle.mana.condensation = 1
	battle.play_card(0)
	check(battle.guard == 4, "Guard buff cannot buff its setter")
	battle.play_card(0)
	check(battle.guard == 11, "Second setter consumes previous buff")
	battle.play_card(0)
	check(battle.guard == 19, "Second setter registers buff for next card")
	battle = fresh_combat(["g09", "g02", "c01"])
	battle.enemy_guard = 100
	battle.mana.diffraction = 1
	battle.mana.conductive = 1
	battle.mana.condensation = 1
	for _i in range(3):
		battle.play_card(0)
	check(battle.enemy_hp == 988 and battle.enemy_guard == 100, "Next attack buffs stack and pierce guard")
	battle = fresh_combat(["g07"], ["r04"])
	battle.guard = 8
	battle.mana.annihilation = 1
	battle.play_card(0)
	check(battle.enemy_hp == 984, "Relic checks block before card consumes it")
	battle = fresh_combat(["c01"], ["r05"])
	battle.mana.condensation = 3
	battle.play_card(0)
	check(battle.hand.size() == 1 and battle.mana.condensation == 3, "One-card deck cycles and first refill relic fires")
	battle.play_card(0)
	check(battle.mana.condensation == 2, "Refill relic fires only once per fight")
	battle.enemy_hp = 1
	battle.play_card(0)
	check(battle.result == "victory" and battle.hand.is_empty(), "Lethal card ends before refill")
	battle = fresh_combat([])
	check(battle.hand.is_empty(), "Empty deck supported")
	battle.guard = 20
	battle.mana.thermal = 9
	battle.end_turn()
	check(battle.hp == 60 and battle.guard == 0 and battle.mana.thermal == 9, "Guard absorbs then expires, mana persists")
	check(battle.hand.is_empty() and battle.phase == "board", "Empty deck advances without recursive refill")
	check(not battle.end_turn(), "Cannot bypass the board phase")
	battle.hp = 15
	battle.gain_xp(3)
	check(battle.level == 2 and battle.max_hp == 65 and battle.hp == 20, "Upgrade heals only increase in max HP")
	battle.gain_xp(1000)
	check(battle.level == 10 and battle.xp == 0 and battle.max_hp == 105, "Level cap and overflow")
	var before: int = battle.hp
	battle.gain_xp(20)
	check(battle.hp == before and battle.xp == 0, "Stars do not convert at max level")
	battle = fresh_combat(["c01"])
	battle.enemy.pattern = [{"type": "guard", "amount": 8}, {"type": "attack", "damage": 2, "hits": 1}]
	battle.intent = {"type": "guard", "amount": 8}
	battle.end_turn()
	check(battle.enemy_guard == 8, "Enemy block survives into player turn")
	battle.phase = "play"
	battle.mana.condensation = 1
	battle.play_card(0)
	check(battle.enemy_hp == 1000 and battle.enemy_guard == 2, "Enemy block is consumed by card damage")
	battle.end_turn()
	check(battle.enemy_guard == 0 and battle.hp == 58, "Enemy remaining guard expires at enemy action")
	battle.phase = "play"
	battle.intent = {"type": "attack", "damage": 3, "hits": 2}
	battle.guard = 4
	battle.end_turn()
	check(battle.hp == 56, "Multihit consumes guard across hits")
	battle.phase = "resolving"
	check(not battle.use_supply("guard_vial"), "No supply use during resolution")
	battle.phase = "board"
	check(battle.use_supply("energy_vial", "annihilation") and battle.mana.annihilation == 3, "Supply can give an attribute outside board")
	check(battle.phase == "board" and battle.played == 0, "Supply does not spend action or count as card")
	battle = fresh_combat([])
	battle.phase = "board"
	fill_board(battle.board)
	var before_invalid: Dictionary = battle.mana.duplicate()
	check(not battle.start_swap(0, 1), "An invalid combat swap is rejected")
	check(battle.phase == "board" and battle.mana == before_invalid and battle.board.action_yields.is_empty(), "Invalid combat swap spends neither the board action nor resources")
	# Reset to a generated board with a known legal ordinary move.
	battle.board.setup(ATTRS, 123)
	var enemy_before: int = battle.enemy_hp
	var move: Array = battle.board.hint()
	battle.start_swap(move[0], move[1])
	var iterations := 0
	while battle.phase == "resolving" and iterations < 1000:
		battle.advance_board()
		iterations += 1
	check(battle.phase == "play" and battle.enemy_hp == enemy_before, "Match gives resources without hurting enemy")
	check(not battle.start_swap(move[0], move[1]), "Only one board action per turn")
	for kind in ["star", "guard"]:
		battle = fresh_combat([])
		battle.phase = "board"
		fill_board(battle.board)
		battle.board.cells[27] = battle.board.piece(kind, "rainbow")
		var quantity: int = target_cells(battle.board, [kind]).size()
		check(battle.start_activate(27), "Combat can activate a " + kind + " rainbow directly")
		battle.advance_board()
		check(not battle.board.pending_rainbow and battle.enemy_hp == 1000, "Automatic rainbow resources never deal direct enemy damage")
		check(battle.guard == quantity if kind == "guard" else battle.level == 3 and battle.xp == quantity - 7, "Automatic " + kind + " rainbow applies the correct guard or experience")
		iterations = 0
		while battle.phase == "resolving" and iterations < 1000:
			battle.advance_board()
			iterations += 1
		check(battle.phase == "play" and not battle.board.pending_rainbow, "Automatic rainbow combat resolution reaches the play phase without UI input")

func _test_content() -> void:
	check(catalog.cards.size() == 18 and catalog.relics.size() == 5 and catalog.supplies.size() == 3, "Content counts")
	var damage_results := {"c01": [6,9], "c02": [0,0], "c03": [3,5], "c04": [6,9], "c05": [6,6], "c06": [15,15], "g01": [0,0], "g02": [0,0], "g03": [5,6], "g04": [12,15], "g05": [0,0], "g06": [0,0], "g07": [6,6], "g08": [3,5], "g09": [0,0], "g10": [0,0], "g11": [6,9], "g12": [8,11]}
	var guard_results := {"c02": [5,8], "c03": [3,5], "g05": [6,9], "g06": [4,6], "g08": [4,6], "g10": [12,12]}
	for id in catalog.cards:
		for upgraded in [false, true]:
			var battle = fresh_combat([id])
			battle.hand[0].upgraded = upgraded
			for kind in Catalog.ATTRIBUTES:
				battle.mana[kind] = 10
			check(battle.play_card(0), "All base and upgraded cards execute: " + id)
			check(1000-battle.enemy_hp == damage_results[id][int(upgraded)], "Exact base/upgraded damage: " + id)
			check(battle.guard == guard_results.get(id, [0,0])[int(upgraded)], "Exact base/upgraded guard: " + id)
			check(battle.discard.size() + battle.hand.size() + battle.draw_pile.size() == 1, "Card conservation through refill: " + id)
	var battle = fresh_combat(["c06", "g10"])
	battle.hand[0].upgraded = true
	battle.hand[1].upgraded = true
	battle.mana.condensation = 2
	battle.play_card(0)
	battle.play_card(0)
	check(battle.mana.condensation == 0 and battle.enemy_hp == 985 and battle.guard == 12, "Upgraded cost reductions")
	battle = fresh_combat(["c01", "c01", "c01"], ["r01", "r02"])
	check(battle.mana.condensation == 1, "Native mana relic triggers at battle start")
	battle.mana.condensation = 10
	for _i in range(3):
		battle.play_card(0)
	check(battle.guard == 2, "Third card relic fires once")
	for _i in range(3):
		battle.play_card(0)
	check(battle.guard == 2, "Sixth card does not retrigger third card relic")
	battle = fresh_combat([], ["r03"])
	fill_board(battle.board)
	for i in range(3):
		battle.board.cells[i] = battle.board.piece("guard")
	battle.phase = "resolving"
	battle.board._begin()
	battle.board._queue_matches(battle.board.matches())
	while battle.phase == "resolving":
		battle.advance_board()
	check(battle.guard == int(battle.board.action_yields.get("guard", 0)) + 3, "Guard-ball relic fires once for entire cascade")

func _test_run() -> void:
	for seed_value in range(50):
		var run_state = Run.new()
		run_state.setup(ATTRS, seed_value)
		check(run_state.deck.size() == 10, "Starter deck size")
		for id in run_state.nodes:
			var node: Dictionary = run_state.nodes[id]
			if node.row < 11:
				check(not node.next.is_empty(), "Every non-boss node has continuation")
			for next in node.next:
				var target: Dictionary = run_state.nodes[next]
				check(target.row == node.row + 1, "Edges advance exactly one row")
				check(node.type == "start" or absi(target.col-node.col) <= 1, "Encounter edges move at most one column; origin connects all entrances")
				check(not (node.type in ["rest", "shop"] and node.type == target.type), "No adjacent rests or shops")
			if node.row == 1:
				check(node.type == "battle", "First row battles")
			if node.row == 10:
				check(node.type == "rest", "Last pre-boss row rests")
		while run_state.phase != "ended":
			check(run_state.enter_node(run_state.available[0]), "Forward traversal")
			if run_state.phase == "boss":
				run_state.finish_battle(true)
			else:
				if run_state.phase == "battle":
					run_state.finish_battle(true)
				while not run_state.rewards.is_empty():
					run_state.accept_reward()
				run_state.complete_node()
		check(run_state.outcome == "victory", "Every route reaches boss")
	var run_state = Run.new()
	run_state.setup(ATTRS, 1)
	var first: String = run_state.available[0]
	run_state.enter_node(first)
	check(not run_state.enter_node(first), "Cannot enter node twice")
	run_state.finish_battle(false)
	check(run_state.lives == 2 and run_state.phase == "rewards", "Ordinary loss advances with rewards and life cost")
	var money: int = run_state.shells
	check(not run_state.finish_battle(false) and run_state.shells == money, "Battle reward is idempotent")
	while not run_state.rewards.is_empty():
		run_state.accept_reward()
	run_state.complete_node()
	check(first in run_state.visited and not run_state.enter_node(first), "Completed node cannot be revisited")
	run_state.phase = "boss"
	run_state.finish_battle(false)
	check(run_state.lives == 0 and run_state.phase == "ended" and run_state.outcome == "defeat", "Boss loss directly zeroes lives")
	run_state = Run.new()
	run_state.setup(ATTRS, 2)
	run_state.enter_node(run_state.available[0])
	run_state.phase = "rest"
	check(run_state.modify_deck(0, true), "Upgrade card")
	run_state.phase = "rest"
	check(not run_state.modify_deck(0, true), "Cannot upgrade same copy twice")
	run_state.visited.clear()
	while not run_state.deck.is_empty():
		run_state.phase = "rest"
		run_state.visited.clear()
		run_state.modify_deck(0, false)
	check(run_state.deck.is_empty(), "Permanent removal can empty deck")
	run_state.phase = "shop"
	run_state.shells = 100
	run_state.supplies = ["healing_vial", "guard_vial", "energy_vial"]
	run_state.stock = [{"type": "supply", "id": "healing_vial", "price": 15, "sold": false}]
	check(not run_state.buy(0) and run_state.shells == 100, "Full inventory purchase does not charge before replacement")
	check(run_state.buy(0, 1) and run_state.shells == 85 and run_state.supplies[1] == "healing_vial", "Replacement and charge atomic")
	check(not run_state.buy(0), "Shop stock cannot be bought twice")
	run_state.phase = "event"
	run_state.event_id = "trade_life"
	run_state.lives = 1
	run_state.event_choice(0)
	check(run_state.phase == "ended" and run_state.relics.is_empty(), "Lethal event ends without reward")
	var offered: Array = run_state.sample(catalog.cards.keys(), 3)
	check(offered.size() == 3 and offered[0] != offered[1] and offered[1] != offered[2] and offered[0] != offered[2], "Reward candidates distinct")
	for event in ["cache", "workbench", "trade_life", "prune"]:
		for choice in [0, 1]:
			var event_run = Run.new()
			event_run.setup(ATTRS, 9)
			event_run.enter_node(event_run.available[0])
			event_run.phase = "event"
			event_run.event_id = event
			if choice == 0 and event in ["workbench", "prune"]:
				event_run.modify_deck(0, event == "workbench", 15 if event == "workbench" else 0)
			else:
				event_run.event_choice(choice)
				while not event_run.rewards.is_empty():
					event_run.accept_reward()
				if event_run.phase == "rewards":
					event_run.complete_node()
			check(event_run.phase == "map", "Event returns to map: " + event)
	var terminal = Run.new()
	terminal.setup(ATTRS, 7)
	terminal.enter_node(terminal.available[0])
	check(not terminal.complete_node(), "Cannot skip unfinished battle")
	terminal.lives = 1
	terminal.finish_battle(false)
	check(terminal.phase == "ended" and terminal.rewards.is_empty(), "Last ordinary life ends without run items")
	var relic_run = Run.new()
	relic_run.setup(ATTRS, 3)
	relic_run.relics = catalog.relics.keys()
	relic_run.queue_relic()
	check(relic_run.shells == 35 and relic_run.relics.size() == 5, "Exhausted relic pool converts to shells")

func _test_save() -> void:
	# Separate fixture; never rewrite the player's actual save during regression tests.
	var path := "user://gameplay_v2_test_fixture.cfg"
	var config := ConfigFile.new()
	config.set_value("legacy", "unlocks", ["a", "b"])
	config.set_value("settings", "volume", 0.37)
	config.set_value("gameplay_v2", "runs", 2)
	check(config.save(path) == OK, "Save fixture created")
	var run_state = Run.new()
	run_state.setup(ATTRS, 10)
	run_state.end_run("victory")
	run_state.battles_won = 7
	check(run_state.save_statistics(path) == OK, "New statistics save succeeds")
	run_state.save_statistics(path)
	config.load(path)
	check(config.get_value("legacy", "unlocks") == ["a", "b"] and config.get_value("settings", "volume") == 0.37, "Legacy save fields preserved")
	check(config.get_value("gameplay_v2", "runs") == 3 and config.get_value("gameplay_v2", "wins") == 1 and config.get_value("gameplay_v2", "battles_won") == 7, "Run statistics saved exactly once")
	check(DirAccess.remove_absolute(path) == OK, "Temporary save fixture cleaned up")
