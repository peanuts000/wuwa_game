extends RefCounted

# Runtime assets are separate from the approved concept; labels remain native UI.
const BACKGROUND = preload("res://assets/ui/menu/paper-theater-background.png")
const TICKETS = preload("res://assets/ui/menu/paper-ticket-atlas.png")
const STAR = preload("res://assets/ui/menu/star.svg")
const SETTINGS = preload("res://assets/ui/menu/settings.svg")
const BOOK = preload("res://assets/ui/menu/book.svg")
const FRAMES := [
	Rect2(54, 70, 1430, 208),
	Rect2(54, 316, 1430, 214),
	Rect2(58, 563, 1420, 214),
	Rect2(532, 800, 474, 182),
]

static func add_background(parent: Control) -> TextureRect:
	var background := TextureRect.new()
	background.name = "MenuStageBackground"
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return background

static func style_button(button: Button, frame: int, font_size: int = 18) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = TICKETS
	texture.region = FRAMES[frame]
	texture.filter_clip = true
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.set_content_margin_all(12.0 if frame < 3 else 10.0)
		match state:
			"hover": style.modulate_color = Color(1.12, 1.09, 1.02)
			"pressed": style.modulate_color = Color(0.85, 0.79, 0.81)
			"disabled": style.modulate_color = Color(0.67, 0.63, 0.73)
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffe3a1")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(9)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	var ink := Color("423341") if frame >= 2 else Color("fff1d4")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color("c8bfd2"))
	button.add_theme_font_size_override("font_size", font_size)
	var inherited_font := button.get_theme_font("font")
	if inherited_font is SystemFont:
		var title_font := inherited_font.duplicate() as SystemFont
		title_font.font_weight = 700
		button.add_theme_font_override("font", title_font)
	button.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.18, 0.55) if frame < 2 else Color.TRANSPARENT)
	button.add_theme_constant_override("outline_size", 1 if frame < 2 else 0)
	button.add_theme_constant_override("h_separation", 7)
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	if frame < 3:
		_add_stars(button)

static func add_corner_icon(button: Button, settings: bool) -> void:
	button.icon = SETTINGS if settings else BOOK
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 23)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)

static func _add_stars(button: Button) -> void:
	for right in [false, true]:
		var star := TextureRect.new()
		star.texture = STAR
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(star)
		star.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT if right else Control.PRESET_CENTER_LEFT)
		star.offset_left = -49 if right else 33
		star.offset_right = -33 if right else 49
		star.offset_top = -8
		star.offset_bottom = 8
		star.modulate = Color(0.62, 0.58, 0.67) if button.disabled else Color.WHITE
