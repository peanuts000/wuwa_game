extends SceneTree

# Real Window canvas-items scaling is exercised, including a 4:3 window with bars.
# Use -- --capture with a graphics driver to produce isolated layout screenshots.
const SAVE_PATH := "res://tests/artifacts/layout_save.cfg"
const LEGACY_PATH := "res://tests/artifacts/layout_missing_legacy.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 960)]
var app
var checks := 0
var failures := 0
var window_label := ""

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[%s] %s" % [window_label, message])

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.22).timeout

func _capture(screen_name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	# Keep-aspect black bars belong to the Window, outside this render texture.
	# Preserve actual rendered pixels instead of composing artificial borders.
	var factor := minf(root.size.x / 1280.0, root.size.y / 720.0)
	var content_size := Vector2i(roundi(1280 * factor), roundi(720 * factor))
	check(image.get_size() == content_size, "Capture dimensions match physical 16:9 content area")
	var error := image.save_png("res://tests/artifacts/v2_%s_%s.png" % [screen_name, window_label])
	check(error == OK, "Screenshot saved")

func _capture_idle_hint() -> void:
	if "--idle-hint" not in OS.get_cmdline_user_args():
		return
	app._record_player_activity()
	check(not app.combat.auto_hint_used and app.highlights.is_empty(), "Idle hint starts unused without highlighted cells")
	await create_timer(7.5).timeout
	check(not app.combat.auto_hint_used and app.highlights.is_empty(), "No automatic hint appears before eight idle seconds")
	await create_timer(0.9).timeout
	check(app.combat.auto_hint_used and app.highlights.size() == 2, "Eight idle seconds highlight one available action")
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png("res://tests/artifacts/v2_idle_hint.png") == OK, "Idle hint screenshot saved")

func _buttons() -> Array:
	return app.find_children("*", "Button", true, false)

func _find_button(title: String):
	for button in _buttons():
		if button.text == title and button.is_visible_in_tree():
			return button
	return null

func _role_buttons() -> Array:
	var result: Array = []
	for button in app.find_children("*", "TextureButton", true, false):
		if button.is_visible_in_tree() and button.has_meta("role_id"):
			result.append(button)
	return result

func _inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.grow(1.0).encloses(inner)

func _click_board_cell(index: int) -> void:
	var button: Button = app.board_buttons[index]
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _check_original_ball_rgb() -> void:
	if window_label != "1280x720" or "--capture" not in OS.get_cmdline_user_args():
		return
	# All source images are 128 square. These interior points have a margin of
	# at least four source pixels from glyph edges, avoiding interpolation/AA.
	var points := {
		"condensation": [Vector2i(46, 30), Vector2i(64, 31)],
		"thermal": [Vector2i(100, 56), Vector2i(62, 75)],
		"conductive": [Vector2i(98, 70), Vector2i(47, 51)],
		"aero": [Vector2i(57, 29), Vector2i(91, 44)],
		"diffraction": [Vector2i(53, 25), Vector2i(42, 64)],
		"annihilation": [Vector2i(45, 65), Vector2i(61, 65)]
	}
	await RenderingServer.frame_post_draw
	var capture: Image = root.get_texture().get_image()
	var empty: Button = app.board_buttons[12]
	var empty_point: Vector2 = empty.get_global_transform_with_canvas() * (empty.size * 0.5)
	var page_color: Color = capture.get_pixel(roundi(empty_point.x), roundi(empty_point.y))
	for kind in app.catalog.ATTRIBUTES:
		var index: int = app.catalog.ATTRIBUTES.find(kind)
		page_color = Color("241b33") if index % 2 == 0 else Color("2b2039")
		var texture_rect: TextureRect = app.board_buttons[index].find_child("PieceTexture", true, false)
		var source: Image = texture_rect.texture.get_image()
		if source.is_compressed():
			source.decompress()
		var original_color: Color = source.get_pixel(0, 0)
		var source_background: Color = source.get_pixelv(points[kind][0])
		var source_glyph: Color = source.get_pixelv(points[kind][1])
		var rendered: Array[Color] = []
		for source_point in points[kind]:
			var uv: Vector2 = (Vector2(source_point) + Vector2.ONE * 0.5) / Vector2(source.get_size())
			var point: Vector2 = texture_rect.get_global_transform_with_canvas() * (texture_rect.size * uv)
			rendered.append(capture.get_pixel(roundi(point.x), roundi(point.y)))
		check(source_background.a >= 0.99 and source_glyph == Color.WHITE and _rgb_difference(rendered[0], page_color) <= 3.0 / 255.0 and _rgb_difference(rendered[1], original_color) <= 3.0 / 255.0, "%s opaque background becomes page RGB and white glyph becomes original attribute RGB: page=%s, background=%s, attribute=%s, glyph=%s" % [kind, page_color.to_html(false), rendered[0].to_html(false), original_color.to_html(false), rendered[1].to_html(false)])

func _rgb_difference(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))

func _check_board_art() -> void:
	var original: Dictionary = app.combat.to_snapshot()
	var original_cells: Array = app.combat.board.cells.duplicate(true)
	var original_selection: int = app.selection
	var original_highlights: Array = app.highlights.duplicate()
	var original_notice: String = app.notice
	var kinds: Array = app.catalog.ATTRIBUTES.duplicate()
	kinds.append_array(["guard", "star"])
	# A display-only copy exercises all eight art paths, including attributes not
	# selected for this run. No swap, resolution, save, or RNG draw occurs here.
	for i in range(8):
		app.combat.board.cells[i].kind = kinds[i]
		app.combat.board.cells[i].special = ""
	for i in range(4):
		app.combat.board.cells[8 + i].special = ["stripe", "stripe", "bomb", "rainbow"][i]
		app.combat.board.cells[8 + i].axis = "h" if i != 1 else "v"
	app.combat.board.cells[12] = null
	app.selection = -1
	app.highlights.clear()
	app._record_player_activity()
	app.battle_view.refresh()
	await _settle()
	var texture_paths: Array[String] = []
	var all_art_valid := true
	for i in range(8):
		var button: Button = app.board_buttons[i]
		var piece = button.find_child("PieceView", false, false)
		var texture: Texture2D = piece.get_texture() if piece != null else null
		all_art_valid = all_art_valid and piece != null and texture != null and piece.kind == kinds[i] and button.text.is_empty()
		if texture != null:
			texture_paths.append(texture.resource_path)
	check(all_art_valid and texture_paths.size() == 8 and texture_paths.all(func(path: String): return texture_paths.count(path) == 1), "All eight ball kinds display distinct real textures without text")
	var special_layers_valid := true
	for i in range(4):
		var button: Button = app.board_buttons[8 + i]
		var piece = button.find_child("PieceView", false, false)
		var overlay = piece.find_child("PieceOverlay", false, false) if piece != null else null
		special_layers_valid = special_layers_valid and piece != null and piece.get_texture() != null and overlay != null and overlay.is_visible_in_tree() and piece.special == ["stripe", "stripe", "bomb", "rainbow"][i] and piece.axis == ("v" if i == 1 else "h") and button.text.is_empty()
	check(special_layers_valid, "Horizontal and vertical stripes, bombs, and rainbows retain their separate overlay above the ball texture")
	var null_piece = app.board_buttons[12].find_child("PieceView", false, false)
	check(null_piece != null and null_piece.get_texture() == null and not null_piece.is_visible_in_tree() and app.board_buttons[12].text.is_empty() and app.board_buttons[12].tooltip_text.is_empty(), "Cleared null cell removes both its old texture and special decoration")
	var children_ignore := true
	for button in app.board_buttons:
		for child in button.find_children("*", "Control", true, false):
			children_ignore = children_ignore and child.mouse_filter == Control.MOUSE_FILTER_IGNORE
	check(children_ignore, "Every board texture and overlay lets pointer events reach its original cell button")
	var fixture_snapshot: Dictionary = app.combat.to_snapshot()
	await _click_board_cell(0)
	check(app.selection == 0 and app.combat.to_snapshot() == fixture_snapshot, "A real pointer click through the ball art selects without changing the model or consuming an action")
	var selected_style: StyleBoxFlat = app.board_buttons[0].get_theme_stylebox("normal")
	check(selected_style.border_color == Color.WHITE and selected_style.border_width_top == 3, "Selection preserves its white circle around the textured ball")
	var focus_style: StyleBoxFlat = app.board_buttons[0].get_theme_stylebox("focus")
	check(app.board_buttons[0].has_focus() and focus_style.border_width_top >= 2, "Textured board cell still receives keyboard focus with a visible focus ring")
	app.highlights = [10, 11]
	app.battle_view.refresh()
	var hints_visible := true
	for index in app.highlights:
		var style: StyleBoxFlat = app.board_buttons[index].get_theme_stylebox("normal")
		hints_visible = hints_visible and style.border_color == Color.WHITE and style.border_width_top == 3
	check(hints_visible, "Hint circles remain visible on bomb and rainbow textures")
	if window_label in ["1280x720", "960x540"]:
		app.board_buttons[0].release_focus()
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(4, 4)
		motion.global_position = motion.position
		root.push_input(motion, true)
		await process_frame
		await _capture("board_textures")
		await _check_original_ball_rgb()
	await _click_board_cell(0)
	check(app.selection == -1 and app.combat.phase == "board" and app.combat.to_snapshot() == fixture_snapshot, "A second real ordinary-ball click through the texture cancels selection without resolution")
	app.combat.board.cells = original_cells
	app.selection = original_selection
	app.highlights = original_highlights
	app.notice = original_notice
	app.battle_view.refresh()
	check(app.combat.to_snapshot() == original, "The art fixture restores the exact original combat and RNG state")

func _check_visible_button_bounds(context: String) -> void:
	var bounds: Rect2 = app.get_global_rect()
	for button in _buttons():
		if button.is_visible_in_tree():
			check(_inside(button.get_global_rect(), bounds), context + " button stays in canvas: " + button.text)
	for button in _role_buttons():
		check(_inside(button.get_global_rect(), bounds), context + " role image stays in canvas: " + str(button.get_meta("role_id")))
	var scrolls: Array = app.find_children("*", "ScrollContainer", true, false)
	var active := 0
	for scroll in scrolls:
		if scroll.is_visible_in_tree():
			active += 1
	check(active == 0, context + " has no whole-page scroll")

func _check_menu() -> void:
	var titles := ["开始探索", "继续游戏", "查看历史探索记录"]
	check(_buttons().size() == 5, "Menu has exactly five buttons")
	var bounds: Rect2 = app.get_global_rect()
	var previous_bottom := 0.0
	for title in titles:
		var button = _find_button(title)
		check(button != null, "Menu has " + title)
		if button == null:
			continue
		var rect: Rect2 = button.get_global_rect()
		check(absf(rect.get_center().x - bounds.get_center().x) <= 2.0, "Main menu action is horizontally centered: " + title)
		check(rect.position.y >= previous_bottom, "Menu actions follow reference order")
		previous_bottom = rect.end.y
	var settings = _find_button("设置")
	var compendium = _find_button("图鉴")
	check(settings != null and settings.get_global_rect().get_center().x > bounds.end.x - bounds.size.x * 0.15 and settings.get_global_rect().get_center().y < bounds.position.y + bounds.size.y * 0.15, "Settings stays in the upper-right corner")
	check(compendium != null and compendium.get_global_rect().get_center().x > bounds.end.x - bounds.size.x * 0.15 and compendium.get_global_rect().get_center().y > bounds.end.y - bounds.size.y * 0.15, "Compendium stays in the lower-right corner")
	check(_find_button("退出游戏") == null, "Quit is removed from the main menu")
	var resume = _find_button("继续游戏")
	check(resume != null and resume.disabled, "Continue disabled without a fixture save")
	_check_visible_button_bounds("Menu")

func _check_characters() -> void:
	check(_role_buttons().size() == 4, "First character page displays four slots")
	_check_visible_button_bounds("Characters")
	var slots := _role_buttons()
	if not slots.is_empty():
		var first: Rect2 = slots[0].get_global_rect()
		check(first.position.y > app.get_global_rect().size.y * 0.70, "Role slots stay at bottom")
	for slot in slots:
		var id: String = str(slot.get_meta("role_id"))
		check(slot.texture_normal != null, "Role slot has a full image: " + id)
		check(slot.find_children("*", "Label", true, false).is_empty(), "Role slot has no text: " + id)
		check(slot.disabled == (id != app.ROLES[0].id), "Only implemented role is enabled: " + id)
	var selected_index: int = app.role_index
	app._select_role(1)
	await _settle()
	check(app.role_index == selected_index, "Unavailable role cannot change selection")
	var start = _find_button("开始探索")
	check(start != null and not start.disabled, "Rejected selection retains playable role")
	app.role_page = 1
	app._render()
	await _settle()
	check(_role_buttons().size() == 3, "Second character page displays remaining three roles")
	var second_ids: Array[String] = []
	for slot in _role_buttons():
		var id: String = str(slot.get_meta("role_id"))
		second_ids.append(id)
		check(slot.disabled, "Second page unavailable role disabled: " + id)
		check(slot.texture_normal != null and slot.find_children("*", "Label", true, false).is_empty(), "Second page role is image-only: " + id)
	for index in range(4, 7):
		check(app.ROLES[index].id in second_ids, "Second page contains " + app.ROLES[index].name)
		app._select_role(index)
		check(app.role_index == selected_index, "Second page unavailable role cannot change selection: " + app.ROLES[index].name)
	_check_visible_button_bounds("Characters page 2")
	app.role_page = 0
	app._select_role(0)
	await _settle()

func _attribute_buttons() -> Array:
	var result: Array = []
	if not is_instance_valid(app.modal):
		return result
	for button in app.modal.find_children("*", "BaseButton", true, false):
		if button.has_meta("attribute_kind"):
			result.append(button)
	return result

func _attribute_confirm():
	return app.modal.find_child("ConfirmAttributes", true, false) if is_instance_valid(app.modal) else null

func _check_attribute_modal_bounds() -> void:
	check(is_instance_valid(app.modal), "Attribute modal exists")
	if not is_instance_valid(app.modal):
		return
	var bounds: Rect2 = app.get_global_rect()
	check(_inside(app.modal.get_global_rect(), bounds), "Attribute modal overlay stays in canvas")
	var panels: Array = app.modal.find_children("*", "PanelContainer", true, false)
	check(not panels.is_empty(), "Attribute modal has a compact panel")
	for panel in panels:
		if panel.is_visible_in_tree():
			check(_inside(panel.get_global_rect(), bounds), "Attribute panel stays in canvas")
	for button in app.modal.find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree():
			check(_inside(button.get_global_rect(), bounds), "Attribute control stays in canvas: " + button.name)

func _check_attribute_dialog() -> void:
	var original: Array = app.chosen.duplicate()
	app._show_attribute_dialog(true)
	await _settle()
	check(app.screen == "characters", "Attribute selection stays on character page")
	check(_attribute_buttons().size() == 6, "Attribute modal contains six balls")
	var kinds: Array[String] = []
	for button in _attribute_buttons():
		kinds.append(str(button.get_meta("attribute_kind")))
	for kind in app.catalog.ATTRIBUTES:
		check(kind in kinds, "Attribute modal contains " + kind)
	var confirm = _attribute_confirm()
	check(confirm != null and not confirm.disabled, "Four selected attributes enable confirmation")
	_check_attribute_modal_bounds()
	app._toggle_attribute("condensation")
	await _settle()
	confirm = _attribute_confirm()
	check(app.attribute_draft.size() == 3, "Removing a ball updates draft to three")
	check(confirm != null and confirm.disabled, "Three selected attributes disable confirmation")
	check(app.chosen == original, "Editing draft does not commit chosen attributes")
	app._close_modal()
	await _settle()
	check(not is_instance_valid(app.modal) and app.screen == "characters", "Cancel returns to character page")
	check(app.chosen == original and app.run_state == null, "Cancel preserves chosen attributes without starting")
	app._show_attribute_dialog(false)
	app._toggle_attribute("condensation")
	app._toggle_attribute("annihilation")
	await _settle()
	var edited: Array = app.attribute_draft.duplicate()
	check(edited.size() == 4 and "condensation" not in edited, "Four-attribute draft can omit condensation")
	confirm = _attribute_confirm()
	check(confirm != null and not confirm.disabled, "Missing condensation remains confirmable")
	var missing_warning := false
	for label in app.modal.find_children("*", "Label", true, false):
		if label.text.contains("未选冷凝") or label.text.contains("缺少冷凝"):
			missing_warning = true
	check(missing_warning, "Missing condensation warning is visible")
	_check_attribute_modal_bounds()
	for index in range(2):
		var preset = app.modal.find_child("AttributePreset%d" % index, true, false)
		check(preset != null, "Attribute preset exists")
		if preset != null:
			preset.pressed.emit()
		await _settle()
		check(app.attribute_draft == app.catalog.data.builds[index].attributes, "Preset selects its four draft attributes")
		check(app.chosen == original, "Preset remains an uncommitted draft")
		_check_attribute_modal_bounds()
	for kind in app.attribute_draft.duplicate():
		if kind not in edited:
			app._toggle_attribute(kind)
	for kind in edited:
		if kind not in app.attribute_draft:
			app._toggle_attribute(kind)
	var confirmed: Array = app.attribute_draft.duplicate()
	check(confirmed.size() == 4 and edited.all(func(kind): return kind in confirmed), "Restored draft contains the intended four kinds")
	app._confirm_attributes(false)
	await _settle()
	check(app.chosen == confirmed, "Confirm commits the four draft attributes")
	check(app.run_state == null and app.screen == "characters" and not is_instance_valid(app.modal), "Confirm-only returns to character page")
	app._show_attribute_dialog(true)
	await _settle()
	_check_attribute_modal_bounds()
	await _capture("attributes_dialog")
	app._confirm_attributes(true)
	await _settle()
	check(app.run_state != null and app.screen == "run", "Confirm-and-start opens exploration")
	if app.run_state != null:
		check(app.run_state.attributes == confirmed, "Run uses the confirmed four attributes")

func _check_battle() -> void:
	var view = app.battle_view
	check(is_instance_valid(view), "BattleView exists")
	if not is_instance_valid(view):
		return
	check(app.board_buttons.size() == 64, "Board keeps 64 buttons")
	var bounds: Rect2 = app.get_global_rect()
	var player: Rect2 = view._panels.player.get_global_rect()
	var local_center: Rect2 = view._layout.center
	var center := Rect2(view.global_position + local_center.position, local_center.size)
	var enemy: Rect2 = view._panels.enemy.get_global_rect()
	check(player.position.x < center.position.x and center.position.x < enemy.position.x, "Player / board / enemy order")
	check(absf(player.size.x / bounds.size.x - 0.245) < 0.02, "Player paper panel about one quarter width")
	check(absf(center.size.x / bounds.size.x - 0.45) < 0.03, "Board column about 45 percent")
	check(absf(enemy.size.x / bounds.size.x - 0.245) < 0.02, "Enemy paper panel about one quarter width")
	check(center.size.y / bounds.size.y > 0.85, "Center leaves space for fixed phase header")
	check(not view._panels.has("center") and not view._panels.has("hand"), "No center or hand background panels")
	check(not view._labels.has("stage") and not view._labels.has("notice"), "No center heading or explanation")
	check(view._labels.journey.text.contains("回合") and view._labels.journey.text.contains("消除行动"), "Turn and phase remain visible in the fixed header")
	var board: Rect2 = view._board_grid.get_global_rect()
	check(absf(board.size.x - board.size.y) <= 1.0, "Board is square")
	check(_inside(board, center), "Board stays within center column")
	check(board.size.x >= 520, "Reference-stage board uses at least 520 logical pixels")
	for cell in app.board_buttons:
		check(_inside(cell.get_global_rect(), board), "Cell stays within square board")
		check(absf(cell.size.x - cell.size.y) <= 1.0, "Board cell remains square")
		var transparent_styles := true
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxFlat = cell.get_theme_stylebox(state)
			transparent_styles = transparent_styles and is_zero_approx(style.bg_color.a) and style.corner_radius_top_left >= cell.size.x * 0.5 - 1
		check(transparent_styles, "Every cell button state has no colored background and retains circular interaction borders")
		var piece = cell.find_child("PieceView", false, false)
		var texture_rect: TextureRect = piece.find_child("PieceTexture", false, false) if piece != null else null
		var correct_material: bool = texture_rect != null and (texture_rect.material is ShaderMaterial if piece.kind in app.catalog.ATTRIBUTES else texture_rect.material == null)
		check(piece != null and piece.get_texture() != null and piece.is_visible_in_tree() and cell.text.is_empty() and texture_rect != null and correct_material and texture_rect.size.is_equal_approx(cell.size) and texture_rect.get_global_rect().is_equal_approx(cell.get_global_rect()), "Ball texture fills the cell with only six attribute outline materials; shield and star retain their original art")
	check(not view._buttons.has("hint") and not view._buttons.has("special"), "Hint and special activation buttons are removed")
	check(view.find_child("Hint", true, false) == null and view.find_child("Special", true, false) == null, "Removed buttons do not remain hidden in the scene")
	for key in ["piles", "end_turn", "retreat", "deck", "relics", "menu_left"]:
		var button: Button = view._buttons[key]
		check(button.is_visible_in_tree(), "Bottom control visible: " + key)
		check(_inside(button.get_global_rect(), bounds), "Bottom control reachable: " + key)
		check(button.get_global_rect().position.y > bounds.size.y * 0.70 if key in ["piles", "end_turn", "deck", "menu_left"] else button.get_global_rect().end.y < 80, "Control stays in its fixed action region: " + key)
	var piles_rect: Rect2 = view._buttons.piles.get_global_rect()
	var deck_rect: Rect2 = view._buttons.deck.get_global_rect()
	check(deck_rect.position.y >= piles_rect.end.y and deck_rect.position.y - piles_rect.end.y <= 12, "Deck follows pile control")
	check(view._buttons.menu_left.position.y == view._buttons.deck.position.y, "Home and deck align beneath piles")
	check(view._player_portrait.texture.resource_path == "res://assets/pieces/condensation_base.png", "Battle retains original Coletta dumpling, not concept character")
	check(view.find_child("BattleStageBackground", false, false) != null and view.hand_view.paper_style, "Stage art and paper battle cards are connected")
	check(view._buttons.end_turn.disabled, "End turn unavailable before board action")
	var hand = view.hand_view
	check(hand.is_collapsed(), "Hand is collapsed during board action")
	check(hand.get_global_rect().end.y == bounds.end.y, "Hand clips at actual bottom of canvas")
	for key in ["piles", "deck", "menu_left"]:
		check(not view._buttons[key].get_global_rect().intersects(center), "Left control stays outside center: " + key)
	var original_specials: Array = []
	for i in range(3):
		original_specials.append(app.combat.board.cells[i].special)
		app.combat.board.cells[i].special = ["stripe", "bomb", "rainbow"][i]
	view.refresh()
	for i in range(3):
		check(app.board_buttons[i].tooltip_text.contains("连续两次点击同球") and app.board_buttons[i].tooltip_text.contains("交换"), "Every special tooltip explains direct and swap activation")
		app.combat.board.cells[i].special = original_specials[i]
	view.refresh()
	await _check_board_art()
	var zone: Rect2 = hand._play_zone
	check(zone.position.is_equal_approx(center.position) and is_equal_approx(zone.size.x, center.size.x), "Drag zone stays in center column")
	check(is_equal_approx(zone.end.y, hand.get_collapsed_top()), "Collapsed drag zone stops before visible card tops")
	check(board.end.y <= hand.get_collapsed_top() - 8, "Large board avoids collapsed card strip")
	var original_buttons: Array = app.board_buttons.duplicate()
	app.combat.phase = "play"
	app._render()
	await _settle()
	var expanded_board: Rect2 = view._board_grid.get_global_rect()
	check(not hand.is_collapsed(), "Hand expands during play")
	check(expanded_board.size.is_equal_approx(board.size) and expanded_board.position.is_equal_approx(board.position), "Play keeps the fixed large board")
	check(absf(expanded_board.size.x - expanded_board.size.y) <= 1, "Expanded board remains square")
	check(expanded_board.end.y > hand.get_expanded_top(), "Expanded cards overlay lower board")
	check(is_equal_approx(hand._play_zone.end.y, hand.get_expanded_top()), "Play drop zone stops above expanded cards")
	check(view._labels.journey.text.contains("出牌阶段"), "Fixed header reports play phase")
	check(not view._buttons.end_turn.disabled, "End turn available during play")
	check(app.board_buttons == original_buttons, "Stage change preserves all board controls")
	await _capture("battle_play")
	if not app.combat.hand.is_empty():
		var uid: int = app.combat.hand[int(app.combat.hand.size() / 2)].uid
		hand._on_hover(uid)
		await _settle()
		var card = hand.get_card_view(uid)
		check(card != null, "Hovered card exists")
		if card != null:
			var card_rect: Rect2 = card.get_global_rect()
			for key in ["piles", "deck", "relics", "menu_left", "end_turn", "retreat"]:
				check(not card_rect.intersects(view._buttons[key].get_global_rect()), "Hovered card does not cover remaining control: " + key)
			check(_inside(card_rect, bounds), "Hovered card remains within canvas")
		hand.cancel_interaction()
		await _settle()
	var original_hand: Array = app.combat.hand.duplicate(true)
	for count in [0, 10, 1, 5]:
		var fixture: Array = []
		for i in range(count):
			fixture.append({"id": "c01", "upgraded": false, "uid": 5000 + i})
		app.combat.hand = fixture
		app._render()
		await _settle()
		var resized_board: Rect2 = view._board_grid.get_global_rect()
		check(not hand.is_collapsed(), "Play hand remains expanded with %d cards" % count)
		check(absf(resized_board.size.x - resized_board.size.y) <= 1, "Same-stage board stays square")
		check(resized_board.size.is_equal_approx(board.size) and resized_board.position.is_equal_approx(board.position), "Fixed board ignores %d-card hand geometry" % count)
		check(hand._play_zone.end.y <= hand.get_expanded_top() + 1 and _inside(hand._play_zone, center), "Drop zone remains above %d-card fan and inside center" % count)
		check(app.board_buttons == original_buttons, "Card-count refresh preserves board controls")
	app.combat.hand = original_hand
	app._render()
	await _settle()
	app.combat.phase = "board"
	app._render()
	await _settle()
	check(hand.is_collapsed(), "Hand collapses again outside play")
	check(view._board_grid.size.is_equal_approx(board.size), "Large board remains unchanged after play")
	check(app.board_buttons == original_buttons, "Returning to board preserves controls")
	_check_visible_button_bounds("Battle")

func _capture_paper_showcase() -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	var snapshot: Dictionary = app.combat.to_snapshot()
	app.combat.phase = "play"
	app.combat.hand = []
	var ids := ["c01", "c02", "c03", "g01", "c06"]
	for i in range(ids.size()):
		app.combat.hand.append({"id": ids[i], "uid": 9000 + i, "upgraded": false})
	for kind in app.catalog.ATTRIBUTES:
		app.combat.mana[kind] = 4
	app._render()
	await _settle()
	var hand = app.battle_view.hand_view
	hand._on_hover(9002)
	await _settle()
	await _capture("paper_battle_showcase")
	for uid in hand._views:
		var card = hand.get_card_view(uid)
		check(card.paper_style and card._effect.text.length() > 0 and card._title.text.length() > 0, "Paper hand keeps native title and live effect")
	check(app.combat.restore_snapshot(snapshot) == OK, "Showcase restores original battle fixture")
	app._render()
	await _settle()

func _clean_fixture() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)

func _run() -> void:
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "Project uses canvas-items scaling")
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "Project keeps aspect ratio")
	check(ProjectSettings.get_setting("display/window/size/min_width") == 960, "Minimum window width")
	check(ProjectSettings.get_setting("display/window/size/min_height") == 540, "Minimum window height")
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	for dimensions in RESOLUTIONS:
		window_label = "%dx%d" % [dimensions.x, dimensions.y]
		_clean_fixture()
		root.size = dimensions
		await _settle()
		app = load("res://scenes/Main.tscn").instantiate()
		app.save_path = SAVE_PATH
		app.legacy_save_path = LEGACY_PATH
		app.apply_display_settings = false
		root.add_child(app)
		await _settle()
		check(root.size == dimensions, "Window has requested physical size")
		check(app.size.is_equal_approx(Vector2(1280, 720)), "Logical canvas stays 1280 by 720")
		_check_menu()
		await _capture("menu")
		app._navigate("characters")
		await _settle()
		await _check_characters()
		await _capture("characters")
		await _check_attribute_dialog()
		if app.run_state != null:
			app._enter_node(app.run_state.available[0])
			await _settle()
			await _check_battle()
			await _capture("battle")
			if dimensions == RESOLUTIONS[0]:
				await _capture_idle_hint()
			await _capture_paper_showcase()
		app.queue_free()
		await process_frame
		app = null
	_clean_fixture()
	print("GAMEPLAY_V2_LAYOUT: %d checks, %d failures; four physical resolutions with 16:9 canvas" % [checks, failures])
	quit(1 if failures else 0)
