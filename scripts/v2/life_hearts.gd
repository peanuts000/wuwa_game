extends Control

signal loss_started(index: int)
signal loss_finished(index: int)

const HEART_ATLAS := preload("res://assets/ui/status/settlement_atlas.png")
const HEART_REGION := Rect2(324, 390, 100, 80)
const LOSS_DURATION := 0.66
const CRACK_PHASE := 0.18
const LEFT_SHARD := [Vector2(0, 0), Vector2(0.48, 0), Vector2(0.54, 0.22), Vector2(0.45, 0.42), Vector2(0.56, 0.59), Vector2(0.43, 0.78), Vector2(0.50, 1), Vector2(0, 1)]
const RIGHT_SHARD := [Vector2(0.48, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.50, 1), Vector2(0.43, 0.78), Vector2(0.56, 0.59), Vector2(0.45, 0.42), Vector2(0.54, 0.22)]
const CRACK_LINE := [Vector2(0.51, 0.20), Vector2(0.54, 0.22), Vector2(0.45, 0.42), Vector2(0.56, 0.59), Vector2(0.43, 0.78), Vector2(0.49, 0.96)]

var _heart_texture: AtlasTexture
var _heart_size := Vector2(40, 32)
var _spacing := 6.0
var _target_lives := 0
var _shown_lives := 0
var _initialized := false
var _breaking_index := -1
var _breaking_elapsed := 0.0

func _init() -> void:
	name = "LifeHearts"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_texture = AtlasTexture.new()
	_heart_texture.atlas = HEART_ATLAS
	_heart_texture.region = HEART_REGION
	set_process(false)
	_update_minimum_size()

func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(is_animating())

func set_heart_size(value: Vector2, spacing: float = 6.0) -> void:
	_heart_size = Vector2(maxf(1.0, value.x), maxf(1.0, value.y))
	_spacing = maxf(0.0, spacing)
	_update_minimum_size()
	queue_redraw()

func set_lives(value: int, animate: bool = false) -> void:
	var next_lives := maxi(0, value)
	if _initialized and next_lives == _target_lives:
		if not animate and is_animating():
			cancel_animation()
		return
	var previous_target := _target_lives
	_target_lives = next_lives
	set_meta("lives", _target_lives)
	tooltip_text = "探索生命"
	if not _initialized or not animate or next_lives > previous_target:
		_initialized = true
		cancel_animation()
		return
	_initialized = true
	if _shown_lives > _target_lives and not is_animating():
		_start_next_loss()
	_update_minimum_size()
	queue_redraw()

func get_lives() -> int:
	return _target_lives

func get_visible_heart_count() -> int:
	return _shown_lives

func is_animating() -> bool:
	return _breaking_index >= 0

func get_breaking_index() -> int:
	return _breaking_index

func get_break_progress() -> float:
	return clampf(_breaking_elapsed / LOSS_DURATION, 0.0, 1.0) if is_animating() else 0.0

func get_heart_texture() -> AtlasTexture:
	return _heart_texture

func get_heart_size() -> Vector2:
	return _heart_size

func get_spacing() -> float:
	return _spacing

func cancel_animation() -> void:
	_shown_lives = _target_lives
	_breaking_index = -1
	_breaking_elapsed = 0.0
	set_process(false)
	_update_minimum_size()
	queue_redraw()

func _start_next_loss() -> void:
	_breaking_index = _shown_lives - 1
	_breaking_elapsed = 0.0
	set_process(true)
	loss_started.emit(_breaking_index)

func _process(delta: float) -> void:
	if not is_animating():
		return
	_breaking_elapsed += maxf(0.0, delta)
	while is_animating() and _breaking_elapsed >= LOSS_DURATION:
		var finished_index := _breaking_index
		var extra_time := _breaking_elapsed - LOSS_DURATION
		_shown_lives -= 1
		_breaking_index = -1
		_breaking_elapsed = 0.0
		loss_finished.emit(finished_index)
		if _shown_lives > _target_lives:
			_start_next_loss()
			_breaking_elapsed = extra_time
		else:
			set_process(false)
	_update_minimum_size()
	queue_redraw()

func _update_minimum_size() -> void:
	var width := float(_shown_lives) * (_heart_size.x + _spacing) - _spacing if _shown_lives > 0 else 0.0
	custom_minimum_size = Vector2(width, _heart_size.y)

func _heart_rect(index: int) -> Rect2:
	return Rect2(Vector2(float(index) * (_heart_size.x + _spacing), (size.y - _heart_size.y) * 0.5), _heart_size)

func _draw() -> void:
	for index in range(_shown_lives):
		var rect := _heart_rect(index)
		if index == _breaking_index:
			_draw_breaking_heart(rect, get_break_progress())
		else:
			draw_texture_rect(_heart_texture, rect, false)

func _draw_breaking_heart(rect: Rect2, progress: float) -> void:
	if progress < CRACK_PHASE:
		var shake := sin(progress / CRACK_PHASE * TAU * 2.0) * _heart_size.x * 0.025
		var cracked_rect := Rect2(rect.position + Vector2(shake, 0), rect.size)
		draw_texture_rect(_heart_texture, cracked_rect, false)
		var visible_segments := mini(CRACK_LINE.size() - 1, int(ceil(progress / CRACK_PHASE * float(CRACK_LINE.size() - 1))))
		for index in range(visible_segments):
			var from: Vector2 = cracked_rect.position + CRACK_LINE[index] * cracked_rect.size
			var to: Vector2 = cracked_rect.position + CRACK_LINE[index + 1] * cracked_rect.size
			draw_line(from, to, Color("582039"), maxf(1.0, _heart_size.x * 0.042), true)
		return
	var phase := clampf((progress - CRACK_PHASE) / (1.0 - CRACK_PHASE), 0.0, 1.0)
	var travel := 1.0 - pow(1.0 - phase, 2.0)
	var alpha := 1.0 - pow(phase, 1.5)
	var left_offset := Vector2(-0.48 * rect.size.x * travel, rect.size.y * (-0.22 * sin(phase * PI) + 1.35 * phase * phase))
	var right_offset := Vector2(0.55 * rect.size.x * travel, rect.size.y * (-0.35 * sin(phase * PI) + 1.50 * phase * phase))
	_draw_shard(LEFT_SHARD, Vector2(0.25, 0.5), rect, left_offset, -0.55 * phase, phase, alpha)
	_draw_shard(RIGHT_SHARD, Vector2(0.75, 0.5), rect, right_offset, 0.65 * phase, phase, alpha)

func _draw_shard(points: Array, pivot: Vector2, rect: Rect2, offset: Vector2, rotation: float, phase: float, alpha: float) -> void:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var atlas_size := HEART_ATLAS.get_size()
	var center := rect.position + pivot * rect.size + offset
	for normalized_point: Vector2 in points:
		vertices.append(center + ((normalized_point - pivot) * rect.size * (1.0 - phase * 0.12)).rotated(rotation))
		uvs.append((HEART_REGION.position + normalized_point * HEART_REGION.size) / atlas_size)
		colors.append(Color(1, 1, 1, alpha))
	draw_polygon(vertices, colors, uvs, HEART_ATLAS)
