extends Control

signal claim_requested(index: int, choice: String)
signal skip_requested(index: int)
signal finish_requested()
signal menu_requested()

const CardView = preload("res://scripts/v2/card_view.gd")
const CARD_SIZE := Vector2(150, 210)
const ACCENT := Color("79dbc8")
const MUTED := Color("a6b6cc")

class RewardBadge:
	extends Control
	var kind := "relic"
	func _draw() -> void:
		var ink := Color("f5d481") if kind == "relic" else (Color("79dbc8") if kind == "supply" else Color("65c9f4"))
		draw_circle(Vector2(20, 20), 19, ink.darkened(0.8))
		if kind == "supply":
			draw_colored_polygon(PackedVector2Array([Vector2(15, 7), Vector2(25, 7), Vector2(25, 16), Vector2(31, 23), Vector2(28, 33), Vector2(12, 33), Vector2(9, 23), Vector2(15, 16)]), ink)
			draw_line(Vector2(14, 10), Vector2(26, 10), Color("203849"), 3, true)
			draw_line(Vector2(13, 25), Vector2(27, 25), ink.lightened(0.4), 3, true)
		elif kind == "card":
			draw_rect(Rect2(8, 8, 19, 25), ink.darkened(0.4), false, 2)
			draw_rect(Rect2(13, 6, 19, 25), ink, true)
			draw_line(Vector2(18, 13), Vector2(27, 13), Color("1b3045"), 2)
			draw_line(Vector2(18, 18), Vector2(27, 18), Color("1b3045"), 2)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(20, 5), Vector2(33, 18), Vector2(20, 35), Vector2(7, 18)]), ink)
			draw_colored_polygon(PackedVector2Array([Vector2(20, 12), Vector2(27, 19), Vector2(20, 28), Vector2(13, 19)]), ink.darkened(0.5))

var _catalog
var _rewards: Array = []
var _list_title := "好东西！"
var _built := false
var _disposed := false
var _locked := false
var _page := "list"
var _card_reward_index := -1
var _card_hover_uid := -1
var _card_base_scale := 1.5
var _item_buttons: Array[Button] = []
var _all_buttons: Array[Button] = []
var _card_views: Array[Control] = []
var _card_homes: Dictionary = {}
var _card_tweens: Dictionary = {}
var _title: Label
var _summary: Label
var _summary_scroll: ScrollContainer
var _menu: Button
var _body: Control
var _scroll: ScrollContainer
var _list_panel: Panel
var _finish: Button
var _skip: Button
var _back: Button
var _empty: Label
var _tooltip: PanelContainer
var _tooltip_label: Label
var _tooltip_owner: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_position_controls)
	if _catalog != null:
		_render_rewards()

func configure(catalog, rewards: Array, title_text: String = "好东西！") -> void:
	_catalog = catalog
	_rewards = rewards.duplicate(true)
	_list_title = title_text
	if is_inside_tree():
		_build()
		_render_rewards()

func set_locked(value: bool) -> void:
	if _disposed:
		return
	_locked = value
	for button in _all_buttons:
		if is_instance_valid(button):
			button.disabled = value
	for card in _card_views:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
		card.focus_mode = Control.FOCUS_NONE if value else Control.FOCUS_ALL
	if value and is_instance_valid(_tooltip):
		_tooltip.hide()

func get_reward_items() -> Array[Button]:
	return _item_buttons.duplicate()

func get_card_views() -> Array[Control]:
	return _card_views.duplicate()

func get_reward_tooltip_text() -> String:
	return _tooltip_label.text if is_instance_valid(_tooltip_label) else ""

func get_tooltip_panel() -> Control:
	return _tooltip

func dispose() -> void:
	if _disposed:
		return
	set_locked(true)
	_disposed = true
	set_process_input(false)
	_stop_card_tweens()
	_tooltip_owner = null
	if is_instance_valid(_tooltip):
		_tooltip.hide()

func _build() -> void:
	if _built:
		return
	_built = true
	var background := ColorRect.new()
	background.color = Color("0c1423")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_title = _label(self, "好东西！", 40, ACCENT)
	_title.name = "RewardTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_scroll = ScrollContainer.new()
	_summary_scroll.name = "RewardSummaryScroll"
	_summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_summary_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_summary_scroll)
	_summary = _label(_summary_scroll, "", 18, MUTED)
	_summary.name = "RewardSummary"
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu = _button(self, "主界面", _request_menu)
	_menu.name = "MenuButton"
	_tooltip = PanelContainer.new()
	_tooltip.name = "RewardTooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.custom_minimum_size = Vector2(290, 0)
	var style := _panel_style(Color("15263b"), ACCENT.darkened(0.3))
	style.set_content_margin_all(14)
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip.z_index = 100
	add_child(_tooltip)
	_tooltip_label = _label(_tooltip, "", 17)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size.x = 262
	_tooltip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip.hide()
	_position_controls()

func _label(parent: Node, text: String, font_size: int = 18, color: Color = Color("edf4ff")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := Color("17283d") if state == "normal" else (Color("29465d") if state == "hover" else Color("101c2c"))
		var style := _panel_style(color, Color("34536a") if state == "hover" else Color("2a3d54"))
		style.set_content_margin_all(12)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	_all_buttons.append(button)
	return button

func _clear_body() -> void:
	_stop_card_tweens()
	_card_views.clear()
	_card_homes.clear()
	_card_hover_uid = -1
	_item_buttons.clear()
	_all_buttons = [_menu]
	_tooltip_owner = null
	_tooltip.hide()
	_scroll = null
	_list_panel = null
	_finish = null
	_skip = null
	_back = null
	_empty = null
	if is_instance_valid(_body):
		remove_child(_body)
		_body.queue_free()
	_body = Control.new()
	_body.name = "RewardBody"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)

func _render_rewards() -> void:
	if _disposed:
		return
	var notices: Array[String] = []
	var first_card := -1
	var items := false
	for i in range(_rewards.size()):
		var reward: Dictionary = _rewards[i]
		if reward.get("type") == "notice":
			notices.append(str(reward.get("text", "")))
		elif reward.get("type") == "card":
			if first_card < 0:
				first_card = i
		else:
			items = true
	_summary.text = "\n".join(notices)
	if not items and first_card >= 0:
		_show_cards(first_card)
	else:
		_show_list()

func _show_list() -> void:
	if _locked or _disposed:
		return
	_page = "list"
	_card_reward_index = -1
	_clear_body()
	_title.text = _list_title
	_summary.show()
	_list_panel = Panel.new()
	_list_panel.name = "RewardListPanel"
	_list_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list_style := _panel_style(Color("101d2e"), Color("294258"))
	list_style.set_corner_radius_all(16)
	_list_panel.add_theme_stylebox_override("panel", list_style)
	_body.add_child(_list_panel)
	_scroll = ScrollContainer.new()
	_scroll.name = "RewardListScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_body.add_child(_scroll)
	var list := VBoxContainer.new()
	list.name = "RewardList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	_scroll.add_child(list)
	for i in range(_rewards.size()):
		var reward: Dictionary = _rewards[i]
		var kind := str(reward.get("type", ""))
		if kind == "notice":
			continue
		if kind == "card":
			_create_row(list, i, "card", "", "选择一张牌", "查看三张候选卡牌，选择一张加入牌组。", true)
			continue
		var choices := _item_choices(reward)
		if choices.size() > 1:
			var prompt := "藏品二选一" if kind == "relic" and choices.size() == 2 else "任选一项"
			_label(list, prompt, 15, MUTED)
		for choice in choices:
			var entry: Dictionary = _catalog.relics[choice.id] if choice.type == "relic" else _catalog.supplies[choice.id]
			_create_row(list, i, choice.type, choice.id, str(entry.name), str(entry.effect))
	if _item_buttons.is_empty():
		var empty_text := "奖励已结算" if _list_title == "奖励节点" else "已领取所有奖励"
		_empty = _label(_body, empty_text, 22, MUTED)
		_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finish = _button(_body, "继续探索  →" if _item_buttons.is_empty() else "跳过剩余奖励  →", _request_finish)
	_finish.name = "FinishButton"
	_position_controls()

func _item_choices(reward: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var kind := str(reward.get("type", ""))
	if kind == "choice":
		for option in reward.get("options", []):
			result.append({"type": str(option.type), "id": str(option.id)})
	elif reward.has("options"):
		for id in reward.options:
			result.append({"type": kind, "id": str(id)})
	elif reward.has("id"):
		result.append({"type": kind, "id": str(reward.id)})
	return result

func _create_row(parent: Node, index: int, kind: String, choice: String, name_text: String, effect: String, opens_cards: bool = false) -> void:
	var callback := _show_cards.bind(index) if opens_cards else _request_claim.bind(index, choice)
	var button := _button(parent, name_text, callback)
	button.name = "Reward_%d_%s" % [index, choice if not choice.is_empty() else kind]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(350, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("reward_index", index)
	button.set_meta("choice", choice)
	button.set_meta("type", kind)
	button.set_meta("id", choice)
	button.set_meta("full_text", name_text + "\n\n" + effect)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 66
		button.add_theme_stylebox_override(state, style)
	var badge := RewardBadge.new()
	badge.kind = kind
	badge.position = Vector2(12, 12)
	badge.size = Vector2(40, 40)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)
	button.mouse_entered.connect(_show_tooltip.bind(button))
	button.focus_entered.connect(_show_tooltip.bind(button))
	button.mouse_exited.connect(_hide_tooltip.bind(button))
	button.focus_exited.connect(_hide_tooltip.bind(button))
	_item_buttons.append(button)

func _show_tooltip(button: Button) -> void:
	if _locked or _disposed or not is_instance_valid(button):
		return
	_tooltip_owner = button
	_tooltip_label.text = str(button.get_meta("full_text", ""))
	_tooltip.size = Vector2(290, 0)
	_tooltip.show()
	_position_tooltip()
	call_deferred("_position_tooltip")

func _hide_tooltip(button: Button) -> void:
	if _tooltip_owner == button and not button.has_focus():
		_tooltip_owner = null
		_tooltip.hide()

func _position_tooltip() -> void:
	if _disposed or not is_instance_valid(_tooltip_owner) or not _tooltip.visible:
		return
	var rect := _tooltip_owner.get_global_rect()
	var inverse := get_global_transform().affine_inverse()
	var first: Vector2 = inverse * rect.position
	var last: Vector2 = inverse * rect.end
	var dimensions := Vector2(290, maxf(_tooltip.get_combined_minimum_size().y, 88))
	_tooltip.size = dimensions
	var x := last.x + 18
	if x + dimensions.x > size.x - 16:
		x = first.x - dimensions.x - 18
	x = clampf(x, 16, maxf(16, size.x - dimensions.x - 16))
	var y := clampf(first.y, 16, maxf(16, size.y - dimensions.y - 16))
	_tooltip.position = Vector2(x, y)

func _show_cards(index: int) -> void:
	if _locked or _disposed or index < 0 or index >= _rewards.size() or _rewards[index].get("type") != "card":
		return
	_page = "cards"
	_card_reward_index = index
	_clear_body()
	_title.text = "选择一张牌"
	_summary.hide()
	_summary_scroll.hide()
	var options: Array = _rewards[index].options
	for i in range(options.size()):
		var id := str(options[i])
		var view := CardView.new()
		view.configure(_catalog, {"id": id, "uid": i + 1, "upgraded": false})
		view.set_meta("reward_index", index)
		view.set_meta("choice", id)
		view.pointer_pressed.connect(func(_uid: int, _pointer: Vector2): _request_claim(index, id))
		view.activation_requested.connect(func(_uid: int): _request_claim(index, id))
		view.focus_entered.connect(_set_card_hover.bind(i + 1))
		view.focus_exited.connect(_clear_card_focus.bind(i + 1))
		_body.add_child(view)
		view.set_available(true)
		_card_views.append(view)
	_skip = _button(_body, "跳过", _request_skip.bind(index))
	_skip.name = "SkipButton"
	var has_items := false
	for reward in _rewards:
		has_items = has_items or reward.get("type") not in ["card", "notice"]
	if has_items:
		_back = _button(_body, "返回奖励", _show_list)
		_back.name = "BackButton"
	_position_controls()

func _request_claim(index: int, choice: String) -> void:
	if _locked or _disposed:
		return
	set_locked(true)
	claim_requested.emit(index, choice)

func _request_skip(index: int) -> void:
	if _locked or _disposed:
		return
	set_locked(true)
	skip_requested.emit(index)

func _request_finish() -> void:
	if _locked or _disposed:
		return
	set_locked(true)
	finish_requested.emit()

func _request_menu() -> void:
	if _locked or _disposed:
		return
	set_locked(true)
	menu_requested.emit()

func _position_controls() -> void:
	if not _built or _disposed:
		return
	_title.position = Vector2(40, 76)
	_title.size = Vector2(maxf(0, size.x - 80), 58)
	var summary_width := minf(740, maxf(0, size.x - 48))
	_summary_scroll.position = Vector2(maxf(24, (size.x - 740) * 0.5), 142)
	_summary.size.x = summary_width
	var summary_height := clampf(_summary.get_combined_minimum_size().y, 28, 112)
	_summary_scroll.size = Vector2(summary_width, summary_height)
	_summary_scroll.visible = _page == "list" and not _summary.text.is_empty()
	var list_top: float = maxf(222, 142 + summary_height + 18) if _summary_scroll.visible else 222.0
	_menu.position = Vector2(maxf(16, size.x - 160), 24)
	_menu.size = Vector2(136, 44)
	if is_instance_valid(_scroll):
		_scroll.position = Vector2((size.x - 360) * 0.5, list_top)
		_scroll.size = Vector2(360, maxf(90, size.y - 120 - list_top))
		_list_panel.position = Vector2((size.x - 410) * 0.5, list_top - 16)
		_list_panel.size = Vector2(410, _scroll.size.y + 32)
	if is_instance_valid(_finish):
		_finish.position = Vector2((size.x - 260) * 0.5, size.y - 78)
		_finish.size = Vector2(260, 52)
	if is_instance_valid(_empty):
		_empty.position = Vector2(40, size.y * 0.48)
		_empty.size = Vector2(size.x - 80, 40)
	if is_instance_valid(_skip):
		_skip.position = Vector2((size.x - 180) * 0.5, size.y - 78)
		_skip.size = Vector2(180, 52)
	if is_instance_valid(_back):
		_back.position = Vector2(32, size.y - 78)
		_back.size = Vector2(160, 52)
	_layout_cards(false)
	_position_tooltip()

func _layout_cards(animated: bool) -> void:
	if _disposed or _card_views.is_empty():
		return
	var count := _card_views.size()
	_card_base_scale = minf(1.5, (size.x - 100) / (count * 150 + (count - 1) * 24))
	var gap := 36.0
	var step := CARD_SIZE.x * _card_base_scale + gap
	for i in range(count):
		var view: Control = _card_views[i]
		var uid: int = view.uid
		var center := Vector2(size.x * 0.5 + (i - (count - 1) * 0.5) * step, size.y * 0.56)
		var home := Transform2D.IDENTITY
		home.x *= _card_base_scale
		home.y *= _card_base_scale
		home.origin = center
		_card_homes[uid] = home
		var hovered := uid == _card_hover_uid
		if hovered:
			center.y -= 60
		var at := center - CARD_SIZE * 0.5
		var scale_value := Vector2.ONE * _card_base_scale * (1.12 if hovered else 1.0)
		view.z_index = 10 if hovered else i
		view.set_emphasized(hovered)
		if _card_tweens.has(uid):
			var previous: Tween = _card_tweens[uid]
			if is_instance_valid(previous):
				previous.kill()
			_card_tweens.erase(uid)
		if animated and is_inside_tree():
			var tween := create_tween().set_parallel(true)
			_card_tweens[uid] = tween
			tween.tween_property(view, "position", at, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(view, "scale", scale_value, 0.16)
		else:
			view.position = at
			view.scale = scale_value

func _set_card_hover(uid: int) -> void:
	if _locked or _disposed or uid == _card_hover_uid:
		return
	_card_hover_uid = uid
	_layout_cards(true)

func _clear_card_focus(uid: int) -> void:
	if _card_hover_uid == uid:
		_set_card_hover(-1)

func _stop_card_tweens() -> void:
	for tween in _card_tweens.values():
		if is_instance_valid(tween):
			tween.kill()
	_card_tweens.clear()

func _card_at(pointer: Vector2) -> int:
	if _card_hover_uid >= 0:
		for view in _card_views:
			if view.uid == _card_hover_uid:
				var point: Vector2 = view.get_transform().affine_inverse() * pointer
				if Rect2(Vector2.ZERO, CARD_SIZE).has_point(point):
					return _card_hover_uid
	for view in _card_views:
		var point: Vector2 = _card_homes[view.uid].affine_inverse() * pointer
		if Rect2(-CARD_SIZE * 0.5, CARD_SIZE).has_point(point):
			return view.uid
	return -1

func _input(event: InputEvent) -> void:
	if _locked or _disposed or _page != "cards" or not is_visible_in_tree():
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var uid := _card_at(pointer)
		if event is InputEventMouseMotion:
			_set_card_hover(uid)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and uid >= 0:
			for view in _card_views:
				if view.uid == uid:
					get_viewport().set_input_as_handled()
					_request_claim(_card_reward_index, str(view.card.id))
					return
