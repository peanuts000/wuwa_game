extends Button

const BOARDS = preload("res://assets/ui/compendium/rough-boards.png")
const ROPE = preload("res://assets/ui/settings/rope.png")
const INK := Color("51364f")
var category := ""
var _title: Label
var _description: Label
var _hint: Label
var _preview: TextureRect
var _knots: Array[TextureRect] = []

func configure(value: Dictionary) -> void:
	category = str(value.id)
	name = "CompendiumChoice_" + category
	text = str(value.title)
	tooltip_text = "进入%s图鉴" % text
	set_meta("category_id", category)
	set_meta("description", str(value.description))

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	_preview = TextureRect.new()
	_preview.name = "CategoryPreview"
	_preview.texture = _atlas(BOARDS, Rect2(18 + ["cards", "supplies", "relics"].find(category) * 506, 60, 494, 924))
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)
	for index in range(2):
		var knot := TextureRect.new()
		knot.texture = _atlas(ROPE, Rect2(462, 1426, 98, 108))
		knot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		knot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(knot)
		_knots.append(knot)
	_title = _label(text, 32)
	_title.name = "CategoryTitle"
	var inherited := get_theme_font("font")
	if inherited is SystemFont:
		var heading := inherited.duplicate() as SystemFont
		heading.font_weight = 700
		_title.add_theme_font_override("font", heading)
	_description = _label(str(get_meta("description")), 20)
	_description.name = "CategoryDescription"
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label("点击查看  ›", 16)
	_hint.add_theme_color_override("font_color", Color("85677b"))
	for event in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]:
		event.connect(_refresh_highlight)
	resized.connect(_position_content)
	_position_content()

func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	add_child(label)
	return label

func _position_content() -> void:
	# Raised crest leaves the two rope knots seated on the board's shoulders.
	_preview.position = Vector2(0, -17)
	_preview.size = size + Vector2(0, 17)
	pivot_offset = Vector2(size.x * 0.5, 14)
	_title.position = Vector2(30, size.y * 0.13)
	_title.size = Vector2(size.x - 60, size.y * 0.095)
	_description.position = Vector2(34, size.y * 0.65)
	_description.size = Vector2(size.x - 68, size.y * 0.115)
	_hint.position = Vector2(34, size.y * 0.83)
	_hint.size = Vector2(size.x - 68, 28)
	for index in range(_knots.size()):
		_knots[index].position = Vector2(size.x * (0.25 + index * 0.5) - 10, 2)
		_knots[index].size = Vector2(20, 23)
	_refresh_highlight()

func _refresh_highlight() -> void:
	var highlighted := not disabled and (is_hovered() or has_focus())
	_preview.modulate = Color(1.1, 1.07, 1.01) if highlighted else Color.WHITE
	if not disabled and is_pressed(): _preview.modulate = Color(0.88, 0.83, 0.76)
	_hint.text = "进入图鉴  ›" if highlighted else "点击查看  ›"
	if not disabled and has_focus(): _hint.text = "◆  进入图鉴  ›"
	_hint.add_theme_color_override("font_color", INK if highlighted else Color("85677b"))
	queue_redraw()

