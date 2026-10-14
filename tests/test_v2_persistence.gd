extends SceneTree

const Run = preload("res://scripts/v2/run.gd")
const Combat = preload("res://scripts/v2/combat.gd")
const Store = preload("res://scripts/v2/save_store.gd")
const ATTRS = ["condensation", "thermal", "conductive", "aero"]
var failures := 0
var checks := 0
var test_path := ""
var legacy_path := ""

func _initialize() -> void:
	test_path = "user://test_v2_persistence_%d.cfg" % Time.get_ticks_usec()
	legacy_path = test_path + ".legacy"
	_test_models()
	_test_rainbow_checkpoints()
	_test_auto_hint_checkpoints()
	_test_store()
	_test_node_checkpoints()
	for suffix in ["", ".bak", ".tmp", ".corrupt", ".legacy"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	print("V2_PERSISTENCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func fresh() -> Dictionary:
	var run_state = Run.new()
	run_state.setup(ATTRS, 20261006)
	var id: String = run_state.available[0]
	check(run_state.enter_node(id), "Enter the initial battle")
	var battle = Combat.new()
	battle.setup(run_state.deck, run_state.attributes, run_state.relics, run_state.enemy_for_node(), 8675309)
	return {"run": run_state, "combat": battle}

func metadata(id: String = "run-a") -> Dictionary:
	return {"run_id": id, "role_id": "condensation_coletta", "started_at": 1791273600}

func fill_board(board) -> void:
	board.cells.clear()
	for y in range(8):
		for x in range(8):
			board.cells.append(board.piece(board.kinds[(x + y * 2) % 6]))

func _test_models() -> void:
	var fixture := fresh()
	var run_state = fixture.run
	var battle = fixture.combat
	var run_copy = Run.new()
	check(run_copy.restore_snapshot(run_state.to_snapshot()) == OK, "Run snapshot restores")
	check(run_copy.to_snapshot() == run_state.to_snapshot(), "Every run field round trips")
	check(run_copy.rng.randi() == run_state.rng.randi(), "Run RNG resumes exactly")
	var bad: Dictionary = run_state.to_snapshot()
	bad.deck.append(bad.deck[0].duplicate())
	var before: Dictionary = run_copy.to_snapshot()
	check(run_copy.restore_snapshot(bad) == ERR_INVALID_DATA, "Duplicate deck instance rejected")
	check(run_copy.to_snapshot() == before, "Failed restore leaves model unchanged")
	bad = run_state.to_snapshot()
	bad.nodes[bad.current].next = ["missing"]
	check(run_copy.restore_snapshot(bad) == ERR_INVALID_DATA, "Unknown map link rejected")
	bad = run_state.to_snapshot()
	bad.phase = "unknown"
	check(run_copy.restore_snapshot(bad) == ERR_INVALID_DATA, "Unknown run phase rejected")
	fill_board(battle.board)
	battle.board.cells[0].special = "rainbow"
	battle.board.cells[1].special = "rainbow"
	check(battle.start_swap(0, 1), "Start double rainbow action")
	var battle_copy = Combat.new()
	check(battle_copy.restore_snapshot(battle.to_snapshot()) == OK, "Queued double rainbow restores")
	check(battle_copy.to_snapshot() == battle.to_snapshot(), "Every combat and board field round trips")
	check(battle.board.rainbow_targets.size() == 2 and not battle.board.pending_rainbow, "Both rainbow swap targets persist by UID without a choice")
	var steps := 0
	while battle.phase == "resolving" and steps < 1000:
		var a: Dictionary = battle.advance_board()
		var b: Dictionary = battle_copy.advance_board()
		check(a == b and battle.to_snapshot() == battle_copy.to_snapshot(), "Each resumed cascade gives identical resources and RNG result")
		check(not battle.board.pending_rainbow and not battle.board.legacy_rainbow_choice, "New rainbows never pause resumed resolution")
		steps += 1
	check(steps < 1000 and battle.phase == "play", "Double rainbow resolves into play phase")
	battle.attack_bonus = 3
	battle.next_damage = 0.75
	battle.next_guard = 4
	battle.next_pierce = true
	battle.refill_triggered = true
	battle.played = 3
	check(battle_copy.restore_snapshot(battle.to_snapshot()) == OK and battle_copy.to_snapshot() == battle.to_snapshot(), "One-shot card buffs and relic trigger flags restore")
	check(battle_copy.rng.randi() == battle.rng.randi() and battle_copy.board.rng.randi() == battle.board.rng.randi(), "Combat and board RNG resume exactly")
	bad = battle.to_snapshot()
	bad.draw_pile.append(bad.hand[0].duplicate())
	check(battle_copy.restore_snapshot(bad) == ERR_INVALID_DATA, "Duplicate cards across combat piles rejected")
	bad = battle.to_snapshot()
	bad.phase = "resolving"
	check(battle_copy.restore_snapshot(bad) == ERR_INVALID_DATA, "Board/combat phase mismatch rejected")
	bad = battle.to_snapshot()
	bad.board.queue = [64]
	check(battle_copy.restore_snapshot(bad) == ERR_INVALID_DATA, "Out-of-range board queue rejected")
	var empty_start = Run.new()
	empty_start.setup(ATTRS, 1)
	empty_start.end_run("abandoned")
	check(run_copy.restore_snapshot(empty_start.to_snapshot()) == OK, "Abandoning before entering first node is valid")

func _test_rainbow_checkpoints() -> void:
	var rainbow_path := test_path + ".rainbow"
	var store = Store.new(rainbow_path, legacy_path)
	check(store.load_store() == OK, "Create isolated rainbow checkpoint profile")
	var fixture := fresh()
	var battle = fixture.combat
	fill_board(battle.board)
	battle.board.cells[0].special = "rainbow"
	var source_uid: int = battle.board.cells[0].uid
	var target_kind: String = battle.board.cells[1].kind
	check(battle.start_swap(0, 1), "Queue single rainbow swap")
	check(battle.board.rainbow_targets == {source_uid: target_kind}, "Swap target belongs to rainbow UID after it moves")
	check(not battle.board.choose_rainbow("guard"), "New action cannot choose an arbitrary rainbow kind")
	check(store.checkpoint(fixture.run, battle, metadata("rainbow")) == OK, "Save queued rainbow before any resources are awarded")
	var reopened = Store.new(rainbow_path, legacy_path)
	check(reopened.load_store() == OK, "Reload UID target checkpoint")
	var restored: Dictionary = reopened.restore_active()
	check(not restored.is_empty() and restored.combat.to_snapshot() == battle.to_snapshot(), "Disk round trip retains exact rainbow target and RNG")
	var a: Dictionary = battle.advance_board()
	var b: Dictionary = restored.combat.advance_board()
	check(a == b and restored.combat.to_snapshot() == battle.to_snapshot(), "First restored removal clears the same target kind")
	check(battle.board.rainbow_targets.is_empty() and not battle.board.pending_rainbow, "Consumed UID target is erased before cells can refill")
	check(store.checkpoint(fixture.run, battle, metadata("rainbow")) == OK, "Save automatic rainbow resolution with holes")
	check(reopened.load_store() == OK, "Reload automatic removal checkpoint")
	restored = reopened.restore_active()
	var steps := 0
	while battle.phase == "resolving" and steps < 1000:
		a = battle.advance_board()
		b = restored.combat.advance_board()
		check(a == b and battle.to_snapshot() == restored.combat.to_snapshot(), "Automatic rainbow resume keeps every cascade and random state identical")
		steps += 1
	check(steps < 1000 and battle.phase == "play", "Automatic rainbow checkpoint completes without choosing")

	# A v1 pause already removed and credited its source; its unknown old target
	# must be chosen once rather than inferred from aggregate resource counters.
	fixture = fresh()
	battle = fixture.combat
	fill_board(battle.board)
	battle.board.cells[0].special = "rainbow"
	battle.board.cells[1].special = "rainbow"
	check(battle.start_activate(0), "Prepare genuine legacy pause phase")
	var legacy: Dictionary = battle.to_snapshot()
	var source_kind: String = legacy.board.cells[0].kind
	legacy.board.version = 1
	legacy.board.erase("rainbow_targets")
	legacy.board.erase("legacy_rainbow_choice")
	legacy.board.cells[0] = null
	legacy.board.queue = [1]
	legacy.board.pending_rainbow = true
	legacy.board.action_yields = {source_kind: 1}
	legacy.mana[source_kind] += 1
	var unchanged: Dictionary = legacy.duplicate(true)
	var old_profile: Dictionary = store.data.duplicate(true)
	old_profile.active = {"metadata": metadata("legacy-rainbow"), "run": fixture.run.to_snapshot(), "combat": legacy.duplicate(true)}
	var old_config := ConfigFile.new()
	old_config.set_value("gameplay_v2", "data", old_profile)
	check(old_config.save(rainbow_path) == OK, "Write an actual version-1 pending rainbow save")
	var old_contents := FileAccess.get_file_as_string(rainbow_path)
	check(reopened.load_store() == OK and reopened.has_active(), "Store accepts version-1 pending rainbow on disk")
	var restored_legacy: Dictionary = reopened.restore_active()
	check(restored_legacy.combat.board.pending_rainbow and restored_legacy.combat.board.legacy_rainbow_choice, "Disk legacy migration exposes its single outstanding choice")
	check(FileAccess.get_file_as_string(rainbow_path) == old_contents, "Loading old rainbow progress does not rewrite its source file")
	check(battle.restore_snapshot(legacy) == OK, "Version-1 deleted rainbow source restores")
	check(legacy == unchanged, "Legacy restore leaves the supplied snapshot unchanged")
	check(battle.board.pending_rainbow and battle.board.legacy_rainbow_choice and battle.board.rainbow_targets.is_empty(), "Only the already-paused old choice remains pending")
	check(battle.advance_board().gained.is_empty() and battle.board.pending_rainbow, "Legacy pause does not guess a target or duplicate source resources")
	check(not battle.board.choose_rainbow("unknown"), "Legacy choice still rejects unknown kinds")
	check(store.checkpoint(fixture.run, battle, metadata("legacy-rainbow")) == OK, "Save migrated legacy choice as board version 2")
	check(store.data.active.combat.board.version == 2 and store.data.active.combat.board.legacy_rainbow_choice, "Pending legacy flag is durable in the new schema")
	check(reopened.load_store() == OK, "Reload migrated legacy checkpoint")
	restored = reopened.restore_active()
	check(restored.combat.to_snapshot() == battle.to_snapshot(), "Restart preserves the exact outstanding legacy selection")
	check(battle.board.choose_rainbow("guard") and restored.combat.board.choose_rainbow("guard"), "Old pending choice is accepted once after restart")
	check(not battle.board.pending_rainbow and not battle.board.legacy_rainbow_choice and not battle.board.choose_rainbow("star"), "Completing old choice clears legacy permission immediately")
	a = battle.advance_board()
	b = restored.combat.advance_board()
	check(a == b and battle.to_snapshot() == restored.combat.to_snapshot(), "Legacy continuation resumes exact resources and RNG")
	check(a.gained.get(source_kind, 0) == 0 and battle.mana[source_kind] == 1, "Previously credited deleted rainbow source is not awarded again")
	check(a.gained.get("thermal", 0) > 1 and not battle.board.pending_rainbow, "Further queued rainbow uses its own kind under the new rule")
	steps = 0
	while battle.phase == "resolving" and steps < 1000:
		a = battle.advance_board()
		b = restored.combat.advance_board()
		check(a == b and battle.to_snapshot() == restored.combat.to_snapshot(), "Legacy cascade remains deterministic after the one old choice")
		check(not battle.board.pending_rainbow, "Further legacy cascades cannot open another old choice")
		steps += 1
	check(steps < 1000 and battle.phase == "play", "Migrated legacy action finishes automatically")

	fixture = fresh()
	battle = fixture.combat
	fill_board(battle.board)
	battle.board.cells[0].special = "rainbow"
	battle.start_swap(0, 1)
	var good: Dictionary = battle.to_snapshot()
	var copy = Combat.new()
	check(copy.restore_snapshot(good) == OK, "Target validation fixture restores")
	var before: Dictionary = copy.to_snapshot()
	for invalid_target in [{str(battle.board.cells[1].uid): "thermal"}, {battle.board.cells[1].uid: "unknown"}, {battle.board.cells[0].uid: "thermal"}, {battle.board.serial + 1: "thermal"}]:
		var bad: Dictionary = good.duplicate(true)
		bad.board.rainbow_targets = invalid_target
		check(copy.restore_snapshot(bad) == ERR_INVALID_DATA and copy.to_snapshot() == before, "Invalid rainbow target cannot partially alter the live model")
	for flag in ["pending_rainbow", "legacy_rainbow_choice"]:
		var bad: Dictionary = good.duplicate(true)
		bad.board[flag] = true
		check(copy.restore_snapshot(bad) == ERR_INVALID_DATA and copy.to_snapshot() == before, "Legacy and pending flags must agree")
	var old_idle: Dictionary = fresh().combat.to_snapshot()
	old_idle.board.version = 1
	old_idle.board.erase("rainbow_targets")
	old_idle.board.erase("legacy_rainbow_choice")
	check(copy.restore_snapshot(old_idle) == OK and not copy.board.legacy_rainbow_choice and not copy.board.choose_rainbow("guard"), "Nonpending version-1 board migrates without granting a choice")
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(rainbow_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(rainbow_path + suffix))

func _test_auto_hint_checkpoints() -> void:
	var fixture := fresh()
	var battle = fixture.combat
	check(not battle.auto_hint_used, "Setup starts the first turn with auto hint unused")
	var untouched: Dictionary = battle.to_snapshot()
	battle.auto_hint_used = true
	var used: Dictionary = battle.to_snapshot()
	var expected: Dictionary = untouched.duplicate(true)
	expected.auto_hint_used = true
	check(used == expected, "Marking a hint changes only its UI flag, including no RNG state")
	var copy = Combat.new()
	check(copy.restore_snapshot(used) == OK and copy.auto_hint_used and copy.to_snapshot() == used, "Used hint flag round trips with every combat field")
	var old: Dictionary = used.duplicate(true)
	old.erase("auto_hint_used")
	check(copy.restore_snapshot(old) == OK and not copy.auto_hint_used and copy.to_snapshot() == untouched, "Old combat snapshot defaults missing hint flag to false")
	check(copy.restore_snapshot(used) == OK, "Prepare atomic hint validation fixture")
	var before: Dictionary = copy.to_snapshot()
	for invalid_flag in [1, "true", null, [], {}]:
		var bad: Dictionary = used.duplicate(true)
		bad.auto_hint_used = invalid_flag
		check(copy.restore_snapshot(bad) == ERR_INVALID_DATA and copy.to_snapshot() == before, "Nonboolean hint flag is rejected without mutating combat or RNG")

	var hint_path := test_path + ".hint"
	var store = Store.new(hint_path, legacy_path)
	check(store.load_store() == OK and store.checkpoint(fixture.run, battle, metadata("hint")) == OK, "Commit a used same-turn hint to disk")
	var reopened = Store.new(hint_path, legacy_path)
	check(reopened.load_store() == OK, "Reload used hint profile")
	var restored: Dictionary = reopened.restore_active()
	check(not restored.is_empty() and restored.combat.auto_hint_used and restored.combat.to_snapshot() == used, "Restart cannot forget that this turn already used its hint")
	var old_profile: Dictionary = store.data.duplicate(true)
	old_profile.active.combat.erase("auto_hint_used")
	var old_config := ConfigFile.new()
	old_config.set_value("gameplay_v2", "data", old_profile)
	check(old_config.save(hint_path) == OK and reopened.load_store() == OK, "A real old disk snapshot without hint flag remains compatible")
	check(not reopened.restore_active().combat.auto_hint_used, "Old disk progress restores its default unused hint")

	battle.phase = "play"
	copy.phase = "play"
	copy.auto_hint_used = false
	var old_turn: int = battle.turn
	check(battle.end_turn() and copy.end_turn(), "Complete a turn with and without a consumed hint")
	check(battle.turn == old_turn + 1 and not battle.auto_hint_used, "Next turn resets auto hint permission")
	check(copy.to_snapshot() == battle.to_snapshot(), "Hint history does not change enemy action, card draws, or RNG next turn")
	battle.auto_hint_used = true
	battle.setup(fixture.run.deck, fixture.run.attributes, fixture.run.relics, fixture.run.enemy_for_node(), 8675309)
	check(not battle.auto_hint_used, "Setup on a reused combat also resets auto hint permission")
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(hint_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(hint_path + suffix))

func _test_store() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("progress", "high_score", 999)
	legacy.set_value("settings", "music_volume", 0.35)
	legacy.set_value("gameplay_v2", "runs", 5)
	legacy.set_value("gameplay_v2", "wins", 2)
	legacy.set_value("gameplay_v2", "battles_won", 12)
	legacy.set_value("gameplay_v2", "battles_lost", 3)
	check(legacy.save(legacy_path) == OK, "Create isolated legacy fixture")
	var old_contents := FileAccess.get_file_as_string(legacy_path)
	var store = Store.new(test_path, legacy_path)
	check(store.load_store() == OK and store.data.statistics.runs == 5 and store.data.history.is_empty(), "Migrate aggregate baseline without inventing history")
	check(not store.has_active(), "Empty profile has no Continue target")
	var fixture := fresh()
	check(store.checkpoint(fixture.run, fixture.combat, metadata()) == OK, "Save an active battle")
	var reopened = Store.new(test_path, legacy_path)
	check(reopened.load_store() == OK and reopened.has_active(), "Continue survives a new Store instance")
	var restored: Dictionary = reopened.restore_active()
	check(not restored.is_empty() and restored.run.to_snapshot() == fixture.run.to_snapshot() and restored.combat.to_snapshot() == fixture.combat.to_snapshot(), "Battle and metadata survive disk without regenerating")
	fill_board(fixture.combat.board)
	fixture.combat.board.cells[0].special = "rainbow"
	fixture.combat.start_activate(0)
	fixture.combat.advance_board()
	check(store.checkpoint(fixture.run, fixture.combat, metadata()) == OK, "Save automatic rainbow holes to disk")
	check(reopened.load_store() == OK, "Load rainbow disk checkpoint")
	restored = reopened.restore_active()
	check(not restored.combat.board.pending_rainbow and not restored.combat.board.legacy_rainbow_choice and restored.combat.board.cells[0] == null, "Disk restoration resumes new rainbow automatically without a modal")
	var invalid: Dictionary = store.data.active.duplicate(true)
	invalid.run.phase = "map"
	check(store._restore_active_value(invalid).is_empty(), "Active snapshot rejects nonbattle phase with live combat")
	fixture.run.finish_battle(true)
	check(store.checkpoint(fixture.run, fixture.combat, metadata()) == OK and store.data.active.combat == null, "Rewards save after battle settlement and drop stale combat")
	check(reopened.load_store() == OK and reopened.restore_active().run.rewards == fixture.run.rewards, "Reward choices are restored exactly")
	fixture.run.end_run("abandoned")
	# Abandoning from a reward screen leaves its unused queue in the terminal model.
	check(store.finalize_run(fixture.run, metadata()) == OK, "Finalize exploration atomically")
	check(not store.has_active() and store.data.history.size() == 1 and store.data.statistics.runs == 6 and store.data.statistics.battles_won == 13, "History, statistics, and removal of Continue commit together")
	check(store.finalize_run(fixture.run, metadata()) == OK and store.data.history.size() == 1 and store.data.statistics.runs == 6, "Repeated finalize is idempotent")
	check(reopened.load_store() == OK and reopened.finalize_run(fixture.run, metadata()) == OK and reopened.data.statistics.runs == 6, "Finalization remains idempotent across restart")
	check(store.data.history[0].floor == fixture.run.nodes[fixture.run.current].row, "History exposes the UI floor key")
	var new_run = Run.new()
	new_run.setup(ATTRS, 22)
	check(store.checkpoint(new_run, null, metadata("run-b")) == OK, "Save map phase without combat")
	new_run.shells = 73
	check(store.checkpoint(new_run, null, metadata("run-b")) == OK, "Commit second generation with a backup")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	corrupt.store_string("not a config file [")
	corrupt.close()
	check(reopened.load_store() == OK and not reopened.load_message.is_empty(), "Corrupt primary recovers from previous valid backup")
	restored = reopened.restore_active()
	check(not restored.is_empty() and restored.run.shells == 20, "Recovery uses the previous complete snapshot")
	check(reopened.save_settings({"fullscreen": true, "resolution": Vector2i(1600, 900)}) == OK, "Recovered profile accepts display settings")
	check(FileAccess.file_exists(test_path + ".corrupt"), "Recovered corrupt primary is preserved separately")
	check(store.load_store() == OK and store.data.settings.fullscreen and store.data.settings.resolution == Vector2i(1600, 900), "Display settings persist after restart")
	check(FileAccess.get_file_as_string(legacy_path) == old_contents, "Legacy save file remains byte-for-byte unchanged")
	check(store.data.legacy_statistics.runs == 5 and store.data.statistics.runs == 6, "Legacy aggregate is imported only once")
	check(store.save_settings({"fullscreen": false, "resolution": Vector2i(2, 2)}) == ERR_INVALID_PARAMETER, "Invalid display resolution rejected")
	var both_corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	both_corrupt.store_string("bad primary [")
	both_corrupt.close()
	both_corrupt = FileAccess.open(test_path + ".bak", FileAccess.WRITE)
	both_corrupt.store_string("bad backup [")
	both_corrupt.close()
	check(reopened.load_store() != OK and not reopened.has_active() and reopened.data.settings.resolution == Vector2i(1280, 720), "Both invalid files give usable defaults with Continue disabled")
	check(reopened.save_settings({"fullscreen": false, "resolution": Vector2i(1280, 720)}) != OK, "Invalid originals are not silently overwritten")

func _test_node_checkpoints() -> void:
	var node_path := test_path + ".nodes"
	var store = Store.new(node_path, legacy_path)
	check(store.load_store() == OK, "Create isolated node checkpoint profile")
	var run_state = Run.new()
	run_state.setup(ATTRS, 443)
	var first: String = run_state.available[0]
	run_state.nodes[first].type = "shop"
	run_state.shells = 100
	check(run_state.enter_node(first), "Enter shop fixture")
	check(run_state.buy(0), "Purchase first shop item")
	check(store.checkpoint(run_state, null, metadata("nodes")) == OK, "Commit purchased shop inventory")
	var reopened = Store.new(node_path, legacy_path)
	check(reopened.load_store() == OK, "Reload shop")
	var restored: Dictionary = reopened.restore_active()
	check(restored.run.to_snapshot() == run_state.to_snapshot() and restored.run.stock[0].sold, "Shop stock and payment survive restart")
	check(not restored.run.buy(0), "Reloading cannot buy sold item again")
	run_state.complete_node()
	var next: String = run_state.available[0]
	run_state.nodes[next].type = "event"
	run_state.enter_node(next)
	run_state.event_id = "cache"
	check(store.checkpoint(run_state, null, metadata("nodes")) == OK, "Commit event choice checkpoint")
	check(reopened.load_store() == OK and reopened.restore_active().run.event_id == "cache", "Event does not reroll on restart")
	run_state.event_choice(1)
	check(store.checkpoint(run_state, null, metadata("nodes")) == OK, "Commit pending event supply reward")
	check(reopened.load_store() == OK and reopened.restore_active().run.to_snapshot() == run_state.to_snapshot(), "Generated event reward and RNG persist together")
	run_state.accept_reward()
	run_state.complete_node()
	next = run_state.available[0]
	run_state.nodes[next].type = "rest"
	run_state.enter_node(next)
	check(store.checkpoint(run_state, null, metadata("nodes")) == OK, "Commit rest screen checkpoint")
	check(reopened.load_store() == OK and reopened.restore_active().run.phase == "rest", "Rest choice screen restores")
	check(run_state.modify_deck(0, true), "Upgrade card at rest")
	check(store.checkpoint(run_state, null, metadata("nodes")) == OK, "Commit upgrade and map advance together")
	check(reopened.load_store() == OK and reopened.restore_active().run.to_snapshot() == run_state.to_snapshot(), "Card upgrade cannot be replayed by restart")
	var before: Dictionary = store.data.duplicate(true)
	var bad_run = Run.new()
	bad_run.restore_snapshot(run_state.to_snapshot())
	bad_run.deck[0].id = "unknown_card"
	check(store.checkpoint(bad_run, null, metadata("nodes")) == ERR_INVALID_DATA and store.data == before, "Invalid checkpoint does not change persistent or in-memory state")
	check(reopened.load_store() == OK and reopened.data == before, "Failed checkpoint retains the prior disk generation")
	var unsupported := ConfigFile.new()
	var incompatible: Dictionary = store.data.duplicate(true)
	incompatible.save_version = 999
	unsupported.set_value("gameplay_v2", "data", incompatible)
	check(unsupported.save(node_path) == OK, "Write unsupported-version fixture")
	check(reopened.load_store() == OK and not reopened.load_message.is_empty(), "Unsupported primary version can recover compatible backup")
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(node_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(node_path + suffix))
