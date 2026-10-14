extends SceneTree

# This test never opens or overwrites the player's save.
const SAVE_PATH := "res://tests/artifacts/relic_ui_save.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 960)]
const RELIC_IDS := ["r01", "r02", "r03", "r04", "r05"]
var app
var checks := 0
var failures := 0
var dimensions_label := "1280x720"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("RELIC_UI [%s]: %s" % [dimensions_label, message])

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_relic_ui_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.22).timeout

func _snapshot() -> Dictionary:
	return {
		"run": app.run_state.to_snapshot(),
		"combat": app.combat.to_snapshot() if app.combat != null else null,
		"metadata": app.metadata.duplicate(true),
		"store": app.store.data.duplicate(true),
		"file": FileAccess.get_file_as_string(SAVE_PATH),
		"backup": FileAccess.get_file_as_string(SAVE_PATH + ".bak") if FileAccess.file_exists(SAVE_PATH + ".bak") else "",
	}

func _fixture(ids: Array) -> void:
	app._commit_run()
	app.run_state.relics = ids.duplicate()
	app._state_changed()
	await _settle()
	check(app.run_state.phase == "map" and app.save_error.is_empty(), "Relic fixture checkpoints a valid exploration")

func _point(control: Control, local: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas() * local

func _center(control: Control) -> Vector2:
	return _point(control, control.size * 0.5)

func _sync_native_pointer(point: Vector2) -> void:
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(point)

func _motion(point: Vector2) -> void:
	_sync_native_pointer(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame

func _mouse(point: Vector2, pressed: bool, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	_sync_native_pointer(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button_index
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _click(point: Vector2) -> void:
	await _motion(point)
	# Keep the real press/release in one input batch, as in the deck UI tests.
	# Yielding between them lets native window input interrupt the synthetic click.
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func _drag(start: Vector2, finish: Vector2) -> void:
	await _motion(start)
	await _mouse(start, true)
	await _motion(finish)
	await _mouse(finish, false)

func _wheel(control: Control) -> void:
	var point := _point(control, Vector2(12, control.size.y * 0.5))
	await _motion(point)
	for _step in range(3):
		await _mouse(point, true, MOUSE_BUTTON_WHEEL_DOWN)
		await _mouse(point, false, MOUSE_BUTTON_WHEEL_DOWN)

func _open_tab(id: String) -> bool:
	var button: Button = app.run_navigation.get_tab_button(id)
	var point := _center(button)
	await _click(point)
	await _settle()
	var opened: bool = app.run_tab == id and button.button_pressed
	check(opened, "Actual pointer opens the " + id + " tab")
	if not opened:
		print("RELIC_UI_POINTER_DIAGNOSTIC [%s]: target=%s actual=%s point=%s rect=%s canvas=%s disabled=%s visible=%s pressed=%s modal=%s viewport_mouse=%s" % [dimensions_label, id, app.run_tab, point, button.get_global_rect(), button.get_global_transform_with_canvas(), button.disabled, button.is_visible_in_tree(), button.button_pressed, is_instance_valid(app.modal), root.get_mouse_position()])
	return opened

func _grid():
	return app.run_tab_relics

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or dimensions_label != "1280x720":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tests/artifacts/" + name + ".png") == OK, "Relic screenshot saves: " + name)

func _check_bounds(grid) -> void:
	var scroll: ScrollContainer = grid.get_scroll_container()
	check(app.size.is_equal_approx(Vector2(1280, 720)) and app.get_global_rect().grow(1).encloses(grid.get_global_rect()), "Relic grid stays inside the 1280 by 720 logical canvas")
	check(not scroll.get_v_scroll_bar().is_visible_in_tree() and not scroll.get_h_scroll_bar().is_visible_in_tree(), "Relic scrollbars stay hidden while preserving the internal viewport")
	if not is_instance_valid(app.modal):
		check(grid.get_global_rect().position.y >= app.run_navigation.get_global_rect().end.y, "Relic grid is below the fixed browser tabs")

func _check_faces(grid, ids: Array) -> void:
	var views: Array = grid.get_relic_views()
	check(views == grid.get_card_views() and views.size() == ids.size(), "Relic card grid displays exactly the supplied instances")
	var faces_exact := true
	var ordered_ids: Array = []
	var ordered_uids: Array = []
	for view in views:
		ordered_ids.append(str(view.card.id))
		ordered_uids.append(int(view.uid))
		var entry: Dictionary = app.catalog.relics[view.card.id]
		faces_exact = faces_exact and view.full_text.contains(entry.name) and view.full_text.contains(entry.effect) and view.tooltip_text.is_empty()
		var effect_visible := false
		for label in view.find_children("*", "Label", true, false):
			effect_visible = effect_visible or (label.is_visible_in_tree() and label.text == entry.effect)
		faces_exact = faces_exact and effect_visible
	check(ordered_ids == ids, "Relic faces preserve their actual catalog IDs and run order")
	var expected_uids: Array = []
	for index in range(ids.size()):
		expected_uids.append(index + 1)
	check(ordered_uids == expected_uids and faces_exact, "Every relic shows its full effect on its face without a redundant tooltip")

func _empty_and_single() -> void:
	await _fixture([])
	var before: Dictionary = _snapshot()
	await _open_tab("relics")
	var grid = _grid()
	check(is_instance_valid(grid), "Empty relic tab uses the reusable relic grid")
	if not is_instance_valid(grid):
		return
	_check_bounds(grid)
	_check_faces(grid, [])
	var empty_visible := false
	for label in grid.find_children("*", "Label", true, false):
		empty_visible = empty_visible or (label.is_visible_in_tree() and label.text.contains("尚未获得藏品"))
	check(empty_visible and _snapshot() == before, "Zero relics show the empty state without inventing or granting anything")
	await _fixture(["r01"])
	before = _snapshot()
	await _open_tab("relics")
	grid = _grid()
	if not is_instance_valid(grid):
		return
	_check_faces(grid, ["r01"])
	if grid.get_relic_views().is_empty():
		return
	var card: Control = grid.get_relic_views()[0]
	check(grid.get_scroll_container().get_global_rect().grow(1).encloses(card.get_global_rect()), "A single relic is fully visible in its card slot")
	await _click(_center(card))
	card.emit_signal("activation_requested", card.uid)
	check(_snapshot() == before and app.run_tab == "relics" and not is_instance_valid(app.modal), "Relic clicks and keyboard activation are read-only")

func _populated_layout() -> void:
	await _fixture(RELIC_IDS)
	var before: Dictionary = _snapshot()
	await _open_tab("deck")
	var deck = app.run_tab_deck
	if not is_instance_valid(deck) or deck.get_card_views().size() < 5:
		return
	await _motion(_center(app.run_navigation.get_tab_button("deck")))
	await _settle()
	var expected_rects: Array[Rect2] = []
	for index in range(5):
		expected_rects.append(deck.get_card_views()[index].get_global_rect())
	await _open_tab("relics")
	var grid = _grid()
	if not is_instance_valid(grid):
		return
	await _motion(_center(app.run_navigation.get_tab_button("relics")))
	await _settle()
	_check_bounds(grid)
	_check_faces(grid, RELIC_IDS)
	var cards: Array = grid.get_relic_views()
	if cards.size() < 5:
		return
	var same_layout := true
	for index in range(5):
		var rect: Rect2 = cards[index].get_global_rect()
		same_layout = same_layout and rect.position.is_equal_approx(expected_rects[index].position) and rect.size.is_equal_approx(expected_rects[index].size)
	check(same_layout, "Relic cards use the same dimensions, columns, and spacing as the deck tab")
	check(is_equal_approx(cards[0].position.y, cards[3].position.y) and cards[4].position.y > cards[0].position.y, "Five relics wrap after the fourth card")
	await _capture("relic_grid")
	var first: Control = cards[0]
	await _motion(_center(app.run_navigation.get_tab_button("relics")))
	await _settle()
	var resting_scale: Vector2 = first.scale
	var hover_point := _center(first)
	await _motion(hover_point)
	await _settle()
	check(first.scale.x > resting_scale.x and grid.get_scroll_container().get_global_rect().grow(1).encloses(first.get_global_rect()), "Actual hover enlarges the relic while keeping its complete face visible (rest=%s actual=%s hovered_uid=%s pointer=%s viewport_mouse=%s card_rect=%s canvas=%s)" % [resting_scale, first.scale, grid._hovered_uid, hover_point, root.get_mouse_position(), first.get_global_rect(), first.get_global_transform_with_canvas()])
	await _capture("relic_grid_hover")
	await _click(_center(first))
	check(_snapshot() == before, "Viewing and clicking five relics preserve run, combat, metadata, and save contents")
	var old_grid = grid
	app._select_run_tab("rules")
	check(old_grid._disposed and not old_grid._pressed and not old_grid._dragged, "Changing tabs disposes the relic view and cancels pointer interaction")
	old_grid.emit_signal("card_selected", first.uid)
	await _settle()
	check(not is_instance_valid(old_grid) and not is_instance_valid(app.run_tab_relics) and _snapshot() == before, "Tab cleanup removes old cards and stale callbacks cannot change exploration")

func _synthetic_entries(count: int) -> Array:
	var entries: Array = []
	for index in range(count):
		var id := "relic_ui_fixture_%02d" % index
		app.catalog.relics[id] = {"id": id, "name": "测试藏品 %d" % (index + 1), "effect": "每回合获得 1 格挡。用于检验长列表滚动，不参与探索。", "price": 45}
		entries.append({"id": id, "uid": index + 1, "upgraded": false})
	return entries

func _long_case() -> void:
	await _open_tab("relics")
	var grid = _grid()
	if not is_instance_valid(grid):
		return
	# The synthetic catalog only configures this view; persistent relic IDs stay real.
	var entries := _synthetic_entries(28)
	grid.configure(app.catalog, entries)
	await _motion(_center(app.run_navigation.get_tab_button("relics")))
	await _settle()
	var before: Dictionary = _snapshot()
	var scroll: ScrollContainer = grid.get_scroll_container()
	var cards: Array = grid.get_relic_views()
	check(cards.size() == 28 and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "Long relic grid keeps all entries inside its scroll area")
	var navigation_rect: Rect2 = app.run_navigation.get_global_rect()
	await _wheel(scroll)
	check(scroll.scroll_vertical > 0 and app.run_navigation.get_global_rect() == navigation_rect, "Actual wheel input scrolls relics beneath fixed browser tabs")
	scroll.scroll_vertical = 0
	await _settle()
	var max_scroll := roundi(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	for _step in range(12):
		if scroll.scroll_vertical >= max_scroll:
			break
		await _drag(_point(scroll, Vector2(12, scroll.size.y - 20)), _point(scroll, Vector2(12, 20)))
	await _settle()
	check(scroll.scroll_vertical >= max_scroll and scroll.get_global_rect().grow(1).encloses(cards.back().get_global_rect()), "Actual blank-area drag reaches the complete last row with hidden scrollbars")
	_check_bounds(grid)
	check(_snapshot() == before, "Scrolling a long view preserves actual run, metadata, combat, and save")
	await _open_tab("map")
	check(not is_instance_valid(grid) and not is_instance_valid(app.run_tab_relics) and _snapshot() == before, "Leaving a long relic grid restores the map without persisting synthetic entries")

func _modal_case() -> void:
	await _fixture(RELIC_IDS)
	var node_id := ""
	for id in app.run_state.nodes:
		if app.run_state.nodes[id].type == "battle":
			node_id = str(id)
			break
	check(not node_id.is_empty(), "Battle relic modal fixture has a genuine battle node")
	if node_id.is_empty():
		return
	app.run_state.available = [node_id]
	app._enter_node(node_id)
	await _settle()
	check(app.run_state.phase == "battle" and app.combat != null and app.save_error.is_empty(), "Battle fixture creates and saves real combat")
	var before: Dictionary = _snapshot()
	app._show_relics()
	await _settle()
	var grid = app.modal.find_child("RelicGrid", true, false) if is_instance_valid(app.modal) else null
	check(grid != null, "Battle relic modal contains the same reusable card grid")
	if grid == null:
		return
	_check_bounds(grid)
	_check_faces(grid, RELIC_IDS)
	var close: Button = app.modal.find_child("CloseDeckButton", true, false)
	var scroll: ScrollContainer = grid.get_scroll_container()
	check(close != null and close.is_visible_in_tree() and not scroll.is_ancestor_of(close) and app.get_global_rect().grow(1).encloses(close.get_global_rect()), "Modal return button is visible outside the relic scroll area")
	check(app.modal.find_children("*", "ScrollContainer", true, false).size() == 1, "Only modal relic cards scroll; title and return button stay fixed")
	await _capture("relic_modal")
	var close_rect: Rect2 = close.get_global_rect()
	grid.configure(app.catalog, _synthetic_entries(28))
	await _settle()
	scroll.ensure_control_visible(grid.get_relic_views().back())
	await _settle()
	check(scroll.scroll_vertical > 0 and close.get_global_rect() == close_rect and close.is_visible_in_tree(), "Long modal relic list keeps its return button reachable at the last row")
	await _click(_center(close))
	await _settle()
	check(not is_instance_valid(app.modal) and not is_instance_valid(grid) and _snapshot() == before, "Actual return-button click closes the modal without changing combat or save")

func _drop_app() -> void:
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = null

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for dimensions in RESOLUTIONS:
		dimensions_label = "%dx%d" % [dimensions.x, dimensions.y]
		_clean()
		root.size = dimensions
		await _settle()
		app = _new_app()
		await _settle()
		await _empty_and_single()
		await _populated_layout()
		await _long_case()
		await _modal_case()
		await _drop_app()
	_clean()
	print("V2_RELIC_UI: %d checks, %d failures; real faces, deck layout parity, four sizes, readonly state/save, hover/scroll/modal/lifecycle" % [checks, failures])
	quit(0 if failures == 0 else 1)
