extends SceneTree

const Run = preload("res://scripts/v2/run.gd")
const Store = preload("res://scripts/v2/save_store.gd")
const ATTRS = ["condensation", "thermal", "conductive", "aero"]
const SAVE_PATH := "res://tests/artifacts/reward_nodes_save.cfg"
const LEGACY_PATH := "res://tests/artifacts/reward_nodes_missing_legacy.cfg"
var checks := 0
var failures := 0
var app

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("REWARD_NODES: " + message)

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _drain_rewards(run_state) -> void:
	var remaining: int = run_state.rewards.size()
	for _index in range(remaining):
		check(run_state.accept_reward(), "Pending reward can be skipped or acknowledged")

func _frontier(seed_value: int = 101):
	var run_state = Run.new()
	run_state.setup(ATTRS, seed_value)
	for _row in range(1, 5):
		check(run_state.enter_node(run_state.available[0]), "Traverse a real path toward its reward node")
		if run_state.phase == "battle":
			check(run_state.finish_battle(true), "Path battle settles normally")
		_drain_rewards(run_state)
		check(run_state.complete_node(), "Path node completes before the reward floor")
	return run_state

func _test_paths() -> void:
	for seed_value in range(40):
		var run_state = Run.new()
		run_state.setup(ATTRS, seed_value)
		var reward_nodes := 0
		for node in run_state.nodes.values():
			if node.row == 5:
				reward_nodes += 1
				check(node.type == "reward", "Every route through floor 5 offers a reward")
			elif node.row == 0:
				check(node.type == "start", "Origin adds no reward encounter")
			elif node.row == 1:
				check(node.type == "battle", "First floor remains battle")
			elif node.row == 10:
				check(node.type == "rest", "Floor 10 remains rest")
			elif node.row == 11:
				check(node.type == "boss", "Final floor remains boss")
			else:
				check(node.type in ["battle", "event", "shop", "rest"], "Other floors retain their existing node types")
		check(reward_nodes > 0, "Generated map contains the guaranteed reward floor")
		var chooser := RandomNumberGenerator.new()
		chooser.seed = seed_value + 900
		var encounters := 0
		for _row in range(1, 12):
			if run_state.available.is_empty():
				check(false, "Random traversal always has a reachable next node")
				break
			var id: String = run_state.available[chooser.randi_range(0, run_state.available.size() - 1)]
			check(run_state.enter_node(id), "A random available route can be entered")
			if run_state.nodes[id].type == "reward":
				encounters += 1
				check(run_state.phase == "rewards", "Reward route enters pending rewards immediately")
			if run_state.phase in ["battle", "boss"]:
				run_state.finish_battle(true)
			if run_state.phase != "ended":
				_drain_rewards(run_state)
				check(run_state.complete_node(), "Resolved route advances once")
		check(encounters == 1 and run_state.outcome == "victory", "Random route receives one reward encounter and reaches its boss")

func _test_rewards() -> void:
	var run_state = _frontier()
	run_state.relics = ["r01"]
	var before: Dictionary = run_state.to_snapshot()
	var id: String = run_state.available[0]
	check(run_state.enter_node(id), "Enter a generated reward node")
	check(run_state.phase == "rewards" and run_state.shells == int(before.shells) + 15, "Reward gives 15 shells immediately without combat")
	for key in ["lives", "deck", "supplies", "battles_won", "battles_lost", "relics"]:
		check(run_state.get(key) == before[key], "Entering a reward consumes no " + key)
	check(run_state.rewards.size() == 2 and run_state.rewards[0].type == "notice" and run_state.rewards[0].requires_ack, "Reward begins with a persistent acknowledgement summary")
	var options: Array = run_state.rewards[1].options
	check(run_state.rewards[1].type == "relic" and options.size() == 2 and options[0] != options[1] and "r01" not in options, "Two relic alternatives are distinct and unowned")
	var pending: Dictionary = run_state.to_snapshot()
	check(not run_state.enter_node(id) and run_state.to_snapshot() == pending, "Re-entering pending reward cannot reroll or add shells")
	check(not run_state.complete_node() and run_state.to_snapshot() == pending, "Unresolved rewards prevent route completion")
	check(not run_state.accept_reward_at(1, "r01") and run_state.to_snapshot() == pending, "A noncandidate owned relic cannot be claimed")
	check(run_state.accept_reward_at(1, options[0]), "Claim one relic alternative")
	check(run_state.relics == ["r01", options[0]] and options[1] not in run_state.relics and run_state.rewards.size() == 1, "Claim grants one relic and consumes the entire choice group")
	check(not run_state.accept_reward_at(1, options[1]) and not run_state.complete_node(), "Other choice cannot be claimed and summary still requires acknowledgement")
	check(run_state.accept_reward() and run_state.complete_node(), "Acknowledgement completes the reward node")
	var completed: Dictionary = run_state.to_snapshot()
	check(run_state.visited.count(id) == 1 and run_state.available == run_state.nodes[id].next, "Completion visits once and exposes the next floor")
	check(not run_state.enter_node(id) and not run_state.accept_reward_at(1, options[0]) and run_state.to_snapshot() == completed, "Completed reward cannot be entered or claimed twice")
	for remaining in [1, 0]:
		run_state = _frontier(remaining + 201)
		var pool: Array = run_state.catalog.relics.keys()
		var unowned: String = pool.back()
		run_state.relics = pool.duplicate()
		if remaining == 1:
			run_state.relics.erase(unowned)
		var shells_before: int = run_state.shells
		run_state.enter_node(run_state.available[0])
		if remaining == 1:
			check(run_state.shells == shells_before + 15 and run_state.rewards.size() == 2 and run_state.rewards[1].options == [unowned], "Last unowned relic is the sole useful candidate")
			check(run_state.accept_reward_at(1, unowned) and run_state.relics.size() == pool.size(), "Last relic can be claimed without requiring two options")
		else:
			check(run_state.shells == shells_before + 30 and run_state.rewards.size() == 1 and run_state.rewards[0].requires_ack, "Complete collection converts the relic reward into 15 extra shells")
		check(run_state.accept_reward() and run_state.complete_node(), "Fallback reward can be acknowledged and completed")

func _test_persistence() -> void:
	_clean()
	var run_state = _frontier(301)
	run_state.enter_node(run_state.available[0])
	var pending: Dictionary = run_state.to_snapshot()
	var metadata := {"run_id": "reward-node-regression", "role_id": "condensation_coletta", "started_at": 1791580800}
	var store = Store.new(SAVE_PATH, LEGACY_PATH)
	check(store.load_store() == OK and store.checkpoint(run_state, null, metadata) == OK, "Checkpoint pending reward in an isolated project artifact")
	var reopened = Store.new(SAVE_PATH, LEGACY_PATH)
	check(reopened.load_store() == OK, "Reload reward checkpoint from disk")
	var restored: Dictionary = reopened.restore_active()
	check(not restored.is_empty(), "Reward snapshot is accepted by the store")
	if restored.is_empty():
		return
	check(restored.combat == null and restored.run.to_snapshot() == pending, "Pending reward, shells, candidates and RNG restore exactly without combat")
	check(not restored.run.enter_node(restored.run.current) and restored.run.to_snapshot() == pending, "Resume cannot duplicate reward shells or reroll alternatives")
	var chosen: String = restored.run.rewards[1].options[0]
	check(restored.run.accept_reward_at(1, chosen) and reopened.checkpoint(restored.run, null, metadata) == OK, "Claimed relic and outstanding acknowledgement persist together")
	check(store.load_store() == OK, "Reload the claimed reward")
	var claimed: Dictionary = store.restore_active()
	check(claimed.run.relics.count(chosen) == 1 and claimed.run.rewards.size() == 1 and claimed.run.rewards[0].requires_ack and claimed.run.shells == pending.shells, "Restart neither grants the relic again nor drops the acknowledgement")
	var candidate = Run.new()
	var bad: Dictionary = pending.duplicate(true)
	bad.nodes[bad.current].type = "unknown_reward"
	check(candidate.restore_snapshot(bad) == ERR_INVALID_DATA, "Unknown map node type remains rejected")
	for invalid_flag in [1, "true", null, [], {}]:
		bad = pending.duplicate(true)
		bad.rewards[0].requires_ack = invalid_flag
		check(candidate.restore_snapshot(bad) == ERR_INVALID_DATA, "Nonboolean acknowledgement flags are rejected")
	var old: Dictionary = _frontier(302).to_snapshot()
	for node in old.nodes.values():
		if node.type == "reward":
			node.type = "battle"
	check(candidate.restore_snapshot(old) == OK and candidate.to_snapshot() == old, "Existing maps without reward nodes restore without regeneration")
	old = pending.duplicate(true)
	old.nodes[old.current].type = "battle"
	old.rewards = [{"type": "notice", "text": "旧版战斗结算"}]
	check(candidate.restore_snapshot(old) == OK, "Old notice snapshots without acknowledgement flag remain valid")

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = LEGACY_PATH
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _settle() -> void:
	await process_frame
	await process_frame

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tests/artifacts/" + name + ".png") == OK, "Reward node screenshot saved")

func _reload_app(expected: Dictionary) -> void:
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = _new_app()
	app._continue_run()
	await _settle()
	check(app.run_state.to_snapshot() == expected and app.combat == null, "Fresh app continues exact pending rewards without combat or a second payout")

func _begin_app_reward(owned: Array = []) -> void:
	app._commit_run()
	app.run_state = _frontier(401)
	app.run_state.relics = owned.duplicate()
	app._state_changed()
	var shells_before: int = app.run_state.shells
	app._enter_node(app.run_state.available[0])
	await _settle()
	check(app.run_state.phase == "rewards" and is_instance_valid(app.reward_view) and app.combat == null, "App enters a real reward map node directly into RewardView without building Combat")
	check(app.save_error == "" and app.run_state.shells == shells_before + (30 if owned.size() == app.catalog.relics.size() else 15), "App checkpoints the guaranteed reward exactly once")

func _item(choice: String):
	if is_instance_valid(app.reward_view):
		for button in app.reward_view.get_reward_items():
			if str(button.get_meta("choice", "")) == choice:
				return button
	return null

func _finish_button():
	return app.reward_view.find_child("FinishButton", true, false) if is_instance_valid(app.reward_view) else null

func _press(button) -> void:
	check(button != null, "Reward action control exists")
	if button != null:
		button.pressed.emit()

func _check_finished(message: String) -> void:
	check(app.run_state.phase == "map" and app.run_state.rewards.is_empty() and not is_instance_valid(app.reward_view), message)
	check(app.run_state.visited.count(app.run_state.current) == 1, "UI completes the reward node once")

func _test_app() -> void:
	_clean()
	root.size = Vector2i(1280, 720)
	app = _new_app()
	await _begin_app_reward(["r01"])
	check(app.reward_view.get_reward_items().size() == 2, "Reward UI displays two unowned relic alternatives")
	var clear_choice_prompt := false
	for label in app.reward_view.find_children("*", "Label", true, false):
		clear_choice_prompt = clear_choice_prompt or label.text == "藏品二选一"
	check(clear_choice_prompt, "Reward UI explicitly identifies the relic choice as 藏品二选一")
	await _capture("v2_reward_node_choice")
	await _reload_app(app.run_state.to_snapshot())
	var options: Array = app.run_state.rewards[1].options.duplicate()
	var chosen = _item(options[0])
	var stale_alternate = _item(options[1])
	_press(chosen)
	_press(stale_alternate)
	check(app.run_state.relics == ["r01", options[0]] and app.run_state.rewards.size() == 1, "Clicking one candidate grants only that relic even with stale second input")
	check(app.run_state.phase == "rewards" and is_instance_valid(app.reward_view) and app.run_state.rewards[0].requires_ack and app.run_state.current not in app.run_state.visited, "Claiming retains the summary until the player continues")
	check(not app._complete_empty_rewards(), "Reward summary acknowledgement prevents silent completion")
	await _reload_app(app.run_state.to_snapshot())
	_press(_finish_button())
	_check_finished("Continue acknowledges the summary and returns to the map")
	var completed: Dictionary = app.run_state.to_snapshot()
	app._finish_rewards()
	check(app.run_state.to_snapshot() == completed, "Repeated continue does not complete or pay the node again")
	await _begin_app_reward()
	var skip_inventory: Array = app.run_state.relics.duplicate()
	app._skip_reward(1)
	check(app.run_state.relics == skip_inventory and app.run_state.rewards.size() == 1 and app.run_state.phase == "rewards", "Skipping a choice grants no relic and retains its acknowledgement")
	_press(_finish_button())
	_check_finished("Skipped reward can be acknowledged and completed")
	await _begin_app_reward()
	_press(_finish_button())
	_check_finished("Skip remaining rewards advances directly without selecting either relic")
	check(app.run_state.relics.is_empty(), "Skip remaining grants neither alternative")
	var all_relics: Array = app.catalog.relics.keys()
	var one_left: Array = all_relics.duplicate()
	var final_relic: String = one_left.pop_back()
	await _begin_app_reward(one_left)
	check(app.reward_view.get_reward_items().size() == 1, "One remaining unowned relic renders as a single claimable item")
	_press(_item(final_relic))
	check(app.run_state.relics.size() == all_relics.size() and app.run_state.phase == "rewards", "Claiming the last relic still requires continuing")
	_press(_finish_button())
	_check_finished("Last-relic fallback completes through the same continue control")
	await _begin_app_reward(all_relics)
	check(app.reward_view.get_reward_items().is_empty() and app.run_state.rewards.size() == 1, "Complete collection shows only its useful currency summary")
	await _capture("v2_reward_node_currency")
	await _reload_app(app.run_state.to_snapshot())
	check(app.run_state.phase == "rewards" and is_instance_valid(app.reward_view), "Currency-only reward stays visible across restart until acknowledged")
	_press(_finish_button())
	_check_finished("Currency-only fallback acknowledges and advances")
	# A battle summary without the new flag must keep its existing automatic route.
	app._commit_run()
	app._enter_node(app.run_state.available[0])
	app.run_state.finish_battle(true)
	app.combat = null
	app.run_state.rewards = [{"type": "notice", "text": "战斗胜利\n贝币已结算"}]
	app._state_changed()
	_check_finished("Existing battle notice-only rewards still complete automatically")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = null

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	_test_paths()
	_test_rewards()
	_test_persistence()
	await _test_app()
	_clean()
	print("V2_REWARD_NODES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
