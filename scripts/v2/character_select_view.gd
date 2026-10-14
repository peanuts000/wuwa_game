extends Control

const MenuArt = preload("res://scripts/v2/paper_menu_theme.gd")
const Catalog = preload("res://scripts/v2/catalog.gd")
const BACKGROUND = preload("res://assets/ui/characters/paper-theater-background.png")
const INK := Color("392b48")
const GOLD := Color("d4ab68")
const TEAL := Color("258c87")
var app
var canvas: Control

func configure(owner_app) -> void:
	app = owner_app
	name = "CharacterSelectView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.name = "CharacterCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.size = Vector2(1280, 720)
	_image(canvas, BACKGROUND, Rect2(0, 0, 1280, 720))
	_build_details()
	_build_navigation()
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if canvas == null: return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Vector2(1280, 720) * factor) * 0.5

func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size

func _image(parent: Node, texture: Texture2D, rect: Rect2, aspect := false) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if aspect else TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	_place(image, rect)
	return image

func _text(text: String, rect: Rect2, font_size := 18, color := INK, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 23:
		var inherited_font := get_theme_font("font")
		if inherited_font is SystemFont:
			var heading_font := inherited_font.duplicate() as SystemFont
			heading_font.font_weight = 700
			label.add_theme_font_override("font", heading_font)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label)
	_place(label, rect)
	return label

func _rule(y: float) -> void:
	var line := ColorRect.new()
	line.color = Color("d5b987")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(line)
	_place(line, Rect2(142, y, 332, 1))

func _ticket(text: String, rect: Rect2, frame: int, font_size: int, callback: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	canvas.add_child(button)
	MenuArt.style_button(button, frame, font_size)
	# Compact controls must not inherit the menu's large decorative star insets.
	for child in button.get_children():
		if child is TextureRect:
			button.remove_child(child)
			child.queue_free()
	button.pressed.connect(callback)
	_place(button, rect)
	return button

func _build_details() -> void:
	var role: Dictionary = app.ROLES[app.role_index]
	_text(role.name, Rect2(157, 59, 213, 54), 34, Color("fff3dc"), true)
	var attribute_kind: String = "thermal" if role.texture == "daniya" else role.texture
	_image(canvas, load("res://assets/ui/board/%s.png" % attribute_kind), Rect2(143, 136, 39, 39), true)
	_text(role.attribute + " · " + ("可探索" if role.available else "待开放"), Rect2(193, 136, 285, 38), 23)
	if role.available:
		var description := _text("以冷凝技能牌消耗\n消除积累的资源。", Rect2(143, 184, 332, 49), 18)
		description.name = "RoleDescription"
		_rule(240)
		_text("基础生命 60", Rect2(143, 249, 165, 28), 19)
		_text("基础攻击 6", Rect2(322, 249, 152, 28), 19)
		_text("每级攻击 +1，生命上限 +5", Rect2(143, 279, 333, 28), 18)
		_rule(318)
		_text("初始牌组 · 10 张", Rect2(143, 328, 332, 30), 23, TEAL)
		_text("碎晶弹 ×4", Rect2(143, 369, 164, 27))
		_text("护身晶幕 ×3", Rect2(321, 369, 162, 27))
		_text("交错射击 ×2", Rect2(143, 398, 166, 27))
		_text("晶簇狙击 ×1", Rect2(321, 398, 162, 27))
		var attributes := _ticket("选择属性球（%d / 4）" % app.chosen.size(), Rect2(143, 430, 335, 39), 2, 20, app._show_attribute_dialog)
		attributes.name = "ChooseAttributes"
		attributes.tooltip_text = "从六种属性中任选四种，整次探索固定"
		for index in range(app.chosen.size()):
			var kind: String = app.chosen[index]
			var x := 150.0 + index * 83
			_image(canvas, load("res://assets/ui/board/%s.png" % kind), Rect2(x + 10, 471, 42, 42), true)
			_text(Catalog.NAMES[kind], Rect2(x, 509, 64, 22), 16, INK, true)
	else:
		_text("角色展示已开放。\n个人初始牌组与战斗能力尚未制作。", Rect2(140, 206, 340, 90), 18)
		_text("暂时无法开始探索", Rect2(143, 336, 332, 38), 22)
	var portrait := _image(canvas, load("res://assets/pieces/%s_base.png" % role.texture), Rect2(603, 53, 468, 468), true)
	portrait.name = "CharacterPortrait"

func _slot_style(selected: bool, focus := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4b3b50") if selected else Color("cbbab0")
	style.border_color = Color("fff0b0") if focus else (GOLD if selected else Color("b8a698"))
	style.set_border_width_all(3 if selected or focus else 1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.2, 0.1, 0.2, 0.22)
	style.shadow_size = 3
	return style

func _build_navigation() -> void:
	_ticket("返回", Rect2(39, 596, 166, 72), 1, 26, func(): app._navigate("menu"))
	_ticket("‹", Rect2(231, 603, 54, 59), 3, 30, func(): app.role_page = maxi(0, app.role_page - 1); app._render(), app.role_page == 0)
	for slot in range(4):
		var index: int = app.role_page * 4 + slot
		if index >= app.ROLES.size(): continue
		var role: Dictionary = app.ROLES[index]
		var rect := Rect2(305 + slot * 154, 583, 144, 98)
		var backing := Panel.new()
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.add_theme_stylebox_override("panel", _slot_style(index == app.role_index))
		canvas.add_child(backing)
		_place(backing, rect)
		var button := TextureButton.new()
		button.name = "Role_" + role.id
		button.set_meta("role_id", role.id)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_normal = load("res://assets/pieces/%s_base.png" % role.texture)
		button.texture_hover = button.texture_normal
		button.texture_pressed = button.texture_normal
		button.texture_disabled = button.texture_normal
		button.disabled = not role.available
		button.self_modulate = Color.WHITE if role.available else Color(0.58, 0.58, 0.58, 0.72)
		button.tooltip_text = role.name + (" · 待开放" if button.disabled else " · " + role.attribute)
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		button.pressed.connect(app._select_role.bind(index))
		canvas.add_child(button)
		_place(button, Rect2(rect.position + Vector2(16, -3), Vector2(112, 98)))
		button.mouse_entered.connect(func(): backing.add_theme_stylebox_override("panel", _slot_style(index == app.role_index, not button.disabled)))
		button.mouse_exited.connect(func(): backing.add_theme_stylebox_override("panel", _slot_style(index == app.role_index)))
		button.focus_entered.connect(func(): backing.add_theme_stylebox_override("panel", _slot_style(index == app.role_index, true)))
		button.focus_exited.connect(func(): backing.add_theme_stylebox_override("panel", _slot_style(index == app.role_index)))
		if not role.available:
			_text("待开放", Rect2(rect.position.x, 661, 144, 22), 15, Color("766378"), true)
		if index == app.role_index:
			for offset in [Vector2(-6, -6), Vector2(126, -6), Vector2(-6, 80), Vector2(126, 80)]:
				_image(canvas, MenuArt.STAR, Rect2(rect.position + offset, Vector2(22, 22)))
	_ticket("›", Rect2(934, 603, 54, 59), 3, 30, func(): app.role_page = mini(1, app.role_page + 1); app._render(), app.role_page == 1)
	var start := _ticket("开始探索", Rect2(1007, 594, 240, 76), 0, 28, func(): app._show_attribute_dialog(true), not app.ROLES[app.role_index].available)
	start.name = "StartExploration"
	_image(start, MenuArt.STAR, Rect2(15, 24, 28, 28))
