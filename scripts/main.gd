extends Control

const BoardModelScript := preload("res://scripts/game/board_model.gd")
const SaveManagerScript := preload("res://scripts/game/save_manager.gd")
const RunMapCanvasScript := preload("res://scripts/ui/run_map_canvas.gd")
const SLOT_ATTRIBUTES: Array[String] = ["衍射", "湮灭", "冷凝", "气动", "热熔", "导电"]
const RESONANCE_MAX_VALUES: Array[int] = [30, 45, 35, 40, 35, 50]
const SWAP_ANIM_SECONDS := 0.28
const CLEAR_ANIM_SECONDS := 0.46
const DROP_BASE_SECONDS := 0.24
const DROP_SECONDS_PER_ROW := 0.12
const DROP_COLUMN_STAGGER_SECONDS := 0.035
const DROP_SPAWN_DELAY_SECONDS := 0.10
const DROP_SPAWN_EXTRA_ROWS := 2
const DROP_LANDING_OVERSHOOT := 9.0
const DROP_SETTLE_SECONDS := 0.10
const POST_CLEAR_PAUSE_SECONDS := 0.12
const POST_DROP_PAUSE_SECONDS := 0.12
const ROSTER_SLOT_SIZE := 156.0
const MAIN_MENU_ROSTER_SLOT_SIZE := 190.0
const PIECE_CARD_SIZE := 260.0
const BATTLE_ROSTER_SLOT_SIZE := 156.0
const BOSS_MAX_HP := 300
const BOSS_SEGMENTS := 3
const BOSS_DAMAGE_PER_PIECE := 6
const ATTACK_FLY_SECONDS := 0.42
const ATTACK_FLY_STAGGER_SECONDS := 0.025
const RUN_MAX_LIVES := 3
const RUN_TOTAL_FLOORS := 5
const RUN_MAP_ROWS := 5
const RUN_MAP_MIN_LANES := 2
const RUN_MAP_MAX_LANES := 3
const RUN_PRE_BOSS_MIN_SUPPLIES := 3
const RUN_PRE_BOSS_MAX_SUPPLIES := 5
const RUN_MIN_SHOPS := 2
const RUN_MAX_SHOPS := 3

var catalog: PieceCatalog = PieceCatalog.new()
var save: SaveManager
var board: BoardModel
var current_boss: Resource
var selected_cell: Vector2i = Vector2i(-1, -1)
var current_roster: PackedStringArray = PackedStringArray()
var score: int = 0
var combo: int = 0
var max_combo: int = 0
var boss_hp: int = BOSS_MAX_HP
var boss_max_hp: int = BOSS_MAX_HP
var moves_since_enemy: int = 0
var skip_bonus_pending: bool = false
var suppress_next_enemy_effect: bool = false
var resonance_values: Array[int] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stats: Dictionary = {
	"normal": 0,
	"special": 0,
	"combo": 0,
}
var run_active: bool = false
var run_state: Dictionary = {}
var current_run_node: Dictionary = {}
var pending_run_reward_items: Array = []

@onready var root: VBoxContainer = VBoxContainer.new()
var page: PanelContainer
var content_margin: MarginContainer
var screen_title: Label
var board_grid: GridContainer
var board_area: CenterContainer
var score_label: Label
var combo_label: Label
var boss_label: Label
var boss_name_label: Label
var boss_avatar: Label
var boss_avatar_texture: TextureRect
var boss_hp_label: Label
var boss_hp_segments: HBoxContainer
var boss_status_text: String = "团子大魔王：观察中"
var roster_bar: HBoxContainer
var current_screen: String = ""
var roster_slot_buttons: Array = []
var selected_roster_slot: int = 0
var has_selected_roster_slot: bool = false
var preserve_roster_slot_selection: bool = false
var roster_detail_label: Label
var is_animating_board: bool = false
var cheat_panel: PanelContainer
var cheat_cell_label: Label
var cheat_x_spin: SpinBox
var cheat_y_spin: SpinBox
var cheat_piece_option: OptionButton
var cheat_effect_option: OptionButton
var cheat_direction_option: OptionButton
var cheat_lock_spin: SpinBox
var cheat_pick_cell_pending: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	_apply_global_theme()
	rng.randomize()
	catalog.load_all()
	save = SaveManagerScript.new()
	save.load_save(catalog.get_default_roster())
	current_roster = _sanitize_roster(save.roster_ids)
	if save.roster_ids != current_roster:
		save.roster_ids = current_roster
		save.save()
	_ensure_default_pieces_in_bag()
	_build_root()
	_show_main_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		if current_screen == "game" and board != null:
			_toggle_cheat_panel()
			get_viewport().set_input_as_handled()

func _apply_global_theme() -> void:
	var theme: Theme = Theme.new()
	theme.set_font_size("font_size", "Label", 26)
	theme.set_font_size("font_size", "Button", 26)
	theme.set_font_size("font_size", "CheckButton", 24)
	theme.set_font_size("font_size", "OptionButton", 24)
	theme.set_font_size("font_size", "HSlider", 24)
	theme.set_font_size("font_size", "GridContainer", 24)
	theme.set_font_size("font_size", "PanelContainer", 24)
	set_theme(theme)

func _build_root() -> void:
	page = PanelContainer.new()
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.size = get_viewport_rect().size
	page.custom_minimum_size = get_viewport_rect().size
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin = MarginContainer.new()
	page.add_child(content_margin)
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.size = get_viewport_rect().size
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 28)
	content_margin.add_theme_constant_override("margin_top", 32)
	content_margin.add_theme_constant_override("margin_right", 28)
	content_margin.add_theme_constant_override("margin_bottom", 32)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(root)
	root.add_theme_constant_override("separation", 14)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, get_viewport_rect().size.y - 64.0)

func _clear_screen() -> void:
	if cheat_panel != null:
		cheat_panel.queue_free()
	cheat_panel = null
	cheat_cell_label = null
	cheat_x_spin = null
	cheat_y_spin = null
	cheat_piece_option = null
	cheat_effect_option = null
	cheat_direction_option = null
	cheat_lock_spin = null
	cheat_pick_cell_pending = false
	_set_page_margins(28, 32, 28, 32)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	selected_cell = Vector2i(-1, -1)

func _add_title(text: String) -> Label:
	screen_title = Label.new()
	screen_title.text = text
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title.add_theme_font_size_override("font_size", 34)
	screen_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(screen_title)
	return screen_title

func _make_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _make_menu_button(text: String, callback: Callable) -> Button:
	var button: Button = _make_button(text, callback)
	button.custom_minimum_size = Vector2(0, 92)
	button.add_theme_font_size_override("font_size", 32)
	return button

func _show_main_menu() -> void:
	_clear_screen()
	current_screen = "menu"
	var viewport_size: Vector2 = get_viewport_rect().size
	var menu_margin_x: int = roundi(clamp(viewport_size.x * 0.02, 16.0, 48.0))
	var menu_margin_y: int = roundi(clamp(viewport_size.y * 0.025, 12.0, 36.0))
	_set_page_margins(menu_margin_x, menu_margin_y, menu_margin_x, menu_margin_y)
	root.add_theme_constant_override("separation", 0)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var roster_grid_width: float = _roster_slot_size() * 3.0 + 24.0
	var menu_layout: HBoxContainer = HBoxContainer.new()
	menu_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_layout.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.035, 28.0, 72.0)))
	menu_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(menu_layout)
	var roster_center: CenterContainer = CenterContainer.new()
	roster_center.custom_minimum_size = Vector2(roster_grid_width + 24.0, _roster_slot_size() * 2.0 + 24.0)
	roster_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	roster_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layout.add_child(roster_center)
	roster_slot_buttons = []
	roster_center.add_child(_make_roster_slots_bar(func(slot_index: int) -> void:
		selected_roster_slot = slot_index
		has_selected_roster_slot = true
		preserve_roster_slot_selection = true
		_show_roster_select()
	))
	var actions: VBoxContainer = VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	actions.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.28, 260.0, 520.0), 0)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_layout.add_child(actions)
	screen_title = Label.new()
	screen_title.text = "团子三消"
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title.add_theme_font_size_override("font_size", 60)
	screen_title.custom_minimum_size = Vector2(0, 92)
	actions.add_child(screen_title)
	var subtitle: Label = Label.new()
	subtitle.text = "最高分：%d" % save.high_score
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	actions.add_child(subtitle)
	actions.add_child(_make_spacer(16))
	actions.add_child(_make_menu_button("开始探索", Callable(self, "_start_run")))
	actions.add_child(_make_menu_button("开始游戏", Callable(self, "_start_game")))
	actions.add_child(_make_menu_button("设置", func() -> void: _show_settings(Callable(self, "_show_main_menu"))))

func _show_roster_select() -> void:
	_clear_screen()
	current_screen = "roster"
	var viewport_size: Vector2 = get_viewport_rect().size
	var roster_margin_x: int = roundi(clamp(viewport_size.x * 0.02, 14.0, 32.0))
	var roster_margin_y: int = roundi(clamp(viewport_size.y * 0.02, 8.0, 24.0))
	_set_page_margins(roster_margin_x, roster_margin_y, roster_margin_x, roster_margin_y)
	root.add_theme_constant_override("separation", 0)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var selector_layout: HBoxContainer = HBoxContainer.new()
	selector_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_layout.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.018, 12.0, 28.0)))
	selector_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(selector_layout)
	var all_pieces: Array = catalog.get_unlocked_pieces(save.unlocked_piece_ids)
	if not preserve_roster_slot_selection:
		has_selected_roster_slot = false
	preserve_roster_slot_selection = false
	var bag_panel: PanelContainer = PanelContainer.new()
	bag_panel.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.52, 360.0, 980.0), 0)
	bag_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_panel.size_flags_stretch_ratio = 1.6
	selector_layout.add_child(bag_panel)
	var selector_scroll: ScrollContainer = ScrollContainer.new()
	selector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_panel.add_child(selector_scroll)
	var list: GridContainer = GridContainer.new()
	list.columns = 2 if viewport_size.x < 1400.0 else 3
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_theme_constant_override("h_separation", 12)
	list.add_theme_constant_override("v_separation", 12)
	selector_scroll.add_child(list)
	var side_panel: VBoxContainer = VBoxContainer.new()
	side_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	side_panel.add_theme_constant_override("separation", roundi(clamp(viewport_size.y * 0.018, 8.0, 16.0)))
	side_panel.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.32, 280.0, 520.0), 0)
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_stretch_ratio = 0.9
	selector_layout.add_child(side_panel)
	screen_title = Label.new()
	screen_title.text = "选择初始出战团子"
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.052, 24.0, 34.0)))
	screen_title.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.075, 36.0, 58.0))
	side_panel.add_child(screen_title)
	roster_slot_buttons = []
	side_panel.add_child(_make_roster_slots_bar(func(slot_index: int) -> void:
		selected_roster_slot = slot_index
		has_selected_roster_slot = true
		_refresh_roster_slot_buttons()
		_update_roster_detail()
	))
	var available_count: int = 0
	for piece in all_pieces:
		var piece_id: String = String(piece.get("id"))
		if not _piece_matches_slot(piece, selected_roster_slot):
			continue
		available_count += 1
		var captured_piece: PieceDefinition = piece
		var captured_piece_id: String = piece_id
		var status_text: String = "已出战" if current_roster.has(piece_id) else ""
		var select_piece_callable: Callable = func() -> void:
			current_roster[selected_roster_slot] = captured_piece_id
			_refresh_roster_slot_buttons()
			_update_roster_detail(captured_piece)
		list.add_child(_make_piece_card(piece, select_piece_callable, status_text))
	if available_count == 0:
		var empty_label: Label = Label.new()
		empty_label.text = "无可用团子"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0, 180)
		empty_label.add_theme_font_size_override("font_size", 24)
		list.add_child(empty_label)
	roster_detail_label = Label.new()
	roster_detail_label.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.20, 72.0, 160.0))
	roster_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	roster_detail_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.036, 16.0, 24.0)))
	side_panel.add_child(roster_detail_label)
	_update_roster_detail()
	var save_button: Button = _make_button("保存", func() -> void:
		save.roster_ids = current_roster
		save.save()
		_show_main_menu()
	)
	save_button.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.10, 46.0, 68.0))
	side_panel.add_child(save_button)
	var back_button: Button = _make_button("返回", Callable(self, "_show_main_menu"))
	back_button.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.10, 46.0, 68.0))
	side_panel.add_child(back_button)

func _make_roster_slots_bar(callback: Callable) -> GridContainer:
	return _make_roster_display_grid(true, callback)

func _make_roster_display_grid(interactive: bool, callback: Callable = Callable()) -> GridContainer:
	var slots: GridContainer = GridContainer.new()
	slots.columns = 3
	slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slots.add_theme_constant_override("h_separation", 12)
	slots.add_theme_constant_override("v_separation", 12)
	var slot_size: float = _roster_slot_size()
	for index in range(6):
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(slot_size, slot_size)
		slot_button.add_theme_font_size_override("font_size", max(18, int(slot_size * 0.15)))
		slot_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_configure_roster_slot_button(slot_button, index)
		if interactive:
			var slot_callable: Callable = func(slot_index: int) -> void:
				callback.call(slot_index)
			slot_button.pressed.connect(slot_callable.bind(index))
		else:
			slot_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots.add_child(slot_button)
		if interactive:
			roster_slot_buttons.append(slot_button)
	return slots

func _make_piece_card(piece: PieceDefinition, callback: Callable, status_text: String = "") -> Button:
	var button: Button = Button.new()
	var card_size: float = _piece_card_size()
	button.custom_minimum_size = Vector2(card_size, card_size)
	button.add_theme_font_size_override("font_size", max(18, int(card_size * 0.092)))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = ""
	_apply_piece_button_style(button, piece)
	button.pressed.connect(callback)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_top = 10
	box.offset_right = -10
	box.offset_bottom = -10
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	button.add_child(box)
	var texture: Texture2D = _piece_preview_texture(piece)
	if texture != null:
		box.add_child(_make_piece_texture_rect(texture, Vector2(card_size * 0.64, card_size * 0.64)))
	var name_label: Label = _make_piece_ui_label(piece.display_name, max(16, int(card_size * 0.092)))
	name_label.custom_minimum_size = Vector2(0, 30)
	box.add_child(name_label)
	var meta_label: Label = _make_piece_ui_label("x%.1f  %s" % [piece.multiplier, piece.rarity], max(12, int(card_size * 0.062)))
	meta_label.custom_minimum_size = Vector2(0, 22)
	box.add_child(meta_label)
	if not status_text.is_empty():
		var status_label: Label = _make_piece_ui_label(status_text, max(12, int(card_size * 0.062)))
		status_label.custom_minimum_size = Vector2(0, 22)
		box.add_child(status_label)
	return button

func _refresh_roster_slot_buttons() -> void:
	for index in range(roster_slot_buttons.size()):
		var button: Button = roster_slot_buttons[index]
		_configure_roster_slot_button(button, index)

func _configure_roster_slot_button(button: Button, index: int) -> void:
	_clear_control_children(button)
	button.text = ""
	var id: String = ""
	if index >= 0 and index < current_roster.size():
		id = current_roster[index]
	var piece: PieceDefinition = catalog.get_piece(id)
	var active: bool = has_selected_roster_slot and index == selected_roster_slot
	_apply_piece_button_style(button, piece, active)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 8
	box.offset_right = -8
	box.offset_bottom = -8
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	button.add_child(box)
	var prefix: String = "出战%d" % (index + 1)
	if index >= 0 and index < SLOT_ATTRIBUTES.size():
		prefix = SLOT_ATTRIBUTES[index]
	var label_size: int = max(17, int(button.custom_minimum_size.x * 0.12))
	var title_label: Label = _make_piece_ui_label(prefix, label_size)
	title_label.custom_minimum_size = Vector2(0, max(22.0, button.custom_minimum_size.x * 0.15))
	box.add_child(title_label)
	var texture: Texture2D = _piece_preview_texture(piece, active)
	if texture != null:
		var icon_size: float = clamp(button.custom_minimum_size.x * 0.60, 52.0, 118.0)
		box.add_child(_make_piece_texture_rect(texture, Vector2(icon_size, icon_size)))
	var name_label: Label = _make_piece_ui_label(piece.display_name if piece != null else "空", label_size)
	name_label.custom_minimum_size = Vector2(0, max(24.0, button.custom_minimum_size.x * 0.15))
	box.add_child(name_label)

func _slot_text(index: int) -> String:
	var id: String = ""
	if index >= 0 and index < current_roster.size():
		id = current_roster[index]
	var piece: PieceDefinition = catalog.get_piece(id)
	var label: String = "空"
	if piece != null:
		label = piece.display_name
	var prefix: String = "出战%d" % (index + 1)
	if index >= 0 and index < SLOT_ATTRIBUTES.size():
		prefix = SLOT_ATTRIBUTES[index]
	return "%s\n%s" % [prefix, label]

func _update_roster_detail(piece: PieceDefinition = null) -> void:
	if roster_detail_label == null:
		return
	var target_piece: PieceDefinition = piece
	if target_piece == null and has_selected_roster_slot and selected_roster_slot < current_roster.size():
		target_piece = catalog.get_piece(current_roster[selected_roster_slot])
	if target_piece == null:
		roster_detail_label.text = "选择一个团子查看特殊消除效果。"
		return
	var effect_name: String = ""
	if not target_piece.default_special_effect_id.is_empty():
		var effect: SpecialEffectDefinition = catalog.get_effect(target_piece.default_special_effect_id)
		if effect != null:
			effect_name = effect.display_name
	var resonance_effect: String = target_piece.resonance_effect_id
	if resonance_effect.is_empty():
		resonance_effect = "none"
	roster_detail_label.text = "%s大招：\n倍率：x%.1f  稀有度：%s\n共鸣：%d  效果：%s\n技能：%s\n%s\n属性：%s" % [
		target_piece.display_name,
		target_piece.multiplier,
		target_piece.rarity,
		target_piece.resonance_cost,
		resonance_effect,
		effect_name,
		target_piece.description,
		String(",").join(target_piece.tags),
	]

func _piece_matches_slot(piece: PieceDefinition, slot_index: int) -> bool:
	if piece == null or slot_index < 0 or slot_index >= SLOT_ATTRIBUTES.size():
		return false
	return piece.tags.has(SLOT_ATTRIBUTES[slot_index])

func _clear_control_children(control: Control) -> void:
	for child in control.get_children():
		control.remove_child(child)
		child.queue_free()

func _piece_preview_texture(piece: PieceDefinition, use_selected: bool = false) -> Texture2D:
	if piece == null:
		return null
	if use_selected and piece.selected_icon_texture != null:
		return piece.selected_icon_texture
	return piece.icon_texture

func _make_piece_texture_rect(texture: Texture2D, min_size: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = min_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon

func _make_piece_ui_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _apply_piece_button_style(button: Button, piece: PieceDefinition, active: bool = false) -> void:
	var bg_color: Color = Color(0.12, 0.12, 0.12, 0.18)
	var border_color: Color = Color(1, 1, 1, 0.20)
	if piece != null:
		var button_texture: Texture2D = _button_texture_for_piece_id(piece.id)
		if button_texture != null:
			_apply_piece_button_texture_style(button, button_texture, active)
			return
		bg_color = _button_background_color_for_piece(piece, active)
		border_color = _selection_color_for_piece_id(piece.id)
		if border_color == Color.TRANSPARENT:
			border_color = piece.theme_color.lightened(0.18)
		border_color.a = 0.78 if active else 0.36
	var border_width: int = 3 if active else 1
	var hover_bg: Color = bg_color.lightened(0.12)
	var pressed_bg: Color = bg_color.darkened(0.10)
	var disabled_bg: Color = bg_color
	disabled_bg.a *= 0.65
	button.add_theme_stylebox_override("normal", _make_piece_button_style(bg_color, border_color, border_width))
	button.add_theme_stylebox_override("hover", _make_piece_button_style(hover_bg, border_color, border_width))
	button.add_theme_stylebox_override("pressed", _make_piece_button_style(pressed_bg, border_color, border_width))
	button.add_theme_stylebox_override("focus", _make_piece_button_style(hover_bg, border_color, border_width))
	button.add_theme_stylebox_override("disabled", _make_piece_button_style(disabled_bg, border_color, border_width))

func _apply_piece_button_texture_style(button: Button, texture: Texture2D, active: bool) -> void:
	var normal: StyleBoxTexture = _make_piece_button_texture_style(texture, active)
	var hover: StyleBoxTexture = _make_piece_button_texture_style(texture, true)
	var pressed: StyleBoxTexture = _make_piece_button_texture_style(texture, true)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)

func _make_piece_button_texture_style(texture: Texture2D, active: bool) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.content_margin_left = 5
	style.content_margin_top = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
	style.expand_margin_left = 0
	style.expand_margin_top = 0
	style.expand_margin_right = 0
	style.expand_margin_bottom = 0
	if active:
		style.modulate_color = Color(1.18, 1.18, 1.18, 1)
	return style

func _button_texture_for_piece_id(piece_id: String) -> Texture2D:
	return _background_texture_for_piece_id(piece_id)

func _button_background_color_for_piece(piece: PieceDefinition, active: bool) -> Color:
	var color: Color = _background_color_for_piece_id(piece.id)
	if color == Color.TRANSPARENT:
		color = piece.theme_color
	color.a = 0.46 if active else 0.34
	return color

func _make_piece_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

func _show_settings(back_callback: Callable) -> void:
	_clear_screen()
	current_screen = "settings"
	root.add_theme_constant_override("separation", 14)
	_add_title("设置")
	root.add_child(_make_slider_row("音效", save.sfx_volume, func(value: float) -> void:
		save.sfx_volume = value
		save.save()
	))
	root.add_child(_make_slider_row("音乐", save.music_volume, func(value: float) -> void:
		save.music_volume = value
		save.save()
	))
	root.add_child(_make_button("返回", back_callback))

func _make_slider_row(label_text: String, value: float, callback: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 32)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(260, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(label)
	row.add_child(slider)
	return row

func _make_spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _start_run() -> void:
	run_active = true
	score = 0
	combo = 0
	max_combo = 0
	stats = {"normal": 0, "special": 0, "combo": 0}
	current_roster = _sanitize_roster(current_roster)
	run_state = {
		"floor": 1,
		"lives": RUN_MAX_LIVES,
		"shells": 0,
		"collectibles": [],
		"completed_nodes": 0,
		"map_nodes": [],
		"available_node_ids": [],
		"current_node_id": "",
		"shop_items": [],
	}
	current_run_node = {}
	pending_run_reward_items = []
	_generate_floor_map(1)
	_show_run_map()

func _generate_floor_map(run_floor: int) -> void:
	var map_nodes: Array = []
	var rows: Array = []
	var middle_nodes: Array = []
	for row_index in range(RUN_MAP_ROWS):
		var row_nodes: Array = []
		var lane_count: int = rng.randi_range(RUN_MAP_MIN_LANES, RUN_MAP_MAX_LANES)
		if row_index == RUN_MAP_ROWS - 1:
			lane_count = rng.randi_range(RUN_PRE_BOSS_MIN_SUPPLIES, RUN_PRE_BOSS_MAX_SUPPLIES)
		for lane_index in range(lane_count):
			var node_type: String = _run_node_type_for_initial_map(row_index)
			var node: Dictionary = {
				"id": "f%d_r%d_l%d" % [run_floor, row_index, lane_index],
				"type": node_type,
				"title": _run_node_title(node_type, run_floor),
				"floor": run_floor,
				"row": row_index,
				"lane": lane_index,
				"links": [],
				"completed": false,
				"elite": node_type == "elite",
			}
			row_nodes.append(node)
			map_nodes.append(node)
			if row_index > 0 and row_index < RUN_MAP_ROWS - 1:
				middle_nodes.append(node)
		rows.append(row_nodes)
	_assign_shop_nodes(middle_nodes, run_floor)
	var boss_node: Dictionary = {
		"id": "f%d_boss" % run_floor,
		"type": "boss",
		"title": _run_node_title("boss", run_floor),
		"boss_id": _default_boss_id(),
		"floor": run_floor,
		"row": RUN_MAP_ROWS,
		"lane": 1,
		"links": [],
		"completed": false,
		"elite": true,
	}
	_assign_reachable_tree_links(rows)
	for node in rows[RUN_MAP_ROWS - 1]:
		node["links"] = [String(boss_node.get("id", ""))]
	map_nodes.append(boss_node)
	run_state["map_nodes"] = map_nodes
	run_state["available_node_ids"] = _ids_for_row(rows[0])
	run_state["current_node_id"] = ""

func _run_node_type_for_initial_map(row_index: int) -> String:
	if row_index == 0:
		return "battle"
	if row_index == RUN_MAP_ROWS - 1:
		return "supply"
	var node_types: Array[String] = ["battle", "battle", "elite", "event"]
	return node_types[rng.randi_range(0, node_types.size() - 1)]

func _assign_shop_nodes(candidates: Array, run_floor: int) -> void:
	if candidates.is_empty():
		return
	var shop_count: int = min(candidates.size(), rng.randi_range(RUN_MIN_SHOPS, RUN_MAX_SHOPS))
	candidates.shuffle()
	for index in range(shop_count):
		var node: Dictionary = candidates[index]
		node["type"] = "shop"
		node["title"] = _run_node_title("shop", run_floor)
		node["elite"] = false

func _assign_reachable_tree_links(rows: Array) -> void:
	for row in rows:
		for node in row:
			node["links"] = []
	for row_index in range(rows.size() - 1):
		var current_row: Array = rows[row_index]
		var next_row: Array = rows[row_index + 1]
		_assign_primary_tree_links(current_row, next_row)
		_trim_tree_row_links(current_row, next_row)

func _assign_primary_tree_links(current_row: Array, next_row: Array) -> void:
	var incoming_by_id: Dictionary = {}
	for next_node in next_row:
		incoming_by_id[String(next_node.get("id", ""))] = 0
	for source_index in range(current_row.size()):
		var target_index: int = _tree_target_index_for_source(source_index, current_row.size(), next_row.size())
		var target_id: String = String(next_row[target_index].get("id", ""))
		_add_tree_link(current_row[source_index], target_id, incoming_by_id)
	for next_index in range(next_row.size()):
		var target_id: String = String(next_row[next_index].get("id", ""))
		if int(incoming_by_id.get(target_id, 0)) > 0:
			continue
		var source_index: int = _tree_source_index_for_target(next_index, next_row.size(), current_row.size())
		_add_tree_link(current_row[source_index], target_id, incoming_by_id)

func _tree_source_index_for_target(target_index: int, target_count: int, source_count: int) -> int:
	if target_count <= 1 or source_count <= 1:
		return 0
	return clamp(roundi(float(target_index) * float(source_count - 1) / float(target_count - 1)), 0, source_count - 1)

func _tree_target_index_for_source(source_index: int, source_count: int, target_count: int) -> int:
	if source_count <= 1 or target_count <= 1:
		return 0
	return clamp(roundi(float(source_index) * float(target_count - 1) / float(source_count - 1)), 0, target_count - 1)

func _add_tree_link(source_node: Dictionary, target_id: String, incoming_by_id: Dictionary) -> void:
	if target_id.is_empty() or int(incoming_by_id.get(target_id, 0)) >= 2:
		return
	var links: Array = _node_links(source_node)
	if links.has(target_id) or links.size() >= 2:
		return
	links.append(target_id)
	links.sort_custom(func(a: String, b: String) -> bool: return a < b)
	source_node["links"] = links
	incoming_by_id[target_id] = int(incoming_by_id.get(target_id, 0)) + 1

func _trim_tree_row_links(current_row: Array, next_row: Array) -> void:
	var allowed_ids: Array = _ids_for_row(next_row)
	var incoming_by_id: Dictionary = {}
	for target_id in allowed_ids:
		incoming_by_id[target_id] = 0
	for node in current_row:
		var node_data: Dictionary = node
		var trimmed_links: Array = []
		for target_id in _node_links(node_data):
			var normalized_id: String = String(target_id)
			if not allowed_ids.has(normalized_id) or trimmed_links.has(normalized_id) or trimmed_links.size() >= 2:
				continue
			if int(incoming_by_id.get(normalized_id, 0)) >= 2:
				continue
			trimmed_links.append(normalized_id)
			incoming_by_id[normalized_id] = int(incoming_by_id.get(normalized_id, 0)) + 1
		node_data["links"] = trimmed_links

func _ids_for_row(row_nodes: Array) -> Array:
	var ids: Array = []
	for node in row_nodes:
		ids.append(String(node.get("id", "")))
	return ids

func _make_legacy_run_node(node_type: String, run_floor: int) -> Dictionary:
	return {
			"id": "",
			"type": node_type,
			"title": _run_node_title(node_type, run_floor),
			"floor": run_floor,
			"row": 0,
			"lane": 0,
			"links": [],
			"completed": false,
			"elite": node_type == "elite",
		}

func _run_node_title(node_type: String, run_floor: int) -> String:
	match node_type:
		"battle":
			return "第 %d 层 普通战斗" % run_floor
		"elite":
			return "第 %d 层 精英战斗" % run_floor
		"supply":
			return "第 %d 层 补给" % run_floor
		"shop":
			return "第 %d 层 商城" % run_floor
		"event":
			return "第 %d 层 事件" % run_floor
		"boss":
			return "第 %d 层 最终首领" % run_floor
	return "第 %d 层 未知节点" % run_floor

func _show_run_map() -> void:
	_clear_screen()
	current_screen = "run_map"
	_add_title("探索路线")
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 12)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(top_bar)
	var left_spacer: Control = Control.new()
	left_spacer.custom_minimum_size = Vector2(160, 1)
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(left_spacer)
	var summary: Label = Label.new()
	summary.text = "层数：%d / %d    生命：%d / %d    贝币：%d    藏品：%d    分数：%d" % [
		int(run_state.get("floor", 1)),
		RUN_TOTAL_FLOORS,
		int(run_state.get("lives", RUN_MAX_LIVES)),
		RUN_MAX_LIVES,
		int(run_state.get("shells", 0)),
		_run_collectibles().size(),
		score,
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(summary)
	var settings_button: Button = _make_button("设置", Callable(self, "_show_run_pause"))
	settings_button.custom_minimum_size = Vector2(160, 60)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_bar.add_child(settings_button)
	var map_scroll: ScrollContainer = ScrollContainer.new()
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.custom_minimum_size = Vector2(0, clamp(get_viewport_rect().size.y * 0.84, 520.0, 860.0))
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(map_scroll)
	var canvas_size: Vector2 = Vector2(max(1600.0, get_viewport_rect().size.x * 1.16), map_scroll.custom_minimum_size.y)
	var node_positions: Dictionary = _run_map_node_positions(canvas_size)
	var map_canvas: Control = RunMapCanvasScript.new()
	map_canvas.custom_minimum_size = canvas_size
	map_canvas.size = canvas_size
	map_canvas.setup(_run_map_nodes(), _run_available_node_ids(), node_positions)
	map_scroll.add_child(map_canvas)
	for node in _run_map_nodes():
		var node_data: Dictionary = node
		var node_id: String = String(node_data.get("id", ""))
		var captured_node_id: String = node_id
		var button: Button = _make_run_map_node_button(node_data)
		button.position = node_positions.get(node_id, Vector2.ZERO) - button.custom_minimum_size * 0.5
		button.disabled = not _is_run_node_available(node_id) or bool(node_data.get("completed", false))
		button.pressed.connect(func() -> void:
			_enter_run_node_by_id(captured_node_id)
		)
		map_canvas.add_child(button)

func _run_node_hint(node_type: String) -> String:
	match node_type:
		"battle":
			return "胜利获得贝币，可能获得藏品"
		"elite":
			return "更强 Boss，固定获得藏品"
		"supply":
			return "获得一个补给包"
		"shop":
			return "花费贝币购买藏品"
		"event":
			return "选择一个随机事件"
		"boss":
			return "通关探索"
	return ""

func _enter_run_node_by_id(node_id: String) -> void:
	if not _is_run_node_available(node_id):
		_show_run_map()
		return
	var node: Dictionary = _find_run_node(node_id)
	if node.is_empty():
		_show_run_map()
		return
	_enter_run_node(node)

func _enter_run_node(node: Dictionary) -> void:
	current_run_node = node.duplicate(true)
	run_state["current_node_id"] = String(current_run_node.get("id", ""))
	match String(current_run_node.get("type", "")):
		"battle", "elite", "boss":
			_start_battle_node(current_run_node)
		"supply":
			_show_supply_node()
		"shop":
			run_state["shop_items"] = _generate_shop_items()
			_show_shop_node()
		"event":
			_show_event_node()
		_:
			_show_run_map()

func _start_game() -> void:
	run_active = false
	current_run_node = {}
	pending_run_reward_items = []
	score = 0
	combo = 0
	max_combo = 0
	current_boss = catalog.get_default_boss()
	boss_max_hp = _current_boss_base_hp()
	boss_hp = boss_max_hp
	moves_since_enemy = 0
	skip_bonus_pending = false
	suppress_next_enemy_effect = false
	resonance_values = []
	for i in range(SLOT_ATTRIBUTES.size()):
		resonance_values.append(0)
	boss_status_text = "团子大魔王：观察中"
	stats = {"normal": 0, "special": 0, "combo": 0}
	current_roster = _sanitize_roster(current_roster)
	_show_game_shell("棋盘生成中...")
	call_deferred("_create_board")

func _start_battle_node(node: Dictionary) -> void:
	combo = 0
	max_combo = 0
	current_boss = catalog.get_boss(String(node.get("boss_id", "")))
	if current_boss == null:
		current_boss = catalog.get_default_boss()
	boss_max_hp = _run_boss_hp_for_node(node)
	boss_hp = boss_max_hp
	moves_since_enemy = 0
	skip_bonus_pending = false
	suppress_next_enemy_effect = false
	resonance_values = []
	for i in range(SLOT_ATTRIBUTES.size()):
		resonance_values.append(0)
	var start_charge: int = int(_collectible_total("start_resonance"))
	if start_charge > 0:
		for i in range(SLOT_ATTRIBUTES.size()):
			resonance_values[i] = min(_resonance_cost(i), start_charge)
	boss_status_text = "探索战斗开始"
	current_roster = _sanitize_roster(current_roster)
	_show_game_shell("探索战斗准备中...")
	call_deferred("_create_board")

func _run_boss_hp_for_node(node: Dictionary) -> int:
	var run_floor: int = int(node.get("floor", int(run_state.get("floor", 1))))
	var node_type: String = String(node.get("type", "battle"))
	var hp: int = _current_boss_base_hp() + (run_floor - 1) * 45
	if node_type == "elite":
		hp += 90
	elif node_type == "boss":
		hp += 180
	return hp

func _default_boss_id() -> String:
	var boss: Resource = catalog.get_default_boss()
	return boss.id if boss != null else ""

func _current_boss_base_hp() -> int:
	if current_boss != null:
		return max(1, current_boss.max_hp)
	return BOSS_MAX_HP

func _current_boss_name() -> String:
	if current_boss != null and not current_boss.display_name.is_empty():
		return current_boss.display_name
	return "团子大魔王"

func _create_board() -> void:
	board = BoardModelScript.new()
	board.setup(catalog, current_roster)
	_redraw_game()

func _show_game() -> void:
	_show_game_shell(boss_status_text)
	_redraw_game()

func _show_game_shell(boss_text: String = "团子大魔王：观察中") -> void:
	_clear_screen()
	current_screen = "game"
	var viewport_size: Vector2 = get_viewport_rect().size
	var game_margin_x: int = roundi(clamp(viewport_size.x * 0.018, 12.0, 24.0))
	var game_margin_y: int = roundi(clamp(viewport_size.y * 0.018, 8.0, 18.0))
	_set_page_margins(game_margin_x, game_margin_y, game_margin_x, game_margin_y)
	root.add_theme_constant_override("separation", 12)
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	var board_pixel_size: float = _board_cell_size() * float(BoardModel.WIDTH) + 2.0 * float(BoardModel.WIDTH - 1)
	var roster_grid_width: float = _battle_roster_slot_size() * 3.0 + 16.0
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.014, 8.0, 18.0)))
	top.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.12, 52.0, 72.0))
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(top)
	score_label = Label.new()
	combo_label = Label.new()
	score_label.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.14, 120.0, 260.0), 42)
	combo_label.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.12, 120.0, 220.0), 42)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(score_label)
	top.add_child(combo_label)
	var hud_spacer: Control = Control.new()
	hud_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hud_spacer)
	var pause_button: Button = _make_button("暂停", Callable(self, "_show_pause"))
	pause_button.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.12, 96.0, 180.0), clamp(viewport_size.y * 0.10, 46.0, 64.0))
	pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(pause_button)
	var battle_layout: HBoxContainer = HBoxContainer.new()
	battle_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_layout.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.014, 10.0, 24.0)))
	battle_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(battle_layout)
	board_area = CenterContainer.new()
	board_area.custom_minimum_size = Vector2(max(280.0, board_pixel_size), 0)
	board_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.size_flags_stretch_ratio = 1.8
	battle_layout.add_child(board_area)
	board_grid = GridContainer.new()
	board_grid.columns = BoardModel.WIDTH
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_grid.add_theme_constant_override("h_separation", 2)
	board_grid.add_theme_constant_override("v_separation", 2)
	board_area.add_child(board_grid)
	var right_column: VBoxContainer = VBoxContainer.new()
	right_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_column.add_theme_constant_override("separation", roundi(clamp(viewport_size.y * 0.018, 8.0, 18.0)))
	right_column.custom_minimum_size = Vector2(max(260.0, roster_grid_width + 24.0), 0)
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.size_flags_stretch_ratio = 1.0
	battle_layout.add_child(right_column)
	var boss_panel: PanelContainer = PanelContainer.new()
	boss_panel.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.48, 190.0, 420.0))
	boss_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boss_panel.size_flags_stretch_ratio = 1.0
	right_column.add_child(boss_panel)
	var boss_box: VBoxContainer = VBoxContainer.new()
	boss_box.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_box.add_theme_constant_override("separation", 18)
	boss_panel.add_child(boss_box)
	boss_avatar = Label.new()
	boss_avatar.text = "魔王"
	boss_avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_avatar.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.09, 92.0, 180.0), clamp(viewport_size.y * 0.14, 70.0, 150.0))
	boss_avatar.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.05, 22.0, 30.0)))
	if current_boss != null and current_boss.texture != null:
		boss_avatar_texture = TextureRect.new()
		boss_avatar_texture.texture = current_boss.texture
		boss_avatar_texture.custom_minimum_size = boss_avatar.custom_minimum_size
		boss_avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		boss_avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		boss_box.add_child(boss_avatar_texture)
	else:
		boss_avatar_texture = null
		boss_box.add_child(boss_avatar)
	boss_hp_segments = HBoxContainer.new()
	boss_hp_segments.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_hp_segments.add_theme_constant_override("separation", 4)
	boss_hp_segments.custom_minimum_size = Vector2(0, 18)
	boss_hp_segments.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(boss_hp_segments)
	boss_hp_label = Label.new()
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.028, 14.0, 20.0)))
	boss_box.add_child(boss_hp_label)
	var boss_text_box: VBoxContainer = VBoxContainer.new()
	boss_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(boss_text_box)
	boss_name_label = Label.new()
	boss_name_label.text = _current_boss_name()
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	boss_name_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.052, 22.0, 32.0)))
	boss_text_box.add_child(boss_name_label)
	boss_label = Label.new()
	boss_label.text = boss_text
	boss_status_text = boss_text
	boss_label.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.28, 88.0, 180.0))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	boss_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.043, 18.0, 26.0)))
	boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	boss_text_box.add_child(boss_label)
	roster_bar = HBoxContainer.new()
	roster_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	roster_bar.add_theme_constant_override("separation", 12)
	roster_bar.custom_minimum_size = Vector2(0, _battle_roster_slot_size() * 2.0 + 28.0)
	roster_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	right_column.add_child(roster_bar)
	_build_cheat_panel()

func _redraw_game() -> void:
	if board == null or board.cells.is_empty():
		if score_label != null:
			score_label.text = "分数：%d  " % score
		if combo_label != null:
			combo_label.text = "Combo：%d  " % combo
		if boss_label != null:
			boss_label.text = "棋盘初始化失败"
		var error_label: Label = Label.new()
		error_label.text = "棋盘初始化失败：没有可用团子。请检查 data/pieces 或 PieceCatalog 默认配置。"
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		root.add_child(error_label)
		return
	score_label.text = "分数：%d  " % score
	combo_label.text = "Combo：%d  " % combo
	_update_boss_hp_ui()
	for child in board_grid.get_children():
		child.queue_free()
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			board_grid.add_child(_make_cell_button(pos))
	for child in roster_bar.get_children():
		child.queue_free()
	roster_bar.add_child(_make_battle_roster_bar())
	_update_cheat_panel_from_selection()

func _update_boss_hp_ui() -> void:
	if boss_hp_label != null:
		boss_hp_label.text = "%d / %d" % [max(0, boss_hp), boss_max_hp]
	if boss_hp_segments == null:
		return
	for child in boss_hp_segments.get_children():
		child.queue_free()
	var segment_max: float = float(boss_max_hp) / float(BOSS_SEGMENTS)
	for index in range(BOSS_SEGMENTS):
		var segment: ProgressBar = ProgressBar.new()
		segment.min_value = 0
		segment.max_value = segment_max
		segment.value = clamp(float(boss_hp) - segment_max * float(index), 0.0, segment_max)
		segment.show_percentage = false
		segment.custom_minimum_size = Vector2(0, 14)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boss_hp_segments.add_child(segment)

func _boss_phase() -> int:
	var hp_ratio: float = float(boss_hp) / float(boss_max_hp)
	if hp_ratio > 0.6667:
		return 3
	if hp_ratio > 0.3334:
		return 2
	return 1

func _damage_boss(cleared_positions: Array) -> void:
	if boss_hp <= 0 or cleared_positions.is_empty():
		return
	var damage: int = cleared_positions.size() * BOSS_DAMAGE_PER_PIECE
	if run_active:
		damage = roundi(float(damage) * (1.0 + _collectible_total("damage_mult")))
	boss_hp = max(0, boss_hp - damage)
	_update_boss_hp_ui()
	if boss_hp <= 0:
		_set_boss_status("%s倒下了，关卡完成！" % _current_boss_name(), "胜利")
	else:
		_set_boss_status("团子命中%s，造成 %d 点伤害。" % [_current_boss_name(), damage], "受击")

func _finish_battle() -> void:
	if run_active:
		_on_run_battle_won()
		return
	save.high_score = max(save.high_score, score)
	save.save()
	_clear_screen()
	_add_title("关卡完成")
	var summary: Label = Label.new()
	summary.text = "大魔王血量归零\n得分：%d\n最高分：%d\n最高 Combo：%d" % [
		score,
		save.high_score,
		max_combo,
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(summary)
	root.add_child(_make_button("再来一局", Callable(self, "_start_game")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _make_battle_roster_bar() -> GridContainer:
	var slots: GridContainer = GridContainer.new()
	slots.columns = 3
	slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slots.add_theme_constant_override("h_separation", 8)
	slots.add_theme_constant_override("v_separation", 8)
	for index in range(SLOT_ATTRIBUTES.size()):
		slots.add_child(_make_battle_roster_slot(index))
	return slots

func _make_battle_roster_slot(index: int) -> Button:
	var piece: PieceDefinition = catalog.get_piece(current_roster[index]) if index < current_roster.size() else null
	var button: Button = Button.new()
	var slot_size: float = _battle_roster_slot_size()
	button.custom_minimum_size = Vector2(slot_size, slot_size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = ""
	button.disabled = is_animating_board
	_apply_battle_roster_button_style(button, _is_resonance_ready(index))
	button.pressed.connect(func() -> void: _on_battle_roster_pressed(index))
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_top = 5
	box.offset_right = -6
	box.offset_bottom = -5
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)
	var texture: Texture2D = _piece_preview_texture(piece, _is_resonance_ready(index))
	if texture != null:
		box.add_child(_make_piece_texture_rect(texture, Vector2(slot_size * 0.78, slot_size * 0.78)))
	var progress: ProgressBar = ProgressBar.new()
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.min_value = 0
	progress.max_value = _resonance_cost(index)
	progress.value = _resonance_value(index)
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 10)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(progress)
	var value_label: Label = Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", max(11, int(slot_size * 0.08)))
	value_label.text = "共鸣 %d/%d" % [_resonance_value(index), _resonance_cost(index)]
	if _is_resonance_ready(index):
		value_label.text = "共鸣解放"
	box.add_child(value_label)
	return button

func _apply_battle_roster_button_style(button: Button, active: bool) -> void:
	var normal: StyleBoxFlat = _make_transparent_button_style(0.0)
	var hover: StyleBoxFlat = _make_transparent_button_style(0.08)
	var pressed: StyleBoxFlat = _make_transparent_button_style(0.14)
	var focus: StyleBoxFlat = _make_transparent_button_style(0.10)
	var disabled: StyleBoxFlat = _make_transparent_button_style(0.0)
	if active:
		normal = _make_transparent_button_style(0.10)
		focus = _make_transparent_button_style(0.16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)

func _make_transparent_button_style(alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, alpha)
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _on_battle_roster_pressed(slot_index: int) -> void:
	if is_animating_board:
		return
	if not _is_resonance_ready(slot_index):
		_set_boss_status("%s回路：%d/%d" % [SLOT_ATTRIBUTES[slot_index], _resonance_value(slot_index), _resonance_cost(slot_index)], "共鸣")
		return
	_release_resonance(slot_index)

func _make_cell_button(pos: Vector2i) -> Button:
	var cell: Variant = board.get_cell(pos)
	var piece: PieceDefinition = null if cell == null else catalog.get_piece(String(cell["piece_id"]))
	var button: Button = Button.new()
	var cell_size: float = _board_cell_size()
	button.custom_minimum_size = Vector2(cell_size, cell_size)
	button.add_theme_font_size_override("font_size", max(18, int(cell_size * 0.34)))
	button.set_meta("board_pos", pos)
	button.pivot_offset = button.custom_minimum_size * 0.5
	if cell == null:
		button.text = ""
		button.disabled = true
		button.modulate = Color(1, 1, 1, 0)
		return button
	if piece != null and piece.icon_texture != null:
		button.text = ""
		_add_piece_background_to_button(button, String(cell["piece_id"]), cell_size)
		_add_piece_icon_to_button(button, _icon_texture_for_cell(piece, pos), cell, piece, cell_size)
	else:
		_apply_piece_background(button, String(cell["piece_id"]))
		button.text = _cell_text(cell, piece)
	if piece != null and piece.icon_texture == null:
		button.modulate = piece.theme_color
	if int(cell["locked_turns"]) > 0:
		button.text += "\n锁"
	if pos == selected_cell and (piece == null or piece.icon_texture == null):
		button.text = "[%s]" % button.text
	if pos == selected_cell:
		_add_selection_corners_to_button(button, String(cell["piece_id"]), cell_size)
	button.pressed.connect(func() -> void: _on_cell_pressed(pos))
	return button

func _add_selection_corners_to_button(button: Button, piece_id: String, cell_size: float) -> void:
	var color: Color = _selection_color_for_piece_id(piece_id)
	if color == Color.TRANSPARENT:
		return
	var line_width: float = max(3.0, round(cell_size * 0.055))
	var corner_length: float = max(14.0, round(cell_size * 0.28))
	_add_corner_line(button, color, 0.0, 0.0, 0.0, 0.0, corner_length, line_width)
	_add_corner_line(button, color, 0.0, 0.0, 0.0, 0.0, line_width, corner_length)
	_add_corner_line(button, color, 1.0, 1.0, 0.0, 0.0, -corner_length, line_width)
	_add_corner_line(button, color, 1.0, 1.0, 0.0, 0.0, -line_width, corner_length)
	_add_corner_line(button, color, 0.0, 0.0, 1.0, 1.0, corner_length, -line_width)
	_add_corner_line(button, color, 0.0, 0.0, 1.0, 1.0, line_width, -corner_length)
	_add_corner_line(button, color, 1.0, 1.0, 1.0, 1.0, -corner_length, -line_width)
	_add_corner_line(button, color, 1.0, 1.0, 1.0, 1.0, -line_width, -corner_length)

func _add_corner_line(parent: Control, color: Color, anchor_left: float, anchor_right: float, anchor_top: float, anchor_bottom: float, width: float, height: float) -> void:
	var line: ColorRect = ColorRect.new()
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.anchor_left = anchor_left
	line.anchor_right = anchor_right
	line.anchor_top = anchor_top
	line.anchor_bottom = anchor_bottom
	line.offset_left = min(0.0, width)
	line.offset_right = max(0.0, width)
	line.offset_top = min(0.0, height)
	line.offset_bottom = max(0.0, height)
	parent.add_child(line)

func _selection_color_for_piece_id(piece_id: String) -> Color:
	return _selection_color_for_attribute(_attribute_for_piece_id(piece_id))

func _icon_texture_for_cell(piece: PieceDefinition, pos: Vector2i) -> Texture2D:
	if pos == selected_cell and piece.selected_icon_texture != null:
		return piece.selected_icon_texture
	return piece.icon_texture

func _apply_piece_background(button: Button, piece_id: String) -> void:
	var bg_color: Color = _background_color_for_piece_id(piece_id)
	if bg_color == Color.TRANSPARENT:
		return
	var normal: StyleBoxFlat = _make_piece_background_style(bg_color)
	var hover: StyleBoxFlat = _make_piece_background_style(bg_color.lightened(0.10))
	var pressed: StyleBoxFlat = _make_piece_background_style(bg_color.darkened(0.08))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)

func _add_piece_background_to_button(button: Button, piece_id: String, cell_size: float) -> void:
	var texture: Texture2D = _background_texture_for_piece_id(piece_id)
	if texture != null:
		var normal: StyleBoxTexture = _make_piece_texture_background_style(texture)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", normal)
		button.add_theme_stylebox_override("pressed", normal)
		button.add_theme_stylebox_override("focus", normal)
		button.add_theme_stylebox_override("disabled", normal)
		return
	var bg_color: Color = _background_color_for_piece_id(piece_id)
	if bg_color == Color.TRANSPARENT:
		return
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: float = round(cell_size * 0.08)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = inset
	panel.offset_top = inset
	panel.offset_right = -inset
	panel.offset_bottom = -inset
	panel.add_theme_stylebox_override("panel", _make_piece_circle_background_style(bg_color))
	button.add_child(panel)

func _background_texture_for_piece_id(piece_id: String) -> Texture2D:
	return _background_texture_for_attribute(_attribute_for_piece_id(piece_id))

func _make_piece_texture_background_style(texture: Texture2D) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style

func _make_piece_background_style(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(3)
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style

func _make_piece_circle_background_style(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(999)
	return style

func _background_color_for_piece_id(piece_id: String) -> Color:
	return _background_color_for_attribute(_attribute_for_piece_id(piece_id))

func _attribute_for_piece_id(piece_id: String) -> String:
	var piece: PieceDefinition = catalog.get_piece(piece_id)
	if piece != null and not piece.tags.is_empty():
		return String(piece.tags[0])
	match piece_id:
		"diffraction_base", "diffraction_phoebe":
			return "衍射"
		"annihilation_base", "annihilation_chisaki":
			return "湮灭"
		"condensation_base", "condensation_coletta":
			return "冷凝"
		"aero_base", "aero_sigrika":
			return "气动"
		"thermal_base", "thermal_emis":
			return "热熔"
		"conductive_base", "conductive_kakaro":
			return "导电"
	return ""

func _background_texture_for_attribute(attribute: String) -> Texture2D:
	match attribute:
		"衍射":
			return load("res://assets/pieces/backgrounds/diffraction_bg.png")
		"湮灭":
			return load("res://assets/pieces/backgrounds/annihilation_bg.png")
		"冷凝":
			return load("res://assets/pieces/backgrounds/condensation_bg.png")
		"气动":
			return load("res://assets/pieces/backgrounds/aero_bg.png")
		"热熔":
			return load("res://assets/pieces/backgrounds/thermal_bg.png")
		"导电":
			return load("res://assets/pieces/backgrounds/conductive_bg.png")
	return null

func _selection_color_for_attribute(attribute: String) -> Color:
	match attribute:
		"衍射":
			return Color(0.72, 0.72, 0.31, 1.0)
		"湮灭":
			return Color(0.70, 0.26, 0.52, 1.0)
		"冷凝":
			return Color(0.42, 0.58, 0.70, 1.0)
		"气动":
			return Color(0.34, 0.72, 0.62, 1.0)
		"热熔":
			return Color(0.74, 0.20, 0.32, 1.0)
		"导电":
			return Color(0.66, 0.34, 0.72, 1.0)
	return Color.TRANSPARENT

func _background_color_for_attribute(attribute: String) -> Color:
	match attribute:
		"衍射":
			return Color(1.0, 0.82, 0.12, 0.34)
		"湮灭":
			return Color(0.46, 0.02, 0.04, 0.42)
		"冷凝":
			return Color(0.18, 0.58, 1.0, 0.34)
		"气动":
			return Color(0.18, 0.86, 0.28, 0.34)
		"热熔":
			return Color(1.0, 0.18, 0.12, 0.34)
		"导电":
			return Color(0.62, 0.20, 1.0, 0.34)
	return Color.TRANSPARENT

func _add_piece_icon_to_button(button: Button, texture: Texture2D, cell: Dictionary, piece: PieceDefinition, cell_size: float) -> void:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: float = round(cell_size * 0.03)
	icon.anchor_left = 0.0
	icon.anchor_top = 0.0
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	button.add_child(icon)

	var overlay_text: String = _cell_text(cell, piece)
	if overlay_text.is_empty():
		return
	var overlay: Label = Label.new()
	overlay.text = overlay_text
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_theme_font_size_override("font_size", max(16, int(cell_size * 0.30)))
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(overlay)

func _board_cell_size() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var side_columns_width: float = clamp(viewport_size.x * 0.32, 280.0, 520.0) if current_screen == "game" else 0.0
	var horizontal_margin: float = clamp(viewport_size.x * 0.06, 44.0, 96.0) if current_screen == "game" else 72.0
	var usable_width: float = max(240.0, viewport_size.x - side_columns_width - horizontal_margin)
	var reserved_height: float = clamp(viewport_size.y * 0.22, 96.0, 118.0) if current_screen == "game" else 120.0
	var usable_height: float = max(240.0, viewport_size.y - reserved_height)
	var gap_total: float = 2.0 * float(BoardModel.WIDTH - 1)
	var width_cell: float = (usable_width - gap_total) / float(BoardModel.WIDTH)
	var height_cell: float = (usable_height - gap_total) / float(BoardModel.HEIGHT)
	return floor(min(128.0, min(width_cell, height_cell)))

func _roster_slot_size() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var landscape_scale: float = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	if current_screen == "menu":
		landscape_scale = min(viewport_size.x / 960.0, viewport_size.y / 540.0)
		return floor(clamp(MAIN_MENU_ROSTER_SLOT_SIZE * landscape_scale, 136.0, MAIN_MENU_ROSTER_SLOT_SIZE))
	elif current_screen != "roster":
		landscape_scale = min(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	return floor(clamp(ROSTER_SLOT_SIZE * landscape_scale, 92.0, ROSTER_SLOT_SIZE))

func _piece_card_size() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var landscape_scale: float = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	return floor(clamp(PIECE_CARD_SIZE * landscape_scale, 126.0, PIECE_CARD_SIZE))

func _battle_roster_slot_size() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var landscape_scale: float = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	return floor(clamp(BATTLE_ROSTER_SLOT_SIZE * landscape_scale, 64.0, BATTLE_ROSTER_SLOT_SIZE))

func _set_page_margins(left: int, top: int, right: int, bottom: int) -> void:
	if content_margin == null:
		return
	content_margin.add_theme_constant_override("margin_left", left)
	content_margin.add_theme_constant_override("margin_top", top)
	content_margin.add_theme_constant_override("margin_right", right)
	content_margin.add_theme_constant_override("margin_bottom", bottom)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		size = get_viewport_rect().size
		if page != null:
			page.size = get_viewport_rect().size
			page.custom_minimum_size = get_viewport_rect().size
		if content_margin != null:
			content_margin.size = get_viewport_rect().size
		if root != null:
			root.custom_minimum_size = Vector2(0, get_viewport_rect().size.y - 64.0)
		if current_screen == "menu":
			_show_main_menu()
		elif current_screen == "roster":
			_show_roster_select()
		elif current_screen == "game" and board_grid != null:
			_show_game_shell(boss_status_text)
			_redraw_game()

func _cell_text(cell: Dictionary, piece: PieceDefinition) -> String:
	var piece_label: String = "?"
	if piece != null:
		piece_label = piece.display_name.left(1)
	var effect_id: String = String(cell["special_effect_id"])
	if effect_id.is_empty():
		if piece != null and piece.icon_texture != null:
			return ""
		return piece_label
	var effect: SpecialEffectDefinition = catalog.get_effect(effect_id)
	if effect == null:
		return piece_label
	return "%s\n%s" % [piece_label, effect.marker]

func _on_cell_pressed(pos: Vector2i) -> void:
	if is_animating_board:
		return
	if cheat_pick_cell_pending:
		cheat_pick_cell_pending = false
		selected_cell = pos
		if cheat_panel != null:
			cheat_panel.visible = true
		_update_cheat_panel_from_selection()
		_redraw_game()
		return
	if cheat_panel != null and cheat_panel.visible:
		selected_cell = pos
		_update_cheat_panel_from_selection()
		_redraw_game()
		return
	var cell: Dictionary = board.get_cell(pos)
	if int(cell["locked_turns"]) > 0:
		boss_label.text = "团子大魔王：该格被锁定"
		return
	if selected_cell == Vector2i(-1, -1):
		if not String(cell["special_effect_id"]).is_empty():
			_activate_special(pos)
		else:
			selected_cell = pos
			_redraw_game()
		return
	if selected_cell == pos:
		selected_cell = Vector2i(-1, -1)
		_redraw_game()
		return
	if not board.are_adjacent(selected_cell, pos):
		selected_cell = pos
		_redraw_game()
		return
	_try_swap(selected_cell, pos)

func _try_swap(a: Vector2i, b: Vector2i) -> void:
	selected_cell = Vector2i(-1, -1)
	var a_cell: Dictionary = board.get_cell(a)
	var b_cell: Dictionary = board.get_cell(b)
	if int(a_cell["locked_turns"]) > 0 or int(b_cell["locked_turns"]) > 0:
		_redraw_game()
		return
	if not String(a_cell["special_effect_id"]).is_empty() or not String(b_cell["special_effect_id"]).is_empty():
		_play_swap_then_special_combo(a, b)
		return
	_play_swap_then_resolve(a, b)

func _play_swap_then_resolve(a: Vector2i, b: Vector2i) -> void:
	is_animating_board = true
	await _animate_swap(a, b, false)
	board.swap(a, b)
	_remap_swapped_cell_buttons(a, b)
	var matches: Array = board.find_matches()
	if matches.is_empty():
		await _animate_swap_back(a, b)
		board.swap(a, b)
		combo = 0
		is_animating_board = false
		_redraw_game()
		return
	await _resolve_matches(matches, b)
	if boss_hp <= 0:
		return
	is_animating_board = false
	_after_player_move()

func _play_swap_then_special_combo(a: Vector2i, b: Vector2i) -> void:
	is_animating_board = true
	await _animate_swap(a, b, false)
	board.swap(a, b)
	_remap_swapped_cell_buttons(a, b)
	await _activate_special_combo(a, b)
	is_animating_board = false

func _activate_special(pos: Vector2i) -> void:
	is_animating_board = true
	var source_cell: Dictionary = board.get_cell(pos)
	var targets: Array = board.collect_effect_targets(pos)
	_charge_special_resonance(String(source_cell["piece_id"]), String(source_cell["special_effect_id"]), targets)
	await _animate_clear(targets)
	await _animate_attack_boss(targets)
	_damage_boss(targets)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return
	board.clear_positions(targets)
	_add_score(120 + targets.size() * 5)
	stats["special"] += 1
	await _collapse_refill_and_animate()
	await _resolve_cascades()
	if boss_hp <= 0:
		return
	is_animating_board = false
	_after_player_move()

func _activate_special_combo(a: Vector2i, b: Vector2i) -> void:
	var a_cell: Dictionary = board.get_cell(a)
	var b_cell: Dictionary = board.get_cell(b)
	var targets: Array = []
	var a_effect: String = String(a_cell["special_effect_id"])
	var b_effect: String = String(b_cell["special_effect_id"])
	if a_effect == "rainbow":
		targets = board.collect_effect_targets(a, String(b_cell["piece_id"]))
	elif b_effect == "rainbow":
		targets = board.collect_effect_targets(b, String(a_cell["piece_id"]))
	elif a_effect == "stripe" and b_effect == "stripe":
		targets = board.collect_effect_targets(a)
		for pos in board.collect_effect_targets(b):
			if not targets.has(pos):
				targets.append(pos)
	elif a_effect == "bomb" and b_effect == "bomb":
		targets = _square_targets(a, 2)
	elif (a_effect == "stripe" and b_effect == "bomb") or (a_effect == "bomb" and b_effect == "stripe"):
		for offset in [-1, 0, 1]:
			var row_pos: Vector2i = Vector2i(a.x, clamp(a.y + offset, 0, BoardModel.HEIGHT - 1))
			for x in range(BoardModel.WIDTH):
				var p: Vector2i = Vector2i(x, row_pos.y)
				if not targets.has(p):
					targets.append(p)
	else:
		targets = board.collect_effect_targets(a)
	_charge_special_resonance(String(a_cell["piece_id"]), a_effect, targets)
	_charge_special_resonance(String(b_cell["piece_id"]), b_effect, targets)
	await _animate_clear(targets)
	await _animate_attack_boss(targets)
	_damage_boss(targets)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return
	board.clear_positions(targets)
	_add_score(200 + targets.size() * 5)
	stats["combo"] += 1
	await _collapse_refill_and_animate()
	await _resolve_cascades()
	if boss_hp <= 0:
		return
	_after_player_move()

func _resolve_matches(matches: Array, preferred_spawn: Vector2i, resolve_after: bool = true) -> void:
	var cleared: Array = []
	var spawn_specs: Array = []
	for group in matches:
		var positions: Array = group["positions"]
		var spawn_pos: Vector2i = preferred_spawn if positions.has(preferred_spawn) else positions[0]
		var effect_id: String = _effect_for_group(group)
		for pos in positions:
			if not cleared.has(pos):
				cleared.append(pos)
		if not effect_id.is_empty():
			spawn_specs.append({"pos": spawn_pos, "effect_id": effect_id, "direction": _direction_for_group(group)})
		var piece_slot: int = _slot_index_for_piece_id(String(group["piece_id"]))
		var charge_reason: String = "消除"
		if piece_slot >= 0:
			charge_reason = "消除%s" % SLOT_ATTRIBUTES[piece_slot]
		_add_resonance(piece_slot, positions.size(), charge_reason)
		if not effect_id.is_empty():
			_add_resonance(4, 8 + max(0, positions.size() - 4) * 4, "生成特殊团子")
			if piece_slot == 0:
				_add_resonance(0, 6, "衍射特殊构型")
		var piece: PieceDefinition = catalog.get_piece(String(group["piece_id"]))
		var multiplier: float = 1.0 if piece == null else piece.multiplier
		var base: int = 10
		if effect_id == "stripe":
			base = 30
		elif effect_id == "rainbow":
			base = 50
		elif effect_id == "bomb":
			base = 40
		_add_score(roundi(base * multiplier * max(1, positions.size() - 2)))
	stats["normal"] += 1
	await _animate_clear(cleared)
	await _animate_attack_boss(cleared)
	_damage_boss(cleared)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return
	board.clear_positions(cleared)
	for spec in spawn_specs:
		board.set_cell(spec["pos"], {
			"piece_id": String(board.get_cell(spec["pos"])["piece_id"]) if board.get_cell(spec["pos"]) != null else String(matches[0]["piece_id"]),
			"special_effect_id": spec["effect_id"],
			"special_direction": spec["direction"],
			"locked_turns": 0,
		})
	await _collapse_refill_and_animate()
	if resolve_after:
		await _resolve_cascades()

func _resolve_cascades() -> void:
	while true:
		if boss_hp <= 0:
			return
		var matches: Array = board.find_matches()
		if matches.is_empty():
			break
		combo += 1
		max_combo = max(max_combo, combo)
		_add_resonance(3, 6 + combo * 2, "连锁Combo")
		await _resolve_matches(matches, Vector2i(-1, -1), false)
		if boss_hp <= 0:
			return

func _animate_swap(a: Vector2i, b: Vector2i, reset_after: bool = true) -> void:
	var button_a: Button = _get_cell_button(a)
	var button_b: Button = _get_cell_button(b)
	if button_a == null or button_b == null:
		return
	var start_a: Vector2 = button_a.position
	var start_b: Vector2 = button_b.position
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(button_a, "position", start_b, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button_b, "position", start_a, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if reset_after:
		button_a.position = start_a
		button_b.position = start_b

func _animate_swap_back(a: Vector2i, b: Vector2i) -> void:
	var button_a: Button = _get_cell_button(a)
	var button_b: Button = _get_cell_button(b)
	if button_a == null or button_b == null:
		return
	var home_a: Vector2 = button_b.position
	var home_b: Vector2 = button_a.position
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(button_a, "position", home_a, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button_b, "position", home_b, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func _remap_swapped_cell_buttons(a: Vector2i, b: Vector2i) -> void:
	var button_a: Button = _get_cell_button(a)
	var button_b: Button = _get_cell_button(b)
	if button_a == null or button_b == null:
		return
	button_a.set_meta("board_pos", b)
	button_b.set_meta("board_pos", a)

func _animate_clear(positions: Array) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var animated: bool = false
	for pos in positions:
		var button: Button = _get_cell_button(pos)
		if button == null:
			continue
		animated = true
		button.pivot_offset = button.size * 0.5
		tween.tween_property(button, "scale", Vector2(0.15, 0.15), CLEAR_ANIM_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(button, "modulate:a", 0.0, CLEAR_ANIM_SECONDS)
	if animated:
		await tween.finished
		await get_tree().create_timer(POST_CLEAR_PAUSE_SECONDS).timeout

func _animate_attack_boss(positions: Array) -> void:
	if positions.is_empty() or boss_avatar == null:
		return
	var target_rect: Rect2 = boss_avatar.get_global_rect()
	var target_center: Vector2 = target_rect.position + target_rect.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var animated: bool = false
	var cell_size: float = _board_cell_size()
	for index in range(positions.size()):
		var pos: Vector2i = positions[index]
		var button: Button = _get_cell_button(pos)
		if button == null:
			continue
		var cell: Variant = board.get_cell(pos)
		if cell == null:
			continue
		var piece: PieceDefinition = catalog.get_piece(String(cell["piece_id"]))
		var projectile: Control
		var projectile_size: Vector2 = Vector2(cell_size * 0.48, cell_size * 0.48)
		if piece != null and piece.icon_texture != null:
			var icon: TextureRect = TextureRect.new()
			icon.texture = piece.icon_texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			projectile = icon
		else:
			var label: Label = Label.new()
			label.text = _cell_text(cell, piece)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", max(16, int(cell_size * 0.24)))
			projectile = label
		projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		projectile.custom_minimum_size = projectile_size
		projectile.size = projectile_size
		projectile.z_index = 80
		add_child(projectile)
		var start_rect: Rect2 = button.get_global_rect()
		projectile.global_position = start_rect.position + start_rect.size * 0.5 - projectile_size * 0.5
		projectile.pivot_offset = projectile_size * 0.5
		animated = true
		var end_position: Vector2 = target_center - projectile_size * 0.5
		var delay: float = float(index) * ATTACK_FLY_STAGGER_SECONDS
		tween.tween_property(projectile, "global_position", end_position, ATTACK_FLY_SECONDS).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(projectile, "scale", Vector2(0.34, 0.34), ATTACK_FLY_SECONDS).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(projectile, "modulate:a", 0.0, ATTACK_FLY_SECONDS * 0.35).set_delay(delay + ATTACK_FLY_SECONDS * 0.65)
		tween.tween_callback(Callable(projectile, "queue_free")).set_delay(delay + ATTACK_FLY_SECONDS)
	if animated:
		await tween.finished

func _collapse_refill_and_animate() -> void:
	var drop_specs: Array = _collapse_refill_with_drop_specs()
	_redraw_game()
	await _animate_drop_specs(drop_specs)

func _collapse_refill_with_drop_specs() -> Array:
	var specs: Array = []
	for x in range(BoardModel.WIDTH):
		var survivors: Array = []
		for y in range(BoardModel.HEIGHT - 1, -1, -1):
			if board.cells[y][x] != null:
				survivors.append({"cell": board.cells[y][x], "from_y": y})
		var survivor_index: int = 0
		var spawn_index: int = 0
		for y in range(BoardModel.HEIGHT - 1, -1, -1):
			if survivor_index < survivors.size():
				var survivor: Dictionary = survivors[survivor_index]
				board.cells[y][x] = survivor["cell"]
				var from_y: int = int(survivor["from_y"])
				if from_y != y:
					specs.append({"from": Vector2i(x, from_y), "to": Vector2i(x, y), "spawn": false})
				survivor_index += 1
			else:
				board.cells[y][x] = board._new_cell(board._random_piece_id())
				specs.append({"from": Vector2i(x, -1 - spawn_index), "to": Vector2i(x, y), "spawn": true})
				spawn_index += 1
	return specs

func _animate_drop_specs(specs: Array) -> void:
	if board_grid == null or specs.is_empty():
		return
	var fall_tween: Tween = create_tween()
	fall_tween.set_parallel(true)
	var animated: bool = false
	var cell_size: float = _board_cell_size()
	for spec in specs:
		var to_pos: Vector2i = spec["to"]
		var from_pos: Vector2i = spec["from"]
		var button: Button = _get_cell_button(to_pos)
		if button == null:
			continue
		var final_position: Vector2 = button.position
		var row_delta: int = from_pos.y - to_pos.y
		if bool(spec.get("spawn", false)):
			row_delta -= DROP_SPAWN_EXTRA_ROWS
		var start_position: Vector2 = final_position + Vector2(0, row_delta * (cell_size + 2.0))
		var landing_position: Vector2 = final_position + Vector2(0, DROP_LANDING_OVERSHOOT)
		button.position = start_position
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2.ONE
		if bool(spec.get("spawn", false)):
			button.modulate.a = 0.0
		animated = true
		var drop_rows: int = abs(row_delta)
		var duration: float = DROP_BASE_SECONDS + float(drop_rows) * DROP_SECONDS_PER_ROW
		var delay: float = float(to_pos.x) * DROP_COLUMN_STAGGER_SECONDS
		if bool(spec.get("spawn", false)):
			delay += DROP_SPAWN_DELAY_SECONDS
			fall_tween.tween_property(button, "modulate:a", 1.0, min(0.18, duration * 0.45)).set_delay(delay)
		fall_tween.tween_property(button, "position", landing_position, duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if animated:
		await fall_tween.finished
		var settle_tween: Tween = create_tween()
		settle_tween.set_parallel(true)
		for spec in specs:
			var button: Button = _get_cell_button(spec["to"])
			if button == null:
				continue
			var final_position: Vector2 = button.position - Vector2(0, DROP_LANDING_OVERSHOOT)
			button.scale = Vector2(1.04, 0.94)
			settle_tween.tween_property(button, "position", final_position, DROP_SETTLE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			settle_tween.tween_property(button, "scale", Vector2.ONE, DROP_SETTLE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await settle_tween.finished
		await get_tree().create_timer(POST_DROP_PAUSE_SECONDS).timeout

func _get_cell_button(pos: Vector2i) -> Button:
	if board_grid == null:
		return null
	for child in board_grid.get_children():
		if child is Button and child.has_meta("board_pos") and child.get_meta("board_pos") == pos:
			return child
	return null

func _effect_for_group(group: Dictionary) -> String:
	if group["directions"].size() > 1:
		return "bomb"
	if group["positions"].size() >= 5:
		return "rainbow"
	if group["positions"].size() == 4:
		return "stripe"
	return ""

func _direction_for_group(group: Dictionary) -> String:
	if group["directions"].is_empty():
		return "horizontal"
	var dir: Vector2i = group["directions"][0]
	return "vertical" if dir.y != 0 else "horizontal"

func _add_score(amount: int) -> void:
	var final_amount: int = amount
	if skip_bonus_pending:
		final_amount = roundi(float(final_amount) * 1.1)
		skip_bonus_pending = false
	final_amount = roundi(float(final_amount) * (1.0 + min(combo, 5) * 0.2))
	if run_active:
		final_amount = roundi(float(final_amount) * (1.0 + _collectible_total("score_mult")))
	score += final_amount

func _after_player_move() -> void:
	combo += 1
	max_combo = max(max_combo, combo)
	moves_since_enemy += 1
	var locked_count: int = _locked_cell_count()
	if locked_count > 0:
		_add_resonance(2, min(6, locked_count), "锁定回合减少")
	board.tick_locks()
	if not board.has_possible_move():
		_end_game()
		return
	var enemy_interval: int = _enemy_check_interval()
	if moves_since_enemy >= enemy_interval:
		moves_since_enemy = 0
		if suppress_next_enemy_effect:
			suppress_next_enemy_effect = false
			_set_boss_status("冷凝共鸣：抵消了团子大魔王的干扰", "冷凝")
			_redraw_game()
			return
		if rng.randf() <= _enemy_effect_chance():
			if _boss_phase() == 1 and rng.randf() <= 0.45:
				_trigger_enemy_extra_skill()
			else:
				_trigger_enemy_effect()
			return
	_redraw_game()

func _enemy_check_interval() -> int:
	if current_boss != null:
		return max(1, current_boss.skill_interval)
	if _boss_phase() <= 2:
		return 2
	return 3

func _enemy_effect_chance() -> float:
	if current_boss != null:
		return clamp(current_boss.skill_chance, 0.0, 1.0)
	match _boss_phase():
		3:
			return 0.30
		2:
			return 0.55
	return 0.70

func _trigger_enemy_extra_skill() -> void:
	_set_boss_status("%s进入濒危阶段，额外技能已触发。" % _current_boss_name(), "蓄力")
	_add_resonance(2, 8, "大魔王额外技能")
	_redraw_game()

func _trigger_enemy_effect() -> void:
	if current_boss != null and not current_boss.skill_effect_id.is_empty():
		_apply_boss_skill_effect(current_boss.skill_effect_id, current_boss.skill_effect_params)
		return
	var roll: int = rng.randi_range(0, 2)
	if roll == 0:
		board.lock_random_cells(3)
		_add_resonance(2, 10, "大魔王锁定")
		_set_boss_status("团子大魔王：锁定了 3 个格子", "攻击")
		_redraw_game()
	elif roll == 1:
		combo = 0
		_add_resonance(2, 6, "大魔王打断")
		_set_boss_status("团子大魔王：打断了 Combo", "怒")
		_redraw_game()
	else:
		board.lock_random_cells(1)
		_add_resonance(2, 5, "大魔王干扰")
		_set_boss_status("团子大魔王：制造了锁定干扰", "扰")
		_redraw_game()

func _apply_boss_skill_effect(effect_id: String, params: Dictionary) -> void:
	match effect_id:
		"boss_random_interference":
			var roll: int = rng.randi_range(0, 2)
			if roll == 0:
				_apply_boss_lock_cells(_param_int(params, "lock_large", 3), _param_int(params, "lock_resonance", 10), "%s：锁定了 %d 个格子")
			elif roll == 1:
				_apply_boss_break_combo(_param_int(params, "break_resonance", 6))
			else:
				_apply_boss_lock_cells(_param_int(params, "lock_small", 1), _param_int(params, "small_resonance", 5), "%s：制造了锁定干扰")
		"lock_cells":
			_apply_boss_lock_cells(_param_int(params, "count", 1), _param_int(params, "resonance", 5), _param_text(params, "status", "%s：锁定了 %d 个格子"))
		"break_combo":
			_apply_boss_break_combo(_param_int(params, "resonance", 6))
		"none", "":
			_redraw_game()
		_:
			push_warning("Unsupported boss skill effect_id: %s" % effect_id)
			_redraw_game()

func _apply_boss_lock_cells(count: int, resonance: int, status_template: String) -> void:
	count = max(1, count)
	board.lock_random_cells(count)
	_add_resonance(2, resonance, "大魔王锁定")
	if status_template.contains("%d"):
		_set_boss_status(status_template % [_current_boss_name(), count], "攻击")
	elif status_template.contains("%s"):
		_set_boss_status(status_template % _current_boss_name(), "攻击")
	else:
		_set_boss_status(status_template, "攻击")
	_redraw_game()

func _apply_boss_break_combo(resonance: int) -> void:
	combo = 0
	_add_resonance(2, resonance, "大魔王打断")
	_set_boss_status("%s：打断了 Combo" % _current_boss_name(), "怒")
	_redraw_game()

func _resonance_value(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= resonance_values.size():
		return 0
	return resonance_values[slot_index]

func _resonance_cost(slot_index: int) -> int:
	if slot_index >= 0 and slot_index < current_roster.size():
		var piece: PieceDefinition = catalog.get_piece(current_roster[slot_index])
		if piece != null and piece.resonance_cost > 0:
			return piece.resonance_cost
	if slot_index >= 0 and slot_index < RESONANCE_MAX_VALUES.size():
		return RESONANCE_MAX_VALUES[slot_index]
	return 30

func _is_resonance_ready(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_ATTRIBUTES.size() and _resonance_value(slot_index) >= _resonance_cost(slot_index)

func _add_resonance(slot_index: int, amount: int, _reason: String = "") -> void:
	if slot_index < 0 or slot_index >= SLOT_ATTRIBUTES.size() or amount <= 0:
		return
	if run_active:
		amount = max(1, roundi(float(amount) * (1.0 + _collectible_total("resonance_mult"))))
	while resonance_values.size() < SLOT_ATTRIBUTES.size():
		resonance_values.append(0)
	resonance_values[slot_index] = min(_resonance_cost(slot_index), resonance_values[slot_index] + amount)

func _slot_index_for_piece_id(piece_id: String) -> int:
	for index in range(current_roster.size()):
		if current_roster[index] == piece_id:
			return index
	return -1

func _charge_special_resonance(piece_id: String, effect_id: String, targets: Array) -> void:
	if effect_id.is_empty():
		return
	_add_resonance(1, 10 + int(targets.size() / 2), "特殊团子")
	if _slot_index_for_piece_id(piece_id) == 0:
		_add_resonance(0, 6, "衍射特消")
	if targets.size() >= BoardModel.WIDTH:
		_add_resonance(5, 8 + int(targets.size() / 2), "大范围导电")

func _release_resonance(slot_index: int) -> void:
	if board == null or is_animating_board or not _is_resonance_ready(slot_index):
		return
	is_animating_board = true
	var release_target_cell: Vector2i = selected_cell
	selected_cell = Vector2i(-1, -1)
	var released: bool = false
	var piece: PieceDefinition = catalog.get_piece(current_roster[slot_index]) if slot_index < current_roster.size() else null
	if piece != null:
		released = await _apply_resonance_effect(piece, release_target_cell)
	if released:
		resonance_values[slot_index] = 0
		if boss_hp <= 0:
			return
		is_animating_board = false
		_after_player_move()
	else:
		is_animating_board = false
		_set_boss_status("%s共鸣解放没有合法目标" % SLOT_ATTRIBUTES[slot_index], "共鸣")
		_redraw_game()

func _apply_resonance_effect(piece: PieceDefinition, release_target_cell: Vector2i) -> bool:
	var params: Dictionary = piece.resonance_effect_params
	match piece.resonance_effect_id:
		"create_special_pieces":
			return _release_create_special_pieces(params)
		"clear_most_common":
			return await _release_clear_targets(_targets_for_most_common_piece(), _param_int(params, "score", 180), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "共鸣"))
		"cleanse_locks":
			return _release_cleanse_locks(params)
		"shuffle_board":
			return _release_shuffle_board(params)
		"clear_area":
			var center: Vector2i = release_target_cell if release_target_cell != Vector2i(-1, -1) else Vector2i(rng.randi_range(0, BoardModel.WIDTH - 1), rng.randi_range(0, BoardModel.HEIGHT - 1))
			return await _release_clear_targets(_square_targets(center, _param_int(params, "radius", 1)), _param_int(params, "score", 160), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "共鸣"))
		"clear_random_cross":
			return await _release_clear_targets(_targets_for_random_cross(), _param_int(params, "score", 170), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "共鸣"))
		"none", "":
			return false
	push_warning("Unsupported resonance effect_id: %s" % piece.resonance_effect_id)
	return false

func _release_create_special_pieces(params: Dictionary) -> bool:
	var candidates: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			var cell: Dictionary = board.get_cell(pos)
			if String(cell["special_effect_id"]).is_empty() and int(cell["locked_turns"]) <= 0:
				candidates.append(pos)
	if candidates.is_empty():
		return false
	candidates.shuffle()
	var count: int = min(_param_int(params, "count", 2), candidates.size())
	for i in range(count):
		var pos: Vector2i = candidates[i]
		var cell: Dictionary = board.get_cell(pos)
		cell["special_effect_id"] = _param_text(params, "special_effect_id", "stripe")
		cell["special_direction"] = "horizontal" if rng.randi_range(0, 1) == 0 else "vertical"
		board.set_cell(pos, cell)
	_add_score(_param_int(params, "score", 120))
	_set_boss_status(_param_text(params, "status", "共鸣解放：生成了特殊团子"), _param_text(params, "avatar", "共鸣"))
	_redraw_game()
	return true

func _release_cleanse_locks(params: Dictionary) -> bool:
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			board.cells[y][x]["locked_turns"] = 0
	suppress_next_enemy_effect = bool(params.get("suppress_next_enemy", true))
	_add_score(_param_int(params, "score", 100))
	_set_boss_status(_param_text(params, "status", "共鸣解放：解除锁定"), _param_text(params, "avatar", "共鸣"))
	_redraw_game()
	return true

func _release_shuffle_board(params: Dictionary) -> bool:
	var piece_ids: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			piece_ids.append(String(board.cells[y][x]["piece_id"]))
	piece_ids.shuffle()
	var index: int = 0
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			board.cells[y][x]["piece_id"] = piece_ids[index]
			index += 1
	_add_score(_param_int(params, "score", 120))
	_set_boss_status(_param_text(params, "status", "共鸣解放：重排棋盘"), _param_text(params, "avatar", "共鸣"))
	_redraw_game()
	return true

func _param_int(params: Dictionary, key: String, default_value: int) -> int:
	var value: Variant = params.get(key, default_value)
	if value is int:
		return value
	if value is float:
		return roundi(value)
	var text: String = String(value)
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return roundi(float(text))
	return default_value

func _param_float(params: Dictionary, key: String, default_value: float) -> float:
	var value: Variant = params.get(key, default_value)
	if value is int or value is float:
		return float(value)
	var text: String = String(value)
	if text.is_valid_float():
		return float(text)
	return default_value

func _param_text(params: Dictionary, key: String, default_value: String) -> String:
	var value: String = String(params.get(key, default_value))
	return default_value if value.is_empty() else value

func _release_diffraction() -> bool:
	var candidates: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			var cell: Dictionary = board.get_cell(pos)
			if String(cell["special_effect_id"]).is_empty() and int(cell["locked_turns"]) <= 0:
				candidates.append(pos)
	if candidates.is_empty():
		return false
	candidates.shuffle()
	var count: int = min(2, candidates.size())
	for i in range(count):
		var pos: Vector2i = candidates[i]
		var cell: Dictionary = board.get_cell(pos)
		cell["special_effect_id"] = "stripe"
		cell["special_direction"] = "horizontal" if rng.randi_range(0, 1) == 0 else "vertical"
		board.set_cell(pos, cell)
	_add_score(120)
	_set_boss_status("衍射共鸣解放：生成了条纹团子", "衍射")
	_redraw_game()
	return true

func _release_condensation() -> bool:
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			board.cells[y][x]["locked_turns"] = 0
	suppress_next_enemy_effect = true
	_add_score(100)
	_set_boss_status("冷凝共鸣解放：解除锁定并抵消下一次干扰", "冷凝")
	_redraw_game()
	return true

func _release_aero() -> bool:
	var piece_ids: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			piece_ids.append(String(board.cells[y][x]["piece_id"]))
	piece_ids.shuffle()
	var index: int = 0
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			board.cells[y][x]["piece_id"] = piece_ids[index]
			index += 1
	_add_score(120)
	_set_boss_status("气动共鸣解放：重排棋盘", "气动")
	_redraw_game()
	return true

func _release_clear_targets(targets: Array, base_score: int, status_text: String, avatar_text: String = "共鸣") -> bool:
	targets = _unique_in_bounds_targets(targets)
	if targets.is_empty():
		return false
	await _animate_clear(targets)
	await _animate_attack_boss(targets)
	_damage_boss(targets)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return true
	board.clear_positions(targets)
	_add_score(base_score + targets.size() * 8)
	await _collapse_refill_and_animate()
	await _resolve_cascades()
	_set_boss_status(status_text, avatar_text)
	return true

func _targets_for_most_common_piece() -> Array:
	var counts: Dictionary = {}
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var piece_id: String = String(board.cells[y][x]["piece_id"])
			counts[piece_id] = int(counts.get(piece_id, 0)) + 1
	var best_id: String = ""
	var best_count: int = 0
	for piece_id in counts.keys():
		if int(counts[piece_id]) > best_count:
			best_id = String(piece_id)
			best_count = int(counts[piece_id])
	var targets: Array = []
	if best_id.is_empty():
		return targets
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			if String(board.cells[y][x]["piece_id"]) == best_id:
				targets.append(Vector2i(x, y))
	return targets

func _targets_for_random_cross() -> Array:
	var targets: Array = []
	var row: int = rng.randi_range(0, BoardModel.HEIGHT - 1)
	var column: int = rng.randi_range(0, BoardModel.WIDTH - 1)
	for x in range(BoardModel.WIDTH):
		targets.append(Vector2i(x, row))
	for y in range(BoardModel.HEIGHT):
		targets.append(Vector2i(column, y))
	return _unique_in_bounds_targets(targets)

func _unique_in_bounds_targets(targets: Array) -> Array:
	var result: Array = []
	for pos in targets:
		if board.in_bounds(pos) and not result.has(pos):
			result.append(pos)
	return result

func _locked_cell_count() -> int:
	if board == null or board.cells.is_empty():
		return 0
	var count: int = 0
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			if int(board.cells[y][x]["locked_turns"]) > 0:
				count += 1
	return count

func _set_boss_status(text: String, avatar_text: String = "魔王") -> void:
	boss_status_text = text
	if boss_label != null:
		boss_label.text = text
	if boss_avatar != null:
		boss_avatar.text = avatar_text

func _build_cheat_panel() -> void:
	cheat_panel = PanelContainer.new()
	cheat_panel.visible = false
	cheat_panel.z_index = 100
	cheat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	cheat_panel.anchor_left = 0.04
	cheat_panel.anchor_top = 0.08
	cheat_panel.anchor_right = 0.96
	cheat_panel.anchor_bottom = 0.96
	cheat_panel.offset_left = 0
	cheat_panel.offset_top = 0
	cheat_panel.offset_right = 0
	cheat_panel.offset_bottom = 0
	add_child(cheat_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cheat_panel.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "战斗作弊器"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	cheat_cell_label = Label.new()
	cheat_cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cheat_cell_label)
	var coord_row: HBoxContainer = HBoxContainer.new()
	coord_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coord_row.add_theme_constant_override("separation", 10)
	box.add_child(coord_row)
	coord_row.add_child(_make_cheat_label("X"))
	cheat_x_spin = _make_cheat_spin(0, BoardModel.WIDTH - 1)
	coord_row.add_child(cheat_x_spin)
	coord_row.add_child(_make_cheat_label("Y"))
	cheat_y_spin = _make_cheat_spin(0, BoardModel.HEIGHT - 1)
	coord_row.add_child(cheat_y_spin)
	coord_row.add_child(_make_button("应用坐标", Callable(self, "_cheat_select_coord")))
	coord_row.add_child(_make_button("点棋盘选格", Callable(self, "_cheat_pick_cell_from_board")))
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	box.add_child(action_row)
	action_row.add_child(_make_button("应用到格子", Callable(self, "_cheat_apply_cell")))
	action_row.add_child(_make_button("清为普通", Callable(self, "_cheat_clear_cell_special")))
	var edit_grid: GridContainer = GridContainer.new()
	edit_grid.columns = 2
	edit_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(edit_grid)
	edit_grid.add_child(_make_cheat_label("团子"))
	cheat_piece_option = OptionButton.new()
	cheat_piece_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for piece: PieceDefinition in catalog.get_unlocked_pieces(save.unlocked_piece_ids):
		cheat_piece_option.add_item(piece.display_name)
		cheat_piece_option.set_item_metadata(cheat_piece_option.get_item_count() - 1, piece.id)
	edit_grid.add_child(cheat_piece_option)
	edit_grid.add_child(_make_cheat_label("状态"))
	cheat_effect_option = OptionButton.new()
	cheat_effect_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_effect_option.add_item("普通")
	cheat_effect_option.set_item_metadata(0, "")
	for effect_id in ["stripe", "bomb", "rainbow"]:
		var effect: SpecialEffectDefinition = catalog.get_effect(effect_id)
		if effect != null:
			cheat_effect_option.add_item(effect.display_name)
			cheat_effect_option.set_item_metadata(cheat_effect_option.get_item_count() - 1, effect.id)
	edit_grid.add_child(cheat_effect_option)
	edit_grid.add_child(_make_cheat_label("方向"))
	cheat_direction_option = OptionButton.new()
	cheat_direction_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_direction_option.add_item("横向")
	cheat_direction_option.set_item_metadata(0, "horizontal")
	cheat_direction_option.add_item("纵向")
	cheat_direction_option.set_item_metadata(1, "vertical")
	edit_grid.add_child(cheat_direction_option)
	edit_grid.add_child(_make_cheat_label("锁定回合"))
	cheat_lock_spin = _make_cheat_spin(0, 9)
	edit_grid.add_child(cheat_lock_spin)
	var boss_row: HBoxContainer = HBoxContainer.new()
	boss_row.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_row.add_theme_constant_override("separation", 10)
	box.add_child(boss_row)
	boss_row.add_child(_make_button("大魔王锁3格", Callable(self, "_cheat_boss_lock_three")))
	boss_row.add_child(_make_button("大魔王断Combo", Callable(self, "_cheat_boss_break_combo")))
	boss_row.add_child(_make_button("Boss血量清0", Callable(self, "_cheat_boss_kill")))
	boss_row.add_child(_make_button("随机干扰", Callable(self, "_trigger_enemy_effect")))
	_update_cheat_panel_from_selection()

func _make_cheat_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _make_cheat_spin(minimum: int, maximum: int) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.rounded = true
	spin.custom_minimum_size = Vector2(90, 56)
	return spin

func _toggle_cheat_panel() -> void:
	if cheat_panel == null:
		return
	cheat_panel.visible = not cheat_panel.visible
	_update_cheat_panel_from_selection()

func _cheat_target_pos() -> Vector2i:
	var pos: Vector2i = selected_cell
	if pos == Vector2i(-1, -1) and cheat_x_spin != null and cheat_y_spin != null:
		pos = Vector2i(int(cheat_x_spin.value), int(cheat_y_spin.value))
	return pos

func _cheat_select_coord() -> void:
	selected_cell = Vector2i(int(cheat_x_spin.value), int(cheat_y_spin.value))
	_update_cheat_panel_from_selection()
	_redraw_game()

func _cheat_pick_cell_from_board() -> void:
	cheat_pick_cell_pending = true
	if cheat_panel != null:
		cheat_panel.visible = false
	_set_boss_status("作弊器：点击棋盘上的目标格子", "选格")

func _cheat_apply_cell() -> void:
	var pos: Vector2i = _cheat_target_pos()
	if board == null or not board.in_bounds(pos):
		return
	selected_cell = pos
	var piece_id: String = String(cheat_piece_option.get_selected_metadata())
	var effect_id: String = String(cheat_effect_option.get_selected_metadata())
	var direction: String = String(cheat_direction_option.get_selected_metadata())
	board.set_cell(pos, {
		"piece_id": piece_id,
		"special_effect_id": effect_id,
		"special_direction": direction,
		"locked_turns": int(cheat_lock_spin.value),
	})
	_set_boss_status("作弊器：已修改 (%d,%d)" % [pos.x, pos.y], "作弊")
	_redraw_game()

func _cheat_clear_cell_special() -> void:
	var pos: Vector2i = _cheat_target_pos()
	if board == null or not board.in_bounds(pos):
		return
	var cell: Dictionary = board.get_cell(pos)
	cell["special_effect_id"] = ""
	cell["special_direction"] = "horizontal"
	cell["locked_turns"] = 0
	board.set_cell(pos, cell)
	selected_cell = pos
	_set_boss_status("作弊器：已清除 (%d,%d) 状态" % [pos.x, pos.y], "作弊")
	_redraw_game()

func _cheat_boss_lock_three() -> void:
	board.lock_random_cells(3)
	_add_resonance(2, 10, "作弊器锁定")
	_set_boss_status("作弊器：团子大魔王锁定了 3 个格子", "攻击")
	_redraw_game()

func _cheat_boss_break_combo() -> void:
	combo = 0
	_add_resonance(2, 6, "作弊器打断")
	_set_boss_status("作弊器：团子大魔王打断了 Combo", "怒")
	_redraw_game()

func _cheat_boss_kill() -> void:
	if board == null or is_animating_board or boss_hp <= 0:
		return
	boss_hp = 0
	_update_boss_hp_ui()
	_set_boss_status("作弊器：Boss 血量已清 0", "胜利")
	_finish_battle()

func _update_cheat_panel_from_selection() -> void:
	if cheat_panel == null or board == null:
		return
	var pos: Vector2i = _cheat_target_pos()
	if not board.in_bounds(pos):
		pos = Vector2i(0, 0)
	if cheat_x_spin != null:
		cheat_x_spin.value = pos.x
	if cheat_y_spin != null:
		cheat_y_spin.value = pos.y
	var cell: Variant = board.get_cell(pos)
	if cell == null:
		if cheat_cell_label != null:
			cheat_cell_label.text = "当前格子：(%d,%d)，正在下落" % [pos.x, pos.y]
		return
	if cheat_cell_label != null:
		cheat_cell_label.text = "当前格子：(%d,%d)，点击棋盘可选格" % [pos.x, pos.y]
	_select_option_by_metadata(cheat_piece_option, String(cell["piece_id"]))
	_select_option_by_metadata(cheat_effect_option, String(cell["special_effect_id"]))
	_select_option_by_metadata(cheat_direction_option, String(cell["special_direction"]))
	if cheat_lock_spin != null:
		cheat_lock_spin.value = int(cell["locked_turns"])

func _select_option_by_metadata(option: OptionButton, value: String) -> void:
	if option == null:
		return
	for i in range(option.get_item_count()):
		if String(option.get_item_metadata(i)) == value:
			option.select(i)
			return
	option.select(0)

func _on_run_battle_won() -> void:
	var node_type: String = String(current_run_node.get("type", "battle"))
	_apply_run_heal_after_battle()
	if node_type == "boss":
		_advance_run_after_node()
		return
	var reward_items: Array = _battle_reward_for_node(current_run_node)
	_show_run_reward("战斗胜利", reward_items)

func _on_run_battle_lost() -> void:
	run_state["lives"] = max(0, int(run_state.get("lives", RUN_MAX_LIVES)) - 1)
	if int(run_state.get("lives", 0)) <= 0:
		_finish_run_failed()
		return
	_clear_screen()
	current_screen = "run_loss"
	_add_title("战斗失利")
	var label: Label = Label.new()
	label.text = "损失 1 点生命。\n剩余生命：%d / %d" % [int(run_state.get("lives", 0)), RUN_MAX_LIVES]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)
	root.add_child(_make_button("回到路线", Callable(self, "_show_run_map")))

func _battle_reward_for_node(node: Dictionary) -> Array:
	var run_floor: int = int(node.get("floor", int(run_state.get("floor", 1))))
	var node_type: String = String(node.get("type", "battle"))
	var reward_items: Array = [_make_shell_reward(8 + run_floor * 2)]
	if node_type == "elite":
		reward_items[0] = _make_shell_reward(14 + run_floor * 3)
		reward_items.append(_make_collectible_reward(_random_collectible("rare")))
	elif rng.randf() <= 0.35:
		reward_items.append(_make_collectible_reward(_random_collectible("common")))
	return reward_items

func _show_supply_node() -> void:
	var roll: int = rng.randi_range(0, 2)
	var reward_items: Array = []
	if roll == 0:
		reward_items.append(_make_life_reward(1))
	elif roll == 1:
		reward_items.append(_make_shell_reward(12 + int(run_state.get("floor", 1)) * 2))
	else:
		reward_items.append(_make_collectible_reward(_random_collectible("common")))
	_show_run_reward("补给包", reward_items)

func _show_shop_node() -> void:
	if _run_shop_items().is_empty():
		run_state["shop_items"] = _generate_shop_items()
	_clear_screen()
	current_screen = "run_shop"
	_add_title("贝币商城")
	var summary: Label = Label.new()
	summary.text = "当前贝币：%d。可以连续购买多个藏品，完成后跳过商城继续探索。" % int(run_state.get("shells", 0))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(summary)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)
	var shop_items: Array = _run_shop_items()
	for index in range(shop_items.size()):
		var item: Dictionary = shop_items[index]
		var collectible: Dictionary = _shop_item_collectible(item)
		var price: int = int(item.get("price", _shop_price(collectible)))
		var sold: bool = bool(item.get("sold", false))
		var captured_index: int = index
		var sold_text: String = "\n已售罄" if sold else ""
		var button: Button = _make_button("%s\n%s\n价格：%d 贝币" % [
			_collectible_name(collectible),
			_collectible_description(collectible) + sold_text,
			price,
		], func() -> void:
			_buy_shop_item(captured_index)
		)
		button.custom_minimum_size = Vector2(330, 190)
		button.disabled = sold or int(run_state.get("shells", 0)) < price
		row.add_child(button)
	root.add_child(_make_button("跳过商城", Callable(self, "_advance_run_after_node")))

func _show_event_node() -> void:
	_clear_screen()
	current_screen = "run_event"
	_add_title("随机事件")
	var info: Label = Label.new()
	info.text = "选择一个事件结果。若事件产生奖励，会作为奖励包展示。"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info)
	root.add_child(_make_button("冒险打捞：失去 1 生命，获得贝币和稀有藏品", Callable(self, "_event_danger_dive")))
	root.add_child(_make_button("潮声祝福：恢复 1 生命", Callable(self, "_event_tide_blessing")))
	root.add_child(_make_button("空手离开", Callable(self, "_advance_run_after_node")))

func _event_danger_dive() -> void:
	if int(run_state.get("lives", 0)) <= 1:
		_show_run_reward("谨慎打捞", [_make_shell_reward(10)])
		return
	run_state["lives"] = int(run_state.get("lives", 0)) - 1
	_show_run_reward("冒险打捞", [_make_shell_reward(18), _make_collectible_reward(_random_collectible("rare"))])

func _event_tide_blessing() -> void:
	_show_run_reward("潮声祝福", [_make_life_reward(1)])

func _show_run_reward(title: String, reward_items: Array) -> void:
	pending_run_reward_items = []
	for item in reward_items:
		var reward_item: Dictionary = item
		if not reward_item.has("accepted"):
			reward_item["accepted"] = null
		pending_run_reward_items.append(reward_item)
	_clear_screen()
	current_screen = "run_reward"
	_add_title(title)
	var label: Label = Label.new()
	label.text = "逐项决定是否收下奖励。"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(label)
	var reward_row: HBoxContainer = HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 14)
	reward_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(reward_row)
	for index in range(pending_run_reward_items.size()):
		var item_data: Dictionary = pending_run_reward_items[index]
		var card: VBoxContainer = VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_theme_constant_override("separation", 8)
		card.custom_minimum_size = Vector2(300, 210)
		reward_row.add_child(card)
		var item_label: Label = Label.new()
		item_label.text = _run_reward_item_text(item_data)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.add_child(item_label)
		var state_label: Label = Label.new()
		state_label.text = _reward_choice_state_text(item_data)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(state_label)
		var choice_row: HBoxContainer = HBoxContainer.new()
		choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
		choice_row.add_theme_constant_override("separation", 8)
		card.add_child(choice_row)
		var captured_index: int = index
		choice_row.add_child(_make_button("收下", func() -> void: _choose_reward_item(captured_index, true)))
		choice_row.add_child(_make_button("丢弃", func() -> void: _choose_reward_item(captured_index, false)))
	if _all_reward_items_chosen():
		root.add_child(_make_button("继续探索", Callable(self, "_continue_after_reward_choices")))

func _choose_reward_item(index: int, accepted: bool) -> void:
	if index < 0 or index >= pending_run_reward_items.size():
		return
	pending_run_reward_items[index]["accepted"] = accepted
	_show_run_reward("奖励确认", pending_run_reward_items)

func _continue_after_reward_choices() -> void:
	for item in pending_run_reward_items:
		var reward_item: Dictionary = item
		if bool(reward_item.get("accepted", false)):
			_apply_run_reward_item(reward_item)
	pending_run_reward_items = []
	_advance_run_after_node()

func _apply_run_reward_item(item: Dictionary) -> void:
	match String(item.get("type", "")):
		"shells":
			run_state["shells"] = int(run_state.get("shells", 0)) + int(item.get("amount", 0))
		"life":
			run_state["lives"] = clamp(int(run_state.get("lives", RUN_MAX_LIVES)) + int(item.get("amount", 0)), 0, RUN_MAX_LIVES)
		"collectible":
			var collectible: Dictionary = _reward_item_collectible(item)
			if not collectible.is_empty():
				var collectibles: Array = _run_collectibles()
				collectibles.append(collectible)
				run_state["collectibles"] = collectibles
				_mark_collectible_seen(String(collectible.get("id", "")))

func _generate_shop_items() -> Array:
	var items: Array = []
	for i in range(3):
		var collectible: Dictionary = _random_collectible("common")
		items.append({
			"collectible": collectible,
			"price": _shop_price(collectible),
			"sold": false,
		})
	return items

func _run_shop_items() -> Array:
	var items: Variant = run_state.get("shop_items", [])
	if items is Array:
		return items
	return []

func _shop_item_collectible(item: Dictionary) -> Dictionary:
	var collectible: Variant = item.get("collectible", {})
	if collectible is Dictionary:
		return collectible
	return {}

func _buy_shop_item(index: int) -> void:
	var shop_items: Array = _run_shop_items()
	if index < 0 or index >= shop_items.size():
		_show_shop_node()
		return
	var item: Dictionary = shop_items[index]
	if bool(item.get("sold", false)):
		_show_shop_node()
		return
	var collectible: Dictionary = _shop_item_collectible(item)
	var price: int = int(item.get("price", _shop_price(collectible)))
	if int(run_state.get("shells", 0)) < price:
		_show_shop_node()
		return
	run_state["shells"] = int(run_state.get("shells", 0)) - price
	var collectibles: Array = _run_collectibles()
	collectibles.append(collectible)
	run_state["collectibles"] = collectibles
	_mark_collectible_seen(String(collectible.get("id", "")))
	item["sold"] = true
	shop_items[index] = item
	run_state["shop_items"] = shop_items
	_show_shop_node()

func _advance_run_after_node() -> void:
	run_state["shop_items"] = []
	run_state["completed_nodes"] = int(run_state.get("completed_nodes", 0)) + 1
	var current_node_id: String = String(run_state.get("current_node_id", ""))
	var completed_node: Dictionary = _find_run_node(current_node_id)
	if completed_node.is_empty():
		_show_run_map()
		return
	_mark_run_node_completed(current_node_id)
	if String(completed_node.get("type", "")) == "boss":
		_start_next_floor_or_finish()
		return
	run_state["available_node_ids"] = _node_links(completed_node)
	run_state["current_node_id"] = ""
	_show_run_map()

func _start_next_floor_or_finish() -> void:
	var next_floor: int = int(run_state.get("floor", 1)) + 1
	if next_floor > RUN_TOTAL_FLOORS:
		_finish_run_complete()
		return
	run_state["floor"] = next_floor
	_generate_floor_map(next_floor)
	_show_run_map()

func _finish_run_complete() -> void:
	_finish_run(true)

func _finish_run_failed() -> void:
	_finish_run(false)

func _finish_run(completed: bool) -> void:
	save.high_score = max(save.high_score, score)
	save.run_best_floor = max(save.run_best_floor, int(run_state.get("floor", 1)))
	save.run_total_shells += int(run_state.get("shells", 0))
	save.save()
	_clear_screen()
	current_screen = "run_end"
	_add_title("探索完成" if completed else "探索结束")
	var summary: Label = Label.new()
	summary.text = "抵达层数：%d / %d\n分数：%d\n贝币：%d\n藏品：%d\n历史最高层：%d\n累计贝币：%d" % [
		int(run_state.get("floor", 1)),
		RUN_TOTAL_FLOORS,
		score,
		int(run_state.get("shells", 0)),
		_run_collectibles().size(),
		save.run_best_floor,
		save.run_total_shells,
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(summary)
	run_active = false
	run_state = {}
	current_run_node = {}
	pending_run_reward_items = []
	root.add_child(_make_button("再来一次探索", Callable(self, "_start_run")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _run_map_nodes() -> Array:
	var nodes: Variant = run_state.get("map_nodes", [])
	if nodes is Array:
		return nodes
	return []

func _run_nodes_for_row(row_index: int) -> Array:
	var result: Array = []
	for node in _run_map_nodes():
		var node_data: Dictionary = node
		if int(node_data.get("row", -1)) == row_index:
			result.append(node_data)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("lane", 0)) < int(b.get("lane", 0))
	)
	return result

func _run_node_short_label(node: Dictionary) -> String:
	if String(node.get("type", "")) == "boss":
		return "BOSS"
	return "%d-%d" % [int(node.get("row", 0)) + 1, int(node.get("lane", 0)) + 1]

func _run_map_node_positions(canvas_size: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var column_gap: float = canvas_size.x / float(RUN_MAP_ROWS + 1)
	var lane_y: Array[float] = [
		canvas_size.y * 0.22,
		canvas_size.y * 0.50,
		canvas_size.y * 0.78,
	]
	for node in _run_map_nodes():
		var node_data: Dictionary = node
		var row_index: int = int(node_data.get("row", 0))
		var lane_index: int = int(node_data.get("lane", 0))
		var x: float = column_gap * (float(row_index) + 0.5)
		var y: float = canvas_size.y * 0.5
		if String(node_data.get("type", "")) != "boss":
			var row_nodes: Array = _run_nodes_for_row(row_index)
			var row_count: int = max(1, row_nodes.size())
			if row_count == 2:
				y = canvas_size.y * (0.34 if lane_index == 0 else 0.66)
			else:
				y = lane_y[clamp(lane_index, 0, lane_y.size() - 1)]
		positions[String(node_data.get("id", ""))] = Vector2(x, y)
	return positions

func _make_run_map_node_button(node: Dictionary) -> Button:
	var node_type: String = String(node.get("type", "battle"))
	var node_id: String = String(node.get("id", ""))
	var available: bool = _is_run_node_available(node_id)
	var completed: bool = bool(node.get("completed", false))
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(250, 96 if node_type != "boss" else 118)
	button.text = "%s\n%s" % [_run_node_icon(node_type), _run_node_map_label(node)]
	button.add_theme_font_size_override("font_size", 22 if node_type != "boss" else 26)
	button.add_theme_stylebox_override("normal", _make_run_node_style(node_type, available, completed, false))
	button.add_theme_stylebox_override("hover", _make_run_node_style(node_type, true, completed, true))
	button.add_theme_stylebox_override("pressed", _make_run_node_style(node_type, true, completed, true))
	button.add_theme_stylebox_override("disabled", _make_run_node_style(node_type, false, completed, false))
	return button

func _run_node_icon(node_type: String) -> String:
	match node_type:
		"battle":
			return "× 作战"
		"elite":
			return "!! 精英作战"
		"supply":
			return "+ 补给"
		"shop":
			return "$ 商城"
		"event":
			return "? 不期而遇"
		"boss":
			return "▲ 层级首领"
	return "· 节点"

func _run_node_map_label(node: Dictionary) -> String:
	var status: String = "DONE" if bool(node.get("completed", false)) else ("READY" if _is_run_node_available(String(node.get("id", ""))) else "LOCKED")
	return "%s    %s" % [_run_node_short_label(node), status]

func _make_run_node_style(node_type: String, available: bool, completed: bool, hover: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var color: Color = Color(0.10, 0.12, 0.12, 0.88)
	if node_type == "boss":
		color = Color(0.20, 0.12, 0.11, 0.92)
	elif node_type == "shop":
		color = Color(0.16, 0.11, 0.24, 0.90)
	elif node_type == "supply":
		color = Color(0.08, 0.20, 0.20, 0.90)
	elif node_type == "event":
		color = Color(0.13, 0.18, 0.13, 0.90)
	if completed:
		color = Color(0.08, 0.16, 0.11, 0.82)
	elif not available:
		color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 0.58)
	elif hover:
		color = color.lightened(0.18)
	style.bg_color = color
	style.border_color = Color(0.95, 0.98, 0.92, 0.95) if available else Color(0.55, 0.58, 0.56, 0.45)
	style.set_border_width_all(2 if available else 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _run_row_links_text(row_index: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node in _run_nodes_for_row(row_index):
		var node_data: Dictionary = node
		var targets: PackedStringArray = PackedStringArray()
		for target_id in _node_links(node_data):
			var target: Dictionary = _find_run_node(String(target_id))
			if not target.is_empty():
				targets.append(_run_node_short_label(target))
		if not targets.is_empty():
			parts.append("%s -> %s" % [_run_node_short_label(node_data), String(", ").join(targets)])
	if parts.is_empty():
		return ""
	return "路线：%s" % String(" / ").join(parts)

func _find_run_node(node_id: String) -> Dictionary:
	for node in _run_map_nodes():
		var node_data: Dictionary = node
		if String(node_data.get("id", "")) == node_id:
			return node_data
	return {}

func _is_run_node_available(node_id: String) -> bool:
	var available_ids: Variant = run_state.get("available_node_ids", [])
	return available_ids is Array and available_ids.has(node_id)

func _run_available_node_ids() -> Array:
	var available_ids: Variant = run_state.get("available_node_ids", [])
	if available_ids is Array:
		return available_ids
	return []

func _mark_run_node_completed(node_id: String) -> void:
	var nodes: Array = _run_map_nodes()
	for index in range(nodes.size()):
		var node_data: Dictionary = nodes[index]
		if String(node_data.get("id", "")) == node_id:
			node_data["completed"] = true
			nodes[index] = node_data
			break
	run_state["map_nodes"] = nodes

func _node_links(node: Dictionary) -> Array:
	var links: Variant = node.get("links", [])
	if links is Array:
		return links.duplicate()
	return []

func _run_collectibles() -> Array:
	var collectibles: Variant = run_state.get("collectibles", [])
	if collectibles is Array:
		return collectibles.duplicate()
	return []

func _make_shell_reward(amount: int) -> Dictionary:
	return {
		"type": "shells",
		"amount": amount,
		"label": "贝币 +%d" % amount,
		"description": "用于在商城购买藏品。",
	}

func _make_life_reward(amount: int) -> Dictionary:
	return {
		"type": "life",
		"amount": amount,
		"label": "生命 +%d" % amount,
		"description": "恢复探索生命，不能超过上限。",
	}

func _make_collectible_reward(collectible: Dictionary) -> Dictionary:
	return {
		"type": "collectible",
		"collectible": collectible,
		"label": "藏品：%s" % _collectible_name(collectible),
		"description": "%s\n%s" % [
			String(collectible.get("rarity", "common")),
			_collectible_description(collectible),
		],
	}

func _reward_item_collectible(item: Dictionary) -> Dictionary:
	var collectible: Variant = item.get("collectible", {})
	if collectible is Dictionary:
		return collectible
	return {}

func _run_reward_item_text(item: Dictionary) -> String:
	return "%s\n%s" % [String(item.get("label", "奖励")), String(item.get("description", ""))]

func _reward_choice_state_text(item: Dictionary) -> String:
	var accepted: Variant = item.get("accepted", null)
	if accepted == null:
		return "未选择"
	return "已收下" if bool(accepted) else "已丢弃"

func _all_reward_items_chosen() -> bool:
	if pending_run_reward_items.is_empty():
		return true
	for item in pending_run_reward_items:
		var reward_item: Dictionary = item
		if reward_item.get("accepted", null) == null:
			return false
	return true

func _random_collectible(min_rarity: String = "common") -> Dictionary:
	var candidates: Array = catalog.get_collectibles_by_min_rarity(min_rarity)
	if candidates.is_empty():
		candidates = catalog.get_collectibles_by_min_rarity("common")
	if candidates.is_empty():
		return {}
	var total_weight: int = 0
	for collectible in candidates:
		total_weight += max(1, collectible.pool_weight)
	var roll: int = rng.randi_range(1, max(1, total_weight))
	var running: int = 0
	for collectible in candidates:
		running += max(1, collectible.pool_weight)
		if roll <= running:
			return _collectible_to_run_data(collectible)
	return _collectible_to_run_data(candidates[0])

func _rarity_rank(rarity: String) -> int:
	return catalog.rarity_rank(rarity)

func _collectible_total(effect_id: String) -> float:
	if not run_active:
		return 0.0
	var total: float = 0.0
	for collectible in _run_collectibles():
		var data: Dictionary = collectible
		if _collectible_effect_id(data) == effect_id:
			var params: Dictionary = _collectible_effect_params(data)
			total += _param_float(params, "value", float(data.get("value", 0.0)))
	return total

func _shop_price(collectible: Dictionary) -> int:
	var base_price: int = int(collectible.get("shop_price", 0))
	if base_price <= 0:
		match String(collectible.get("rarity", "common")):
			"rare":
				base_price = 16
			"epic":
				base_price = 24
			_:
				base_price = 10
	var discount: float = clamp(_collectible_total("shop_discount"), 0.0, 0.75)
	return max(1, roundi(float(base_price) * (1.0 - discount)))

func _apply_run_heal_after_battle() -> void:
	var heal: int = int(_collectible_total("heal_after_battle"))
	if heal <= 0:
		return
	run_state["lives"] = clamp(int(run_state.get("lives", RUN_MAX_LIVES)) + heal, 0, RUN_MAX_LIVES)

func _mark_collectible_seen(collectible_id: String) -> void:
	if collectible_id.is_empty() or save.seen_collectible_ids.has(collectible_id):
		return
	save.seen_collectible_ids.append(collectible_id)

func _collectible_to_run_data(collectible: Resource) -> Dictionary:
	return {
		"id": collectible.id,
		"name": collectible.display_name,
		"description": collectible.description,
		"rarity": collectible.rarity,
		"effect_id": collectible.effect_id,
		"effect": collectible.effect_id,
		"effect_params": collectible.effect_params.duplicate(true),
		"value": float(collectible.effect_params.get("value", 0.0)),
		"shop_price": collectible.shop_price,
		"pool_weight": collectible.pool_weight,
		"max_stack": collectible.max_stack,
	}

func _collectible_name(collectible: Dictionary) -> String:
	var collectible_name: String = String(collectible.get("name", ""))
	return collectible_name if not collectible_name.is_empty() else String(collectible.get("display_name", "藏品"))

func _collectible_description(collectible: Dictionary) -> String:
	return String(collectible.get("description", ""))

func _collectible_effect_id(collectible: Dictionary) -> String:
	var effect_id: String = String(collectible.get("effect_id", ""))
	return effect_id if not effect_id.is_empty() else String(collectible.get("effect", ""))

func _collectible_effect_params(collectible: Dictionary) -> Dictionary:
	var params: Variant = collectible.get("effect_params", {})
	if params is Dictionary:
		return params
	return {"value": float(collectible.get("value", 0.0))}

func _show_pause() -> void:
	_clear_screen()
	_add_title("暂停")
	root.add_child(_make_slider_row("音效", save.sfx_volume, func(value: float) -> void:
		save.sfx_volume = value
		save.save()
	))
	root.add_child(_make_slider_row("音乐", save.music_volume, func(value: float) -> void:
		save.music_volume = value
		save.save()
	))
	root.add_child(_make_button("继续游戏", Callable(self, "_show_game")))
	root.add_child(_make_button("重新开始", Callable(self, "_start_game")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _show_run_pause() -> void:
	_clear_screen()
	current_screen = "run_pause"
	_add_title("设置")
	root.add_child(_make_slider_row("音效", save.sfx_volume, func(value: float) -> void:
		save.sfx_volume = value
		save.save()
	))
	root.add_child(_make_slider_row("音乐", save.music_volume, func(value: float) -> void:
		save.music_volume = value
		save.save()
	))
	root.add_child(_make_button("继续探索", Callable(self, "_show_run_map")))
	root.add_child(_make_button("放弃探索", Callable(self, "_finish_run_failed")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _end_game() -> void:
	if run_active:
		_on_run_battle_lost()
		return
	save.high_score = max(save.high_score, score)
	save.save()
	_clear_screen()
	_add_title("游戏结束")
	var summary: Label = Label.new()
	summary.text = "得分：%d\n最高分：%d\n最高 Combo：%d\n普通消除：%d\n特殊消除：%d\n组合触发：%d" % [
		score,
		save.high_score,
		max_combo,
		stats["normal"],
		stats["special"],
		stats["combo"],
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(summary)
	root.add_child(_make_button("再来一局", Callable(self, "_start_game")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _square_targets(center: Vector2i, radius: int) -> Array:
	var targets: Array = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var pos: Vector2i = Vector2i(x, y)
			if board.in_bounds(pos):
				targets.append(pos)
	return targets

func _ensure_default_pieces_in_bag() -> void:
	if save == null:
		return
	var changed: bool = false
	for piece_id in catalog.get_default_roster():
		if save.unlocked_piece_ids.has(piece_id):
			continue
		save.unlocked_piece_ids.append(piece_id)
		changed = true
	if changed:
		save.save()

func _sanitize_roster(ids: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var defaults: PackedStringArray = catalog.get_default_roster()
	for slot_index in range(SLOT_ATTRIBUTES.size()):
		var chosen_id: String = ""
		if slot_index < ids.size():
			var saved_id: String = ids[slot_index]
			var saved_piece: PieceDefinition = catalog.get_piece(saved_id)
			if saved_piece != null and not catalog.is_piece_hidden(saved_id) and _piece_matches_slot(saved_piece, slot_index):
				chosen_id = saved_id
		if chosen_id.is_empty() and slot_index < defaults.size():
			chosen_id = defaults[slot_index]
		if chosen_id.is_empty():
			for piece in catalog.get_unlocked_pieces(save.unlocked_piece_ids if save != null else PackedStringArray()):
				if _piece_matches_slot(piece, slot_index):
					chosen_id = piece.id
					break
		result.append(chosen_id)
	return result
