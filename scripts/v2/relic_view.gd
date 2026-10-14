extends Control

signal activation_requested(uid: int)

const CARD_SIZE := Vector2(150, 210)
const GOLD := Color("f5d481")
const ShopItemIcon = preload("res://scripts/v2/shop_item_icon.gd")

var uid := -1
var item_kind := "relic"
var full_text := ""
var card: Dictionary = {}
var available := true
var unavailable_reason := ""
var _catalog
var _emphasized := false
var _title: Label
var _effect: Label
var _icon: Control

func _ready() -> void:
	_build_face()
	_refresh_face()

func configure(catalog, value: Dictionary) -> void:
	_catalog = catalog
	card = value.duplicate(true)
	uid = int(card.get("uid", -1))
	name = ("Supply_%d" if item_kind == "supply" else "Relic_%d") % uid
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	set_meta("supply_id" if item_kind == "supply" else "relic_id", str(card.get("id", "")))
	set_meta("readonly", true)
	if is_node_ready():
		_refresh_face()

func set_available(value: bool, reason: String = "") -> void:
	available = value
	unavailable_reason = reason
	tooltip_text = reason
	queue_redraw()

func set_emphasized(value: bool) -> void:
	_emphasized = value
	queue_redraw()

func _build_face() -> void:
	if is_instance_valid(_title):
		return
	_title = _make_label(Vector2(10, 8), Vector2(130, 25), 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", GOLD.lightened(0.2))
	_icon = ShopItemIcon.new()
	_icon.position = Vector2(43, 38)
	_icon.size = Vector2(64, 64)
	add_child(_icon)
	_effect = _make_label(Vector2(10, 114), Vector2(130, 84), 11)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect.add_theme_constant_override("line_spacing", -1)

func _make_label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("edf4ff"))
	label.add_theme_color_override("font_outline_color", Color("101820"))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	return label

func _refresh_face() -> void:
	if _catalog == null or not is_instance_valid(_title) or card.is_empty():
		return
	var entries: Dictionary = _catalog.supplies if item_kind == "supply" else _catalog.relics
	var entry: Dictionary = entries.get(card.get("id", ""), {})
	if entry.is_empty():
		return
	_title.text = str(entry.name)
	_effect.text = str(entry.effect)
	_icon.configure(item_kind, str(card.id))
	full_text = _title.text + "\n\n" + _effect.text
	set_available(available, unavailable_reason)

func _draw() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("17283b")
	frame.border_color = GOLD.lightened(0.25) if _emphasized or has_focus() else GOLD.darkened(0.15)
	frame.set_border_width_all(3 if _emphasized else 2)
	frame.set_corner_radius_all(5)
	frame.shadow_color = Color(0, 0, 0, 0.5)
	frame.shadow_size = 6
	frame.shadow_offset = Vector2(0, 3)
	draw_style_box(frame, Rect2(Vector2.ZERO, CARD_SIZE))
	draw_rect(Rect2(4, 109, 142, 97), Color(0.04, 0.07, 0.11, 0.72))
	draw_line(Vector2(10, 108), Vector2(140, 108), GOLD.darkened(0.35), 1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		accept_event()
