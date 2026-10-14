extends Control

signal settings_changed(settings: Dictionary)
signal retry_requested
signal quit_requested
signal closed

const BOARD = preload("res://assets/ui/settings/rough-board.png")
const TICKET = preload("res://assets/ui/settings/rough-ticket.png")
const ROPE = preload("res://assets/ui/settings/rope.png")
const INK := Color("51364f")
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var board: Control
var shade: ColorRect
var stage: Control
var full: CheckButton
var resolution_label: Label
var retry: Button
var close_button: Button
var choices: Array[Button] = []
var actions: Array[BaseButton] = []
var ropes: Array[Line2D] = []
var values: Dictionary = {}
var state := "opening"
var travel := -650.0
var angle := 0.0
var slack := 0.0
var motion: Tween
var shade_motion: Tween
var _saved_focus: Array = []
var _previous_focus: WeakRef
var _disposed := false

func _ready() -> void:
	name = "SettingsPopup"
	z_index = 300
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	shade = ColorRect.new()
	shade.name = "SettingsShade"
	shade.color = Color(0.10, 0.06, 0.14, 0.0)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_shade_input)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	# Line2D repeats along texture X; isolate and rotate the vertical source
	# instead of repeating AtlasTexture UVs across the entire transparent atlas.
	var rope_image := ROPE.get_image()
	if rope_image.is_compressed(): rope_image.decompress()
	rope_image = rope_image.get_region(Rect2i(489, 120, 48, 128))
	rope_image.rotate_90(CLOCKWISE)
	var rope_texture := ImageTexture.create_from_image(rope_image)
	for index in range(2):
		var rope := Line2D.new()
		rope.width = 10
		rope.texture = rope_texture
		rope.texture_mode = Line2D.LINE_TEXTURE_TILE
		rope.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		stage.add_child(rope)
		ropes.append(rope)
	board = Control.new()
	board.name = "SettingsPanel"
	board.size = Vector2(680, 420)
	board.pivot_offset = Vector2(340, 18)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(board)
	# The star projects above the panel; the blank ribbon sits behind the native title.
	var art := _texture(board, _atlas(BOARD, Rect2(30, 28, 1470, 974)), Rect2(0, -40, 680, 460))
	art.name = "WoodBoard"
	for x in [170, 510]:
		_texture(board, _atlas(ROPE, Rect2(462, 1426, 98, 108)), Rect2(x - 12, 5, 24, 27))
	_label("设置", Rect2(100, 40, 480, 40), 30, HORIZONTAL_ALIGNMENT_CENTER)
	close_button = _button("×", Rect2(587, 39, 42, 38), request_close)
	close_button.name = "CloseSettingsButton"
	close_button.tooltip_text = "关闭设置（Esc）"
	close_button.add_theme_font_size_override("font_size", 28)
	full = CheckButton.new()
	full.name = "FullscreenToggle"
	full.text = "全屏显示"
	full.position = Vector2(60, 99)
	full.size = Vector2(560, 42)
	_style(full)
	board.add_child(full)
	full.toggled.connect(func(enabled: bool):
		if state == "open":
			values.fullscreen = enabled
			settings_changed.emit(values.duplicate()))
	actions.append(full)
	resolution_label = _label("窗口分辨率", Rect2(60, 153, 560, 28), 20)
	for index in range(RESOLUTIONS.size()):
		var dimensions: Vector2i = RESOLUTIONS[index]
		var button := _button("%d × %d" % [dimensions.x, dimensions.y], Rect2(60 + index * 190, 190, 180, 43), func():
			if state == "open":
				values.resolution = dimensions
				settings_changed.emit(values.duplicate()))
		button.name = "Resolution%d" % dimensions.x
		button.toggle_mode = true
		choices.append(button)
		actions.append(button)
	_label("画面按 16:9 等比缩放，其他比例保留黑边。\n窗口超出屏幕时会缩小到可用区域。", Rect2(60, 246, 560, 48), 16)
	var quit_button := _button("退出游戏", Rect2(235, 305, 210, 43), func():
		if state == "open": quit_requested.emit())
	quit_button.name = "SettingsQuitButton"
	_style_exit(quit_button)
	actions.append(quit_button)
	retry = _button("", Rect2(60, 354, 560, 30), func():
		if state == "open": retry_requested.emit())
	retry.name = "SettingsSaveRetry"
	retry.add_theme_font_size_override("font_size", 14)
	retry.hide()
	actions.append(retry)
	_lock_background_focus()
	get_viewport().gui_focus_changed.connect(_guard_focus)
	resized.connect(_layout)
	_layout()
	_set_enabled(false)
	close_button.grab_focus()
	shade_motion = create_tween()
	shade_motion.tween_property(shade, "color:a", 0.48, 0.2)
	motion = create_tween()
	motion.tween_method(_set_travel, -650.0, 20.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_method(_settle_board, 0.0, 1.0, 0.47)
	motion.tween_callback(func():
		state = "open"
		_set_enabled(true)
		full.grab_focus())

func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas

func _texture(parent: Control, texture: Texture2D, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _label(text: String, rect: Rect2, font_size: int, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(label)
	return label

func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	_style(button)
	button.pressed.connect(callback)
	board.add_child(button)
	return button

func _style(button: BaseButton) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.set_content_margin_all(5)
		style.bg_color = Color("f5e3c6")
		style.border_color = Color("b3917c")
		style.set_border_width_all(1)
		if style_name == "hover": style.bg_color = Color("fff0d7")
		if style_name in ["pressed", "hover_pressed"]:
			style.bg_color = Color("9b82a9") if style_name == "hover_pressed" else Color("897297")
			style.border_color = Color("d9bb8c")
		if style_name == "disabled": style.bg_color = Color("ded0b9")
		if style_name == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("795b87")
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(style_name, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(color_name, INK)
	button.add_theme_color_override("font_pressed_color", Color("fff3d9"))
	button.add_theme_color_override("font_hover_pressed_color", Color("fff3d9"))

func _style_exit(button: Button) -> void:
	var texture := _atlas(TICKET, Rect2(90, 205, 1802, 370))
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.set_content_margin_all(6)
		if state_name == "hover": style.modulate_color = Color(1.12, 1.08, 1.03)
		if state_name == "pressed": style.modulate_color = Color(0.85, 0.79, 0.84)
		if state_name == "disabled": style.modulate_color = Color(0.76, 0.72, 0.73)
		button.add_theme_stylebox_override(state_name, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color("fff3d9"))

func update_settings(settings: Dictionary, error: String) -> void:
	values = settings.duplicate()
	full.set_pressed_no_signal(values.get("fullscreen", false))
	var selected: Vector2i = values.get("resolution", Vector2i(1280, 720))
	resolution_label.text = "窗口分辨率 · %d × %d" % [selected.x, selected.y]
	for index in range(choices.size()):
		choices[index].set_pressed_no_signal(selected == RESOLUTIONS[index])
		choices[index].text = ("✓ " if selected == RESOLUTIONS[index] else "") + "%d × %d" % [RESOLUTIONS[index].x, RESOLUTIONS[index].y]
	retry.text = error + " 点击重试"
	retry.visible = not error.is_empty()
	if not retry.visible and retry.has_focus(): full.grab_focus()
	_update_focus_ring()

func _set_enabled(enabled: bool) -> void:
	for button in actions:
		button.disabled = not enabled
	_update_focus_ring()

func _update_focus_ring() -> void:
	var focusables: Array[BaseButton] = [close_button]
	for button in actions:
		if not button.disabled and button.visible: focusables.append(button)
	for index in range(focusables.size()):
		var button := focusables[index]
		button.focus_next = button.get_path_to(focusables[(index + 1) % focusables.size()])
		button.focus_previous = button.get_path_to(focusables[(index - 1 + focusables.size()) % focusables.size()])

func _lock_background_focus() -> void:
	var current := get_viewport().gui_get_focus_owner()
	if current != null: _previous_focus = weakref(current)
	for control in get_parent().find_children("*", "Control", true, false):
		if control != self and not is_ancestor_of(control) and control.focus_mode != Control.FOCUS_NONE:
			_saved_focus.append([weakref(control), control.focus_mode])
			control.focus_mode = Control.FOCUS_NONE

func _guard_focus(control: Control) -> void:
	if not _disposed and control != null and not is_ancestor_of(control):
		close_button.grab_focus()

func _layout() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - Vector2(1280, 720) * factor) * 0.5
	_update_pose()

func _set_travel(value: float) -> void:
	travel = value
	_update_pose()

func _settle_board(progress: float) -> void:
	var decay := pow(1.0 - progress, 2)
	travel = 20.0 * cos(progress * TAU * 1.25) * decay
	angle = deg_to_rad(1.7) * sin(progress * TAU * 1.5) * decay
	slack = 9.0 * sin(progress * PI) * decay
	_update_pose()

func _update_pose() -> void:
	board.position = Vector2(300, 180 + travel)
	board.rotation = angle
	for index in range(ropes.size()):
		var x := 170.0 + index * 340.0
		var endpoint := board.get_transform() * Vector2(x, 17)
		var top := Vector2(300 + x, -stage.position.y / maxf(stage.scale.y, 0.001))
		var points := PackedVector2Array()
		for step in range(13):
			var fraction := step / 12.0
			points.append(top.lerp(endpoint, fraction) + Vector2(sin(fraction * PI) * slack * (-1 if index == 0 else 1), 0))
		ropes[index].points = points

func _shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		request_close()

func request_close() -> void:
	if state == "closing" or _disposed: return
	state = "closing"
	_set_enabled(false)
	close_button.grab_focus()
	if motion != null: motion.kill()
	if shade_motion != null: shade_motion.kill()
	motion = create_tween().set_parallel(true)
	motion.tween_method(_set_travel, travel, -650.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_property(shade, "color:a", 0.0, 0.3)
	motion.chain().tween_callback(func(): closed.emit())

func dispose() -> void:
	if _disposed: return
	_disposed = true
	if motion != null: motion.kill()
	if shade_motion != null: shade_motion.kill()
	if get_viewport().gui_focus_changed.is_connected(_guard_focus):
		get_viewport().gui_focus_changed.disconnect(_guard_focus)
	for entry in _saved_focus:
		var control = entry[0].get_ref()
		if is_instance_valid(control): control.focus_mode = entry[1]
	_saved_focus.clear()
	var previous = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(previous) and previous.is_inside_tree(): previous.grab_focus()

func _exit_tree() -> void:
	dispose()
