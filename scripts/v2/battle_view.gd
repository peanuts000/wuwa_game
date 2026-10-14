extends Control

const Catalog = preload("res://scripts/v2/catalog.gd")
const HandView = preload("res://scripts/v2/hand_view.gd")
const PieceView = preload("res://scripts/v2/piece_view.gd")
const BoardAnimation = preload("res://scripts/v2/board_animation.gd")
const Art = preload("res://scripts/v2/paper_battle_theme.gd")
const BattleDecor = preload("res://scripts/v2/paper_battle_decor.gd")
const MUTED := Color("766077")
const ACCENT := Color("79dbc8")

var app: Control
var hand_view: Control
var board_buttons: Array = []
var piece_views: Array = []
var _locked := false
var _generation := 0
var _configured := false
var _layout: Dictionary = {}
var _panels: Dictionary = {}
var _labels: Dictionary = {}
var _buttons: Dictionary = {}
var _mana_labels: Dictionary = {}
var _supply_buttons: Array = []
var _player_portrait: TextureRect
var _enemy_portrait: TextureRect
var _player_health: ProgressBar
var _enemy_health: ProgressBar
var _board_grid: GridContainer
var _feedback: Control
var _active_tweens: Array[Tween] = []
var _cell_side := 0.0
var _board_animation: Control
var _disposed := false
var _decor: Control
var _mana_icons: Dictionary = {}

func configure(game_app: Control) -> void:
	if _configured:
		return
	_configured = true
	app = game_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_position_controls)
	_position_controls()
	refresh()

func _build() -> void:
	var background := TextureRect.new()
	background.name = "BattleStageBackground"
	background.texture = Art.BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_decor = BattleDecor.new()
	_decor.view = self
	_decor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_decor)
	_decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["player", "enemy", "piles", "actions", "intent", "phase"]:
		var panel := Panel.new()
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if key in ["piles", "actions"] else Art.paper())
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_panels[key] = panel
	_label("player_name", 22, ACCENT)
	_label("journey", 12, MUTED)
	_player_portrait = _portrait("res://assets/pieces/condensation_base.png")
	_label("player_hp", 18)
	_player_health = _health_bar(ACCENT)
	_label("player_guard", 18, Color("bdcce3"))
	_label("player_stats", 17)
	_label("player_xp", 16, MUTED)
	_label("mana_title", 15, MUTED)
	for kind in Catalog.ATTRIBUTES:
		var value := _label("mana_" + kind, 17, Catalog.COLORS[kind])
		_mana_labels[kind] = value
		var icon := PieceView.new()
		add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		icon.configure({"kind": kind, "special": "", "axis": ""})
		_mana_icons[kind] = icon
	_label("supplies_title", 15, MUTED)
	for i in range(3):
		var supply := _button("supply_%d" % i, "", "_use_supply", [i])
		supply.add_theme_font_size_override("font_size", 14)
		_supply_buttons.append(supply)
	_label("enemy_heading", 15, MUTED).text = "当前敌人"
	_label("enemy_name", 22, Color("ffba94"))
	_enemy_portrait = _portrait("res://assets/enemies/purple_dumpling.png")
	_label("enemy_hp", 18)
	_enemy_health = _health_bar(Color("f48364"))
	_label("enemy_guard", 18, Color("bdcce3"))
	_label("intent_heading", 16, MUTED).text = "下一次行动"
	_label("intent", 21, Color("ffba94"), true)
	_label("latest", 14, MUTED, true)
	_labels.latest.max_lines_visible = 2
	_board_grid = GridContainer.new()
	_board_grid.columns = 8
	_board_grid.add_theme_constant_override("h_separation", 5)
	_board_grid.add_theme_constant_override("v_separation", 5)
	add_child(_board_grid)
	for i in range(64):
		var button := Button.new()
		button.name = "Cell%d" % i
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): _invoke("_click_cell", [i]))
		button.add_theme_color_override("font_color", Color("101e2c"))
		button.add_theme_color_override("font_disabled_color", Color("101e2c"))
		button.add_theme_color_override("font_hover_color", Color("101e2c"))
		_board_grid.add_child(button)
		board_buttons.append(button)
		var piece := PieceView.new()
		button.add_child(piece)
		button.mouse_entered.connect(func(): piece.set_hovered(true))
		button.mouse_exited.connect(func(): piece.set_hovered(false))
		button.focus_entered.connect(func(): piece.set_focused(true))
		button.focus_exited.connect(func(): piece.set_focused(false))
		piece_views.append(piece)
	app.board_buttons = board_buttons
	_label("piles_heading", 17, MUTED).text = "牌堆与构筑"
	_labels.piles_heading.hide()
	_button("piles", "抽牌堆 / 弃牌堆", "_show_piles")
	_button("deck", "牌组", "_show_deck")
	_button("relics", "藏品", "_show_relics")
	_button("menu_left", "主界面", "_return_menu")
	_label("hand_count", 17, MUTED)
	_button("end_turn", "结束回合  →", "_end_turn")
	_button("retreat", "撤退", "_confirm_retreat")
	_button("menu", "主界面", "_return_menu")
	hand_view = HandView.new()
	hand_view.paper_style = true
	hand_view.name = "HandView"
	add_child(hand_view)
	hand_view.configure(app.catalog)
	hand_view.play_requested.connect(func(uid: int): _invoke("_play_card_uid", [uid]))
	_feedback = Control.new()
	_feedback.name = "Feedback"
	_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feedback)
	for key in _labels:
		_labels[key].add_theme_color_override("font_color", Art.INK)
	for key in ["player_name", "enemy_name", "journey"]:
		_labels[key].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_labels.journey.add_theme_font_size_override("font_size", 20)
	_labels.intent.add_theme_font_size_override("font_size", 25)
	_labels.latest.add_theme_color_override("font_color", Art.CREAM)
	_labels.hand_count.add_theme_color_override("font_color", Art.CREAM)

func _label(key: String, font_size: int = 18, color: Color = Color("edf4ff"), wrap: bool = false) -> Label:
	var value := Label.new()
	value.name = key.to_pascal_case()
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.clip_text = not wrap
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if wrap:
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.max_lines_visible = 3
	add_child(value)
	_labels[key] = value
	return value

func _button(key: String, title: String, method: String, args: Array = []) -> Button:
	var value := Button.new()
	value.name = key.to_pascal_case()
	value.text = title
	value.add_theme_font_size_override("font_size", 16)
	value.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("223149") if state == "normal" else (Color("304964") if state == "hover" else Color("172338"))
		style.set_corner_radius_all(8)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = ACCENT
			style.set_border_width_all(2)
		value.add_theme_stylebox_override(state, style)
	value.pressed.connect(func(): _invoke(method, args))
	Art.button(value, key == "end_turn")
	add_child(value)
	_buttons[key] = value
	return value

func _invoke(method: String, args: Array = []) -> void:
	if is_instance_valid(app) and app.has_method(method):
		app.callv(method, args)

func _portrait(path: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = load(path)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	return portrait

func _health_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color("493d45")
	back.border_color = Art.GOLD
	back.set_border_width_all(1)
	back.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	return bar

func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size

func _text_place(key: String, rect: Rect2) -> void:
	_place(_labels[key], rect)

func _button_place(key: String, rect: Rect2) -> void:
	_place(_buttons[key], rect)

func _position_controls() -> void:
	if not _configured or size.x <= 0 or size.y <= 0:
		return
	var left := Rect2(30, 252, 314, 318)
	var center := Rect2(354, 80, 572, 640)
	var right := Rect2(940, 272, 314, 140)
	var hand := Rect2(338, 520, 604, 200)
	var board := Rect2(380, 84, 520, 520)
	_layout = {"player": left, "center": center, "enemy": right, "board": board,
		"piles": Rect2(30, 587, 302, 121), "actions": Rect2(948, 608, 300, 100),
		"intent": Rect2(940, 416, 314, 140), "phase": Rect2(376, 17, 528, 53), "hand": hand}
	for key in _panels:
		_place(_panels[key], _layout[key])
	_place(_player_portrait, Rect2(74, 87, 225, 169))
	_place(_enemy_portrait, Rect2(968, 101, 250, 160))
	_text_place("player_name", Rect2(50, 268, 274, 29))
	_text_place("journey", Rect2(450, 30, 435, 28))
	_text_place("player_hp", Rect2(52, 303, 272, 24))
	_place(_player_health, Rect2(52, 331, 272, 10))
	_text_place("player_guard", Rect2(52, 345, 133, 24))
	_text_place("player_stats", Rect2(195, 345, 132, 24))
	_text_place("player_xp", Rect2(52, 373, 270, 20))
	_text_place("mana_title", Rect2(52, 399, 270, 23))
	for i in range(Catalog.ATTRIBUTES.size()):
		var kind: String = Catalog.ATTRIBUTES[i]
		var x := 54.0 + (i % 3) * 92
		var y := 427.0 + floorf(i / 3.0) * 34
		_place(_mana_icons[kind], Rect2(x, y, 26, 26))
		_text_place("mana_" + kind, Rect2(x + 32, y, 47, 27))
	_text_place("supplies_title", Rect2(52, 498, 270, 21))
	for i in range(3):
		_button_place("supply_%d" % i, Rect2(52 + i * 91, 525, 82, 29))
	_labels.enemy_heading.hide()
	_text_place("enemy_name", Rect2(962, 286, 268, 28))
	_text_place("enemy_hp", Rect2(962, 320, 268, 24))
	_place(_enemy_health, Rect2(962, 351, 268, 11))
	_text_place("enemy_guard", Rect2(962, 376, 268, 23))
	_text_place("intent_heading", Rect2(964, 433, 265, 23))
	_text_place("intent", Rect2(964, 464, 265, 71))
	_text_place("latest", Rect2(950, 562, 294, 44))
	_place(hand_view, hand)
	_cell_side = (board.size.x - 5.0 * 7.0) / 8.0
	for i in range(board_buttons.size()):
		board_buttons[i].custom_minimum_size = Vector2(_cell_side, _cell_side)
		_refresh_cell(i)
	_place(_board_grid, board)
	_text_place("hand_count", Rect2(42, 580, 270, 24))
	_text_place("piles_heading", Rect2(42, 580, 270, 24))
	_button_place("piles", Rect2(40, 609, 286, 36))
	_button_place("deck", Rect2(40, 654, 137, 32))
	_button_place("menu_left", Rect2(186, 654, 140, 32))
	for i in range(2):
		var key: String = ["relics", "retreat"][i]
		_button_place(key, Rect2(1129 + i * 63, 25, 57, 42))
		_buttons[key].add_theme_font_size_override("font_size", 15)
	_button_place("end_turn", Rect2(948, 622, 306, 73))
	_buttons.menu.hide()
	_refresh_play_zone()
	_decor.queue_redraw()

func get_run_status_rect() -> Rect2:
	return Rect2(38, 20, 300, 52)

func _refresh_play_zone() -> void:
	if _layout.is_empty() or app.combat == null:
		return
	var center: Rect2 = _layout.center
	var global_center := Rect2(global_position + center.position, center.size)
	var hand_top: float = hand_view.get_expanded_top() if app.combat.phase == "play" and not app.resolving_ui and not is_instance_valid(_board_animation) else hand_view.get_collapsed_top()
	var height := clampf(hand_top - global_center.position.y, 0.0, center.size.y)
	hand_view.set_play_zone(Rect2(global_center.position, Vector2(center.size.x, height)))

func refresh(played_uid: int = -1) -> void:
	if _disposed or not _configured or not is_instance_valid(app) or app.combat == null or app.run_state == null:
		return
	var battle = app.combat
	var run = app.run_state
	hand_view.configure(app.catalog, battle)
	hand_view.set_collapsed(battle.phase != "play" or app.resolving_ui or is_instance_valid(_board_animation))
	hand_view.update_hand(battle.hand, _can_play_uid, _unavailable_reason, played_uid)
	hand_view.set_locked(_locked or app.resolving_ui or is_instance_valid(_board_animation) or is_instance_valid(app.modal))
	_refresh_play_zone()
	_labels.player_name.text = "柯莱塔  ·  Lv.%d" % battle.level
	var stage: String = {"board": "消除行动", "resolving": "消除结算", "play": "出牌阶段", "enemy": "敌人行动", "ended": "战斗结束"}.get(battle.phase, battle.phase)
	var floor_number: int = run.nodes.get(run.current, {}).get("row", 0)
	_labels.journey.text = "第%d层 · 回合%d · %s" % [floor_number, battle.turn, stage]
	_labels.journey.tooltip_text = _labels.journey.text
	_labels.player_hp.text = "生命  %d / %d" % [battle.hp, battle.max_hp]
	_player_health.max_value = battle.max_hp
	_player_health.value = battle.hp
	_labels.player_guard.text = "◇  格挡  %d" % battle.guard
	_labels.player_stats.text = "攻击  %d" % battle.attack()
	_labels.player_xp.text = "经验  " + ("%d / %d" % [battle.xp, battle.level + 2] if battle.level < 10 else "MAX")
	_labels.mana_title.text = "技能点  ·  跨回合保留"
	for kind in Catalog.ATTRIBUTES:
		_mana_labels[kind].text = str(battle.mana.get(kind, 0))
		_mana_labels[kind].tooltip_text = Catalog.NAMES[kind]
	_labels.supplies_title.text = "补给" if not run.supplies.is_empty() else "暂无补给"
	for i in range(3):
		var button: Button = _supply_buttons[i]
		button.visible = true
		if i < run.supplies.size():
			var item: Dictionary = app.catalog.supplies[run.supplies[i]]
			button.text = item.name
			button.tooltip_text = item.effect
			button.disabled = _locked or app.resolving_ui or is_instance_valid(_board_animation) or battle.phase not in ["board", "play"]
		else:
			button.text = "—"
			button.tooltip_text = "空补给位"
			button.disabled = true
	_labels.enemy_name.text = battle.enemy.name
	_labels.enemy_name.tooltip_text = battle.enemy.name
	_labels.enemy_hp.text = "生命  %d / %d" % [battle.enemy_hp, battle.enemy_max_hp]
	_enemy_health.max_value = battle.enemy_max_hp
	_enemy_health.value = battle.enemy_hp
	_labels.enemy_guard.text = "◇  格挡  %d" % battle.enemy_guard
	_labels.intent.text = battle.intent_text()
	_labels.latest.text = app.notice if app.notice != "" else (battle.log_lines.back() if not battle.log_lines.is_empty() else "")
	_labels.latest.tooltip_text = _labels.latest.text
	_labels.latest.add_theme_color_override("font_color", Color("ffce85") if app.notice != "" else Art.CREAM)
	for i in range(64):
		_refresh_cell(i)
	_buttons.end_turn.disabled = _locked or app.resolving_ui or is_instance_valid(_board_animation) or battle.phase != "play"
	_buttons.retreat.disabled = _locked or app.resolving_ui or is_instance_valid(_board_animation) or battle.phase not in ["board", "play"]
	_buttons.piles.text = "抽牌堆 %d  /  弃牌堆 %d" % [battle.draw_pile.size(), battle.discard.size()]
	_buttons.deck.text = "牌组 %d" % run.deck.size()
	_buttons.relics.text = "藏品 %d" % run.relics.size()
	_labels.hand_count.text = "手牌 %d  ·  已出 %d 张" % [battle.hand.size(), battle.played]
	app.board_buttons = board_buttons

func _refresh_cell(index: int) -> void:
	var cell: Variant = app.combat.board.cells[index]
	var button: Button = board_buttons[index]
	var piece: Control = piece_views[index]
	piece.configure(cell, index == app.selection, index in app.highlights, button.has_focus())
	var title := ""
	if cell != null:
		if piece.get_texture() == null:
			title = {"star": "★", "guard": "盾"}.get(cell.kind, Catalog.NAMES[cell.kind].left(1))
			if cell.special != "":
				title += "\n" + {"stripe": "━" if cell.axis == "h" else "┃", "bomb": "✦", "rainbow": "◎"}[cell.special]
	button.text = title
	button.disabled = cell == null or _locked or app.resolving_ui or is_instance_valid(_board_animation) or app.combat.phase != "board"
	button.add_theme_font_size_override("font_size", clampi(roundi(_cell_side * 0.27), 13, 24) if cell != null and cell.special != "" else clampi(roundi(_cell_side * 0.42), 18, 36))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.set_corner_radius_all(ceili(_cell_side * 0.5))
		style.set_content_margin_all(0)
		if cell != null and (index == app.selection or index in app.highlights):
			style.set_border_width_all(3)
			style.border_color = Color.WHITE
		if state == "focus" and cell != null:
			style.set_border_width_all(2)
			style.border_color = ACCENT
		button.add_theme_stylebox_override(state, style)
	var display_name: String = "" if cell == null else {"star": "星声", "guard": "护盾"}.get(cell.kind, Catalog.NAMES[cell.kind])
	button.tooltip_text = "" if cell == null else display_name + " · " + {"": "普通球", "stripe": "条纹：连续两次点击同球或与邻球交换可发动，消除整行或整列。", "bomb": "炸弹：连续两次点击同球或与邻球交换可发动，消除周围 3×3。", "rainbow": "彩虹：连续两次点击同球直接发动，清除自身球种；与邻球交换发动，清除对方球种；被消除时清除自身球种。两个彩虹交换时，各清除对方球种。"}[cell.special]

func _card_index(uid: int) -> int:
	if not is_instance_valid(app) or app.combat == null:
		return -1
	for i in range(app.combat.hand.size()):
		if int(app.combat.hand[i].get("uid", -1)) == uid:
			return i
	return -1

func _can_play_uid(uid: int) -> bool:
	var index := _card_index(uid)
	return index >= 0 and not _locked and not app.resolving_ui and not is_instance_valid(_board_animation) and app.combat.can_play(index)

func _unavailable_reason(uid: int) -> String:
	var index := _card_index(uid)
	if index < 0:
		return "这张牌已不在手牌中。"
	if _locked or app.resolving_ui or is_instance_valid(_board_animation):
		return "正在结算，请稍候。"
	if app.combat.phase != "play":
		return "先完成本回合的消除行动。" if app.combat.phase == "board" else "当前阶段不能出牌。"
	var missing: Array[String] = []
	var costs: Dictionary = app.catalog.cost(app.combat.hand[index])
	for kind in costs:
		var amount: int = int(costs[kind]) - int(app.combat.mana.get(kind, 0))
		if amount > 0:
			missing.append("%s %d" % [Catalog.NAMES[kind], amount])
	return "还缺少 " + "、".join(missing) + " 技能点。" if not missing.is_empty() else ""

func set_locked(value: bool) -> void:
	_locked = value
	if _configured:
		refresh()

func animate_card(uid: int) -> void:
	if not _configured or not is_instance_valid(hand_view):
		return
	await hand_view.animate_play(uid)

func _begin_board_animation(cells: Array) -> void:
	if is_instance_valid(_board_animation) or _disposed:
		return
	_board_animation = BoardAnimation.new()
	add_child(_board_animation)
	_board_animation.configure(_board_grid, board_buttons, cells)
	# Transparency preserves GridContainer geometry while its ghost pieces move.
	_board_grid.modulate.a = 0.0
	refresh()

func animate_board_step(before_cells: Array, step: Dictionary, swap_before: Array = [], swap_indices: Array = []) -> void:
	if _disposed or not _configured or not is_instance_valid(app) or app.combat == null:
		return
	var generation := _generation
	if not is_instance_valid(_board_animation):
		# Newly built GridContainers need a layout pass before their slot bounds
		# can be captured. An already displayed board must be hidden synchronously
		# so a refresh of the advanced model cannot flash before the old pieces.
		if board_buttons.is_empty() or board_buttons[0].size.x <= 0.0 or board_buttons[0].size.y <= 0.0:
			await get_tree().process_frame
			if generation != _generation or _disposed:
				return
		_begin_board_animation(swap_before if not swap_before.is_empty() else before_cells)
	var after_cells: Array = app.combat.board.cells.duplicate(true)
	await _board_animation.animate_step(before_cells, after_cells, step, swap_before, swap_indices)
	if generation == _generation and not _disposed:
		refresh()

func animate_invalid_swap(before_cells: Array, a: int, b: int) -> void:
	if _disposed or not _configured:
		return
	var generation := _generation
	if board_buttons.is_empty() or board_buttons[0].size.x <= 0.0 or board_buttons[0].size.y <= 0.0:
		await get_tree().process_frame
		if generation != _generation or _disposed:
			return
	_begin_board_animation(before_cells)
	await _board_animation.animate_invalid_swap(before_cells, a, b)
	if generation == _generation and not _disposed:
		finish_board_animation()

func finish_board_animation() -> void:
	if is_instance_valid(_board_animation):
		_board_animation.dispose()
		_board_animation.queue_free()
	_board_animation = null
	if is_instance_valid(_board_grid):
		_board_grid.modulate.a = 1.0
	if not _disposed:
		refresh()

func animate_feedback(before: Dictionary) -> void:
	if not _configured or app.combat == null:
		return
	var generation := _generation
	var battle = app.combat
	var animated := false
	for actor in ["player", "enemy"]:
		var hp_key: String = "hp" if actor == "player" else "enemy_hp"
		var guard_key: String = "guard" if actor == "player" else "enemy_guard"
		var hp_delta: int = int(battle.get(hp_key)) - int(before.get(hp_key, battle.get(hp_key)))
		var guard_delta: int = int(battle.get(guard_key)) - int(before.get(guard_key, battle.get(guard_key)))
		if hp_delta != 0:
			_float_feedback(actor, "%s%d 生命" % ["+" if hp_delta > 0 else "", hp_delta], ACCENT if hp_delta > 0 else Color("ff8e87"), 0)
			_flash(_player_portrait if actor == "player" else _enemy_portrait, hp_delta < 0)
			animated = true
		if guard_delta != 0:
			_float_feedback(actor, "%s%d 格挡" % ["+" if guard_delta > 0 else "", guard_delta], Color("c7d8ff"), 34)
			animated = true
	if animated:
		await get_tree().create_timer(0.36).timeout
		if generation != _generation:
			return

func _float_feedback(actor: String, title: String, color: Color, offset: int) -> void:
	var rect: Rect2 = _layout[actor]
	var value := Label.new()
	value.text = title
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", color)
	value.add_theme_color_override("font_outline_color", Color("0c1423"))
	value.add_theme_constant_override("outline_size", 5)
	value.add_theme_font_size_override("font_size", 25)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback.add_child(value)
	value.position = rect.position + Vector2(0, 160 + offset)
	value.size = Vector2(rect.size.x, 34)
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.set_parallel(true)
	tween.tween_property(value, "position:y", value.position.y - 45, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(value, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tween.finished.connect(func():
		_active_tweens.erase(tween)
		if is_instance_valid(value):
			value.queue_free())

func _flash(portrait: TextureRect, damage: bool) -> void:
	portrait.modulate = Color("ff8176") if damage else ACCENT
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.tween_property(portrait, "modulate", Color.WHITE, 0.3)
	tween.finished.connect(func(): _active_tweens.erase(tween))

func dispose() -> void:
	_generation += 1
	_locked = true
	_disposed = true
	finish_board_animation()
	for tween in _active_tweens:
		if tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	if is_instance_valid(hand_view):
		hand_view.set_locked(true)
		if hand_view.has_method("dispose"):
			hand_view.dispose()
	if is_instance_valid(_feedback):
		for child in _feedback.get_children():
			child.queue_free()
