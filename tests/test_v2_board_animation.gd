extends SceneTree

# Every save in this suite belongs to this fixture, never the player's profile.
const SAVE_PATH := "res://tests/artifacts/board_animation_save.cfg"
const Combat = preload("res://scripts/v2/combat.gd")
var app
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("BOARD_ANIMATION: " + message)

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_board_animation_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	instance.set_process(false)
	return instance

func _new_battle(seed_value: int = 8675309) -> void:
	app._commit_run()
	app._enter_node(app.run_state.available[0])
	app.combat = Combat.new()
	app.combat.setup(app.run_state.deck, app.run_state.attributes, app.run_state.relics, app.run_state.enemy_for_node(), seed_value)
	var board = app.combat.board
	for y in range(8):
		for x in range(8):
			board.cells[y * 8 + x] = board.piece(board.kinds[(x + 2 * y) % board.kinds.size()])
	# Make an actual card affordable so a premature play-phase unlock is observable.
	for kind in app.combat.mana:
		app.combat.mana[kind] = 99
	app.selection = -1
	app.highlights.clear()
	app._render()
	check(app._checkpoint() == OK, "The isolated fixture checkpoint succeeds")
	await process_frame
	await process_frame
	check(app.battle_view.hand_view.is_collapsed(), "Board action starts with the real hand collapsed")

func _copy_combat(snapshot: Dictionary):
	var copy = Combat.new()
	check(copy.restore_snapshot(snapshot) == OK, "Model oracle restores the exact combat and RNG")
	return copy

func _finish_model(model) -> void:
	var steps := 0
	while model.phase == "resolving" and steps < 1000:
		model.advance_board()
		steps += 1
	check(steps < 1000 and model.phase == "play", "Pure model resolution terminates automatically")

func _wait_until(predicate: Callable, timeout_seconds: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not bool(predicate.call()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.005).timeout
	return bool(predicate.call())

func _all_cells_disabled() -> bool:
	for button in app.board_buttons:
		if not button.disabled:
			return false
	return true

func _blocked_inputs(label: String) -> void:
	var snapshot: Dictionary = app.combat.to_snapshot()
	var supplies: Array = app.run_state.supplies.duplicate()
	var selection: int = app.selection
	app._click_cell(0)
	app._activate_selected()
	app._hint()
	if not app.combat.hand.is_empty():
		app._play_card_uid(int(app.combat.hand[0].uid))
	app._end_turn()
	app._use_supply(0)
	check(app.combat.to_snapshot() == snapshot and app.run_state.supplies == supplies and app.selection == selection, label + " rejects board, card, turn, hint, and supply actions")

func _assert_checkpoint(label: String) -> void:
	var restored: Dictionary = app.store.restore_active()
	check(not restored.is_empty() and restored.combat != null and restored.combat.to_snapshot() == app.combat.to_snapshot(), label + " persists the exact current resources, cells, phase, and RNG")

func _assert_resting_board(label: String) -> void:
	var animator = app.battle_view._board_animation
	check(not is_instance_valid(animator) or (not animator.active and animator.visuals.is_empty() and animator.fading_visuals.is_empty()), label + " removes every temporary animation node")
	check(is_equal_approx(app.battle_view._board_grid.modulate.a, 1.0), label + " restores the real board opacity")
	var matching := true
	for index in range(64):
		var cell: Dictionary = app.combat.board.cells[index]
		var piece = app.battle_view.piece_views[index]
		matching = matching and piece.visible and piece.kind == cell.kind and piece.special == cell.special and piece.axis == cell.axis
	check(matching, label + " displays every final piece with its final special and axis")

func _finish_ui(label: String, expected: Dictionary) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	var tucked := true
	var locked := true
	var reached_play_while_locked := false
	var checked_boundary := false
	while (app.resolving_ui or app.ui_locked) and Time.get_ticks_msec() < deadline:
		tucked = tucked and app.battle_view.hand_view.is_collapsed()
		locked = locked and app.ui_locked and app.resolving_ui and _all_cells_disabled() and app.battle_view.hand_view._locked and app.battle_view._buttons.end_turn.disabled
		if app.combat.phase == "play":
			reached_play_while_locked = true
			if not checked_boundary:
				check(app.combat.can_play(0), label + " has an affordable card at the model play boundary")
				_blocked_inputs(label + " final falling frame")
				checked_boundary = true
		await create_timer(0.005).timeout
	check(not app.resolving_ui and not app.ui_locked, label + " finishes its complete visual sequence")
	check(tucked and locked, label + " holds the hand and all action controls throughout the animation")
	check(reached_play_while_locked, label + " keeps the model play phase locked until its final drop lands")
	check(app.combat.to_snapshot() == expected, label + " exactly matches pure model resources, special UIDs, cascades, log, and RNG")
	check(not app.battle_view.hand_view.is_collapsed() and not app.battle_view.hand_view._locked and not app.battle_view._buttons.end_turn.disabled, label + " expands and enables the hand after landing")
	_assert_checkpoint(label + " final frame")
	_assert_resting_board(label)

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png("res://tests/artifacts/" + name + ".png") == OK, name + " screenshot saves")

func _test_invalid_swap() -> void:
	await _new_battle()
	check(not app.combat.board.legal_swap(0, 1), "Invalid fixture cannot create a match")
	var before: Dictionary = app.combat.to_snapshot()
	var uid_a: int = before.board.cells[0].uid
	var uid_b: int = before.board.cells[1].uid
	var home_a: Vector2 = app.board_buttons[0].global_position
	var home_b: Vector2 = app.board_buttons[1].global_position
	app._click_cell(0)
	app._click_cell(1)
	var animator = app.battle_view._board_animation
	check(app.ui_locked and not app.resolving_ui and animator.active, "Invalid swap starts a visual-only input lock")
	check(is_zero_approx(app.battle_view._board_grid.modulate.a) and animator.visuals.size() == 64, "Invalid swap uses real piece ghosts over the hidden board")
	check(app.combat.to_snapshot() == before, "Invalid swap consumes no action, resource, or RNG")
	_assert_checkpoint("Invalid swap")
	_blocked_inputs("Invalid swap")
	check(animator.visuals.has(uid_a) and animator.visuals.has(uid_b), "Both swapped pieces retain their UIDs")
	var ghost_a: Control = animator.visuals[uid_a]
	var ghost_b: Control = animator.visuals[uid_b]
	var moved := await _wait_until(func(): return ghost_a.global_position.distance_to(home_a) > 1.0 and ghost_b.global_position.distance_to(home_b) > 1.0, 1.0)
	check(moved, "Invalid swap actually moves both visible piece nodes")
	var outbound := await _wait_until(func(): return ghost_a.global_position.distance_to(home_b) < 1.0 and ghost_b.global_position.distance_to(home_a) < 1.0, 1.0)
	check(outbound, "Invalid swap reaches the exchanged cells before returning")
	await _capture("v2_board_invalid_swap")
	var returned := await _wait_until(func(): return not app.ui_locked, 2.0)
	check(returned and app.combat.phase == "board" and app.combat.to_snapshot() == before, "Invalid swap returns to its initial cells and leaves the action available")
	check(not app.board_buttons[0].disabled and not app.board_buttons[1].disabled, "Invalid swap restores real board input")
	_assert_resting_board("Invalid swap")

func _special_creation_fixture() -> void:
	# A stable column with guard, guard, conductive, guard becomes four guards.
	# The exchanged guard retains its UID at row 3, then falls into the cleared row 4.
	for index in [10, 18, 34, 27]:
		app.combat.board.cells[index] = app.combat.board.piece("guard")
	app._render()
	app._checkpoint()

func _test_valid_swap_and_drop() -> void:
	await _new_battle()
	_special_creation_fixture()
	check(app.combat.board.matches().is_empty(), "Four-match fixture starts without an existing match")
	var before: Dictionary = app.combat.to_snapshot()
	var model = _copy_combat(before)
	check(model.start_swap(27, 26), "Four-match fixture has a legal swap")
	var first_step: Dictionary = model.advance_board()
	var first_expected: Dictionary = model.to_snapshot()
	var uid: int = before.board.cells[27].uid
	check(first_step.removed.size() == 3 and first_expected.board.cells[26].uid == uid and first_expected.board.cells[26].special == "stripe", "Oracle retains the newly generated special UID and yields only three guards")
	_finish_model(model)
	var expected: Dictionary = model.to_snapshot()
	app._click_cell(27)
	app._click_cell(26)
	var animator = app.battle_view._board_animation
	check(app.combat.to_snapshot() == first_expected, "Valid swap settles its first clear exactly once before its first await")
	_assert_checkpoint("Valid swap first clear")
	check(app.ui_locked and app.resolving_ui and animator.active and animator.visuals.has(uid), "Valid swap locks input and preserves the exchanged visual UID")
	_blocked_inputs("Valid swap")
	var ghost: Control = animator.visuals[uid]
	var home: Vector2 = ghost.global_position
	check(await _wait_until(func(): return ghost.global_position.distance_to(home) > 1.0, 1.0), "Valid swap visibly moves the exchanged piece")
	await _capture("v2_board_valid_swap")
	check(await _wait_until(func(): return not animator.fading_visuals.is_empty(), 2.0), "Clear step retains visible fading nodes")
	var fading: Control = animator.fading_visuals[0]
	check(await _wait_until(func(): return is_instance_valid(fading) and fading.scale.x < 0.98 and fading.modulate.a < 0.98, 1.0), "Removed pieces visibly shrink and fade instead of disappearing instantly")
	await _capture("v2_board_clear")
	check(await _wait_until(func(): return is_instance_valid(ghost) and ghost.get_meta("cell").special == "stripe", 2.0), "Generated special updates the retained ghost's visible overlay")
	check(animator.visuals.get(uid) == ghost, "Special creation reuses the exchanged visual node by UID")
	var cleared_position: Vector2 = ghost.global_position
	check(await _wait_until(func(): return is_instance_valid(ghost) and ghost.global_position.y > cleared_position.y + 1.0, 2.0), "Retained special visibly falls into a lower cleared cell")
	check(animator.visuals.get(uid) == ghost and int(ghost.get_meta("board_index")) >= 34, "Gravity maps the same special UID to its lower destination")
	await _capture("v2_board_drop")
	await _finish_ui("Valid swap", expected)

func _find_cascade_seed() -> int:
	var initial: Dictionary = app.combat.to_snapshot()
	for seed_value in range(1, 200):
		var candidate = Combat.new()
		if candidate.restore_snapshot(initial) != OK:
			return -1
		candidate.board.rng.seed = seed_value
		candidate.start_activate(27)
		var steps := 0
		while candidate.phase == "resolving" and steps < 100:
			candidate.advance_board()
			steps += 1
		if candidate.phase == "play" and candidate.board.cascades > 0:
			return seed_value
	return -1

func _test_special_activation(special: String) -> void:
	await _new_battle()
	app.combat.board.cells[27] = app.combat.board.piece(app.run_state.attributes[0], special, "h")
	if special == "bomb":
		var seed_value := _find_cascade_seed()
		check(seed_value > 0, "Bomb fixture finds an actual deterministic refill cascade")
		app.combat.board.rng.seed = seed_value
	app._render()
	app._checkpoint()
	var before: Dictionary = app.combat.to_snapshot()
	var model = _copy_combat(before)
	check(model.start_activate(27), special + " oracle accepts direct activation")
	model.advance_board()
	var first_expected: Dictionary = model.to_snapshot()
	_finish_model(model)
	var expected: Dictionary = model.to_snapshot()
	app._click_cell(27)
	check(app.combat.to_snapshot() == before and app.selection == 27, special + " first click only selects")
	app._click_cell(27)
	check(app.combat.to_snapshot() == first_expected and app.resolving_ui and app.ui_locked, special + " second click synchronously settles one first clear")
	_assert_checkpoint(special + " first clear")
	var animator = app.battle_view._board_animation
	check(not animator.fading_visuals.is_empty(), special + " direct activation immediately shows its removed ghosts")
	_blocked_inputs(special + " activation")
	if special == "bomb":
		check(expected.board.cascades > 0, "Bomb result includes a real later cascade")
	await _finish_ui(special + " activation", expected)

func _test_leave_and_continue() -> void:
	await _new_battle()
	_special_creation_fixture()
	app._click_cell(27)
	app._click_cell(26)
	var old_combat = app.combat
	var old_animator = app.battle_view._board_animation
	var stopped: Dictionary = old_combat.to_snapshot()
	var expected_model = _copy_combat(stopped)
	_finish_model(expected_model)
	app._return_menu()
	check(app.screen == "menu" and not app.ui_locked and not app.resolving_ui and not old_animator.active, "Leaving cancels the active visual lock and animation")
	check(old_animator.visuals.is_empty() and old_animator.fading_visuals.is_empty(), "Leaving clears all obsolete piece ghosts")
	_assert_checkpoint("Paused first clear")
	# Continue immediately, while the disposed view still has pending async waits.
	app._continue_run()
	check(app.combat != old_combat and app.screen == "run", "Continue restores a new combat instance")
	await _finish_ui("Immediate continue", expected_model.to_snapshot())
	check(old_combat.to_snapshot() == stopped, "Obsolete async callbacks never advance the paused combat")
	# Recreate the entire app during another active clear to exercise persistence.
	await _new_battle()
	_special_creation_fixture()
	app._click_cell(27)
	app._click_cell(26)
	var restart_model = _copy_combat(app.combat.to_snapshot())
	_finish_model(restart_model)
	app._return_menu()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = _new_app()
	check(app.screen == "menu" and app.store.has_active(), "Restart offers the isolated in-progress checkpoint")
	app._continue_run()
	await _finish_ui("App restart", restart_model.to_snapshot())

func _test_modal_during_animation() -> void:
	await _new_battle()
	# Keep the first playable card from ending the encounter in this boundary test.
	app.combat.enemy.hp = 1000
	app.combat.enemy_hp = 1000
	app.combat.enemy_max_hp = 1000
	_special_creation_fixture()
	app._click_cell(27)
	app._click_cell(26)
	check(app.resolving_ui and app.ui_locked, "Modal fixture begins during an actual board animation")
	app._show_deck()
	var source_modal: Control = app.modal
	var hand = app.battle_view.hand_view
	check(is_instance_valid(source_modal) and hand._locked, "Opening the deck during animation locks the real hand")
	check(await _wait_until(func(): return not app.resolving_ui and not app.ui_locked, 10.0), "Board visuals finish while the deck remains open")
	check(is_instance_valid(source_modal) and app.modal == source_modal and hand._locked and not hand.is_collapsed(), "Completed board animation preserves the open modal's hand lock")
	var before: Dictionary = app.combat.to_snapshot()
	var uid: int = app.combat.hand[0].uid
	check(app.combat.can_play(0), "Modal fixture has a genuinely affordable card")
	hand.request_play(uid)
	check(app.combat.to_snapshot() == before and not app.ui_locked, "Open deck prevents a hand play request after the board animation")
	app._close_modal()
	check(not is_instance_valid(app.modal) and not hand._locked, "Closing the deck restores hand interaction")
	var oracle = _copy_combat(before)
	check(oracle.play_card(0), "Modal close oracle plays the selected card once")
	hand.request_play(uid)
	check(app.ui_locked and app.combat.to_snapshot() == oracle.to_snapshot(), "First unlocked hand request pays and resolves the card exactly once")
	hand.request_play(uid)
	check(app.combat.to_snapshot() == oracle.to_snapshot(), "Repeated request during the card animation cannot pay or resolve twice")
	check(await _wait_until(func(): return not app.ui_locked, 3.0), "Card animation finishes after closing the modal")
	check(not hand._locked and app.combat.to_snapshot() == oracle.to_snapshot(), "Completed card animation retains the exact single-play resources and result")
	_assert_checkpoint("Modal close single card play")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	_clean()
	app = _new_app()
	await _test_invalid_swap()
	await _test_valid_swap_and_drop()
	for special in ["stripe", "bomb", "rainbow"]:
		await _test_special_activation(special)
	await _test_leave_and_continue()
	await _test_modal_during_animation()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	_clean()
	print("V2_BOARD_ANIMATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
