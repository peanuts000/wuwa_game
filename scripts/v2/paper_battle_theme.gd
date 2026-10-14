extends RefCounted

const BACKGROUND = preload("res://assets/ui/battle/stage-background.png")
const PAPER = preload("res://assets/ui/battle/paper-panel.png")
const ILLUSTRATIONS = preload("res://assets/ui/battle/card-art-atlas.png")
const MenuArt = preload("res://scripts/v2/paper_menu_theme.gd")
const INK := Color("392b48")
const MUTED := Color("766077")
const GOLD := Color("d5ae6d")
const CREAM := Color("fff0d1")
static var _art: Dictionary = {}

static func paper() -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = PAPER
	var dimensions := PAPER.get_size()
	atlas.region = Rect2(dimensions * Vector2(0.016, 0.075), dimensions * Vector2(0.97, 0.84))
	atlas.filter_clip = true
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.set_content_margin_all(16)
	return style

static func dark_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("30233f")
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(5)
	style.shadow_color = Color(0.1, 0.04, 0.13, 0.5)
	style.shadow_size = 4
	return style

static func button(value: Button, primary: bool = false) -> void:
	if primary:
		MenuArt.style_button(value, 0, 26)
		return
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := dark_style()
		if state == "hover": style.bg_color = Color("574268")
		if state == "pressed": style.bg_color = Color("21172d")
		if state == "disabled": style.border_color = Color("87765e")
		value.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		value.add_theme_color_override(state, CREAM)
	value.add_theme_color_override("font_disabled_color", Color("a596ab"))
	var focus := dark_style()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("fff2b6")
	value.add_theme_stylebox_override("focus", focus)

static func card_art(id: String) -> Texture2D:
	var index: int = {"c01": 0, "c02": 1, "c03": 2, "c04": 2, "c05": 5, "c06": 3,
		"g01": 4, "g02": 4, "g03": 0, "g04": 2, "g05": 5, "g06": 1,
		"g07": 5, "g08": 5, "g09": 2, "g10": 1, "g11": 3, "g12": 0}.get(id, 0)
	if not _art.has(index):
		var texture := AtlasTexture.new()
		texture.atlas = ILLUSTRATIONS
		var cell := ILLUSTRATIONS.get_size() / Vector2(3, 2)
		texture.region = Rect2(Vector2(index % 3, index / 3) * cell, cell)
		texture.filter_clip = true
		_art[index] = texture
	return _art[index]
