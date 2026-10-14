extends Control

signal category_requested(category: String)
signal close_requested()

const Choice = preload("res://scripts/v2/compendium_choice.gd")
const CompendiumView = preload("res://scripts/v2/compendium_view.gd")
const PaperMenuTheme = preload("res://scripts/v2/paper_menu_theme.gd")
const ROPE = preload("res://assets/ui/settings/rope.png")
const CATEGORIES := [
	{"id": "cards", "title": "卡牌", "description": "查看角色专属卡牌\n与通用卡牌。"},
	{"id": "supplies", "title": "补给品", "description": "查看各种补给品\n及其使用效果。"},
	{"id": "relics", "title": "藏品", "description": "查看各种藏品\n及其被动效果。"},
]

var _choices: Array[Button] = []
var _close: Button
var _disposed := false
var _stage: Control
var _dimmer: ColorRect
var _ropes: Array[Line2D] = []
var _motions: Array[Tween] = []
var _travel := [-680.0, -680.0, -680.0]
var _angles := [0.0, 0.0, 0.0]
var _slack := [0.0, 0.0, 0.0]
var _opened := 0
var state := "opening"

func _ready() -> void:
	name = "CompendiumHub"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	PaperMenuTheme.add_background(self)
	_dimmer = ColorRect.new()
	_dimmer.name = "CompendiumShade"
	_dimmer.color = Color(0.10, 0.06, 0.14, 0.48)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_dimmer.gui_input.connect(_shade_input)
	add_child(_dimmer)
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.name = "CompendiumStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	clip_contents = true
	var rope_image := ROPE.get_image()
	if rope_image.is_compressed(): rope_image.decompress()
	rope_image = rope_image.get_region(Rect2i(489, 120, 48, 128))
	rope_image.rotate_90(CLOCKWISE)
	var rope_texture := ImageTexture.create_from_image(rope_image)
	for index in range(6):
		var rope := Line2D.new()
		rope.width = 7
		rope.texture = rope_texture
		rope.texture_mode = Line2D.LINE_TEXTURE_TILE
		rope.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_stage.add_child(rope)
		_ropes.append(rope)
	for category in CATEGORIES:
		var choice := Choice.new()
		choice.configure(category)
		choice.pressed.connect(_request_category.bind(str(category.id)))
		_stage.add_child(choice)
		choice.disabled = true
		_choices.append(choice)
	_close = Button.new()
	_close.name = "CloseCompendiumButton"
	_close.text = "图鉴"
	_close.tooltip_text = "返回主界面（Esc 或点击木牌外）"
	_close.pressed.connect(_request_close)
	add_child(_close)
	CompendiumView.layout_toggle_button(_close)
	PaperMenuTheme.style_button(_close, 3)
	PaperMenuTheme.add_corner_icon(_close, false)
	resized.connect(_position_choices)
	_position_choices()
	for index in range(_choices.size()):
		var motion := create_tween()
		_motions.append(motion)
		motion.tween_interval(index * 0.08)
		motion.tween_method(_set_travel.bind(index), -680.0, 15.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		motion.tween_method(_settle_board.bind(index), 0.0, 1.0, 0.47)
		motion.tween_callback(_finish_opening)

func get_category_buttons() -> Array[Button]:
	return _choices.duplicate()

func _position_choices() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	_stage.scale = Vector2.ONE * factor
	_stage.position = (size - Vector2(1280, 720) * factor) * 0.5
	for i in range(_choices.size()):
		_choices[i].size = Vector2(300, 540)
		_update_pose(i)

func _set_travel(value: float, index: int) -> void:
	_travel[index] = value
	_update_pose(index)

func _settle_board(progress: float, index: int) -> void:
	var decay := pow(1.0 - progress, 2)
	_travel[index] = 15.0 * cos(progress * TAU * 1.25) * decay
	_angles[index] = deg_to_rad(1.4) * sin(progress * TAU * 1.5) * decay * (-1 if index == 1 else 1)
	_slack[index] = 7.0 * sin(progress * PI) * decay
	_update_pose(index)

func _update_pose(index: int) -> void:
	var board := _choices[index]
	board.position = Vector2(112 + index * 378, 80 + _travel[index])
	board.rotation = _angles[index]
	for side in range(2):
		var endpoint := board.get_transform() * Vector2(75 + side * 150, 13)
		var top := Vector2(187 + index * 378 + side * 150, -_stage.position.y / maxf(_stage.scale.y, 0.001))
		var points := PackedVector2Array()
		for step in range(13):
			var fraction := step / 12.0
			points.append(top.lerp(endpoint, fraction) + Vector2(sin(fraction * PI) * _slack[index] * (-1 if side == 0 else 1), 0))
		_ropes[index * 2 + side].points = points

func _finish_opening() -> void:
	if _disposed or state != "opening": return
	_opened += 1
	if _opened != _choices.size(): return
	state = "open"
	for choice in _choices:
		choice.disabled = false
		choice._refresh_highlight()
	_choices[0].grab_focus()

func _request_category(category: String) -> void:
	if not _disposed and state == "open":
		category_requested.emit(category)

func _request_close() -> void:
	request_close()

func _shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dimmer.accept_event()
		# The painted crest extends above the logical button. Clicking that visible
		# part of a board must not count as an outside click, even during motion.
		var point: Vector2 = _dimmer.get_global_transform() * event.position
		for choice in _choices:
			var local_point: Vector2 = choice.get_global_transform().affine_inverse() * point
			if Rect2(choice._preview.position, choice._preview.size).has_point(local_point):
				return
		request_close()

func request_close() -> void:
	if _disposed or state in ["closing", "closed"]: return
	state = "closing"
	for motion in _motions:
		if motion != null: motion.kill()
	_motions.clear()
	for choice in _choices:
		choice.disabled = true
		choice.focus_mode = Control.FOCUS_NONE
		choice._refresh_highlight()
	_close.disabled = true
	_close.focus_mode = Control.FOCUS_NONE
	var motion := create_tween().set_parallel(true)
	_motions.append(motion)
	for index in range(_choices.size()):
		motion.tween_method(_close_pose.bind(index, _travel[index], _angles[index], _slack[index]), 0.0, 1.0, 0.3).set_delay(index * 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_property(_dimmer, "color:a", 0.0, 0.38)
	motion.chain().tween_callback(_finish_closing)

func _close_pose(progress: float, index: int, start_travel: float, start_angle: float, start_slack: float) -> void:
	_travel[index] = lerpf(start_travel, -680.0, progress)
	_angles[index] = start_angle * (1.0 - progress)
	_slack[index] = start_slack * (1.0 - progress)
	_update_pose(index)

func _finish_closing() -> void:
	if _disposed or state != "closing": return
	state = "closed"
	close_requested.emit()

func dispose() -> void:
	_disposed = true
	for motion in _motions:
		if motion != null: motion.kill()
	for button in _choices:
		button.disabled = true
	_close.disabled = true

func _exit_tree() -> void:
	dispose()
