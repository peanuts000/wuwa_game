extends SceneTree

const SAVE_PATH := "res://tests/artifacts/compendium_stage_save.cfg"
var app
var checks := 0
var failures := 0
var close_events := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _wait(seconds := 0.05) -> void:
	await process_frame
	await create_timer(seconds).timeout

func _click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	await _click_point(point)

func _click_point(point: Vector2, mouse_button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = mouse_button
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _record_close() -> void:
	close_events += 1

func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tests/artifacts/compendium_stage_%s.png" % label) == OK, "Screenshot saved: " + label)

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	_clean()
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path = SAVE_PATH
	app.legacy_save_path = "res://tests/artifacts/missing_compendium_stage_legacy.cfg"
	app.apply_display_settings = false
	root.add_child(app)
	await _wait()
	var before: Dictionary = app.store.data.duplicate(true)
	var chosen: Array = app.chosen.duplicate()
	app._navigate("compendium")
	var hub = app.compendium_hub
	check(hub.state == "opening", "Opening starts before controls activate")
	check(hub.get_category_buttons().all(func(button): return button.disabled), "Moving wooden boards cannot be clicked")
	hub._request_category("cards")
	check(app.screen == "compendium", "Early category request ignored")
	await _wait(0.43)
	await _capture("falling")
	await _click(hub.get_category_buttons()[0])
	check(app.screen == "compendium" and hub.state == "opening", "Clicking a moving disabled board does not close the hub")
	await _wait(0.8)
	check(hub.state == "open" and hub.get_category_buttons().all(func(button): return not button.disabled), "All three boards settle and activate")
	check(root.gui_get_focus_owner() == hub.get_category_buttons()[0], "First board receives keyboard focus")
	var first_board = hub.get_category_buttons()[0]
	await _click_point(first_board.get_global_transform_with_canvas() * Vector2(150, -8))
	check(hub.state == "open", "Painted crest above the button is not outside the board")
	await _click_point(Vector2(450, 350), MOUSE_BUTTON_RIGHT)
	check(hub.state == "open", "Right-clicking the background does not dismiss the hub")
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(1280, 960)]:
		root.size = dimensions
		await _wait()
		var previous := Rect2()
		for button in hub.get_category_buttons():
			var rect: Rect2 = button.get_global_rect()
			check(app.get_global_rect().encloses(rect), "Board fits " + str(dimensions))
			check(not rect.intersects(hub._close.get_global_rect()), "Return control remains unobstructed")
			check(button.rotation == 0 and not button.disabled, "Resize does not replay entrance")
			check(button.find_child("CategoryDescription", true, false).get_global_rect().size.x < rect.size.x, "Native copy fits wooden board")
			if previous.size != Vector2.ZERO: check(previous.end.x < rect.position.x, "Boards do not overlap")
			previous = rect
		for index in range(6):
			var board: Control = hub.get_category_buttons()[index / 2]
			var expected: Vector2 = board.get_transform() * Vector2(75 + (index % 2) * 150, 13)
			check(hub._ropes[index].points[-1].is_equal_approx(expected), "Rope endpoint stays attached")
		await _capture("%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _wait()
	for index in range(3):
		var button = app.compendium_hub.get_category_buttons()[index]
		if index == 1:
			button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(button)
		await _wait()
		check(app.screen == ["compendium_cards", "compendium_supplies", "compendium_relics"][index], "Native category navigation works")
		await _key(KEY_ESCAPE)
		await _wait(1.15)
		check(app.screen == "compendium" and app.compendium_hub.state == "open", "Escape returns to settled selector")
	check(app.store.data == before and app.chosen == chosen and app.run_state == null, "Browsing preserves save data and run configuration")
	hub = app.compendium_hub
	hub.close_requested.connect(_record_close)
	await _click(app.compendium_hub._close)
	check(app.screen == "compendium" and hub.state == "closing", "Corner action starts closing before navigation")
	check(hub.get_category_buttons().all(func(button): return button.disabled) and hub._close.disabled, "Closing disables category and corner actions")
	var close_motion = hub._motions[0]
	hub._request_category("cards")
	await _key(KEY_ESCAPE)
	await _click_point(Vector2(640, 650))
	check(app.screen == "compendium" and hub._motions[0] == close_motion, "Repeated close and category requests cannot restart animation or navigate early")
	await _wait(0.12)
	check(hub._travel[0] < -1 and hub._travel[0] > -680 and hub._dimmer.color.a < 0.48, "Closing visibly lifts the boards and fades the shade")
	await _capture("closing")
	root.size = Vector2i(960, 540)
	await _wait()
	check(hub.state == "closing", "Resize during closing does not restart the entrance")
	for index in range(6):
		var board: Control = hub.get_category_buttons()[index / 2]
		var expected: Vector2 = board.get_transform() * Vector2(75 + (index % 2) * 150, 13)
		check(hub._ropes[index].points[-1].is_equal_approx(expected), "Ropes follow boards while closing and resizing")
	await _wait(0.45)
	check(app.screen == "menu" and close_events == 1 and not is_instance_valid(hub), "Animated corner exit navigates once after completion")
	for outside_point in [Vector2(450, 350), Vector2(640, 650)]:
		app._navigate("compendium")
		await _wait(1.15)
		hub = app.compendium_hub
		await _click_point(app.get_global_transform_with_canvas() * outside_point)
		check(hub.state == "closing" and app.screen == "compendium", "Clicking a gap or below the boards starts animated exit at scaled resolution")
		await _wait(0.45)
		check(app.screen == "menu", "Outside click exits without activating menu behind it")
	root.size = Vector2i(1280, 720)
	await _wait()
	app._navigate("compendium")
	await _wait(1.15)
	hub = app.compendium_hub
	hub.get_category_buttons()[1].grab_focus()
	await _key(KEY_ESCAPE)
	check(hub.state == "closing" and app.screen == "compendium", "Escape with a focused category starts the same animation")
	await _wait(0.45)
	check(app.screen == "menu", "Escape returns to menu after animation")
	app._navigate("compendium")
	var old_hub = app.compendium_hub
	await _wait(0.1)
	await _key(KEY_ESCAPE)
	check(old_hub.state == "closing", "Escape can interrupt the entrance")
	await _wait(1.2)
	check(app.screen == "menu" and not is_instance_valid(old_hub), "Leaving during entrance frees tweens and cannot reopen a catalog")
	app._navigate("compendium")
	await _wait(0.48)
	old_hub = app.compendium_hub
	old_hub.close_requested.connect(_record_close)
	old_hub.request_close()
	check(old_hub.state == "closing", "Can close during the entrance rebound")
	app._navigate("characters")
	await _wait(1.2)
	check(app.screen == "characters" and not is_instance_valid(old_hub) and close_events == 1, "Disposing a closing hub cancels its late navigation callback")
	check(app.store.data == before and app.chosen == chosen, "All close paths preserve save data and choices")
	app.queue_free()
	await process_frame
	_clean()
	print("V2_COMPENDIUM_STAGE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
