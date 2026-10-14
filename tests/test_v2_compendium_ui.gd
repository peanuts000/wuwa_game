extends SceneTree

# Use -- --capture with a graphics driver for reviewable 1280x720 screenshots.
const CardView = preload("res://scripts/v2/card_view.gd")
const SAVE_PATH := "res://tests/artifacts/compendium_ui_save.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 960)]
var app
var checks := 0
var failures := 0
var dimensions_label := "1280x720"
var menu_compendium_rect := Rect2()
var menu_compendium_font_size := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("COMPENDIUM_UI [%s]: %s" % [dimensions_label, message])

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.22).timeout

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_compendium_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _button(title: String):
	for button in app.find_children("*", "Button", true, false):
		if button.text == title and button.is_visible_in_tree():
			return button
	return null

func _category(category_id: String):
	for button in app.compendium_view.get_category_buttons():
		if str(button.get_meta("category_id", "")) == category_id:
			return button
	return null

func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _click(control: Control) -> void:
	check(is_instance_valid(control), "Pointer target exists")
	if not is_instance_valid(control):
		return
	var point := _center(control)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame

func _capture(screen_name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or dimensions_label != "1280x720":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tests/artifacts/v2_" + screen_name + ".png") == OK, "Screenshot saves: " + screen_name)

func _snapshot() -> Dictionary:
	return {
		"run": app.run_state.to_snapshot() if app.run_state != null else null,
		"combat": app.combat.to_snapshot() if app.combat != null else null,
		"metadata": app.metadata.duplicate(true),
		"chosen": app.chosen.duplicate(),
		"role_index": app.role_index,
		"role_page": app.role_page,
		"catalog": app.catalog.data.duplicate(true),
		"store": app.store.data.duplicate(true),
		"save_bytes": FileAccess.get_file_as_bytes(SAVE_PATH)
	}

func _menu_layout() -> void:
	var bounds: Rect2 = app.get_global_rect()
	check(app.screen == "menu", "Application starts on the main menu")
	check(app.find_children("*", "Button", true, false).size() == 5, "Menu offers three main actions and two corner controls")
	var previous := Rect2()
	for title in ["开始探索", "继续游戏", "查看历史探索记录"]:
		var button = _button(title)
		check(button != null, "Menu action exists: " + title)
		if button == null:
			continue
		var rect: Rect2 = button.get_global_rect()
		check(bounds.grow(1).encloses(rect) and absf(rect.get_center().x - bounds.get_center().x) < 2, "Main action stays centered inside the canvas: " + title)
		if previous.size != Vector2.ZERO:
			check(rect.position.y > previous.end.y and is_equal_approx(rect.size.x, previous.size.x), "Main actions stack vertically at equal width")
		previous = rect
	var settings = _button("设置")
	var compendium = _button("图鉴")
	check(settings != null and settings.get_global_rect().get_center().x > bounds.end.x - bounds.size.x * 0.15 and settings.get_global_rect().get_center().y < bounds.position.y + bounds.size.y * 0.15, "Settings is in the upper-right corner")
	check(compendium != null and compendium.get_global_rect().get_center().x > bounds.end.x - bounds.size.x * 0.15 and compendium.get_global_rect().get_center().y > bounds.end.y - bounds.size.y * 0.15, "Compendium is in the lower-right corner")
	if compendium != null:
		menu_compendium_rect = compendium.get_global_rect()
		menu_compendium_font_size = compendium.get_theme_font_size("font_size")
		check(compendium.size.is_equal_approx(Vector2(124, 60)) and menu_compendium_font_size == 18, "Menu compendium button uses the shared size and font")
		check(is_equal_approx(bounds.end.x - menu_compendium_rect.end.x, 24) and is_equal_approx(bounds.end.y - menu_compendium_rect.end.y, 24), "Menu compendium button keeps the shared right and bottom margins")
	check(_button("退出游戏") == null and _button("继续游戏").disabled, "Quit is absent and continue is disabled before an exploration exists")

func _matches_snapshot(before: Dictionary) -> bool:
	var after := _snapshot()
	for key in before:
		if before[key] != after[key]:
			print("Snapshot changed: ", key)
			if before[key] is Dictionary and after[key] is Dictionary:
				for field in before[key]:
					if before[key][field] != after[key].get(field):
						print("  ", field, ": ", before[key][field], " -> ", after[key].get(field))
	return after == before

func _main_menu_actions() -> void:
	await _click(_button("继续游戏"))
	check(app.screen == "menu" and app.run_state == null, "Disabled continue ignores a real pointer click")
	await _motion(_center(_button("开始探索")))
	await _settle()
	await _capture("menu_hover")
	await _click(_button("开始探索"))
	check(app.screen == "characters", "The paper start button opens character selection")
	await _click(_button("返回"))
	check(app.screen == "menu", "Character selection returns to the themed menu")
	await _click(_button("查看历史探索记录"))
	check(app.screen == "history", "The paper history button opens exploration history")
	await _click(_button("返回主界面"))
	check(app.screen == "menu", "History returns to the themed menu")
	_button("开始探索").grab_focus()
	await _settle()
	await _capture("menu_keyboard_focus")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()
	check(app.screen == "characters", "Keyboard Enter activates the focused paper button")
	await _click(_button("返回"))
	await _motion(Vector2(4, 4))

func _settings_navigation() -> void:
	var menu_settings = _button("设置")
	var menu_settings_rect := Rect2()
	var menu_settings_font_size := 0
	if menu_settings != null:
		menu_settings_rect = menu_settings.get_global_rect()
		menu_settings_font_size = menu_settings.get_theme_font_size("font_size")
		var bounds: Rect2 = app.get_global_rect()
		check(menu_settings.size.is_equal_approx(Vector2(124, 60)) and menu_settings_font_size == 18 and is_equal_approx(bounds.end.x - menu_settings_rect.end.x, 24) and is_equal_approx(menu_settings_rect.position.y - bounds.position.y, 24), "Menu settings button keeps its fixed upper-right geometry")
	await _click(menu_settings)
	check(app.screen == "settings", "The settings corner button opens settings")
	var close = _button("设置")
	check(close != null and close.name == "CloseSettingsButton", "Settings provides its corner toggle as the return action")
	if close != null:
		check(close.get_global_rect().is_equal_approx(menu_settings_rect) and close.get_theme_font_size("font_size") == menu_settings_font_size and close.pressed.get_connections().size() == 1, "Settings return toggle matches the menu size, position, and font")
		var panel = app.find_child("SettingsPanel", true, false)
		check(panel != null and not panel.get_global_rect().intersects(close.get_global_rect()) and panel.get_global_rect().position.y >= close.get_global_rect().end.y, "Settings content begins below the corner toggle")
	var has_settings_title := false
	for label in app.find_children("*", "Label", true, false):
		if label.text == "设置":
			has_settings_title = true
	check(not has_settings_title and _button("返回主界面") == null, "Settings omits the old title and in-panel return button")
	var quit_button = _button("退出游戏")
	check(quit_button != null and not quit_button.disabled and quit_button.pressed.get_connections().size() == 1, "Settings exposes an enabled quit action")
	if quit_button != null:
		check(app.get_global_rect().grow(1).encloses(quit_button.get_global_rect()), "Settings quit stays inside the canvas")
		if close != null:
			check(not quit_button.get_global_rect().intersects(close.get_global_rect()), "Settings quit remains separate from the corner return action")
	app._save_display(app.store.data.settings.duplicate(true))
	await _settle()
	close = _button("设置")
	check(app.screen == "settings" and close != null and close.name == "CloseSettingsButton" and close.get_global_rect().is_equal_approx(menu_settings_rect) and close.get_theme_font_size("font_size") == menu_settings_font_size, "Saving display settings preserves the corner return toggle layout")
	await _capture("settings")
	await _click(close)
	check(app.screen == "menu" and _button("退出游戏") == null, "Clicking settings again returns to the main menu")

func _open_hub() -> void:
	await _click(_button("图鉴"))
	check(app.screen == "compendium" and is_instance_valid(app.compendium_hub) and not is_instance_valid(app.compendium_view), "The menu opens the category selector before any card catalog")

func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle()

func _hub_layout() -> void:
	var bounds: Rect2 = app.get_global_rect()
	var buttons: Array = app.compendium_hub.get_category_buttons()
	check(buttons.size() == 3, "The selector offers exactly three catalogs")
	var previous := Rect2()
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		var rect := button.get_global_rect()
		check(button.text == ["卡牌", "补给品", "藏品"][index] and not button.disabled, "The catalogs follow the requested left-to-right order")
		check(bounds.encloses(rect) and rect.size.y > rect.size.x, "Each tall category panel fits within the canvas")
		check(button.find_child("CategoryPreview", true, false) != null and button.find_child("CategoryDescription", true, false) != null, "Each category includes an illustration and explanation")
		if index > 0:
			check(rect.position.x > previous.end.x and rect.size.is_equal_approx(previous.size) and is_equal_approx(rect.position.y, previous.position.y), "All panels share one evenly sized horizontal row")
		previous = rect
	var close = _button("图鉴")
	check(close != null and close.get_global_rect().is_equal_approx(menu_compendium_rect), "Selector return action matches the main menu corner")
	for button in buttons:
		check(not button.get_global_rect().intersects(close.get_global_rect()), "Panels leave room for return navigation")

func _browse_item_catalogs() -> void:
	await _open_hub()
	_hub_layout()
	await _capture("compendium_hub")
	var before := _snapshot()
	for group in ["supplies", "relics"]:
		if group == "supplies":
			await _click(_button("补给品"))
		else:
			_button("藏品").grab_focus()
			await _key(KEY_ENTER)
		check(app.screen == "compendium_" + group and is_instance_valid(app.compendium_items), "Category opens its own catalog: " + group)
		var view = app.compendium_items
		var faces: Array = view.get_item_views()
		var expected: Array = app.catalog.data[group]
		var ids: Array = []
		check(faces.size() == expected.size(), "Item catalog shows every configured item: " + group)
		for face in faces:
			ids.append(str(face.card.id))
			var entry: Dictionary = app.catalog.get(group)[face.card.id]
			check(face.full_text == entry.name + "\n\n" + entry.effect, "Item face uses the actual catalog name and effect")
			check(face.item_kind == ("supply" if group == "supplies" else "relic") and face.get_meta("readonly") and not face.get_meta("selectable"), "Item previews use the matching icon kind and readonly interaction")
			await _click(face)
			face.activation_requested.emit(face.uid)
			check(_matches_snapshot(before), "Item clicks cannot consume or grant items or change saves")
		for entry in expected:
			check(ids.count(str(entry.id)) == 1, "Item catalog includes each item exactly once")
		var bounds: Rect2 = app.get_global_rect()
		check(bounds.grow(1).encloses(view.get_grid().get_global_rect()) and not view.get_grid().get_global_rect().intersects(_button("图鉴").get_global_rect()), "Item scroll area fits and excludes return navigation")
		await _capture("compendium_" + group)
		if group == "supplies":
			await _click(_button("图鉴"))
		else:
			await _key(KEY_ESCAPE)
		check(app.screen == "compendium" and not is_instance_valid(app.compendium_items), "Item catalog returns to the selector and frees its interactions")
	await _click(_button("图鉴"))
	await _settle() # Allow the selector's 0.38-second closing animation to finish.
	check(app.screen == "menu" and _snapshot() == before, "Selector returns to the menu without changing game state")

func _open_compendium() -> void:
	await _open_hub()
	await _click(_button("卡牌"))
	check(app.screen == "compendium_cards" and is_instance_valid(app.compendium_view), "Card category opens the existing card catalog")

func _compendium_layout() -> void:
	var view = app.compendium_view
	var bounds: Rect2 = app.get_global_rect()
	var sidebar = view.find_child("CompendiumSidebar", true, false)
	var close = view.find_child("CloseCompendiumButton", true, false)
	var deck = view.get_deck_view()
	check(bounds.grow(1).encloses(view.get_global_rect()), "Compendium stays inside the logical canvas at this window size")
	check(sidebar != null and sidebar.get_global_rect().position.x < bounds.position.x + bounds.size.x * 0.08 and sidebar.get_global_rect().end.x < bounds.position.x + bounds.size.x * 0.30, "Categories occupy a fixed left sidebar")
	check(close != null and close.text == "图鉴" and close.get_global_rect().get_center().x > bounds.end.x - bounds.size.x * 0.15 and close.get_global_rect().get_center().y > bounds.end.y - bounds.size.y * 0.15, "The returning compendium button stays in the lower-right corner")
	if close != null:
		check(close.get_global_rect().is_equal_approx(menu_compendium_rect) and close.get_theme_font_size("font_size") == menu_compendium_font_size, "Compendium return button exactly matches the main menu size, position, and font")
	check(view.find_child("CompendiumTitle", true, false) == null and view.find_child("CompendiumSummary", true, false) == null, "Compendium omits the category title and card count controls")
	check(deck != null and sidebar != null and deck.get_global_rect().position.x >= sidebar.get_global_rect().end.x, "Card area is to the right of the category sidebar")
	if close != null and deck != null:
		check(not deck.is_ancestor_of(close) and not close.get_global_rect().intersects(deck.get_scroll_container().get_global_rect()), "Return navigation remains outside the scrolling cards")
	var buttons: Array = view.get_category_buttons()
	check(buttons.size() == app.ROLES.size() + 1, "Every role and common cards have a category")
	var ids: Array[String] = []
	for button in buttons:
		ids.append(str(button.get_meta("category_id", "")))
		check(not button.disabled, "Compendium category remains browseable: " + str(button.get_meta("category_id", "")))
	for role in app.ROLES:
		check(role.id in ids, "Role category exists: " + role.name)
		var button = _category(role.id)
		if button == null:
			continue
		check(button.text.is_empty() and button.tooltip_text == role.name, "Role category replaces its name with a portrait and keeps its name in the tooltip: " + role.name)
		check(button.size.is_equal_approx(Vector2(128, 128)) and button.custom_minimum_size.is_equal_approx(Vector2(128, 128)) and button.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "Role portrait button keeps a fixed centered 128px square: " + role.name)
		var portrait = button.find_child("RolePortrait", true, false)
		check(portrait is TextureRect and portrait.is_visible_in_tree() and portrait.texture != null and portrait.texture.resource_path == "res://assets/pieces/%s_base.png" % role.texture, "Role portrait displays its matching existing dumpling placeholder: " + role.name)
	check("common" in ids, "Common card category exists")
	var common = _category("common")
	check(common != null and common.text == "通用牌" and common.find_child("RolePortrait", true, false) == null, "Common cards retain their text category button")

func _faces(expected_pool: String, expected_count: int) -> void:
	var view = app.compendium_view
	var cards: Array = view.get_visible_cards()
	var actual_ids: Array[String] = []
	var expected_ids: Array[String] = []
	for entry in app.catalog.data.cards:
		if entry.pool == expected_pool:
			expected_ids.append(str(entry.id))
	for card in cards:
		actual_ids.append(str(card.id))
	actual_ids.sort()
	expected_ids.sort()
	check(cards.size() == expected_count and actual_ids == expected_ids, "Category shows its full catalog without duplicates or cards from another pool")
	var faces: Array = view.get_deck_view().get_card_views()
	check(faces.size() == cards.size(), "Every filtered card has a rendered face")
	for face in faces:
		check(face.paper_style, "Compendium shares battle card artwork")
		check(face.get_script() == CardView and face.full_text == app.catalog.card_text(face.card) and not face.card.get("upgraded", false), "Compendium displays the actual base card effect and cost: " + str(face.card.id))

func _browse_categories() -> void:
	check(app.compendium_view.selected_category == app.catalog.data.role.id, "Compendium opens with the implemented role selected")
	_faces("character", 6)
	await _capture("compendium")
	await _click(_category("common"))
	check(app.compendium_view.selected_category == "common", "Clicking common cards changes the category")
	_faces("common", 12)
	await _capture("compendium_common")
	var view = app.compendium_view
	var deck = view.get_deck_view()
	var scroll: ScrollContainer = deck.get_scroll_container()
	var close_rect: Rect2 = _button("图鉴").get_global_rect()
	var cards: Array = deck.get_card_views()
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "The full common catalog has an internal scroll range")
	if not cards.is_empty():
		scroll.ensure_control_visible(cards.back())
		await _settle()
		check(scroll.scroll_vertical > 0 and scroll.get_global_rect().grow(1).encloses(cards.back().get_global_rect()), "Scrolling reaches the final common card")
		check(_button("图鉴").get_global_rect() == close_rect, "Browsing lower card rows keeps return navigation fixed")
	for role in app.ROLES:
		if role.id == app.catalog.data.role.id:
			continue
		var category = _category(role.id)
		var character_scroll = view.find_child("CharacterScroll", true, false)
		if character_scroll != null:
			character_scroll.ensure_control_visible(category)
			await _settle()
			check(character_scroll.get_global_rect().grow(1).encloses(category.get_global_rect()), "Scrolling reveals the whole square role portrait: " + role.name)
		await _click(category)
		check(view.selected_category == role.id and view.get_visible_cards().is_empty() and view.get_deck_view().get_card_views().is_empty(), "An unimplemented role opens its own empty card collection: " + role.name)
		var empty_message := false
		for label in view.find_children("*", "Label", true, false):
			if label.is_visible_in_tree() and (label.text.contains("暂无") or label.text.contains("没有") or label.text.contains("未收录") or label.text.contains("待") or label.text.contains("空")):
				empty_message = true
		check(empty_message, "Empty role category explains that it has no cards: " + role.name)
		if role.id == app.ROLES[1].id:
			await _capture("compendium_empty")
	await _click(_button("图鉴"))
	check(app.screen == "compendium" and not is_instance_valid(app.compendium_view), "Card catalog returns to the category selector")
	await _click(_button("图鉴"))
	await _settle() # The hub navigates only after its wooden boards retract.
	check(app.screen == "menu" and not is_instance_valid(app.compendium_hub), "Selector returns to the main menu")

func _readonly_and_lifecycle() -> void:
	app._commit_run()
	app._enter_node(app.run_state.available[0])
	app._return_menu()
	await _settle()
	check(app.store.has_active() and not _button("继续游戏").disabled, "Paused exploration enables continue on the new menu")
	var before := _snapshot()
	await _browse_item_catalogs()
	check(_snapshot() == before, "Supply and relic browsing preserve a paused exploration")
	for category in ["supplies", "relics", ""]:
		await _open_hub()
		var old_page = app.compendium_hub
		if not category.is_empty():
			await _click(_button("补给品" if category == "supplies" else "藏品"))
			old_page = app.compendium_items
		app._navigate("settings")
		old_page.close_requested.emit()
		if category.is_empty():
			old_page.category_requested.emit("cards")
		check(app.screen == "settings", "Disposed catalog callbacks cannot reopen pages")
		await _settle()
		check(not is_instance_valid(old_page), "Old selector and item catalogs are freed")
		await _click(_button("设置"))
		check(_snapshot() == before, "Item catalog transitions preserve the saved exploration")
	for _iteration in range(3):
		await _open_compendium()
		var old_view = app.compendium_view
		old_view.select_category("common")
		await _settle()
		var first: Control = old_view.get_deck_view().get_card_views()[0]
		await _motion(_center(first))
		await _settle()
		await _click(first)
		first.activation_requested.emit(int(first.uid))
		check(_snapshot() == before, "Card hover and activation preserve paused run, combat, randomness, settings, and catalog")
		# Leave while a hover tween is active and deliver the old page's callback.
		app._navigate("settings")
		old_view.close_requested.emit()
		check(app.screen == "settings", "A stale compendium return callback cannot change the current page")
		await _settle()
		check(not is_instance_valid(old_view) and not is_instance_valid(app.compendium_view), "Leaving frees the old compendium and its card interactions")
		await _click(_button("设置"))
		check(app.screen == "menu" and _snapshot() == before, "Repeated compendium transitions preserve the saved exploration")
	await _click(_button("继续游戏"))
	check(app.screen == "run" and app.run_state.to_snapshot() == before.run and app.combat.to_snapshot() == before.combat, "Continue restores the exact exploration after compendium browsing")
	app._return_menu()
	await _settle()

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
		_menu_layout()
		await _capture("menu")
		await _main_menu_actions()
		await _settings_navigation()
		var before := _snapshot()
		await _browse_item_catalogs()
		await _open_compendium()
		_compendium_layout()
		await _browse_categories()
		check(_snapshot() == before, "Browsing every category without a run leaves saves, settings, role selection, and catalog unchanged")
		if dimensions == RESOLUTIONS[0]:
			await _readonly_and_lifecycle()
		await _drop_app()
	_clean()
	print("V2_COMPENDIUM_UI: %d checks, %d failures; menu/settings, categories, card faces, four window sizes, readonly navigation and lifecycle" % [checks, failures])
	quit(0 if failures == 0 else 1)
