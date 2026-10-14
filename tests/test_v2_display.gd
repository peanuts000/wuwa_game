extends SceneTree

const SAVE_PATH := "res://tests/artifacts/display_save.cfg"
var failures := 0
var checks := 0
var app

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_display_legacy.cfg"
	root.add_child(instance)
	return instance

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.15).timeout

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)
	app = _new_app()
	await _settle()
	check(app.find_children("*", "Button", true, false).size() == 5, "Display startup reaches full menu")
	app._save_display({"fullscreen": true, "resolution": Vector2i(1600, 900)})
	await _settle()
	check(app.store.data.settings.fullscreen, "Fullscreen preference is persisted")
	if DisplayServer.get_name() != "headless":
		check(root.mode == Window.MODE_FULLSCREEN, "Fullscreen setting applies to actual Window")
	app._save_display({"fullscreen": false, "resolution": Vector2i(1920, 1080)})
	await _settle()
	check(app.store.data.settings.resolution == Vector2i(1920, 1080), "Requested resolution persists even if clamped")
	if DisplayServer.get_name() != "headless":
		check(root.mode == Window.MODE_WINDOWED, "Window setting exits fullscreen")
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(root.current_screen)
		check(root.size.x <= usable.size.x and root.size.y <= usable.size.y, "Window fits actual usable screen")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = _new_app()
	await _settle()
	check(app.store.data.settings.resolution == Vector2i(1920, 1080) and not app.store.data.settings.fullscreen, "Fresh app restores display preferences")
	if DisplayServer.get_name() != "headless":
		check(root.mode == Window.MODE_WINDOWED, "Fresh app applies restored Window mode")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)
	print("V2_DISPLAY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
