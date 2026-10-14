extends Control

signal play_requested(uid: int)

const CardView = preload("res://scripts/v2/card_view.gd")
const CARD_SIZE := Vector2(150, 210)
const DRAG_DISTANCE := 8.0
const COLLAPSED_PEEK := 28.0

var _catalog
var _combat
var _views: Dictionary = {}
var _order: Array[int] = []
var _tweens: Dictionary = {}
var _home_transforms: Dictionary = {}
var _can_play: Callable
var _reason: Callable
var _play_zone := Rect2()
var _locked := false
var _collapsed := false
var _disposed := false
var _hovered_uid := -1
var _pressed_uid := -1
var _press_position := Vector2.ZERO
var _dragged := false
var _drag_offset := Vector2.ZERO
var _animating_uid := -1
var _departure_tweens: Array[Tween] = []
var _departure_views: Array[Control] = []
var paper_style := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	resized.connect(_on_resized)
	_layout(false)

func configure(catalog, combat = null) -> void:
	_catalog = catalog
	_combat = combat

func update_hand(cards: Array, can_play: Callable, reason: Callable = Callable(), played_uid: int = -1) -> void:
	_can_play = can_play
	_reason = reason
	cancel_interaction()
	var next_order: Array[int] = []
	for value in cards:
		var card: Dictionary = value
		var uid := int(card.get("uid", -1))
		if uid >= 0:
			next_order.append(uid)
	for uid in _views.keys():
		if uid not in next_order or uid == played_uid:
			_remove_view(uid, uid != played_uid)
	_order = next_order
	var entering: Array[int] = []
	for value in cards:
		var card: Dictionary = value
		var uid := int(card.get("uid", -1))
		if uid < 0:
			continue
		if not _views.has(uid):
			var view := CardView.new()
			view.paper_style = paper_style
			view.configure(_catalog, card, _combat)
			view.pointer_pressed.connect(_on_pointer_pressed)
			view.activation_requested.connect(request_play)
			view.focus_entered.connect(_on_hover.bind(uid))
			view.focus_exited.connect(_on_unhover.bind(uid))
			add_child(view)
			_views[uid] = view
			entering.append(uid)
		else:
			_views[uid].configure(_catalog, card, _combat)
		var playable := _can_play.is_valid() and bool(_can_play.call(uid))
		var message := str(_reason.call(uid)) if _reason.is_valid() else ""
		_views[uid].set_available(playable, message)
		_apply_interaction_state(_views[uid])
	_layout(true, entering)

func set_locked(value: bool) -> void:
	_locked = value
	if value:
		cancel_interaction()

func set_collapsed(value: bool) -> void:
	if _disposed or _collapsed == value:
		return
	_collapsed = value
	_pressed_uid = -1
	_dragged = false
	_hovered_uid = -1
	_animating_uid = -1
	for view in _views.values():
		_apply_interaction_state(view)
	queue_redraw()
	_layout(true, [], 0.22)

func is_collapsed() -> bool:
	return _collapsed

func get_expanded_top() -> float:
	return _hand_top(false)

func get_collapsed_top() -> float:
	return _hand_top(true)

func _hand_top(collapsed: bool) -> float:
	if _order.is_empty():
		return get_global_rect().end.y
	var minimum := INF
	for i in range(_order.size()):
		var home := _resting_transform(i, _order.size(), collapsed)
		for corner in [Vector2(-75, -105), Vector2(75, -105), Vector2(75, 105), Vector2(-75, 105)]:
			var point: Vector2 = get_global_transform() * (home * corner)
			minimum = minf(minimum, point.y)
	return minimum

func _apply_interaction_state(view: Control) -> void:
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE if _collapsed or _disposed else Control.MOUSE_FILTER_STOP
	view.focus_mode = Control.FOCUS_NONE if _collapsed or _disposed else Control.FOCUS_ALL
	if (_collapsed or _disposed) and view.has_focus():
		view.release_focus()

func set_play_zone(zone: Rect2) -> void:
	_play_zone = zone
	queue_redraw()

func get_card_view(uid: int):
	return _views.get(uid)

func cancel_interaction() -> void:
	_pressed_uid = -1
	_dragged = false
	_hovered_uid = -1
	queue_redraw()
	_layout(true)

func request_play(uid: int) -> void:
	if _locked or _collapsed or _disposed or not _views.has(uid) or not _can_play.is_valid() or not bool(_can_play.call(uid)):
		return
	play_requested.emit(uid)

func animate_play(uid: int) -> void:
	if not _views.has(uid):
		return
	_animating_uid = uid
	_pressed_uid = -1
	_dragged = false
	_hovered_uid = -1
	queue_redraw()
	_stop_tween(uid)
	var view: Control = _views[uid]
	view.z_index = 100
	view.set_emphasized(true)
	var destination := _play_zone.position + Vector2(_play_zone.size.x * 0.5, _play_zone.size.y * 0.32)
	if _play_zone.size == Vector2.ZERO:
		destination = get_global_rect().position + Vector2(size.x * 0.5, -100)
	var target := _to_local(destination) - CARD_SIZE * 0.5
	var tween := create_tween().set_parallel(true)
	_tweens[uid] = tween
	tween.tween_property(view, "position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(view, "rotation", 0.0, 0.18)
	tween.tween_property(view, "scale", Vector2.ONE * 0.78, 0.18)
	tween.tween_property(view, "modulate:a", 0.0, 0.18)
	# A timer also completes if a resize or page switch cancels the visual tween.
	await get_tree().create_timer(0.18).timeout
	if _animating_uid == uid:
		if is_instance_valid(view) and _views.get(uid) == view:
			_stop_tween(uid)
			view.position = target
			view.rotation = 0
			view.scale = Vector2.ONE * 0.78
			view.modulate.a = 0
		_animating_uid = -1

func dispose() -> void:
	_disposed = true
	_locked = true
	_pressed_uid = -1
	_dragged = false
	_hovered_uid = -1
	_animating_uid = -1
	set_process_input(false)
	for uid in _tweens.keys():
		_stop_tween(uid)
	for tween in _departure_tweens:
		if is_instance_valid(tween):
			tween.kill()
	for view in _departure_views:
		if is_instance_valid(view):
			view.queue_free()
	_departure_tweens.clear()
	_departure_views.clear()
	for view in _views.values():
		_apply_interaction_state(view)

func _on_pointer_pressed(uid: int, pointer: Vector2) -> void:
	if _locked or _collapsed or _disposed or not _views.has(uid) or not _can_play.is_valid() or not bool(_can_play.call(uid)):
		return
	_pressed_uid = uid
	_press_position = pointer
	_dragged = false
	_hovered_uid = uid
	var view: Control = _views[uid]
	_drag_offset = _to_local(pointer) - (view.position + CARD_SIZE * 0.5)

func _input(event: InputEvent) -> void:
	if _collapsed or _disposed:
		return
	if event is InputEventMouseMotion and _pressed_uid < 0:
		_update_hover(_pointer_from_event(event))
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _locked:
		var pointer := _pointer_from_event(event)
		var uid := _card_at(pointer)
		if uid >= 0:
			_on_pointer_pressed(uid, pointer)
			if _pressed_uid >= 0:
				_views[uid].grab_focus()
				get_viewport().set_input_as_handled()
		return
	if _pressed_uid < 0:
		return
	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		cancel_interaction()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_interaction()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var pointer := _pointer_from_event(event)
		if not _dragged and pointer.distance_to(_press_position) >= DRAG_DISTANCE:
			_dragged = true
			_stop_tween(_pressed_uid)
		if _dragged and _views.has(_pressed_uid):
			var view: Control = _views[_pressed_uid]
			view.position = _to_local(pointer) - _drag_offset - CARD_SIZE * 0.5
			view.rotation = 0
			view.scale = Vector2.ONE * 1.12
			view.z_index = 100
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var uid := _pressed_uid
		var valid_drop := not _dragged or _play_zone.has_point(_pointer_from_event(event))
		_pressed_uid = -1
		_dragged = false
		_hovered_uid = -1
		queue_redraw()
		if valid_drop:
			request_play(uid)
		else:
			_layout(true)
		get_viewport().set_input_as_handled()

func _on_hover(uid: int) -> void:
	if _collapsed or _disposed or _pressed_uid >= 0 or _animating_uid >= 0:
		return
	_hovered_uid = uid
	_layout(true)

func _on_unhover(uid: int) -> void:
	if _pressed_uid >= 0 or uid != _hovered_uid:
		return
	_hovered_uid = -1
	_layout(true)

func _on_resized() -> void:
	cancel_interaction()
	_layout(false)

func _to_local(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point

func _pointer_from_event(event: InputEventMouse) -> Vector2:
	var local := get_global_transform_with_canvas().affine_inverse() * event.position
	return get_global_transform() * local

func _base_card_at(pointer: Vector2) -> int:
	var local := _to_local(pointer)
	for i in range(_order.size() - 1, -1, -1):
		var uid: int = _order[i]
		if _home_transforms.has(uid):
			var relative: Vector2 = _home_transforms[uid].affine_inverse() * local
			if Rect2(-CARD_SIZE * 0.5, CARD_SIZE).has_point(relative):
				return uid
	return -1

func _hovered_contains(pointer: Vector2) -> bool:
	if _hovered_uid < 0 or not _views.has(_hovered_uid):
		return false
	var view: Control = _views[_hovered_uid]
	var relative := view.get_transform().affine_inverse() * _to_local(pointer)
	return Rect2(Vector2.ZERO, CARD_SIZE).has_point(relative)

func _card_at(pointer: Vector2) -> int:
	if _hovered_contains(pointer):
		return _hovered_uid
	return _base_card_at(pointer)

func _update_hover(pointer: Vector2) -> void:
	if _collapsed or _disposed or _animating_uid >= 0:
		return
	# Hit-test the resting fan, so raising a card never causes enter/exit flicker.
	var candidate := _base_card_at(pointer)
	if candidate < 0 and _hovered_contains(pointer):
		candidate = _hovered_uid
	if candidate != _hovered_uid:
		_hovered_uid = candidate
		_layout(true)

func _resting_transform(index: int, count: int, collapsed: bool) -> Transform2D:
	var base_scale := minf(1.0, maxf(0.35, (size.x - 48) / CARD_SIZE.x))
	var step := minf(100.0, maxf(0, size.x - CARD_SIZE.x * base_scale - 56) / maxf(1, count - 1))
	var middle := (count - 1) * 0.5
	var fraction := (index - middle) / maxf(1, middle)
	var at := Vector2(size.x * 0.5 + (index - middle) * step, size.y - CARD_SIZE.y * base_scale * 0.5 - 24 + absf(fraction) * 8)
	var angle := deg_to_rad(clampf((index - middle) * 3.8, -14, 14))
	if collapsed:
		at.y = size.y + CARD_SIZE.y * base_scale * 0.5 - COLLAPSED_PEEK
		angle = 0
	var home := Transform2D.IDENTITY
	home.x = Vector2(cos(angle), sin(angle)) * base_scale
	home.y = Vector2(-sin(angle), cos(angle)) * base_scale
	home.origin = at
	return home

func _layout(animated: bool, entering: Array[int] = [], duration: float = 0.16) -> void:
	if _disposed or size.x <= 0 or _order.is_empty():
		return
	var count := _order.size()
	for i in range(count):
		var uid: int = _order[i]
		if not _views.has(uid):
			continue
		var view: Control = _views[uid]
		var home := _resting_transform(i, count, _collapsed)
		var at := home.origin
		var angle := home.get_rotation()
		var base_scale := home.x.length()
		_home_transforms[uid] = home
		if uid == _animating_uid or (_dragged and uid == _pressed_uid):
			continue
		var target_scale := Vector2.ONE * base_scale
		var hovered := not _collapsed and uid == _hovered_uid
		if hovered:
			at.y -= 60
			angle = 0
			target_scale *= 1.12
		view.z_index = 60 if hovered else i
		view.set_emphasized(hovered)
		var target := at - CARD_SIZE * 0.5
		_stop_tween(uid)
		if uid in entering:
			view.position = target + Vector2(24, 68)
			view.rotation = angle
			view.scale = target_scale * 0.85
			view.modulate.a = 0
		if animated and is_inside_tree():
			var tween := create_tween().set_parallel(true)
			_tweens[uid] = tween
			tween.tween_property(view, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(view, "rotation", angle, duration)
			tween.tween_property(view, "scale", target_scale, duration)
			tween.tween_property(view, "modulate:a", 1.0, duration)
		else:
			view.position = target
			view.rotation = angle
			view.scale = target_scale
			view.modulate.a = 1

func _stop_tween(uid: int) -> void:
	if _tweens.has(uid):
		var tween: Tween = _tweens[uid]
		if is_instance_valid(tween):
			tween.kill()
		_tweens.erase(uid)

func _remove_view(uid: int, animate: bool) -> void:
	_stop_tween(uid)
	var view: Control = _views[uid]
	_views.erase(uid)
	_home_transforms.erase(uid)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.focus_mode = Control.FOCUS_NONE
	if animate and is_inside_tree():
		var tween := create_tween().set_parallel(true)
		_departure_tweens.append(tween)
		_departure_views.append(view)
		tween.tween_property(view, "position:y", view.position.y + 35, 0.12)
		tween.tween_property(view, "modulate:a", 0.0, 0.12)
		tween.chain().tween_callback(func():
			_departure_tweens.erase(tween)
			_departure_views.erase(view)
			if is_instance_valid(view):
				view.queue_free())
	else:
		view.queue_free()

func _draw() -> void:
	if not _dragged or _play_zone.size == Vector2.ZERO:
		return
	var first := _to_local(_play_zone.position)
	var last := _to_local(_play_zone.end)
	var rect := Rect2(first, last - first)
	var valid := _play_zone.has_point(get_global_mouse_position())
	var color := Color(0.47, 0.86, 0.78, 0.12 if valid else 0.045)
	draw_rect(rect, color)
	draw_rect(rect.grow(-2), Color(0.47, 0.86, 0.78, 0.8 if valid else 0.3), false, 2)
