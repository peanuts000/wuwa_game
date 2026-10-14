extends SceneTree

const SAVE_PATH := "res://tests/artifacts/settings_popup_save.cfg"
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

func _wait(seconds := 0.05) -> void:
	await process_frame
	await create_timer(seconds).timeout

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
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

func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tests/artifacts/settings_%s.png" % label) == OK, "Capture saved: " + label)

func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	_cleanup()
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path = SAVE_PATH
	app.legacy_save_path = "res://tests/artifacts/missing_settings_legacy.cfg"
	app.apply_display_settings = false
	root.add_child(app)
	await _wait()
	var menu = app.get_node("MenuStageBackground")
	var opener = app.get_node("MenuSettingsButton")
	await _click(opener.get_global_rect().get_center())
	var popup = app.modal
	check(is_instance_valid(popup) and app.screen == "menu", "Settings opens as an overlay on menu")
	if not is_instance_valid(popup):
		quit(1)
		return
	check(popup.state == "opening" and popup.full.disabled, "Settings disabled while falling")
	app._show_settings()
	check(app.modal == popup, "Repeated open does not duplicate popup")
	await _wait(0.22)
	await _capture("falling")
	await _wait(0.18)
	await _capture("rebound")
	await _wait(0.55)
	check(popup.state == "open" and not popup.full.disabled, "Drop finishes and enables settings")
	check(popup.board.position.is_equal_approx(Vector2(300, 180)), "Board settles at intended position")
	check(app.get_node("MenuStageBackground") == menu, "Opening preserves original menu")
	check(opener.focus_mode == Control.FOCUS_NONE, "Background keyboard focus is locked")
	for index in range(10):
		await _key(KEY_TAB)
		check(popup.is_ancestor_of(root.gui_get_focus_owner()), "Tab stays in popup")
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _wait()
		var panel: Rect2 = popup.board.get_global_rect()
		check(app.get_global_rect().encloses(panel), "Board fits %s" % dimensions)
		for button in popup.actions:
			if button.visible:
				check(panel.encloses(button.get_global_rect()), "Control fits board at %s: %s" % [dimensions, button.name])
		check(popup.state == "open", "Resize does not replay drop")
		await _capture("%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _wait()
	app.apply_display_settings = DisplayServer.get_name() != "headless"
	await _click(popup.full.get_global_transform_with_canvas() * (popup.full.size * 0.5))
	check(app.store.data.settings.fullscreen and app.modal == popup, "Fullscreen change saves without replacing popup")
	if app.apply_display_settings:
		check(root.mode == Window.MODE_FULLSCREEN, "Fullscreen applies to real window while popup stays open")
	# The OS mode switch updates the canvas scale asynchronously. Sample the
	# transformed control position only after the fullscreen layout has settled.
	await _wait(0.3)
	await _click(popup.full.get_global_transform_with_canvas() * (popup.full.size * 0.5))
	await _wait(0.3)
	if app.apply_display_settings:
		check(root.mode == Window.MODE_WINDOWED, "Popup can return real window to windowed mode")
	for index in range(3):
		var choice = popup.choices[index]
		await _click(choice.get_global_transform_with_canvas() * (choice.size * 0.5))
		await _wait()
		check(app.store.data.settings.resolution == popup.RESOLUTIONS[index], "Resolution choice persists")
	check(app.get_node("MenuStageBackground") == menu and popup.state == "open", "Changes preserve menu and animation state")
	app.apply_display_settings = false
	root.size = Vector2i(1280, 720)
	await _wait()
	app.store._writable = false
	await _click(popup.choices[1].get_global_rect().get_center())
	check(popup.retry.visible and app.pending_settings.resolution == Vector2i(1600, 900), "Failed save retains requested selection and exposes retry")
	await _capture("save_error")
	app.store._writable = true
	await _click(popup.retry.get_global_rect().get_center())
	check(app.pending_settings.is_empty() and not popup.retry.visible and app.modal == popup, "Retry succeeds in same popup")
	await _key(KEY_ESCAPE)
	check(popup.state == "closing", "Escape starts animated close")
	app._close_modal()
	app._show_settings()
	await _wait(0.4)
	check(not is_instance_valid(app.modal) and opener.has_focus(), "Closing completes once and restores opener focus")
	app._show_settings()
	await _wait(0.1)
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	check(not is_instance_valid(app.modal), "Can close during drop without late animation callback")
	app._show_settings()
	await _wait(0.95)
	popup = app.modal
	await _click(Vector2(50, 650))
	await _wait(0.4)
	check(not is_instance_valid(app.modal) and app.screen == "menu", "Outside click closes without background navigation")
	app._show_settings()
	await _wait(0.95)
	await _click(app.modal.close_button.get_global_rect().get_center())
	await _wait(0.4)
	check(not is_instance_valid(app.modal), "Close button dismisses popup")
	app._show_settings()
	await _wait(0.95)
	# A background button outside the board must only dismiss, never activate.
	await _click(Vector2(640, 630))
	await _wait(0.4)
	check(app.screen == "menu" and not is_instance_valid(app.modal), "History button cannot receive clicks through shade")
	app._show_settings()
	await _wait(0.1)
	app._modal("进度未能保存")
	check(app.modal.name != "SettingsPopup", "Replacement modal immediately disposes setting animation")
	await _wait(0.9)
	check(is_instance_valid(app.modal), "Old animation cannot close replacement modal")
	app._close_modal()
	app._show_settings()
	await _wait(0.1)
	app._navigate("characters")
	await _wait(0.9)
	check(app.screen == "characters" and not is_instance_valid(app.modal), "Page cleanup cancels popup animation")
	app._commit_run()
	app._return_menu()
	app._show_settings()
	await _wait(0.95)
	app.store._writable = false
	await _click(app.modal.find_child("SettingsQuitButton", true, false).get_global_rect().get_center())
	check(is_instance_valid(app.modal) and app.modal.name != "SettingsPopup" and app.progress_dirty, "Failed quit checkpoint replaces settings with recovery dialog")
	await _wait(0.4)
	check(is_instance_valid(app.modal), "Failed quit dialog remains usable after popup disposal")
	app.store._writable = true
	app._close_modal()
	check(app.screen == "menu", "Returning from failed quit retains menu")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	_cleanup()
	print("V2_SETTINGS_POPUP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
