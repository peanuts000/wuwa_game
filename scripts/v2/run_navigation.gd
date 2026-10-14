extends Control

signal tab_selected(tab_id: String)
signal menu_requested

const BAR_HEIGHT := 80.0
const PAGE_COLOR := Color("0c1423")
const BAR_COLOR := Color("141f32")
const BORDER_COLOR := Color("294258")
const ACCENT := Color("79dbc8")
const TEXT_COLOR := Color("edf4ff")
const MUTED_COLOR := Color("a6b6cc")
const PaperArt = preload("res://scripts/v2/paper_map_theme.gd")
const TAB_ICONS := {
	"map": preload("res://assets/ui/map/nav-map.svg"),
	"deck": preload("res://assets/ui/map/nav-deck.svg"),
	"relics": preload("res://assets/ui/map/nav-relics.svg"),
}
var _paper := false

var _menu: Button
var _tabs: Dictionary = {}
var _tab_order: Array[String] = []
var _selected := "map"
var _disposed := false

func _init() -> void:
	custom_minimum_size.y = BAR_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(_position_controls)
	_position_controls()

func configure(_lives: int, _shells: int, deck_count: int, relic_count: int, selected_tab: String = "map", include_shop: bool = false, page_prefix: String = "Map") -> void:
	if _disposed:
		return
	_paper = page_prefix == "Map"
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tabs.clear()
	_tab_order.clear()
	for entry in [
		["map", "地图"],
		["deck", "牌组 %d" % deck_count],
		["relics", "藏品 %d" % relic_count],
	]:
		_make_tab(str(entry[0]), str(entry[1]), page_prefix)
	if include_shop:
		_make_tab("shop", "商店", page_prefix)
	_menu = Button.new()
	_menu.name = page_prefix + "Menu"
	_menu.text = "主界面"
	_menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_menu.add_theme_font_size_override("font_size", 18)
	_menu.pressed.connect(func(): menu_requested.emit())
	add_child(_menu)
	if _paper:
		_menu.tooltip_text = "主界面"
		for state in ["normal", "hover", "pressed", "focus"]:
			var circle := StyleBoxFlat.new()
			circle.bg_color = Color("776088") if state == "hover" else Color("584368")
			circle.border_color = PaperArt.GOLD
			circle.set_border_width_all(2)
			circle.set_corner_radius_all(32)
			_menu.add_theme_stylebox_override(state, circle)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_menu.add_theme_color_override(state, Color.TRANSPARENT)
		var home := TextureRect.new()
		home.texture = PaperArt.HOME
		home.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		home.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu.add_child(home)
		home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		home.offset_left = 13
		home.offset_top = 13
		home.offset_right = -13
		home.offset_bottom = -13
	set_selected(selected_tab)
	_position_controls()

func _make_tab(tab_id: String, value: String, page_prefix: String) -> void:
	var button := Button.new()
	button.name = page_prefix + tab_id.capitalize() + "Tab"
	button.text = value
	button.tooltip_text = value
	if TAB_ICONS.has(tab_id):
		button.icon = TAB_ICONS[tab_id]
		button.text = value.get_slice(" ", 1) if tab_id != "map" else ""
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if tab_id == "map" else HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 40)
		button.add_theme_constant_override("h_separation", 8)
	button.toggle_mode = true
	button.set_meta("tab_id", tab_id)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_activate_tab.bind(tab_id))
	add_child(button)
	if _paper:
		var title_font := button.get_theme_font("font").duplicate() as SystemFont
		if title_font != null:
			title_font.font_weight = 650
			button.add_theme_font_override("font", title_font)
	_tabs[tab_id] = button
	_tab_order.append(tab_id)

func _activate_tab(tab_id: String) -> void:
	if _disposed:
		return
	set_selected(tab_id)
	tab_selected.emit(tab_id)

func get_tab_button(tab_id: String) -> Button:
	return _tabs.get(tab_id)

func set_selected(tab_id: String) -> void:
	_selected = tab_id if _tabs.has(tab_id) else "map"
	set_meta("selected_tab", _selected)
	for id in _tab_order:
		var button: Button = _tabs[id]
		var active := id == _selected
		button.set_pressed_no_signal(active)
		button.set_meta("selected", active)
		button.add_theme_stylebox_override("normal", _tab_style(active))
		button.add_theme_stylebox_override("pressed", _tab_style(active))
		button.add_theme_stylebox_override("hover", _tab_style(active, true))
		button.add_theme_stylebox_override("hover_pressed", _tab_style(active, true))
		var focus := StyleBoxFlat.new()
		focus.corner_radius_top_left = 12
		focus.corner_radius_top_right = 12
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = PaperArt.GOLD if _paper else ACCENT
		focus.border_width_top = 2
		focus.border_width_left = 2
		focus.border_width_right = 2
		button.add_theme_stylebox_override("focus", focus)
		var font_color := TEXT_COLOR if active else MUTED_COLOR
		if _paper:
			font_color = Color("fff0d3") if active else PaperArt.INK
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_pressed_color", font_color)
		button.add_theme_color_override("font_hover_color", font_color)
		button.add_theme_color_override("font_hover_pressed_color", font_color)
		button.add_theme_color_override("font_focus_color", font_color)

func _tab_style(active: bool, hovered: bool = false) -> StyleBox:
	if _paper:
		return PaperArt.tab_style(active, hovered)
	var style := StyleBoxFlat.new()
	style.bg_color = PAGE_COLOR if active else (Color("223149") if hovered else Color("1b2a40"))
	style.border_color = ACCENT if active else BORDER_COLOR
	style.border_width_top = 2 if active else 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_bottom = 0 if active else 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _position_controls() -> void:
	if _disposed or not is_instance_valid(_menu):
		return
	var compact := size.x < 1100.0
	_menu.size = Vector2(90 if compact else 98, 44)
	_menu.position = Vector2(size.x - 20 - _menu.size.x, 18)
	if _paper:
		_menu.size = Vector2(64, 64)
		_menu.position = Vector2(size.x - 20 - 64, 8)
	var widths: Array[float] = []
	var desired_width := 0.0
	var gap := 6.0
	for id in _tab_order:
		var width := 104.0 if TAB_ICONS.has(id) else 88.0
		widths.append(width)
		desired_width += width
	var gap_width := gap * maxf(0, _tab_order.size() - 1)
	var right_edge := _menu.position.x - 16
	var available_width := right_edge - (20 + 300 + 24) - gap_width
	var width_scale := minf(1.0, maxf(0.65, available_width / maxf(1.0, desired_width)))
	var x := right_edge - desired_width * width_scale - gap_width
	for index in range(_tab_order.size()):
		var button: Button = _tabs[_tab_order[index]]
		button.add_theme_font_size_override("font_size", 18 if compact else 20)
		button.position = Vector2(x, 20)
		button.size = Vector2(widths[index] * width_scale, BAR_HEIGHT - 20)
		x += button.size.x + gap
	queue_redraw()

func _draw() -> void:
	if _paper:
		draw_line(Vector2(0, BAR_HEIGHT - 1), Vector2(size.x, BAR_HEIGHT - 1), Color(0.74, 0.59, 0.36, 0.45))
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, BAR_HEIGHT)), BAR_COLOR)
	draw_line(Vector2(0, BAR_HEIGHT - 1), Vector2(size.x, BAR_HEIGHT - 1), BORDER_COLOR)

func dispose() -> void:
	_disposed = true
