extends Control

const Catalog = preload("res://scripts/v2/catalog.gd")
const Run = preload("res://scripts/v2/run.gd")
const Combat = preload("res://scripts/v2/combat.gd")
const MapScrollView = preload("res://scripts/v2/map_scroll_view.gd")
const SaveStore = preload("res://scripts/v2/save_store.gd")
const BattleView = preload("res://scripts/v2/battle_view.gd")
const RewardView = preload("res://scripts/v2/reward_view.gd")
const ShopView = preload("res://scripts/v2/shop_view.gd")
const DeckView = preload("res://scripts/v2/deck_view.gd")
const CompendiumView = preload("res://scripts/v2/compendium_view.gd")
const CompendiumHub = preload("res://scripts/v2/compendium_hub.gd")
const ItemCompendiumView = preload("res://scripts/v2/item_compendium_view.gd")
const RunNavigation = preload("res://scripts/v2/run_navigation.gd")
const RelicGrid = preload("res://scripts/v2/relic_grid.gd")
const RunStatus = preload("res://scripts/v2/run_status.gd")
const PaperMenuTheme = preload("res://scripts/v2/paper_menu_theme.gd")
const CharacterSelectView = preload("res://scripts/v2/character_select_view.gd")
const SettingsPopup = preload("res://scripts/v2/settings_popup.gd")
const PaperMapBackdrop = preload("res://scripts/v2/paper_map_backdrop.gd")
const AUTO_HINT_DELAY := 8.0
const ROLES = [
	{"id": "condensation_coletta", "name": "柯莱塔", "attribute": "冷凝", "texture": "condensation", "available": true},
	{"id": "diffraction_phoebe", "name": "菲比", "attribute": "衍射", "texture": "diffraction", "available": false},
	{"id": "annihilation_chisaki", "name": "千咲", "attribute": "湮灭", "texture": "annihilation", "available": false},
	{"id": "aero_sigrika", "name": "西格莉卡", "attribute": "气动", "texture": "aero", "available": false},
	{"id": "thermal_emis", "name": "爱弥斯", "attribute": "热熔", "texture": "thermal", "available": false},
	{"id": "thermal_daniya", "name": "达妮娅", "attribute": "热熔", "texture": "daniya", "available": false},
	{"id": "conductive_kakaro", "name": "卡卡罗", "attribute": "导电", "texture": "conductive", "available": false},
]
var catalog = Catalog.new()
var run_state
var combat
var chosen: Array = ["condensation", "thermal", "conductive", "aero"]
var attribute_draft: Array = []
var attribute_start_run := false
var content: VBoxContainer
var modal: Control
var selection := -1
var highlights: Array = []
var notice := ""
var screen := "menu"
var resolving_ui := false
var board_buttons: Array = []
var stats_message := ""
var save_path := "user://gameplay_v2.cfg"
var legacy_save_path := "user://save.cfg"
var store
var metadata: Dictionary = {}
var battle_view
var reward_view
var map_scroll_view
var shop_view
var compendium_view
var compendium_hub
var compendium_items
var run_navigation
var run_tab := ""
var run_tab_content: Control
var run_tab_deck
var run_tab_relics
var run_tab_map
var run_status
var _status_run_id := ""
var _run_status_anchor: Control
var role_index := 0
var role_page := 0
var ui_locked := false
var session_generation := 0
var save_error := ""
var progress_dirty := false
var progress_error := ""
var settings_error := ""
var pending_settings: Dictionary = {}
var apply_display_settings := true
var idle_hint_elapsed := 0.0
const MUTED = Color("a6b6cc")
const ACCENT = Color("79dbc8")

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 18
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("223149") if state == "normal" else (Color("304964") if state == "hover" else Color("172338"))
		box.set_corner_radius_all(10)
		box.set_content_margin_all(12)
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = ACCENT
			box.set_border_width_all(2)
		skin.set_stylebox(state, "Button", box)
	skin.set_color("font_color", "Button", Color("edf4ff"))
	skin.set_color("font_disabled_color", "Button", Color("7b8ca6"))
	skin.set_color("font_color", "Label", Color("edf4ff"))
	theme = skin
	resized.connect(func(): call_deferred("_position_run_status"))
	store = SaveStore.new(save_path, legacy_save_path)
	store.load_store()
	if apply_display_settings:
		_apply_display(store.data.settings)
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_quit_game)
	_render()

func _can_auto_hint() -> bool:
	return screen == "run" and run_state != null and run_state.phase in ["battle", "boss"] and combat != null and combat.phase == "board" and not resolving_ui and not ui_locked and not is_instance_valid(modal)

func _process(delta: float) -> void:
	if is_instance_valid(_run_status_anchor) and is_instance_valid(run_status) and run_status.visible:
		_position_run_status()
	if not _can_auto_hint() or combat.auto_hint_used:
		idle_hint_elapsed = 0.0
		return
	idle_hint_elapsed += maxf(0.0, delta)
	if idle_hint_elapsed >= AUTO_HINT_DELAY:
		_hint()

func _record_player_activity() -> void:
	idle_hint_elapsed = 0.0

func _input(event: InputEvent) -> void:
	# Handle the stage's cancel action before a focused GUI control can consume it.
	if event.is_action_pressed("ui_cancel") and screen == "compendium" and is_instance_valid(compendium_hub) and not is_instance_valid(modal):
		compendium_hub.request_close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		_record_player_activity()
	elif event is InputEventMouseMotion and not event.relative.is_zero_approx():
		_record_player_activity()
	elif event is InputEventKey and event.pressed:
		_record_player_activity()

func _clear(scrolling: bool = true) -> void:
	_record_player_activity()
	if is_instance_valid(modal) and modal is SettingsPopup:
		modal.dispose()
	session_generation += 1
	resolving_ui = false
	ui_locked = false
	_clear_run_tab_content()
	if is_instance_valid(run_navigation):
		run_navigation.dispose()
	run_navigation = null
	run_tab = ""
	if is_instance_valid(battle_view):
		battle_view.dispose()
	battle_view = null
	if is_instance_valid(map_scroll_view):
		map_scroll_view.dispose()
	map_scroll_view = null
	if is_instance_valid(shop_view):
		shop_view.dispose()
	shop_view = null
	if is_instance_valid(reward_view):
		reward_view.dispose()
	reward_view = null
	if is_instance_valid(compendium_view):
		compendium_view.dispose()
	compendium_view = null
	if is_instance_valid(compendium_hub):
		compendium_hub.dispose()
	compendium_hub = null
	if is_instance_valid(compendium_items):
		compendium_items.dispose()
	compendium_items = null
	for child in get_children():
		if child == run_status:
			continue
		remove_child(child)
		child.queue_free()
	_run_status_anchor = null
	modal = null
	board_buttons.clear()
	var background := ColorRect.new()
	background.color = Color("0c1423")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if scrolling:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(scroll)
		scroll.add_child(margin)
	else:
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

func _label(parent: Node, text: String, font_size: int = 18, color: Color = Color("edf4ff")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _paragraph(parent: Node, text: String, color: Color = MUTED) -> Label:
	var label := _label(parent, text, 18, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(parent: Node, text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _box(parent: Node, width: float = 0) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("141f32")
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box

func _render() -> void:
	_sync_run_status()
	_render_page()
	_position_run_status()
	call_deferred("_position_run_status")

func _sync_run_status() -> void:
	if not is_instance_valid(run_status):
		run_status = RunStatus.new()
		run_status.name = "RunStatus"
		run_status.z_index = 110
		add_child(run_status)
	if screen != "run" or run_state == null:
		run_status.hide()
		run_status.get_hearts().cancel_animation()
		_status_run_id = ""
		return
	var current_id := str(metadata.get("run_id", ""))
	var animate := not _status_run_id.is_empty() and _status_run_id == current_id
	_status_run_id = current_id
	run_status.show()
	run_status.configure(run_state.lives, run_state.shells, animate)

func _position_run_status() -> void:
	if not is_instance_valid(run_status) or not run_status.visible:
		return
	var in_battle := is_instance_valid(battle_view)
	run_status.set_compact(false)
	if in_battle:
		var rect: Rect2 = battle_view.get_run_status_rect()
		run_status.position = battle_view.position + rect.position
		run_status.size = rect.size
	elif is_instance_valid(_run_status_anchor):
		run_status.global_position = _run_status_anchor.global_position
		run_status.size = _run_status_anchor.size
	else:
		run_status.position = Vector2(20, 14)
		run_status.size = Vector2(300, 52)

func _render_page() -> void:
	if _complete_empty_rewards():
		_checkpoint()
	if screen == "run" and run_state != null and run_state.phase in ["battle", "boss"]:
		if not is_instance_valid(battle_view):
			_clear(false)
			content.get_parent().hide()
			battle_view = BattleView.new()
			battle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(battle_view)
			battle_view.configure(self)
		battle_view.refresh()
		_show_save_banner()
		return
	if screen == "run" and run_state != null and run_state.phase == "rewards":
		_clear(false)
		content.get_parent().hide()
		_rewards_screen()
		_show_save_banner()
		return
	if screen == "run" and run_state != null and run_state.phase == "map":
		_clear(false)
		content.get_parent().hide()
		_map_screen()
		_show_save_banner()
		return
	if screen == "run" and run_state != null and run_state.phase == "shop":
		_clear(false)
		content.get_parent().hide()
		_shop_screen()
		_show_save_banner()
		return
	_clear(screen == "run" or screen == "history")
	match screen:
		"menu": _menu_screen()
		"characters": _character_screen()
		"history": _history_screen()
		"compendium": _compendium_screen()
		"compendium_cards": _card_compendium_screen()
		"compendium_supplies": _item_compendium_screen("supplies")
		"compendium_relics": _item_compendium_screen("relics")
	if screen != "run" or run_state == null:
		_show_save_banner()
		return
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	content.add_child(header)
	_run_status_anchor = Control.new()
	_run_status_anchor.name = "RunStatusAnchor"
	_run_status_anchor.custom_minimum_size = Vector2(300, 52)
	_run_status_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_run_status_anchor)
	var heading := _label(header, "晶域行旅", 28, ACCENT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "牌组 %d" % run_state.deck.size(), _show_deck)
	_button(header, "藏品 %d" % run_state.relics.size(), _show_relics)
	_button(header, "主界面", _return_menu)
	if run_state.phase == "ended":
		_summary_screen()
	elif run_state.phase == "rest":
		_rest_screen()
	elif run_state.phase == "event":
		_event_screen()
	_show_save_banner()

func _region(parent: Control, rect: Rect2) -> Control:
	var region := Control.new()
	region.anchor_left = rect.position.x
	region.anchor_top = rect.position.y
	region.anchor_right = rect.end.x
	region.anchor_bottom = rect.end.y
	parent.add_child(region)
	return region

func _fill_box(parent: Control) -> VBoxContainer:
	var box := _box(parent)
	box.get_parent().set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return box

func _portrait(parent: Node, texture_name: String, minimum: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load("res://assets/pieces/%s_base.png" % texture_name)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = minimum
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _navigate(destination: String) -> void:
	if destination == "settings":
		_show_settings()
		return
	screen = destination
	_render()

func _settings_toggle_button(callback: Callable) -> Button:
	var button := _button(self, "设置", callback)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -148
	button.offset_right = -24
	button.offset_top = 24
	button.offset_bottom = 84
	return button

func _menu_screen() -> void:
	content.get_parent().hide()
	PaperMenuTheme.add_background(self)
	var region := _region(self, Rect2(0.323, 0.574, 0.354, 0.334))
	region.name = "MenuActionsRegion"
	var actions := VBoxContainer.new()
	actions.name = "MenuActions"
	actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actions.add_theme_constant_override("separation", 12)
	region.add_child(actions)
	var start_button := _button(actions, "开始探索", func(): _navigate("characters"))
	PaperMenuTheme.style_button(start_button, 0, 28)
	var continue_button := _button(actions, "继续游戏", _continue_run, not store.has_active() and not progress_dirty)
	continue_button.tooltip_text = "继续上次探索" if not continue_button.disabled else "暂无可继续的探索"
	PaperMenuTheme.style_button(continue_button, 1, 26)
	var history_button := _button(actions, "查看历史探索记录", func(): _navigate("history"))
	PaperMenuTheme.style_button(history_button, 2, 20)
	for button in [start_button, continue_button, history_button]:
		button.custom_minimum_size.y = 72
	var settings_button := _settings_toggle_button(_show_settings)
	settings_button.name = "MenuSettingsButton"
	PaperMenuTheme.style_button(settings_button, 3)
	settings_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	PaperMenuTheme.add_corner_icon(settings_button, true)
	var compendium_button := _button(self, "图鉴", func(): _navigate("compendium"))
	compendium_button.name = "MenuCompendiumButton"
	CompendiumView.layout_toggle_button(compendium_button)
	PaperMenuTheme.style_button(compendium_button, 3)
	PaperMenuTheme.add_corner_icon(compendium_button, false)
	if store.load_message != "":
		var message := _region(self, Rect2(0.04, 0.9, 0.76, 0.075))
		var backing := Panel.new()
		backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var message_style := StyleBoxFlat.new()
		message_style.bg_color = Color(0.17, 0.12, 0.23, 0.93)
		message_style.set_corner_radius_all(8)
		backing.add_theme_stylebox_override("panel", message_style)
		message.add_child(backing)
		var label := _paragraph(message, store.load_message, Color("fff1d4"))
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 12
		label.offset_right = -12
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _compendium_screen() -> void:
	content.get_parent().hide()
	compendium_hub = CompendiumHub.new()
	add_child(compendium_hub)
	var generation := session_generation
	compendium_hub.category_requested.connect(func(category: String):
		if screen == "compendium" and generation == session_generation:
			_navigate("compendium_" + category))
	compendium_hub.close_requested.connect(func():
		if screen == "compendium" and generation == session_generation:
			_navigate("menu"))

func _card_compendium_screen() -> void:
	content.get_parent().hide()
	compendium_view = CompendiumView.new()
	add_child(compendium_view)
	compendium_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	compendium_view.configure(catalog, ROLES)
	var generation := session_generation
	compendium_view.close_requested.connect(func():
		if screen == "compendium_cards" and generation == session_generation:
			_navigate("compendium"))

func _item_compendium_screen(group: String) -> void:
	content.get_parent().hide()
	compendium_items = ItemCompendiumView.new()
	compendium_items.configure(catalog, group)
	add_child(compendium_items)
	var generation := session_generation
	compendium_items.close_requested.connect(func():
		if screen == "compendium_" + group and generation == session_generation:
			_navigate("compendium"))

func _character_screen() -> void:
	content.get_parent().hide()
	var view := CharacterSelectView.new()
	add_child(view)
	view.configure(self)

func _select_role(index: int) -> void:
	if index < 0 or index >= ROLES.size() or not ROLES[index].available:
		return
	role_index = index
	_render()

func _history_screen() -> void:
	_label(content, "历史探索记录", 32, ACCENT)
	var totals: Dictionary = store.data.statistics
	_paragraph(content, "累计探索 %d 局 · 成功 %d 局 · 战胜 %d 场 · 战败 %d 场" % [totals.get("runs", 0), totals.get("wins", 0), totals.get("battles_won", 0), totals.get("battles_lost", 0)])
	if store.data.history.is_empty():
		_paragraph(content, "暂无逐局记录。旧版累计统计已保留，之后完成的探索会记录在这里。")
	for index in range(store.data.history.size()-1, -1, -1):
		var entry: Dictionary = store.data.history[index]
		var box := _box(content)
		var attributes: Array[String] = []
		for kind in entry.get("attributes", []):
			attributes.append(Catalog.NAMES.get(kind, kind))
		_label(box, "%s · 第 %d 层" % [{"victory": "探索成功", "defeat": "探索失败", "abandoned": "主动结束"}.get(entry.get("outcome", ""), "已结束"), entry.get("floor", 0)], 24, ACCENT)
		_paragraph(box, "%s → %s\n柯莱塔 · %s\n战胜 %d / 战败 %d · 贝币 %d · 牌组 %d · 藏品 %d" % [_format_time(entry.get("started_at", 0)), _format_time(entry.get("ended_at", 0)), "、".join(attributes), entry.get("battles_won", 0), entry.get("battles_lost", 0), entry.get("shells", 0), entry.get("deck_count", 0), entry.get("relic_count", 0)])
	_button(content, "返回主界面", func(): _navigate("menu"))

func _format_time(timestamp: Variant) -> String:
	return Time.get_datetime_string_from_unix_time(int(timestamp) + 8*3600).replace("T", " ") + " 北京时间" if int(timestamp) > 0 else "时间未记录"

func _show_settings() -> void:
	if screen != "menu" or is_instance_valid(modal):
		return
	var opener := get_node_or_null("MenuSettingsButton") as Button
	if opener != null: opener.grab_focus()
	var popup := SettingsPopup.new()
	modal = popup
	popup.settings_changed.connect(_save_display)
	popup.retry_requested.connect(_retry_save)
	popup.quit_requested.connect(_quit_game)
	popup.closed.connect(func():
		if modal == popup: _close_modal(true))
	add_child(popup)
	popup.update_settings(pending_settings if not pending_settings.is_empty() else store.data.settings, settings_error)
	_show_save_banner()

func _refresh_display_ui() -> void:
	if is_instance_valid(modal) and modal is SettingsPopup:
		modal.update_settings(pending_settings if not pending_settings.is_empty() else store.data.settings, settings_error)
		_show_save_banner()
	else:
		_render()

func _save_display(settings: Dictionary) -> void:
	var error: Error = store.save_settings(settings)
	if error == OK:
		pending_settings.clear()
		settings_error = ""
		if apply_display_settings:
			_apply_display(settings)
	else:
		pending_settings = settings.duplicate()
		settings_error = "显示设置保存失败（%d）。" % error
	_update_save_error()
	_refresh_display_ui()

func _apply_display(settings: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_tree().root
	window.mode = Window.MODE_FULLSCREEN if settings.get("fullscreen", false) else Window.MODE_WINDOWED
	if not settings.get("fullscreen", false):
		var requested: Vector2i = settings.get("resolution", Vector2i(1280, 720))
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
		var factor: float = minf(1.0, minf(float(usable.size.x-32)/requested.x, float(usable.size.y-64)/requested.y))
		window.size = Vector2i(Vector2(requested)*factor)
		window.position = usable.position + (usable.size-window.size)/2

func _show_attribute_dialog(start_run: bool = false) -> void:
	if screen != "characters" or not ROLES[role_index].available:
		return
	attribute_draft = chosen.duplicate()
	attribute_start_run = start_run
	_refresh_attribute_dialog()

func _refresh_attribute_dialog() -> void:
	var box := _modal("选择属性球 · 任选四种", true)
	modal.name = "AttributeDialog"
	_paragraph(box, "本局属性固定，消除属性球获得对应技能点。")
	var presets := HBoxContainer.new()
	box.add_child(presets)
	for i in range(2):
		var preset := _button(presets, catalog.data.builds[i].name, _attribute_preset.bind(i))
		preset.name = "AttributePreset%d" % i
		preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for kind in Catalog.ATTRIBUTES:
		var button := _button(grid, ("✓ " if kind in attribute_draft else "+ ") + Catalog.NAMES[kind], _toggle_attribute.bind(kind))
		button.set_meta("attribute_kind", kind)
		button.custom_minimum_size = Vector2(145, 70)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.modulate = Catalog.COLORS[kind]
	_label(box, "已选择 %d / 4" % attribute_draft.size(), 20)
	if "condensation" not in attribute_draft:
		_paragraph(box, "未选冷凝：柯莱塔初始牌组会缺少常规费用来源。仍可按此选择开始。", Color("ffce85"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	_button(actions, "取消", _close_modal).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var confirm := _button(actions, "确认并开始探索" if attribute_start_run else "确认选择", _confirm_attributes.bind(attribute_start_run), attribute_draft.size() != 4)
	confirm.name = "ConfirmAttributes"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size.y = 52

func _toggle_attribute(kind: String) -> void:
	if kind not in Catalog.ATTRIBUTES:
		return
	if kind in attribute_draft:
		attribute_draft.erase(kind)
	elif attribute_draft.size() < 4:
		attribute_draft.append(kind)
	_refresh_attribute_dialog()

func _attribute_preset(index: int) -> void:
	attribute_draft = catalog.data.builds[index].attributes.duplicate()
	_refresh_attribute_dialog()

func _confirm_attributes(start_run: bool = false) -> void:
	if screen != "characters" or attribute_draft.size() != 4:
		return
	chosen = attribute_draft.duplicate()
	_close_modal()
	_render()
	if start_run:
		_start_run()

func _start_run() -> void:
	if chosen.size() != 4 or not ROLES[role_index].available:
		return
	if progress_dirty and run_state != null and run_state.phase == "ended" and _checkpoint() != OK:
		var box := _modal("上次探索的结算尚未保存")
		_paragraph(box, save_error, Color("ffba94"))
		_button(box, "重试并开始新探索", func(): if _checkpoint() == OK: _start_run())
		_button(box, "返回", _close_modal)
		return
	if store.has_active() or progress_dirty:
		var box := _modal("开始新的探索？")
		_paragraph(box, "当前有一局未完成的探索。确认后会用新探索覆盖其进度。")
		_button(box, "确认开始新探索", _commit_run)
		_button(box, "返回", _close_modal)
		return
	_commit_run()

func _commit_run() -> void:
	run_state = Run.new()
	run_state.setup(chosen)
	combat = null
	metadata = {"run_id": "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()], "role_id": "condensation_coletta", "started_at": int(Time.get_unix_time_from_system())}
	selection = -1
	highlights.clear()
	notice = ""
	screen = "run"
	_state_changed()

func _checkpoint() -> Error:
	if run_state == null or metadata.is_empty():
		return OK
	var error: Error = store.finalize_run(run_state, metadata) if run_state.phase == "ended" else store.checkpoint(run_state, combat, metadata)
	progress_dirty = error != OK
	progress_error = "" if error == OK else "探索保存失败（%d）。当前进度仍在内存中，请重试。" % error
	_update_save_error()
	_show_save_banner()
	return error

func _state_changed() -> void:
	_close_modal()
	_complete_empty_rewards()
	_checkpoint()
	_render()

func _update_save_error() -> void:
	var errors: Array[String] = []
	if progress_error != "":
		errors.append(progress_error)
	if settings_error != "":
		errors.append(settings_error)
	save_error = "  /  ".join(errors)

func _retry_save() -> void:
	if not pending_settings.is_empty():
		_save_display(pending_settings.duplicate())
	if progress_dirty:
		_checkpoint()
	_update_save_error()
	_refresh_display_ui()

func _show_save_banner() -> void:
	var previous := get_node_or_null("SaveError")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	if save_error == "" or (is_instance_valid(modal) and modal is SettingsPopup):
		return
	var banner := Button.new()
	banner.name = "SaveError"
	banner.text = save_error + "  点击重试"
	banner.add_theme_font_size_override("font_size", 16)
	banner.modulate = Color("ffba94")
	banner.anchor_left = 0.18
	banner.anchor_right = 0.82
	banner.offset_top = 4
	banner.offset_bottom = 44
	banner.z_index = 200
	banner.pressed.connect(_retry_save)
	add_child(banner)

func _continue_run() -> void:
	_status_run_id = ""
	if progress_dirty and run_state != null:
		screen = "run"
		_render()
		if combat != null and combat.phase == "resolving":
			_resolve_board()
		return
	var restored: Dictionary = store.restore_active()
	if restored.is_empty():
		save_error = "无法恢复探索。" + store.load_message
		_render()
		return
	run_state = restored.run
	combat = restored.combat
	metadata = restored.metadata
	chosen = run_state.attributes.duplicate()
	selection = -1
	highlights.clear()
	notice = ""
	screen = "run"
	_render()
	if combat != null and combat.phase == "resolving":
		_resolve_board()

func _return_menu() -> void:
	_checkpoint()
	screen = "menu"
	_render()

func _quit_game() -> void:
	if _checkpoint() != OK:
		var box := _modal("进度未能保存")
		_paragraph(box, save_error, Color("ffba94"))
		_button(box, "重试保存并退出", _quit_game)
		_button(box, "返回游戏", _close_modal)
		return
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(modal):
			if not modal.get_meta("rainbow_choice", false):
				_close_modal()
		elif is_instance_valid(run_tab_content):
			_select_run_tab("shop" if run_state.phase == "shop" else "map")
		elif screen == "run":
			_return_menu()
		elif screen in ["compendium_cards", "compendium_supplies", "compendium_relics"]:
			_navigate("compendium")
		elif screen == "compendium" and is_instance_valid(compendium_hub):
			compendium_hub.request_close()
		elif screen != "menu":
			_navigate("menu")

func _map_screen() -> void:
	var book := PaperMapBackdrop.new()
	add_child(book)
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_scroll_view = MapScrollView.new()
	map_scroll_view.name = "MapScrollView"
	map_scroll_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_scroll_view.offset_left = 62
	map_scroll_view.offset_right = -62
	map_scroll_view.offset_top = 138
	map_scroll_view.offset_bottom = -162
	map_scroll_view.paper_backdrop = false
	add_child(map_scroll_view)
	map_scroll_view.configure(run_state)
	var generation := session_generation
	var source_view = map_scroll_view
	map_scroll_view.node_selected.connect(func(id: String):
		if generation == session_generation and source_view == map_scroll_view and screen == "run" and run_tab == "map" and source_view.is_visible_in_tree() and not is_instance_valid(modal):
			_enter_node(id))
	_run_navigation("Map")

func _run_navigation(page_name: String) -> void:
	run_tab = "shop" if page_name == "Shop" else "map"
	run_navigation = RunNavigation.new()
	run_navigation.name = page_name + "Navigation"
	add_child(run_navigation)
	run_navigation.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	run_navigation.offset_bottom = 80
	run_navigation.z_index = 100
	run_navigation.configure(run_state.lives, run_state.shells, run_state.deck.size(), run_state.relics.size(), run_tab, page_name == "Shop", page_name)
	var generation := session_generation
	var source_view = run_navigation
	run_navigation.tab_selected.connect(func(id: String):
		if generation == session_generation and source_view == run_navigation:
			_select_run_tab(id))
	run_navigation.menu_requested.connect(func():
		if generation == session_generation and source_view == run_navigation and screen == "run":
			_return_menu())

func _clear_run_tab_content() -> void:
	if is_instance_valid(run_tab_deck):
		run_tab_deck.dispose()
	run_tab_deck = null
	if is_instance_valid(run_tab_relics):
		run_tab_relics.dispose()
	run_tab_relics = null
	if is_instance_valid(run_tab_map):
		run_tab_map.dispose()
	run_tab_map = null
	if is_instance_valid(run_tab_content):
		remove_child(run_tab_content)
		run_tab_content.queue_free()
	run_tab_content = null

func _sync_run_tab_visibility() -> void:
	if is_instance_valid(map_scroll_view):
		map_scroll_view.visible = run_tab == "map"
		map_scroll_view.set_locked(run_tab != "map" or is_instance_valid(modal))
	if is_instance_valid(shop_view):
		shop_view.visible = run_tab == "shop"
		shop_view.set_locked(run_tab != "shop" or is_instance_valid(modal))

func _select_run_tab(tab_id: String) -> void:
	if screen != "run" or run_state == null or run_state.phase not in ["map", "shop"] or not is_instance_valid(run_navigation):
		return
	if is_instance_valid(modal) or tab_id not in ["map", "deck", "relics", "shop"] or (tab_id == "shop" and run_state.phase != "shop"):
		run_navigation.set_selected(run_tab)
		return
	if tab_id == run_tab:
		run_navigation.set_selected(run_tab)
		return
	_record_player_activity()
	_clear_run_tab_content()
	run_tab = tab_id
	run_navigation.set_selected(run_tab)
	_sync_run_tab_visibility()
	if (run_tab == "map" and run_state.phase == "map") or run_tab == "shop":
		return
	run_tab_content = Control.new()
	run_tab_content.name = "RunTabContent"
	add_child(run_tab_content)
	run_tab_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	run_tab_content.offset_top = 80
	var background := ColorRect.new()
	background.color = Color("0c1423")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_tab_content.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if run_tab == "map":
		run_tab_map = MapScrollView.new()
		run_tab_map.name = "RunTabMap"
		run_tab_content.add_child(run_tab_map)
		run_tab_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		run_tab_map.configure(run_state)
		return
	var margin := MarginContainer.new()
	run_tab_content.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	if run_tab == "deck":
		run_tab_deck = DeckView.new()
		margin.add_child(run_tab_deck)
		run_tab_deck.configure(catalog, run_state.deck)
		return
	if run_tab == "relics":
		run_tab_relics = _relic_grid(margin)
		return

func _enter_node(id: String) -> void:
	if not run_state.enter_node(id):
		return
	selection = -1
	highlights.clear()
	notice = ""
	if run_state.phase in ["battle", "boss"]:
		combat = Combat.new()
		combat.setup(run_state.deck, run_state.attributes, run_state.relics, run_state.enemy_for_node())
	_state_changed()

func _click_cell(index: int) -> void:
	if combat == null or screen != "run" or combat.phase != "board" or resolving_ui or ui_locked or index < 0 or index >= combat.board.cells.size():
		return
	_record_player_activity()
	highlights.clear()
	notice = ""
	if selection < 0:
		selection = index
	elif selection == index:
		if combat.board.cells[index] != null and combat.board.cells[index].special != "":
			_activate_selected()
			return
		selection = -1
	elif combat.board.adjacent(selection, index):
		var from := selection
		var before_cells: Array = combat.board.cells.duplicate(true)
		if combat.start_swap(from, index):
			selection = -1
			notice = ""
			_checkpoint()
			_resolve_board(before_cells, [from, index])
			return
		else:
			notice = "本次交换没有形成消除，不消耗行动。"
			selection = -1
			_animate_invalid_swap(before_cells, from, index)
			return
	else:
		selection = index
	_render()

func _activate_selected() -> void:
	if ui_locked or resolving_ui or combat == null or screen != "run" or combat.phase != "board":
		return
	_record_player_activity()
	if combat.start_activate(selection):
		selection = -1
		highlights.clear()
		notice = ""
		_checkpoint()
		_resolve_board()

func _hint() -> void:
	if not _can_auto_hint() or combat.auto_hint_used:
		return
	var targets: Array = combat.board.hint()
	if targets.is_empty():
		idle_hint_elapsed = 0.0
		return
	combat.auto_hint_used = true
	highlights = targets
	notice = "白圈是一组可用行动。"
	_checkpoint()
	_render()

func _animate_invalid_swap(before_cells: Array, a: int, b: int) -> void:
	var generation := session_generation
	ui_locked = true
	if is_instance_valid(battle_view):
		battle_view.set_locked(true)
		await battle_view.animate_invalid_swap(before_cells, a, b)
	if generation != session_generation or screen != "run":
		return
	ui_locked = false
	if is_instance_valid(battle_view):
		battle_view.finish_board_animation()
		battle_view.set_locked(false)
	_render()

func _resolve_board(swap_before: Array = [], swap_indices: Array = []) -> void:
	if resolving_ui or combat == null or screen != "run":
		return
	resolving_ui = true
	ui_locked = true
	var generation := session_generation
	var current_combat = combat
	if is_instance_valid(battle_view):
		battle_view.set_locked(true)
	while current_combat.phase == "resolving":
		if generation != session_generation or screen != "run" or current_combat != combat:
			return
		if current_combat.board.pending_rainbow:
			resolving_ui = false
			ui_locked = false
			if is_instance_valid(battle_view):
				battle_view.finish_board_animation()
				battle_view.set_locked(false)
			_show_rainbow_choice()
			return
		var before_cells: Array = current_combat.board.cells.duplicate(true)
		var step: Dictionary = current_combat.advance_board()
		_checkpoint()
		if is_instance_valid(battle_view):
			await battle_view.animate_board_step(before_cells, step, swap_before, swap_indices)
		if generation != session_generation or screen != "run" or current_combat != combat:
			return
		swap_before = []
		swap_indices = []
		_render()
		if current_combat.phase != "resolving":
			break
	if generation != session_generation:
		return
	resolving_ui = false
	ui_locked = false
	if is_instance_valid(battle_view):
		battle_view.finish_board_animation()
		battle_view.set_locked(false)
	_render()

func _show_rainbow_choice() -> void:
	if not combat.board.legacy_rainbow_choice:
		return
	var generation := session_generation
	var box := _modal("旧版彩虹进度 · 完成此前的选择")
	modal.set_meta("rainbow_choice", true)
	_paragraph(box, "这次彩虹已在旧规则下触发。完成此前的选择后，后续彩虹将自动按交换对象或自身球种消除。")
	for kind in combat.board.kinds:
		_button(box, Catalog.NAMES[kind], func():
			if generation == session_generation and combat.board.choose_rainbow(kind):
				_close_modal()
				_checkpoint()
				_resolve_board())
	_button(box, "保存并返回主界面", _return_menu)

func _play_card(index: int) -> void:
	if combat != null and index >= 0 and index < combat.hand.size():
		_play_card_uid(int(combat.hand[index].uid))

func _play_card_uid(uid: int) -> void:
	if ui_locked or screen != "run" or combat == null:
		return
	var index := -1
	for i in range(combat.hand.size()):
		if int(combat.hand[i].uid) == uid:
			index = i
			break
	if not combat.can_play(index):
		return
	var generation := session_generation
	var before := _feedback_snapshot()
	ui_locked = true
	if is_instance_valid(battle_view):
		battle_view.set_locked(true)
	if not combat.play_card(index):
		ui_locked = false
		_render()
		return
	if combat.phase == "ended":
		run_state.finish_battle(combat.result == "victory")
	_checkpoint()
	if is_instance_valid(battle_view):
		await battle_view.animate_card(uid)
		if generation != session_generation:
			return
		await battle_view.animate_feedback(before)
	if generation != session_generation:
		return
	ui_locked = false
	if screen == "run" and run_state.phase in ["battle", "boss"] and is_instance_valid(battle_view):
		battle_view.refresh(uid)
		battle_view.set_locked(false)
	else:
		_render()

func _feedback_snapshot() -> Dictionary:
	return {"hp": combat.hp, "guard": combat.guard, "enemy_hp": combat.enemy_hp, "enemy_guard": combat.enemy_guard}

func _end_turn() -> void:
	if ui_locked or combat == null or screen != "run" or combat.phase != "play":
		return
	_record_player_activity()
	var generation := session_generation
	var before := _feedback_snapshot()
	ui_locked = true
	if is_instance_valid(battle_view):
		battle_view.hand_view.set_locked(true)
		battle_view.hand_view.set_collapsed(true)
	if not combat.end_turn():
		ui_locked = false
		_render()
		return
	selection = -1
	highlights.clear()
	notice = ""
	if combat.phase == "ended":
		run_state.finish_battle(combat.result == "victory")
	_checkpoint()
	if is_instance_valid(battle_view):
		battle_view.set_locked(true)
		await battle_view.animate_feedback(before)
	if generation != session_generation:
		return
	ui_locked = false
	_render()
	if is_instance_valid(battle_view):
		battle_view.set_locked(false)

func _after_combat_action() -> void:
	if combat.phase == "ended":
		run_state.finish_battle(combat.result == "victory")
	_state_changed()

func _use_supply(index: int) -> void:
	if ui_locked:
		return
	var id: String = run_state.supplies[index]
	if id == "energy_vial":
		var box := _modal("选择获得 3 点技能点的属性")
		for kind in Catalog.ATTRIBUTES:
			_button(box, Catalog.NAMES[kind], _consume_supply.bind(index, kind))
		_button(box, "取消", _close_modal)
	else:
		_consume_supply(index, "")

func _consume_supply(index: int, kind: String) -> void:
	if index >= 0 and index < run_state.supplies.size() and combat.use_supply(run_state.supplies[index], kind):
		run_state.supplies.remove_at(index)
		_state_changed()

func _rest_screen() -> void:
	var box := _box(content)
	_label(box, "休整站  /  选择一项", 30)
	_paragraph(box, "只影响本次探索。战斗生命会在下场战斗开始时自动回满。")
	_button(box, "恢复 1 点探索生命", func(): run_state.rest_heal(); _state_changed(), run_state.lives >= 3)
	_button(box, "永久移除一张牌", func(): _choose_deck(false), run_state.deck.is_empty())
	_button(box, "升级一张牌", func(): _choose_deck(true))
	_button(box, "跳过并继续", _complete_node)

func _choose_deck(upgrade: bool, price: int = 0) -> void:
	if not _can_modify_deck(upgrade, price):
		return
	var box := _modal("选择升级一张牌 · 以下显示升级后效果" if upgrade else "选择永久移除一张牌", false, false)
	if price > 0:
		_paragraph(box, "选定后支付 %d 贝币。" % price)
	var previews: Array = []
	var candidates: Dictionary = {}
	for card in run_state.deck:
		if upgrade and card.upgraded:
			continue
		candidates[int(card.uid)] = card.duplicate(true)
		var preview: Dictionary = card.duplicate(true)
		if upgrade:
			preview.upgraded = true
		previews.append(preview)
	var reason := "贝币不足：需要 %d 贝币。" % price if run_state.shells < price else ""
	var view := _deck_grid(box, previews, true, reason, "没有符合条件的牌。")
	var context := {
		"generation": session_generation, "run": run_state, "modal": modal, "view": view,
		"phase": run_state.phase, "current": run_state.current, "event_id": run_state.event_id,
		"cards": candidates,
	}
	view.card_selected.connect(_select_deck_card.bind(upgrade, price, context))
	_deck_close_button(box)

func _can_modify_deck(upgrade: bool, price: int) -> bool:
	if screen != "run" or run_state == null or price < 0:
		return false
	if run_state.phase == "rest":
		return price == 0
	return run_state.phase == "event" and ((run_state.event_id == "workbench" and upgrade and price == 15) or (run_state.event_id == "prune" and not upgrade and price == 0))

func _select_deck_card(uid: int, upgrade: bool, price: int, context: Dictionary) -> void:
	if context.generation != session_generation or context.run != run_state or not is_instance_valid(context.modal) or context.modal != modal or not is_instance_valid(context.view) or not context.modal.is_ancestor_of(context.view) or not _can_modify_deck(upgrade, price):
		return
	if run_state.phase != context.phase or run_state.current != context.current or run_state.event_id != context.event_id:
		return
	var index := -1
	for i in range(run_state.deck.size()):
		if int(run_state.deck[i].uid) == uid:
			index = i
			break
	if index < 0 or not context.cards.has(uid) or run_state.deck[index] != context.cards[uid]:
		context.view.set_locked(false)
		return
	if run_state.modify_deck(index, upgrade, price):
		_state_changed()
	else:
		context.view.set_locked(false)

func _shop_screen() -> void:
	shop_view = ShopView.new()
	shop_view.name = "ShopView"
	shop_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_view.offset_top = 80
	add_child(shop_view)
	var generation := session_generation
	var source_run = run_state
	var source_view = shop_view
	var stock: Array = run_state.stock.duplicate(true)
	shop_view.buy_requested.connect(func(index: int):
		if index >= 0 and index < stock.size() and _valid_shop_context(generation, index, stock[index], source_run, source_view):
			_buy(index)
		elif is_instance_valid(source_view) and source_view == shop_view:
			source_view.set_locked(run_tab != "shop" or is_instance_valid(modal)))
	shop_view.leave_requested.connect(func():
		if generation == session_generation and source_run == run_state and source_view == shop_view and source_view.is_visible_in_tree() and run_tab == "shop" and screen == "run" and run_state.phase == "shop" and not is_instance_valid(modal):
			_complete_node())
	shop_view.configure(catalog, stock, run_state.shells)
	_run_navigation("Shop")

func _valid_shop_context(generation: int, index: int, expected: Dictionary, source_run, source_view) -> bool:
	return generation == session_generation and source_run == run_state and is_instance_valid(source_view) and source_view == shop_view and source_view.is_visible_in_tree() and run_tab == "shop" and screen == "run" and run_state != null and run_state.phase == "shop" and index >= 0 and index < run_state.stock.size() and run_state.stock[index] == expected

func _buy(index: int) -> void:
	if screen != "run" or run_state == null or run_state.phase != "shop" or is_instance_valid(modal) or index < 0 or index >= run_state.stock.size():
		return
	if is_instance_valid(run_navigation) and run_tab != "shop":
		return
	var item: Dictionary = run_state.stock[index]
	if item.sold or run_state.shells < item.price:
		if is_instance_valid(shop_view):
			shop_view.set_locked(false)
		return
	if item.type == "supply" and run_state.supplies.size() >= 3:
		var generation := session_generation
		var expected: Dictionary = item.duplicate(true)
		var source_run = run_state
		var source_view = shop_view
		var box := _modal("补给已满 · 选择替换一格", true)
		var source_modal: Control = modal
		_paragraph(box, "购买 %s · %d 贝币" % [catalog.supplies[item.id].name, item.price])
		for slot in range(run_state.supplies.size()):
			_button(box, "替换 " + catalog.supplies[run_state.supplies[slot]].name, _replace_shop_supply.bind(generation, index, expected, source_run, source_view, slot, source_modal))
		_button(box, "取消", _close_modal)
	elif run_state.buy(index):
		_state_changed()
	elif is_instance_valid(shop_view):
		shop_view.set_locked(false)

func _replace_shop_supply(generation: int, index: int, expected: Dictionary, source_run, source_view, slot: int, source_modal: Control) -> void:
	if not is_instance_valid(source_modal) or modal != source_modal or not _valid_shop_context(generation, index, expected, source_run, source_view) or slot < 0 or slot >= run_state.supplies.size():
		return
	if run_state.buy(index, slot):
		_state_changed()

func _event_screen() -> void:
	var data: Dictionary = {}
	for entry in catalog.data.events:
		if entry.id == run_state.event_id:
			data = entry
	var box := _box(content)
	_label(box, data.name, 30)
	_paragraph(box, "路途中遇到的一次抉择。")
	for i in range(data.choices.size()):
		var disabled: bool = i == 0 and ((run_state.event_id == "workbench" and run_state.shells < 15) or (run_state.event_id == "prune" and run_state.deck.is_empty()))
		_button(box, data.choices[i], _event_choice.bind(i), disabled)

func _event_choice(choice: int) -> void:
	if choice == 0 and run_state.event_id == "workbench":
		_choose_deck(true, 15)
	elif choice == 0 and run_state.event_id == "prune":
		_choose_deck(false)
	elif run_state.event_choice(choice):
		_state_changed()

func _complete_empty_rewards() -> bool:
	if screen != "run" or run_state == null or run_state.phase != "rewards" or is_instance_valid(modal):
		return false
	if run_state.current == "" or run_state.current in run_state.visited:
		return false
	for reward in run_state.rewards:
		if reward.get("type") != "notice" or reward.get("requires_ack", false):
			return false
	while not run_state.rewards.is_empty():
		if not run_state.accept_reward():
			return false
	if not run_state.complete_node():
		return false
	combat = null
	return true

func _rewards_screen() -> void:
	reward_view = RewardView.new()
	reward_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(reward_view)
	var generation := session_generation
	var pending: Array = run_state.rewards.duplicate(true)
	reward_view.claim_requested.connect(func(index: int, choice: String):
		if index >= 0 and index < pending.size() and _valid_reward_context(generation, index, pending[index]):
			_claim_reward(index, choice))
	reward_view.skip_requested.connect(func(index: int):
		if index >= 0 and index < pending.size() and _valid_reward_context(generation, index, pending[index]):
			_skip_reward(index))
	reward_view.finish_requested.connect(func():
		if generation == session_generation and screen == "run" and run_state.phase == "rewards":
			_finish_rewards())
	reward_view.menu_requested.connect(func():
		if generation == session_generation:
			_return_menu())
	var title := "奖励节点" if run_state.nodes[run_state.current].type == "reward" else "好东西！"
	reward_view.configure(catalog, pending, title)

func _valid_reward_context(generation: int, index: int, expected: Dictionary) -> bool:
	return generation == session_generation and screen == "run" and run_state != null and run_state.phase == "rewards" and index >= 0 and index < run_state.rewards.size() and run_state.rewards[index] == expected

func _claim_reward(index: int, choice: String, replace_index: int = -1) -> void:
	if screen != "run" or run_state == null or run_state.phase != "rewards" or is_instance_valid(modal) or index < 0 or index >= run_state.rewards.size():
		return
	var reward: Dictionary = run_state.rewards[index]
	var selected_type: String = reward.type
	var allowed := false
	if selected_type == "choice":
		for option in reward.options:
			if option.id == choice:
				selected_type = option.type
				allowed = true
				break
	else:
		allowed = choice in reward.get("options", [reward.get("id", "")])
	if not allowed or choice == "":
		if is_instance_valid(reward_view):
			reward_view.set_locked(false)
		return
	if selected_type == "supply" and run_state.supplies.size() >= 3 and replace_index < 0:
		var generation := session_generation
		var expected: Dictionary = reward.duplicate(true)
		var box := _modal("补给已满 · 选择替换一格", true)
		var replacement_modal: Control = modal
		_paragraph(box, "领取 %s\n%s" % [catalog.supplies[choice].name, catalog.supplies[choice].effect], ACCENT)
		for slot in range(run_state.supplies.size()):
			_button(box, "替换 " + catalog.supplies[run_state.supplies[slot]].name, _replace_reward_slot.bind(generation, index, expected, choice, slot, replacement_modal))
		_button(box, "取消", _close_modal)
		return
	if run_state.accept_reward_at(index, choice, replace_index):
		_state_changed()
	elif is_instance_valid(reward_view):
		reward_view.set_locked(false)

func _replace_reward_slot(generation: int, index: int, expected: Dictionary, choice: String, slot: int, source_modal: Control) -> void:
	if is_instance_valid(source_modal) and modal == source_modal and _valid_reward_context(generation, index, expected) and run_state.accept_reward_at(index, choice, slot):
		_state_changed()

func _skip_reward(index: int) -> void:
	if screen == "run" and run_state != null and run_state.phase == "rewards" and not is_instance_valid(modal) and run_state.accept_reward_at(index):
		_state_changed()

func _finish_rewards() -> void:
	if screen != "run" or run_state == null or run_state.phase != "rewards" or is_instance_valid(modal):
		return
	while not run_state.rewards.is_empty():
		if not run_state.accept_reward():
			return
	_complete_node()

func _complete_node() -> void:
	if run_state.complete_node():
		combat = null
		_state_changed()

func _summary_screen() -> void:
	var box := _box(content)
	_label(box, "探索成功" if run_state.outcome == "victory" else ("探索已结束" if run_state.outcome == "abandoned" else "探索失败"), 42, ACCENT)
	_paragraph(box, "你击败了晶壳统御者。" if run_state.outcome == "victory" else "本次旅程到此结束。可以重新选择四种属性，再次出发。")
	_label(box, "胜利 %d 场    战败 %d 场    牌组 %d 张    藏品 %d 件" % [run_state.battles_won, run_state.battles_lost, run_state.deck.size(), run_state.relics.size()], 22)
	if progress_error != "":
		_paragraph(box, progress_error, Color("ffba94"))
	_button(box, "重新出发", func(): _navigate("characters"))
	_button(box, "返回主界面", _return_menu)

func _modal(title: String, compact: bool = false, scrolling: bool = true) -> VBoxContainer:
	_record_player_activity()
	_close_modal(true)
	if is_instance_valid(run_tab_deck):
		run_tab_deck.set_locked(true)
	if is_instance_valid(run_tab_relics):
		run_tab_relics.set_locked(true)
	if is_instance_valid(run_tab_map):
		run_tab_map.set_locked(true)
	if is_instance_valid(map_scroll_view):
		map_scroll_view.set_locked(true)
	if is_instance_valid(shop_view):
		shop_view.set_locked(true)
	if is_instance_valid(battle_view):
		battle_view.hand_view.cancel_interaction()
		battle_view.hand_view.set_locked(true)
	if is_instance_valid(reward_view):
		reward_view.set_locked(true)
	modal = Control.new()
	modal.z_index = 300
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	if compact:
		shade.color.a = 0.72
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		modal.add_child(center)
		var dialog_box := _box(center, 640)
		_label(dialog_box, title, 26, ACCENT)
		return dialog_box
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 70 if scrolling else 32)
	modal.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	if scrolling:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		margin.add_child(scroll)
		scroll.add_child(box)
	else:
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(box)
	_label(box, title, 30, ACCENT)
	return box

func _close_modal(immediate: bool = false) -> void:
	_record_player_activity()
	var was_settings := is_instance_valid(modal) and modal is SettingsPopup
	if is_instance_valid(modal) and modal is SettingsPopup:
		if not immediate:
			modal.request_close()
			return
		modal.dispose()
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null
	if was_settings: _show_save_banner()
	if is_instance_valid(run_tab_deck):
		run_tab_deck.set_locked(false)
	if is_instance_valid(run_tab_relics):
		run_tab_relics.set_locked(false)
	if is_instance_valid(run_tab_map):
		run_tab_map.set_locked(false)
	if is_instance_valid(map_scroll_view):
		map_scroll_view.set_locked(false)
	if is_instance_valid(shop_view):
		shop_view.set_locked(false)
	if is_instance_valid(battle_view):
		battle_view.hand_view.set_locked(ui_locked)
	if is_instance_valid(reward_view):
		reward_view.set_locked(false)
	if is_instance_valid(run_navigation):
		_sync_run_tab_visibility()

func _show_deck() -> void:
	if screen != "run" or run_state == null:
		return
	var box := _modal("本局牌组 · %d 张" % run_state.deck.size(), false, false)
	_deck_grid(box, run_state.deck)
	_deck_close_button(box)

func _deck_grid(parent: Node, cards: Array, selectable: bool = false, reason: String = "", empty_text: String = "牌组为空。") -> DeckView:
	var view := DeckView.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(view)
	var preview_combat = combat if run_state != null and run_state.phase in ["battle", "boss"] else null
	view.configure(catalog, cards, selectable, reason, preview_combat)
	view.set_empty_text(empty_text)
	modal.tree_exiting.connect(view.dispose)
	return view

func _deck_close_button(box: VBoxContainer) -> Button:
	var button := _button(box, "返回", _close_modal)
	button.name = "CloseDeckButton"
	button.custom_minimum_size.y = 52
	return button

func _show_relics() -> void:
	var box := _modal("本局藏品", false, false)
	var view := _relic_grid(box)
	modal.tree_exiting.connect(view.dispose)
	_deck_close_button(box)

func _relic_grid(parent: Node) -> RelicGrid:
	var view := RelicGrid.new()
	parent.add_child(view)
	var entries: Array = []
	for i in range(run_state.relics.size()):
		entries.append({"id": str(run_state.relics[i]), "uid": i + 1, "upgraded": false})
	view.configure(catalog, entries)
	view.set_empty_text("尚未获得藏品。")
	return view

func _show_map() -> void:
	var box := _modal("章节路线", true)
	var map := MapScrollView.new()
	map.name = "RouteMapScrollView"
	map.custom_minimum_size = Vector2(604, 440)
	map.configure(run_state)
	box.add_child(map)
	modal.tree_exiting.connect(map.dispose)
	_button(box, "返回战斗", _close_modal)

func _show_piles() -> void:
	if combat == null or screen != "run":
		return
	var box := _modal("抽牌堆与弃牌堆", false, false)
	var tabs := TabContainer.new()
	tabs.name = "PileTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("141f32")
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(8)
	tabs.add_theme_stylebox_override("panel", panel_style)
	for state in ["tab_selected", "tab_unselected", "tab_hovered"]:
		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color = Color("223149") if state == "tab_selected" else Color("172338")
		tab_style.set_corner_radius_all(8)
		tab_style.set_content_margin_all(12)
		tabs.add_theme_stylebox_override(state, tab_style)
	tabs.add_theme_color_override("font_selected_color", ACCENT)
	tabs.add_theme_color_override("font_unselected_color", MUTED)
	box.add_child(tabs)
	for group_index in range(2):
		var group: Array = (combat.draw_pile if group_index == 0 else combat.discard).duplicate(true)
		group.sort_custom(func(a: Dictionary, b: Dictionary):
			var a_name := str(catalog.cards[a.id].name) + (" +" if a.upgraded else "")
			var b_name := str(catalog.cards[b.id].name) + (" +" if b.upgraded else "")
			return int(a.uid) < int(b.uid) if a_name == b_name else a_name < b_name)
		var page := VBoxContainer.new()
		page.name = ("抽牌堆（%d）" if group_index == 0 else "弃牌堆（%d）") % group.size()
		tabs.add_child(page)
		if group_index == 0:
			_label(page, "按名称排序，不显示抽取顺序", 18, MUTED)
		_deck_grid(page, group, false, "", "该牌堆为空。")
	_deck_close_button(box)

func _show_log() -> void:
	var box := _modal("战斗记录")
	_paragraph(box, "\n".join(combat.log_lines))
	_button(box, "返回", _close_modal)

func _show_rules() -> void:
	var box := _modal("操作与规则")
	_rules_content(box)
	_button(box, "返回", _close_modal)

func _rules_content(box: Node) -> void:
	_paragraph(box, "1. 每回合先消除一次，再出牌，最后手动结束回合。无效交换不消耗行动。消除阶段 8 秒无操作会自动出现白圈提示，每回合仅一次。\n\n2. 点击相邻两球交换。条纹、炸弹和彩虹球都可连续点击同一颗球两次直接发动。特殊球与任意相邻球交换也会发动；双特殊球各发动一次。\n\n3. 四连生成条纹，五连生成彩虹，T / L 生成炸弹。新特殊球留在棋盘，其他被移除球才提供资源。条纹清行或列，炸弹清 3×3，彩虹与哪种球交换就清除全部该球种；主动发动或被消除则清除全部自身球种。双彩虹交换各清除对方球种，无需选择。\n\n4. 四属性球提供对应技能点，经验球升级，防御球提供格挡。所有消除只提供资源。技能点不设上限，跨回合保留。\n\n5. 每回合抽 5 张；手牌全部用完立即抽至多 5 张。抽牌堆空时洗入弃牌堆。出牌只消耗卡面技能点。攻击牌直接造成伤害；能力牌打出后持续整场战斗生效；其余均为技能牌。回合结束丢弃全部剩余手牌。\n\n6. A 为当前攻击力，N 为本回合此前已出牌数。临时攻击与「下一张牌」效果在本回合结束后失效。每战等级重置为 1、技能点清零、生命回满。\n\n7. 玩家格挡在自己下回合开始清空。敌人格挡在敌人下次行动前清空。补给可在消除前或出牌阶段使用，不消耗行动。\n\n8. 普通战败扣 1 探索生命，有剩余生命时仍有奖励并能前进。首领战败生命直接归零；击败首领才算探索胜利。\n\n9. 每张卡牌只能升级一次；可自由获取无法支付费用的牌，也可删空牌组。\n\n探索进度自动保存，可从主界面继续；完成探索后记录历史和统计，旧版存档数据保留。")

func _confirm_retreat() -> void:
	if ui_locked:
		return
	var box := _modal("从本场战斗撤退？")
	_paragraph(box, "撤退按战败结算。" + ("这是首领战，探索生命将直接归零。" if run_state.phase == "boss" else "消耗 1 点探索生命；有剩余生命时继续探索。"))
	_button(box, "确认撤退", func(): combat.phase = "ended"; combat.result = "defeat"; _after_combat_action())
	_button(box, "继续战斗", _close_modal)

func _confirm_abandon() -> void:
	var box := _modal("结束本次探索？")
	_paragraph(box, "本局卡牌、贝币和藏品不会带入下一局。")
	_button(box, "结束探索", func(): run_state.end_run("abandoned"); _state_changed())
	_button(box, "继续探索", _close_modal)
