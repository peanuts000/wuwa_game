extends SceneTree

# This fixture never reads or writes the player's save or legacy progress.
const SAVE_PATH := "res://tests/artifacts/idle_hint_save.cfg"
var app
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("IDLE_HINT: " + message)

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_idle_hint_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	# Test the boundary with explicit deltas, independent of rendering speed.
	instance.set_process(false)
	return instance

func _restart() -> void:
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = _new_app()
	check(app.screen == "menu" and app.store.has_active(), "Restart offers the isolated active checkpoint")
	app._continue_run()
	await process_frame
	check(app.screen == "run" and app.combat != null, "Restart resumes the actual battle")

func _new_battle() -> void:
	app._commit_run()
	app._enter_node(app.run_state.available[0])
	await process_frame
	check(app.combat.phase == "board" and not app.combat.auto_hint_used, "New battle begins with an unused hint")

func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	root.push_input(event, true)
	await process_frame

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _click(point: Vector2) -> void:
	await _motion(point, Vector2(1, 0))
	await _mouse(point, true)
	await _mouse(point, false)

func _key(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_K
	event.physical_keycode = KEY_K
	event.pressed = pressed
	event.echo = echo
	root.push_input(event, true)
	await process_frame

func _capture_hint() -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png("res://tests/artifacts/v2_idle_hint.png") == OK, "First automatic hint screenshot saves")

func _test_real_activity() -> void:
	var outside := Vector2(4, 4)
	app.idle_hint_elapsed = 5.0
	await _mouse(outside, true)
	check(is_zero_approx(app.idle_hint_elapsed), "Real mouse press resets inactivity")
	app.idle_hint_elapsed = 5.0
	await _mouse(outside, false)
	check(is_equal_approx(app.idle_hint_elapsed, 5.0), "Mouse release alone does not reset inactivity")
	await _motion(Vector2(8, 8), Vector2(4, 4))
	check(is_zero_approx(app.idle_hint_elapsed), "Real nonzero pointer movement resets inactivity")
	app.idle_hint_elapsed = 5.0
	await _motion(Vector2(8, 8))
	check(is_equal_approx(app.idle_hint_elapsed, 5.0), "Zero relative movement does not postpone the hint")
	await _key(true)
	check(is_zero_approx(app.idle_hint_elapsed), "Real non-echo key press resets inactivity")
	app.idle_hint_elapsed = 5.0
	await _key(true, true)
	check(is_zero_approx(app.idle_hint_elapsed), "Held-key echo navigation also counts as player activity")
	app.idle_hint_elapsed = 5.0
	await _key(false)
	check(is_equal_approx(app.idle_hint_elapsed, 5.0), "Key release alone does not reset inactivity")
	app._click_cell(63)
	check(is_zero_approx(app.idle_hint_elapsed) and app.selection == 63, "Cell selection records activity")
	app.idle_hint_elapsed = 5.0
	app._activate_selected()
	check(is_zero_approx(app.idle_hint_elapsed) and app.combat.phase == "board", "Attempting to activate an ordinary ball records activity without an action")
	app._click_cell(63)
	check(app.selection == -1, "Ordinary second selection cancels before threshold checks")

func _test_threshold_and_restart() -> void:
	app._click_cell(63)
	var before: Dictionary = app.combat.to_snapshot()
	var expected_hint: Array = app.combat.board.hint()
	check(not expected_hint.is_empty(), "Live battle has a hintable action")
	app._process(7.0)
	check(not app.combat.auto_hint_used and app.highlights.is_empty(), "No hint before eight seconds")
	app.idle_hint_elapsed = 7.999
	app._process(0.0)
	check(not app.combat.auto_hint_used and app.highlights.is_empty(), "7.999 seconds remains below the threshold")
	app.idle_hint_elapsed = 7.0
	app._process(1.0)
	check(app.combat.auto_hint_used and app.highlights == expected_hint, "Eight seconds produces one automatic action hint")
	check(app.selection == 63, "Automatic hint preserves the selected ball")
	check(app.notice == "白圈是一组可用行动。", "Automatic hint explains the white action circles")
	for index in expected_hint:
		var style: StyleBoxFlat = app.board_buttons[index].get_theme_stylebox("normal")
		check(style.border_color == Color.WHITE and style.border_width_top == 3, "Hinted ball %d has the actual white border" % index)
	before.auto_hint_used = true
	check(app.combat.to_snapshot() == before, "Hint changes no resources, board, action, or RNG state")
	var restored: Dictionary = app.store.restore_active()
	check(restored.get("combat") != null and restored.combat.auto_hint_used, "Automatic hint usage is checkpointed immediately")
	check(restored.combat.to_snapshot() == before, "Saved hint checkpoint preserves the exact combat")
	await _capture_hint()
	app._process(100.0)
	app._hint()
	check(app.combat.to_snapshot() == before and app.highlights == expected_hint, "Waiting and direct hint requests cannot use another hint this turn")
	check(is_zero_approx(app.idle_hint_elapsed), "A used hint stops accumulating idle time")
	app._click_cell(0)
	check(app.highlights.is_empty() and app.combat.auto_hint_used, "Further player activity clears circles and keeps the hint consumed")
	app._process(100.0)
	check(app.highlights.is_empty(), "Cleared hint circles do not reappear in the same turn")
	app.idle_hint_elapsed = 5.0
	app._return_menu()
	check(is_zero_approx(app.idle_hint_elapsed), "Returning to the menu clears elapsed inactivity")
	await _restart()
	check(app.combat.auto_hint_used and app.highlights.is_empty(), "Restart preserves usage without restoring obsolete circles")
	check(is_zero_approx(app.idle_hint_elapsed), "Restart never restores the elapsed timer")
	app._process(100.0)
	check(app.highlights.is_empty() and app.combat.auto_hint_used, "Restart cannot grant a second hint in the saved turn")
	# End a real turn through the app, including its enemy feedback input lock.
	# Choose this enemy's actual attack step: a random initial charge has no feedback tween.
	var has_attack := false
	for index in range(app.combat.enemy.pattern.size()):
		if app.combat.enemy.pattern[index].type == "attack":
			app.combat.intent_index = index
			app.combat.intent = app.combat.enemy.pattern[index].duplicate(true)
			has_attack = true
			break
	check(has_attack, "Feedback fixture uses a genuine enemy attack intent")
	app.combat.phase = "play"
	app._render()
	var turn_before: int = app.combat.turn
	app._end_turn()
	check(app.combat.turn == turn_before + 1 and not app.combat.auto_hint_used, "Starting the next turn restores one hint")
	check(app.ui_locked, "Enemy feedback holds the real UI input lock")
	app._process(20.0)
	check(not app.combat.auto_hint_used and app.highlights.is_empty() and is_zero_approx(app.idle_hint_elapsed), "Feedback lock prevents idle hints even after the model enters the next board phase")
	await create_timer(0.45).timeout
	check(app.combat.phase == "board" and not app.ui_locked, "Enemy feedback completes before hints become eligible")
	app._process(8.0)
	check(app.combat.auto_hint_used and not app.highlights.is_empty(), "A new eligible turn may receive another hint")

func _check_paused(label: String) -> void:
	app.idle_hint_elapsed = 3.0
	app._process(100.0)
	app._hint()
	check(not app.combat.auto_hint_used and app.highlights.is_empty() and app.selection == 31 and is_zero_approx(app.idle_hint_elapsed), "%s blocks hints without accumulating inactivity or disturbing selection" % label)

func _test_pause_conditions() -> void:
	await _new_battle()
	app.selection = 31
	for page in ["menu", "characters", "history", "settings"]:
		app.screen = page
		_check_paused("Screen " + page)
	app.screen = "run"
	var actual_run_phase: String = app.run_state.phase
	for phase in ["map", "rest", "shop", "event", "rewards", "ended"]:
		app.run_state.phase = phase
		_check_paused("Run phase " + phase)
	app.run_state.phase = actual_run_phase
	# Enemy is a transient UI guard fixture, never checkpoint this invalid model phase.
	for phase in ["play", "enemy", "resolving", "ended"]:
		app.combat.phase = phase
		_check_paused("Combat phase " + phase)
	app.combat.phase = "board"
	app.resolving_ui = true
	_check_paused("Board resolution UI lock")
	app.resolving_ui = false
	app.ui_locked = true
	_check_paused("General UI lock")
	app.ui_locked = false
	app._modal("隔离测试弹窗")
	_check_paused("Modal dialog")
	app._close_modal()
	app._render()
	check(app._can_auto_hint(), "Closing the modal restores actual board hint eligibility")
	app.idle_hint_elapsed = 5.0
	check(app._checkpoint() == OK, "Unused-turn checkpoint succeeds")
	var snapshot: Dictionary = app.combat.to_snapshot()
	check(not snapshot.has("idle_hint_elapsed"), "Elapsed inactivity is not part of the model checkpoint")
	app._return_menu()
	app._process(100.0)
	check(not app.combat.auto_hint_used, "Actual menu pause cannot consume the unused hint")
	await _restart()
	check(not app.combat.auto_hint_used and is_zero_approx(app.idle_hint_elapsed), "Unused hint resumes with a fresh timer")
	app._process(3.0)
	check(not app.combat.auto_hint_used, "Five pre-restart seconds do not combine with three post-restart seconds")
	app._process(-20.0)
	check(is_equal_approx(app.idle_hint_elapsed, 3.0), "Negative delta cannot reduce inactivity")
	app._process(5.0)
	check(app.combat.auto_hint_used and not app.highlights.is_empty(), "Fresh post-restart eight-second threshold still works")
	# The boss route uses the same board-phase guard as an ordinary battle.
	app.combat.auto_hint_used = false
	app.highlights.clear()
	app.run_state.phase = "boss"
	app.idle_hint_elapsed = 0.0
	app._process(8.0)
	check(app.combat.auto_hint_used and not app.highlights.is_empty(), "Boss board phase also receives its automatic hint")
	app.run_state.phase = actual_run_phase

func _latin_fixture(special: String = "") -> Array:
	var board = app.combat.board
	for y in range(8):
		for x in range(8):
			board.cells[y * 8 + x] = board.piece(board.kinds[(x + 2 * y) % board.kinds.size()])
	var target := 27
	if special != "":
		board.cells[target] = board.piece(app.run_state.attributes[0], special, "h")
	var removed: Array = []
	for index in range(64):
		if (special == "stripe" and index / 8 == target / 8) or (special == "bomb" and absi(index % 8 - target % 8) <= 1 and absi(index / 8 - target / 8) <= 1) or (special == "rainbow" and board.cells[index].kind == board.cells[target].kind):
			removed.append(index)
	app.selection = -1
	app.highlights.clear()
	app._render()
	return removed

func _test_special_double_clicks() -> void:
	for special in ["stripe", "bomb", "rainbow"]:
		await _new_battle()
		var expected_removed: Array = _latin_fixture(special)
		await process_frame
		var before: Dictionary = app.combat.to_snapshot()
		var expected_yields: Dictionary = {}
		for index in expected_removed:
			var kind: String = before.board.cells[index].kind
			expected_yields[kind] = expected_yields.get(kind, 0) + 1
		var target: Button = app.board_buttons[27]
		var point: Vector2 = target.get_global_rect().get_center()
		app.idle_hint_elapsed = 3.0
		await _click(point)
		check(app.selection == 27 and app.combat.phase == "board", "%s first real pointer click only selects the special ball" % special)
		check(app.combat.to_snapshot() == before and is_zero_approx(app.idle_hint_elapsed), "%s first click consumes no action and resets inactivity" % special)
		await _click(point)
		check(app.combat.phase == "resolving" and app.selection == -1, "%s second real pointer click starts one resolution" % special)
		check(not app.combat.board.pending_rainbow and not is_instance_valid(app.modal), "%s double-click has no target-choice pause" % special)
		check(app.combat.board.action_yields == expected_yields, "%s second click clears precisely its first action range" % special)
		var exact_range := true
		for index in range(64):
			if index in expected_removed:
				exact_range = exact_range and app.combat.board.cells[index] == null
			else:
				exact_range = exact_range and app.combat.board.cells[index] == before.board.cells[index]
		check(exact_range, "%s first clear removes its full range and leaves all other cells unchanged" % special)
		var activated: Dictionary = app.combat.to_snapshot()
		# Mouse down/up on the disabled old cell cannot enqueue another action.
		await _mouse(point, true)
		await _mouse(point, false)
		check(app.combat.to_snapshot() == activated, "%s rapid third click cannot activate twice" % special)
		app._return_menu()
		await create_timer(0.18).timeout
		check(app.combat.to_snapshot() == activated, "%s leaving during resolution cancels its old async continuation" % special)
	await _new_battle()
	_latin_fixture()
	await process_frame
	var before: Dictionary = app.combat.to_snapshot()
	var point: Vector2 = app.board_buttons[27].get_global_rect().get_center()
	await _click(point)
	check(app.selection == 27, "Ordinary ball first real click selects")
	await _click(point)
	check(app.selection == -1 and app.combat.phase == "board", "Ordinary ball second real click cancels selection")
	check(app.combat.to_snapshot() == before, "Ordinary second click never starts or consumes an action")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	_clean()
	app = _new_app()
	check(is_equal_approx(app.AUTO_HINT_DELAY, 8.0), "Automatic hint delay is eight seconds")
	await _new_battle()
	await _test_real_activity()
	await _test_threshold_and_restart()
	await _test_pause_conditions()
	await _test_special_double_clicks()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	_clean()
	print("V2_IDLE_HINT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
