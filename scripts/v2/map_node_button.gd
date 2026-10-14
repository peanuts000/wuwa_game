extends Button

const Art = preload("res://scripts/v2/paper_map_theme.gd")
var kind := "battle"
var completed := false
var current := false
var available := false
var _hovered := false

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func setup(node: Dictionary, seen: bool, here: bool, reachable: bool) -> void:
	kind = str(node.type)
	completed = seen
	current = here
	available = reachable
	disabled = not reachable
	set_meta("node_id", str(node.id))
	set_meta("available", reachable)
	set_meta("map_state", "current" if here else ("completed" if seen else ("available" if reachable else "future")))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reachable else Control.CURSOR_ARROW
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.44
	if available or current:
		draw_circle(center, radius + 3, Color("725090"), false, 5, true)
		draw_circle(center, radius + 6, Color("efc979"), false, 2, true)
	var tint := Color.WHITE if available or current or completed else Color(0.78, 0.73, 0.80, 0.64)
	if _hovered and available:
		tint = Color(1.15, 1.1, 1.04)
	if is_pressed() and available:
		tint = Color(0.83, 0.77, 0.87)
	if kind == "start":
		draw_circle(center, radius, Color("f5e7cd"))
		draw_circle(center, radius - 2, Art.GOLD, false, 2, true)
		draw_texture_rect(Art.node_texture(kind), Rect2(size * 0.18, size * 0.64), false, tint)
		var font := ThemeDB.fallback_font
		var label_size := font.get_string_size("起点", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, Vector2(center.x - label_size.x * 0.5, size.y + 15), "起点", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Art.INK)
	else:
		draw_texture_rect(Art.node_texture(kind), Rect2(Vector2.ZERO, size), false, tint)
	if has_focus() and available:
		draw_circle(center, radius + 9, Color("fff0bd"), false, 2, true)
	if completed and kind != "start":
		var badge := Vector2(size.x - 9, size.y - 10)
		draw_circle(badge, 11, Color("8a603d"))
		draw_circle(badge, 11, Color("ffe4ac"), false, 2, true)
		draw_polyline(PackedVector2Array([badge + Vector2(-5, 0), badge + Vector2(-1, 4), badge + Vector2(6, -5)]), Color("fff8e5"), 2.5, true)
	if current:
		draw_texture_rect(Art.HERO, Rect2(Vector2(center.x - 30, -26), Vector2(60, 60)), false)

func _make_custom_tooltip(value: String) -> Object:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5e7cd")
	style.border_color = Art.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0.16, 0.1, 0.2, 0.4)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = Art.node_texture(kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52, 52)
	row.add_child(icon)
	var label := Label.new()
	label.text = value
	label.custom_minimum_size.x = 240
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Art.INK)
	label.add_theme_font_size_override("font_size", 17)
	row.add_child(label)
	return panel
