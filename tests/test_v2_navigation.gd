extends SceneTree

const SAVE_PATH := "res://tests/artifacts/navigation_save.cfg"
var app
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_navigation_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _finish_resolution() -> void:
	var frames := 0
	var automatic := true
	var tucked := true
	while (app.combat.phase == "resolving" or app.resolving_ui) and frames < 1000:
		automatic = automatic and not app.combat.board.pending_rainbow and not is_instance_valid(app.modal)
		tucked = tucked and app.battle_view.hand_view.is_collapsed()
		await create_timer(0.01).timeout
		frames += 1
	check(automatic and not app.combat.board.pending_rainbow and not is_instance_valid(app.modal), "New resolution never waits for a rainbow choice")
	check(tucked, "Automatic resolution keeps the hand tucked")
	check(app.combat.phase == "play", "Resumed resolution completes")
	check(not app.battle_view.hand_view.is_collapsed(), "Automatic resolution expands the hand on the play phase")

func _rainbow_fixture(kind: String, partner: String = "") -> void:
	var board = app.combat.board
	for y in range(8):
		for x in range(8):
			board.cells[y * 8 + x] = board.piece(board.kinds[(x + 2 * y) % board.kinds.size()])
	board.cells[0] = board.piece(kind, "rainbow")
	if partner != "":
		board.cells[1] = board.piece(partner)
	app.selection = -1
	app.highlights.clear()
	app._render()

func _count_kind(kind: String) -> int:
	var amount := 0
	for cell in app.combat.board.cells:
		if cell != null and cell.kind == kind:
			amount += 1
	return amount

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	_clean()
	app = _new_app()
	app._navigate("characters")
	var original_attributes: Array = app.chosen.duplicate()
	app._show_attribute_dialog()
	app._toggle_attribute("condensation")
	check(app.chosen == original_attributes, "Draft selection does not modify confirmed attributes")
	var confirm = app.modal.find_child("ConfirmAttributes", true, false)
	check(confirm != null and confirm.disabled, "Fewer than four attributes disables confirmation")
	app._confirm_attributes(true)
	check(app.run_state == null and app.screen == "characters", "Incomplete draft cannot start a run")
	app._close_modal()
	check(app.chosen == original_attributes and app.screen == "characters", "Cancel keeps original choice and character page")
	app._show_attribute_dialog()
	app._attribute_preset(1)
	var configured: Array = app.attribute_draft.duplicate()
	app._confirm_attributes()
	check(app.chosen == configured and app.screen == "characters" and app.modal == null, "Confirm updates character configuration without starting")
	app._show_attribute_dialog(true)
	app._confirm_attributes(true)
	check(app.screen == "run" and app.store.has_active(), "New run creates active checkpoint")
	var original_id: String = app.metadata.run_id
	app._return_menu()
	app._navigate("characters")
	app._show_attribute_dialog(true)
	app._confirm_attributes(true)
	check(is_instance_valid(app.modal) and app.metadata.run_id == original_id, "Replacement waits for final confirmation")
	app._close_modal()
	app._return_menu()
	app._continue_run()
	check(app.run_state.phase == "map" and app.metadata.run_id == original_id, "Continue restores original map")
	app._enter_node(app.run_state.available[0])
	check(app.battle_view.hand_view.is_collapsed(), "New battle starts with tucked hand")
	var move: Array = app.combat.board.hint()
	app._click_cell(move[0])
	app._click_cell(move[1])
	app._return_menu()
	var stopped: Dictionary = app.combat.to_snapshot()
	await create_timer(0.25).timeout
	check(app.combat.to_snapshot() == stopped, "Old resolver does not mutate paused combat")
	var restored: Dictionary = app.store.restore_active()
	check(restored.combat.to_snapshot() == stopped, "Partial chain restored exactly")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = _new_app()
	check(app.screen == "menu" and app.store.has_active(), "Fresh app offers persisted continue")
	app._continue_run()
	await _finish_resolution()
	check(not app.battle_view.hand_view.is_collapsed(), "Restored chain expands the hand only after resolving")
	var battle_before = app.battle_view
	app._hint()
	check(app.battle_view == battle_before, "Battle refresh keeps persistent subtree")
	# A new rainbow selects on the first click and automatically activates on the second.
	var turn_before: int = app.combat.turn
	app._end_turn()
	check(app.battle_view.hand_view.is_collapsed(), "Enemy feedback immediately tucks the hand")
	app._end_turn()
	check(app.combat.turn == turn_before + 1, "Repeated end-turn input does not advance another turn")
	await create_timer(0.45).timeout
	check(app.combat.phase == "board" and app.battle_view.hand_view.is_collapsed(), "Next board phase keeps the hand tucked")
	var own_kind: String = app.run_state.attributes[0]
	var partner_kind: String = app.run_state.attributes[1]
	_rainbow_fixture(own_kind)
	var own_count := _count_kind(own_kind)
	var mana_before: Dictionary = app.combat.mana.duplicate()
	var tooltip: String = app.board_buttons[0].tooltip_text
	check(tooltip.contains("对方球种") and tooltip.contains("自身球种") and not tooltip.contains("指定一种"), "Rainbow tooltip explains automatic target rules")
	app.board_buttons[0].pressed.emit()
	check(app.selection == 0 and app.combat.phase == "board", "First rainbow click only selects it")
	app.board_buttons[0].pressed.emit()
	check(app.combat.phase == "resolving" and app.selection == -1, "Second rainbow click starts resolution")
	check(not app.combat.board.pending_rainbow and not is_instance_valid(app.modal), "Direct rainbow activation does not open a selection modal")
	check(app.combat.board.action_yields == {own_kind: own_count}, "Direct rainbow activation removes exactly its own kind before refill")
	check(app.combat.mana[own_kind] - mana_before[own_kind] == own_count, "Direct rainbow activation credits its own resource once")
	check(app.battle_view.hand_view.is_collapsed(), "Automatic rainbow resolution keeps the hand tucked")
	var rainbow: Dictionary = app.combat.to_snapshot()
	app._return_menu()
	await create_timer(0.25).timeout
	check(app.combat.to_snapshot() == rainbow, "Exited rainbow resolver cannot continue changing the saved chain")
	var rainbow_restored: Dictionary = app.store.restore_active()
	check(rainbow_restored.combat.to_snapshot() == rainbow, "Automatic rainbow partial chain restores exactly")
	var expected_combat = rainbow_restored.combat
	var expected_steps := 0
	while expected_combat.phase == "resolving" and expected_steps < 1000:
		expected_combat.advance_board()
		expected_steps += 1
	check(expected_combat.phase == "play" and not expected_combat.board.pending_rainbow, "Persisted rainbow continues without a choice")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = _new_app()
	app._continue_run()
	check(app.combat.phase in ["resolving", "play"] and not is_instance_valid(app.modal), "Fresh app automatically resumes the saved rainbow chain")
	check(app.battle_view.hand_view.is_collapsed() == (app.combat.phase != "play" or app.resolving_ui), "Restored rainbow hand waits for the last refill animation before expanding")
	await _finish_resolution()
	check(app.combat.to_snapshot() == expected_combat.to_snapshot(), "Resumed rainbow has identical later randomness and resources")
	# Swapping supplies the partner's kind while the rainbow source grants its own one ball.
	app._end_turn()
	await create_timer(0.45).timeout
	check(app.combat.phase == "board", "Rainbow swap fixture starts in the board phase")
	_rainbow_fixture(own_kind, partner_kind)
	var partner_count := _count_kind(partner_kind)
	mana_before = app.combat.mana.duplicate()
	app.board_buttons[0].pressed.emit()
	app.board_buttons[1].pressed.emit()
	check(app.combat.phase == "resolving" and not app.combat.board.pending_rainbow and not is_instance_valid(app.modal), "Swapped rainbow resolves immediately without choosing a target")
	check(app.combat.board.action_yields == {own_kind: 1, partner_kind: partner_count}, "Swapped rainbow removes the partner kind and only its own source")
	check(app.combat.mana[own_kind] - mana_before[own_kind] == 1 and app.combat.mana[partner_kind] - mana_before[partner_kind] == partner_count, "Rainbow swap awards exact source and partner resources before refill")
	await _finish_resolution()
	for kind in app.catalog.ATTRIBUTES:
		app.combat.mana[kind] = 100
	app._render()
	app._show_deck()
	var uid: int = app.combat.hand[0].uid
	var hand_before: Array = app.combat.hand.duplicate(true)
	app.battle_view.hand_view.request_play(uid)
	check(app.combat.hand == hand_before, "Modal prevents hand activation")
	app._close_modal()
	var played_before: int = app.combat.played
	app._play_card_uid(uid)
	app._play_card_uid(uid)
	check(app.combat.played == played_before+1, "Rapid duplicate card input commits once")
	app._return_menu()
	var saved_after_card: Dictionary = app.store.restore_active().combat.to_snapshot()
	await create_timer(0.65).timeout
	check(app.screen == "menu", "Old card animation cannot route back into battle")
	app._continue_run()
	check(app.combat.to_snapshot() == saved_after_card, "Card effects persist through interrupted animation")
	# Failed persistence must still retain the newer in-memory exploration.
	app.combat.mana.condensation += 7
	var unsaved: Dictionary = app.combat.to_snapshot()
	app.store._writable = false
	app._return_menu()
	check(app.progress_dirty and app.save_error != "", "Failed save is explicit")
	app._continue_run()
	check(app.combat.to_snapshot() == unsaved, "Continue keeps unsaved in-memory state rather than older checkpoint")
	app.store._writable = true
	check(app._checkpoint() == OK and not app.progress_dirty, "Retry saves newest progress")
	app.store._writable = false
	app.run_state.end_run("abandoned")
	app._state_changed()
	var terminal: Dictionary = app.run_state.to_snapshot()
	app._return_menu()
	app._continue_run()
	check(app.run_state.to_snapshot() == terminal and app.run_state.phase == "ended", "Unsaved terminal state never resumes old battle")
	app.store._writable = true
	app._retry_save()
	app._state_changed()
	check(app.store.data.history.size() == 1 and not app.store.has_active(), "Terminal history commits once and clears active")
	app._navigate("history")
	check(app.find_children("*", "Button", true, false).size() > 0, "History provides return navigation")
	app.store._writable = false
	app._save_display({"fullscreen": false, "resolution": Vector2i(1600, 900)})
	check(not app.pending_settings.is_empty() and app.settings_error != "", "Failed settings retain requested values")
	app.store._writable = true
	app._retry_save()
	check(app.pending_settings.is_empty() and app.save_error == "" and app.store.data.settings.resolution == Vector2i(1600, 900), "Settings retry persists request and clears error")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	_clean()
	print("V2_NAVIGATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
