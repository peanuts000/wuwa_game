extends SceneTree

# All UI actions use a separate save and a deliberately absent legacy file.
const SAVE_PATH := "res://tests/artifacts/map_ui_save.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 960)]
var app
var map_scroll
var checks := 0
var failures := 0
var dimensions_label := "1280x720"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("MAP_UI [%s]: %s" % [dimensions_label, message])

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_map_ui_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.12).timeout

func _new_map() -> void:
	app._commit_run()
	await _settle()
	map_scroll = app.find_child("MapScrollView", true, false)
	check(app.run_state.phase == "map" and is_instance_valid(map_scroll), "Real exploration opens MapScrollView")

func _point(control: Control, local: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas() * local

func _center(control: Control) -> Vector2:
	return _point(control, control.size * 0.5)

func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	root.push_input(event, true)
	await process_frame

func _mouse(point: Vector2, pressed: bool, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button_index
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _click(point: Vector2) -> void:
	await _motion(point)
	await _mouse(point, true)
	await _mouse(point, false)

func _raw_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _drag(start: Vector2, finish: Vector2) -> void:
	await _motion(start)
	await _mouse(start, true)
	await _motion(finish, finish - start)
	await _mouse(finish, false)

func _nav_button(prefix: String):
	var nav = app.find_child("MapNavigation", true, false)
	if nav == null:
		return null
	for button in nav.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix) or button.tooltip_text.begins_with(prefix):
			return button
	return null

func _visible_node(available_only: bool = false):
	for button in map_scroll.map_view.find_children("*", "Button", true, false):
		if button.has_meta("node_id") and (not available_only or bool(button.get_meta("available"))) and map_scroll.get_global_rect().has_point(button.get_global_rect().get_center()):
			return button
	return null

func _max_scroll() -> int:
	var bar: ScrollBar = map_scroll.get_h_scroll_bar()
	return maxi(0, roundi(bar.max_value - bar.page))

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var suffix := "" if dimensions_label == "1280x720" else "_" + dimensions_label
	check(root.get_texture().get_image().save_png("res://tests/artifacts/" + name + suffix + ".png") == OK, "Map screenshot saves: " + name)

func _check_layout() -> void:
	var nav: Control = app.find_child("MapNavigation", true, false)
	var life = app.run_status.get_hearts()
	var shells: Label = app.run_status.amount
	check(nav != null and life != null and shells != null, "Fixed navigation exposes heart lives and currency")
	if nav == null or life == null or shells == null:
		return
	check(app.size.is_equal_approx(Vector2(1280, 720)), "Map logical canvas stays 1280 by 720")
	check(nav.get_global_rect().position.is_equal_approx(app.get_global_rect().position) and is_equal_approx(nav.size.y, 80), "MapNavigation occupies the fixed top 80 pixels")
	check(is_equal_approx(map_scroll.position.y, 138) and is_equal_approx(map_scroll.size.y, 420) and is_equal_approx(map_scroll.position.x, 62), "Map viewport fits inside the illustrated book above its legend")
	check(life.get_lives() == app.run_state.lives and life.get_visible_heart_count() == app.run_state.lives and shells.text == str(app.run_state.shells), "Fixed hearts and currency show current model values")
	check(life.get_global_rect().position.x < 400 and shells.get_global_rect().position.x < 500 and nav.get_global_rect().encloses(life.get_global_rect()) and nav.get_global_rect().encloses(shells.get_global_rect()), "Life and currency stay at upper left inside navigation")
	for title in ["地图", "牌组", "藏品", "主界面"]:
		var button = _nav_button(title)
		check(button != null and nav.get_global_rect().grow(1).encloses(button.get_global_rect()), "Fixed navigation contains " + title)
	var last_tab_x := -INF
	for id in ["map", "deck", "relics"]:
		var tab: Button = app.run_navigation.get_tab_button(id)
		check(tab != null, "Map navigation exposes the " + id + " tab")
		if tab == null:
			continue
		var rect := tab.get_global_rect()
		check(rect.position.x > last_tab_x and absf(rect.end.y - nav.get_global_rect().end.y) <= 2.0, "Browser tabs follow their order and meet the content edge: " + id)
		last_tab_x = rect.position.x
	_check_selected_tab("map")
	var removed_copy := true
	for label in app.find_children("*", "Label", true, false):
		removed_copy = removed_copy and not label.text.contains("晶域行旅") and not label.text.contains("第一章") and not label.text.contains("金色节点可以进入") and not label.text.contains("选择下一站")
	check(removed_copy, "Map removes the old title, chapter, and instruction text")
	check(map_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER and map_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Map scrollbars use hidden modes")
	check(not map_scroll.get_v_scroll_bar().is_visible_in_tree() and not map_scroll.get_h_scroll_bar().is_visible_in_tree(), "Both map scrollbars are actually hidden")
	check(_max_scroll() > 0 and map_scroll.clip_contents, "Long map is scrollable and clips below the fixed bar")
	var all_nodes_tagged := true
	for button in map_scroll.map_view.find_children("*", "Button", true, false):
		all_nodes_tagged = all_nodes_tagged and button.has_meta("node_id") and button.has_meta("available")
	check(all_nodes_tagged, "Map nodes expose stable identities and availability")

func _check_start() -> void:
	var origin: Button = map_scroll.map_view.get_node("Node_start")
	var initial: Dictionary = app.run_state.to_snapshot()
	check(app.run_state.current == "start" and origin.current and origin.kind == "start", "Initial player marker is on the origin")
	check(origin.text == "起点" and origin.disabled and not origin.get_meta("available"), "Origin is labeled and cannot be entered again")
	check(map_scroll.get_global_rect().encloses(origin.get_global_rect()) and map_scroll.scroll_horizontal == 0, "Initial viewport shows the complete origin")
	for id in app.run_state.available:
		var encounter: Button = map_scroll.map_view.get_node("Node_" + id)
		check(not encounter.disabled and not encounter.current and encounter.position.x > origin.position.x, "Initial route choices appear to the right of the player")
	await _click(_center(origin))
	check(app.run_state.to_snapshot() == initial and app.combat == null, "Clicking the origin does not start an encounter or grant rewards")
	await _drag(_center(origin), _center(origin) - Vector2(32, 0))
	check(map_scroll.scroll_horizontal >= 24 and app.run_state.to_snapshot() == initial, "Dragging the origin scrolls without activating it")
	map_scroll.scroll_horizontal = 0
	await _settle()

func _check_selected_tab(id: String) -> void:
	var selected := 0
	var navigation = app.run_navigation
	for tab_id in ["map", "deck", "relics"]:
		var button: Button = navigation.get_tab_button(tab_id)
		if button != null and button.button_pressed:
			selected += 1
	check(app.run_tab == id and selected == 1 and navigation.get_tab_button(id).button_pressed, "Exactly the current browser tab is selected: " + id)

func _tab_switching() -> void:
	var before: Dictionary = app.run_state.to_snapshot()
	var persistent_map = map_scroll
	var navigation = app.run_navigation
	var fixed_rect: Rect2 = navigation.get_global_rect()
	var saved_scroll: int = map_scroll.scroll_horizontal
	var first_node: Button = map_scroll.map_view.get_child(0)
	await _click(_center(navigation.get_tab_button("deck")))
	await _settle()
	_check_selected_tab("deck")
	var deck = app.run_tab_content.find_child("DeckView", true, false) if is_instance_valid(app.run_tab_content) else null
	check(deck != null and not is_instance_valid(app.modal), "Deck tab replaces the main content with card faces")
	check(not map_scroll.is_visible_in_tree() and map_scroll._locked and not map_scroll._pressed, "Deck tab hides and locks the persistent map")
	if deck != null:
		check(deck.get_card_views().size() == app.run_state.deck.size(), "Deck tab shows every real card")
		check(app.get_global_rect().grow(1).encloses(deck.get_global_rect()) and deck.get_global_rect().position.y >= navigation.get_global_rect().end.y - 1, "Deck cards fit below the fixed browser tabs")
		var details_free := true
		for card in deck.get_card_views():
			details_free = details_free and card.tooltip_text.is_empty()
		check(details_free, "Deck tab cards have no redundant detailed tooltip")
		var old_content = app.run_tab_content
		await _click(_center(navigation.get_tab_button("deck")))
		check(app.run_tab_content == old_content, "Clicking the active tab preserves its content")
	await _capture("map_tab_deck")
	first_node.pressed.emit()
	map_scroll.node_selected.emit(app.run_state.available[0])
	var blank: Vector2 = _point(map_scroll, Vector2(320, 24))
	await _drag(blank, _point(map_scroll, Vector2(120, 24)))
	await _mouse(blank, true, MOUSE_BUTTON_WHEEL_DOWN)
	await _mouse(blank, false, MOUSE_BUTTON_WHEEL_DOWN)
	check(map_scroll.scroll_horizontal == saved_scroll and app.run_state.to_snapshot() == before and app.combat == null, "Inactive map ignores node activation, drag, and wheel input")
	for id in ["relics"]:
		await _click(_center(navigation.get_tab_button(id)))
		await _settle()
		_check_selected_tab(id)
		check(is_instance_valid(app.run_tab_content) and app.run_tab_content.is_visible_in_tree() and not is_instance_valid(app.modal), "Tab content opens directly beneath navigation: " + id)
		check(navigation.get_global_rect() == fixed_rect and app.run_state.to_snapshot() == before, "Tab switching keeps navigation, exploration, and RNG unchanged: " + id)
		await _capture("map_tab_" + id)
	await _click(_center(navigation.get_tab_button("map")))
	await _settle()
	_check_selected_tab("map")
	check(map_scroll == persistent_map and map_scroll.is_visible_in_tree() and not map_scroll._locked and not is_instance_valid(app.run_tab_content), "Map tab restores the same interactive map")
	check(map_scroll.scroll_horizontal == saved_scroll and app.run_state.to_snapshot() == before, "Returning to the map preserves its scroll offset and exploration")

func _basic_drag() -> void:
	var before: Dictionary = app.run_state.to_snapshot()
	var nav: Control = app.find_child("MapNavigation", true, false)
	var fixed_rect: Rect2 = nav.get_global_rect()
	var life_rect: Rect2 = app.run_status.get_hearts().get_global_rect()
	var shells_rect: Rect2 = app.run_status.amount.get_global_rect()
	var first: Button = _visible_node(true)
	check(first != null, "Initial map exposes an available node")
	if first == null:
		return
	var first_x: float = first.get_global_rect().position.x
	var start: Vector2 = _point(map_scroll, Vector2(400, 24))
	var finish: Vector2 = _point(map_scroll, Vector2(180, 24))
	await _drag(start, finish)
	check(map_scroll.scroll_horizontal > 150, "Left dragging empty map space moves the horizontal view")
	check(first.get_global_rect().position.x < first_x - 150, "Dragging moves the actual nodes with the map")
	check(nav.get_global_rect() == fixed_rect and app.run_status.get_hearts().get_global_rect() == life_rect and app.run_status.amount.get_global_rect() == shells_rect, "Navigation, hearts, and currency remain fixed while nodes scroll")
	check(app.run_state.to_snapshot() == before and app.combat == null, "Blank-space dragging never enters or mutates a node")
	check(not map_scroll._pressed and not map_scroll._dragged, "Releasing a blank-space drag clears its input state")
	await _capture("map_dragged")
	map_scroll.scroll_horizontal = 0
	await _settle()
	first = _visible_node(true)
	var point: Vector2 = _center(first)
	var delta: Vector2 = _point(map_scroll, Vector2(-32, 0)) - _point(map_scroll, Vector2.ZERO)
	await _drag(point, point + delta)
	check(map_scroll.scroll_horizontal >= 24 and app.run_state.to_snapshot() == before, "Dragging an available node scrolls without entering it")
	check(not map_scroll._pressed and not map_scroll._dragged, "Node drag release clears interaction state")

func _edge_and_navigation_cases() -> void:
	var before: Dictionary = app.run_state.to_snapshot()
	var blank: Vector2 = _point(map_scroll, Vector2(320, 24))
	map_scroll.scroll_horizontal = 0
	await _settle()
	await _drag(blank, _point(map_scroll, Vector2(-1600, 24)))
	check(map_scroll.scroll_horizontal == _max_scroll(), "Drag beyond the left of the window clamps to the map's right boundary")
	check(not map_scroll._pressed and not map_scroll._dragged and app.run_state.to_snapshot() == before, "Off-canvas release ends drag without entering a node")
	await _drag(blank, _point(map_scroll, Vector2(2400, 24)))
	check(map_scroll.scroll_horizontal == 0, "Reverse drag clamps to the map's left boundary")
	map_scroll.scroll_horizontal = 100
	await process_frame
	var offset: int = map_scroll.scroll_horizontal
	await _motion(blank)
	await _mouse(blank, true)
	await _motion(_point(map_scroll, Vector2(200, 24)), Vector2(-120, 0))
	check(map_scroll._dragged, "A real move crosses the drag threshold before cancellation")
	map_scroll.cancel_interaction()
	var cancelled_offset: int = map_scroll.scroll_horizontal
	await _mouse(blank, false)
	check(not map_scroll._pressed and not map_scroll._dragged and map_scroll.scroll_horizontal == cancelled_offset and app.run_state.to_snapshot() == before, "Cancelling a drag makes its later release harmless")
	check(cancelled_offset > offset, "Cancellation fixture really scrolled the map")
	await _mouse(blank, true)
	await _motion(_point(map_scroll, Vector2(250, 24)), Vector2(-70, 0))
	var focus_offset: int = map_scroll.scroll_horizontal
	root.focus_exited.emit()
	check(not map_scroll._pressed and not map_scroll._dragged, "Losing window focus cancels an active map drag")
	await _mouse(blank, false)
	check(map_scroll.scroll_horizontal == focus_offset and app.run_state.to_snapshot() == before, "Late release after focus loss neither scrolls nor enters a node")
	var deck = _nav_button("牌组")
	check(deck != null, "Deck navigation exists for drag isolation")
	if deck != null:
		var nav_point: Vector2 = _center(deck)
		var nav_before: int = map_scroll.scroll_horizontal
		await _drag(nav_point, blank)
		check(map_scroll.scroll_horizontal == nav_before and not is_instance_valid(app.modal) and app.run_state.phase == "map", "Starting a drag on navigation does not drag or activate the map")
		await _click(nav_point)
		check(app.run_tab == "deck" and not is_instance_valid(app.modal), "Ordinary deck navigation click selects its content tab")
		await _click(_center(_nav_button("地图")))
		await _settle()
		check(map_scroll.scroll_horizontal == nav_before and app.run_state.to_snapshot() == before, "Navigation drag isolation preserves the map offset when switching back")
	map_scroll.scroll_horizontal = 0
	await process_frame
	await _mouse(blank, true, MOUSE_BUTTON_WHEEL_DOWN)
	await _mouse(blank, false, MOUSE_BUTTON_WHEEL_DOWN)
	check(map_scroll.scroll_horizontal > 0, "Mouse wheel remains usable with hidden scrollbars")
	var wheeled: int = map_scroll.scroll_horizontal
	await _mouse(blank, true, MOUSE_BUTTON_WHEEL_UP)
	await _mouse(blank, false, MOUSE_BUTTON_WHEEL_UP)
	check(map_scroll.scroll_horizontal < wheeled, "Wheel up reverses map scrolling")
	check(app.run_state.to_snapshot() == before, "Navigation, boundaries, and wheel preserve exploration state")

func _menu_and_node_click() -> void:
	var before: Dictionary = app.run_state.to_snapshot()
	var old_scroll = map_scroll
	var old_navigation = app.run_navigation
	var menu = _nav_button("主界面")
	check(menu != null, "Map navigation has the menu action")
	if menu != null:
		await _motion(_center(menu))
		_raw_click(_center(menu))
		old_navigation.tab_selected.emit("deck")
		old_navigation.menu_requested.emit()
		check(app.screen == "menu" and not is_instance_valid(app.run_tab_content) and app.run_state.to_snapshot() == before, "Stale navigation callbacks cannot open tab content after returning to the menu")
		await _settle()
	check(app.screen == "menu" and not is_instance_valid(old_scroll), "Menu navigation disposes map interactions")
	var saved: Dictionary = app.store.restore_active()
	check(saved.get("run") != null and saved.run.to_snapshot() == before, "Map menu action checkpoints the exact exploration")
	app._continue_run()
	await _settle()
	map_scroll = app.find_child("MapScrollView", true, false)
	check(app.run_state.to_snapshot() == before and is_instance_valid(map_scroll), "Continue restores the same map progress")
	map_scroll.scroll_horizontal = 0
	await _settle()
	var node: Button = _visible_node(true)
	check(node != null, "Resumed map has a clickable available node")
	if node == null:
		return
	var id: String = node.get_meta("node_id")
	await _click(_center(node))
	check(app.run_state.current == id and app.run_state.phase == app.run_state.nodes[id].type and app.combat != null, "An ordinary available-node click still enters its battle")
	await _battle_map_popup()
	await _new_map()
	node = _visible_node(true)
	id = node.get_meta("node_id")
	var point: Vector2 = _center(node)
	var release_delta: Vector2 = _point(map_scroll, Vector2(0, 12)) - _point(map_scroll, Vector2.ZERO)
	var before_release: Dictionary = app.run_state.to_snapshot()
	await _mouse(point, true)
	await _mouse(point + release_delta, false)
	check(app.run_state.to_snapshot() == before_release and app.combat == null, "Release displaced past the threshold without a motion event does not activate a node")
	var tiny_delta: Vector2 = _point(map_scroll, Vector2(3, 2)) - _point(map_scroll, Vector2.ZERO)
	await _drag(point, point + tiny_delta)
	check(app.run_state.current == id and app.combat != null, "Small pointer jitter below eight pixels still counts as a node click")

func _battle_map_popup() -> void:
	var run_before: Dictionary = app.run_state.to_snapshot()
	var combat_before: Dictionary = app.combat.to_snapshot()
	app._show_map()
	await _settle()
	var popup = app.modal.find_child("RouteMapScrollView", true, false) if is_instance_valid(app.modal) else null
	check(popup != null, "Battle route modal reuses the draggable map component")
	if popup == null:
		return
	check(not popup.get_v_scroll_bar().is_visible_in_tree() and not popup.get_h_scroll_bar().is_visible_in_tree(), "Battle route popup hides both scrollbars")
	var disabled_nodes := true
	for button in popup.map_view.find_children("*", "Button", true, false):
		disabled_nodes = disabled_nodes and button.disabled and not bool(button.get_meta("available"))
	check(disabled_nodes, "Battle route popup keeps every node unavailable")
	var start: Vector2 = _point(popup, Vector2(340, 24))
	var finish: Vector2 = _point(popup, Vector2(140, 24))
	await _drag(start, finish)
	check(popup.scroll_horizontal > 150 and app.run_state.to_snapshot() == run_before and app.combat.to_snapshot() == combat_before, "Battle route popup drag scrolls without changing exploration or combat")
	await _capture("map_popup_dragged")
	await _mouse(start, true)
	await _motion(finish, finish - start)
	check(popup._dragged, "Popup close fixture has an active pointer drag")
	app._close_modal()
	check(popup._disposed and not popup._pressed and not popup._dragged, "Closing the popup disposes and cancels its active drag")
	await _mouse(finish, false)
	check(not is_instance_valid(popup) and not is_instance_valid(app.modal) and app.combat.to_snapshot() == combat_before, "Late popup release cannot operate the underlying battle")

func _progress_and_focus() -> void:
	await _new_map()
	var route: Array = []
	var id: String = app.run_state.available[0]
	for _stage in range(4):
		route.append(id)
		if route.size() < 4:
			id = app.run_state.nodes[id].next[0]
	app.run_state.visited = route
	app.run_state.current = id
	app.run_state.available = app.run_state.nodes[id].next.duplicate()
	app.run_state.shells = 35
	var snapshot: Dictionary = app.run_state.to_snapshot()
	app._render()
	await _settle()
	map_scroll = app.map_scroll_view
	var current := map_scroll.map_view.get_node("Node_" + id) as Button
	check(map_scroll.scroll_horizontal > 0 and map_scroll.get_global_rect().encloses(current.get_global_rect()), "Opening a progressed map focuses the current stage")
	check(app.run_state.to_snapshot() == snapshot, "Horizontal projection and current-node focusing preserve model and RNG")
	var previous_x := -INF
	for stage_id in route:
		var position: Vector2 = map_scroll.map_view.point(app.run_state.nodes[stage_id])
		check(position.x > previous_x, "Successive completed stages progress to the right")
		previous_x = position.x
	await _capture("map_progress")
	var reward_id: String = app.run_state.available[0]
	var reward := map_scroll.map_view.get_node("Node_" + reward_id) as Button
	check(app.run_state.nodes[reward_id].type == "reward", "Stage five keeps its guaranteed reward node")
	map_scroll.scroll_horizontal = 0
	await _settle()
	reward.grab_focus()
	await _settle()
	check(map_scroll.get_global_rect().encloses(reward.get_global_rect()), "Keyboard focus reveals its node horizontally")
	await _motion(_center(reward))
	await create_timer(0.8).timeout
	await _capture("map_reward_hover")
	await _click(_center(reward))
	check(app.run_state.current == reward_id and app.run_state.phase == "rewards" and app.run_state.shells == 50, "A real reward-node click grants 15 shells and opens the reward flow")
	await _capture("map_reward_opened")

func _drop_app() -> void:
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = null
	map_scroll = null

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
		await _new_map()
		_check_layout()
		await _check_start()
		await _capture("map_idle")
		await _basic_drag()
		await _tab_switching()
		if dimensions == Vector2i(1280, 720):
			await _edge_and_navigation_cases()
			await _menu_and_node_click()
			await _progress_and_focus()
		await _drop_app()
	_clean()
	print("V2_MAP_UI: %d checks, %d failures; fixed navigation, hidden bars, real drag/click/wheel, modal and save recovery" % [checks, failures])
	quit(0 if failures == 0 else 1)
