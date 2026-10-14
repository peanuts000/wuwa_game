extends Control

signal card_selected(uid: int)

const CardView = preload("res://scripts/v2/card_view.gd")
const CARD_SIZE := Vector2(150, 210)
const CARD_SCALE := 1.30
const DRAG_DISTANCE := 8.0
const COLUMN_GAP := 40.0
const ROW_GAP := 60.0
const PADDING := 24.0
const TOP_PADDING := 64.0

var _catalog
var _cards: Array = []
var _selectable := false
var _unavailable_reason := ""
var _scroll: ScrollContainer
var _content: Control
var _empty: Label
var _card_views: Array[Control] = []
var _by_uid: Dictionary = {}
var _homes: Dictionary = {}
var _tweens: Dictionary = {}
var _base_scale := CARD_SCALE
var _hovered_uid := -1
var _locked := false
var _disposed := false
var _pressed := false
var _pressed_uid := -1
var _dragged := false
var _press_position := Vector2.ZERO
var _press_scroll := 0.0
var _window: Window

func _init() -> void:
	name = "DeckView"
	custom_minimum_size = Vector2(0, 360)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _ready() -> void:
	_build()
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	_window = get_window()
	_window.focus_exited.connect(cancel_interaction)
	_position_cards()

func _build() -> void:
	if is_instance_valid(_scroll):
		return
	_scroll = ScrollContainer.new()
	_scroll.name = "DeckScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.follow_focus = false
	_scroll.clip_contents = true
	add_child(_scroll)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
	_scroll.resized.connect(_on_resized)
	_content = Control.new()
	_content.name = "DeckContent"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_empty = Label.new()
	_empty.name = "DeckEmpty"
	_empty.text = "牌组为空"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.add_theme_font_size_override("font_size", 22)
	_empty.add_theme_color_override("font_color", Color("a6b6cc"))
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_empty)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(catalog, cards: Array, selectable: bool = false, unavailable_reason: String = "", combat = null) -> void:
	if _disposed:
		return
	_build()
	cancel_interaction()
	_catalog = catalog
	_cards = cards.duplicate(true)
	_selectable = selectable
	_unavailable_reason = unavailable_reason
	for view in _card_views:
		_content.remove_child(view)
		view.queue_free()
	_card_views.clear()
	_by_uid.clear()
	_homes.clear()
	for value in _cards:
		var card: Dictionary = value
		var view := _create_card_view(_catalog, card, combat)
		var uid: int = view.uid
		view.set_meta("uid", uid)
		view.set_meta("card_id", str(card.id))
		view.set_meta("upgraded", bool(card.get("upgraded", false)))
		view.set_meta("selectable", selectable)
		view.set_available(not selectable or unavailable_reason.is_empty(), unavailable_reason if selectable else "")
		if not selectable:
			view.mouse_default_cursor_shape = Control.CURSOR_ARROW
		view.activation_requested.connect(_on_card_activation.bind(view))
		view.focus_entered.connect(_on_focus.bind(uid))
		view.focus_exited.connect(_on_focus_exited.bind(uid))
		_content.add_child(view)
		_card_views.append(view)
		_by_uid[uid] = view
	_empty.visible = _card_views.is_empty()
	_apply_locked_state()
	_position_cards()
	call_deferred("_position_cards")

func _create_card_view(catalog, value: Dictionary, combat = null) -> Control:
	var view := CardView.new()
	view.configure(catalog, value, combat)
	return view

func get_card_views() -> Array[Control]:
	return _card_views.duplicate()

func get_scroll_container() -> ScrollContainer:
	return _scroll

func get_content() -> Control:
	return _content

func set_empty_text(text: String) -> void:
	_build()
	_empty.text = text

func _viewport_rect() -> Rect2:
	var rect := _scroll.get_global_rect()
	if _scroll.get_v_scroll_bar().is_visible_in_tree():
		rect.size.x = maxf(0, rect.size.x - _scroll.get_v_scroll_bar().size.x)
	return rect

func _position_cards() -> void:
	if _disposed or not is_instance_valid(_scroll) or _scroll.size.x <= 0 or _scroll.size.y <= 0:
		return
	var width := _viewport_rect().size.x
	_base_scale = minf(CARD_SCALE, minf(maxf(0.1, (width - 24) / (CARD_SIZE.x * 1.12)), maxf(0.1, (_scroll.size.y - 24) / (CARD_SIZE.y * 1.12))))
	var card_width := CARD_SIZE.x * _base_scale
	var card_height := CARD_SIZE.y * _base_scale
	var columns := maxi(1, mini(4, floori((width - PADDING * 2 + COLUMN_GAP) / (card_width + COLUMN_GAP))))
	var row_width := columns * card_width + (columns - 1) * COLUMN_GAP
	var left := (width - row_width) * 0.5
	var rows := ceili(float(_card_views.size()) / columns)
	var height := TOP_PADDING + rows * card_height + maxi(0, rows - 1) * ROW_GAP + 44
	_content.custom_minimum_size.y = maxf(_scroll.size.y, height if rows > 0 else 0.0)
	for i in range(_card_views.size()):
		var view: Control = _card_views[i]
		var home := Transform2D.IDENTITY
		home.x *= _base_scale
		home.y *= _base_scale
		home.origin = Vector2(left + card_width * 0.5 + (i % columns) * (card_width + COLUMN_GAP), TOP_PADDING + card_height * 0.5 + floorf(float(i) / columns) * (card_height + ROW_GAP))
		_homes[int(view.uid)] = home
	_layout_cards(false)

func _layout_cards(animated: bool) -> void:
	if _disposed or not is_instance_valid(_scroll):
		return
	var width := _viewport_rect().size.x
	for view in _card_views:
		var uid: int = view.uid
		if not _homes.has(uid):
			continue
		var home: Transform2D = _homes[uid]
		var center := home.origin
		var hovered := uid == _hovered_uid
		var factor := _base_scale * (1.12 if hovered else 1.0)
		if hovered:
			center.y -= 32
			var half := CARD_SIZE * factor * 0.5
			center.x = clampf(center.x, half.x + 12, maxf(half.x + 12, width - half.x - 12))
			center.y = clampf(center.y, _scroll.scroll_vertical + half.y + 12, maxf(_scroll.scroll_vertical + half.y + 12, _scroll.scroll_vertical + _scroll.size.y - half.y - 12))
		view.z_index = 20 if hovered else 0
		view.set_emphasized(hovered)
		_stop_tween(uid)
		var at := center - CARD_SIZE * 0.5
		if animated and is_inside_tree():
			var tween := create_tween().set_parallel(true)
			_tweens[uid] = tween
			tween.tween_property(view, "position", at, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(view, "scale", Vector2.ONE * factor, 0.16)
		else:
			view.position = at
			view.scale = Vector2.ONE * factor

func _set_hover(uid: int) -> void:
	if not _can_interact() or _pressed or _hovered_uid == uid:
		return
	_hovered_uid = uid
	_layout_cards(true)

func _on_focus(uid: int) -> void:
	if not _can_interact() or not _by_uid.has(uid):
		return
	# The active hover already targets a position inside the viewport. Preserve
	# it while its tween finishes, so focusing a partially visible card cannot
	# scroll its resting slot away between the mouse press and release.
	if _hovered_uid == uid:
		return
	_cancel_hover()
	_scroll.ensure_control_visible(_by_uid[uid])
	_set_hover(uid)

func _on_focus_exited(uid: int) -> void:
	if _hovered_uid == uid:
		_set_hover(-1)

func _on_card_activation(uid: int, source: Control) -> void:
	_request_select(uid, source)

func _request_select(uid: int, source: Control = null) -> void:
	if not _can_interact() or not _selectable or not _unavailable_reason.is_empty() or not _by_uid.has(uid) or (source != null and _by_uid[uid] != source):
		return
	set_locked(true)
	card_selected.emit(uid)

func _can_interact() -> bool:
	return not _locked and not _disposed and is_inside_tree() and is_visible_in_tree() and is_instance_valid(_scroll)

func _pointer_from_event(event: InputEventMouse) -> Vector2:
	var local := get_global_transform_with_canvas().affine_inverse() * event.position
	return get_global_transform() * local

func _card_at(pointer: Vector2) -> int:
	if not _viewport_rect().has_point(pointer):
		return -1
	var local := _content.get_global_transform().affine_inverse() * pointer
	if _hovered_uid >= 0 and _by_uid.has(_hovered_uid):
		var view: Control = _by_uid[_hovered_uid]
		if Rect2(Vector2.ZERO, CARD_SIZE).has_point(view.get_transform().affine_inverse() * local):
			return _hovered_uid
	for view in _card_views:
		var uid: int = view.uid
		if _homes.has(uid) and Rect2(-CARD_SIZE * 0.5, CARD_SIZE).has_point(_homes[uid].affine_inverse() * local):
			return uid
	return -1

func _input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if _scroll.get_global_rect().has_point(_pointer_from_event(event)):
			cancel_interaction()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pointer := _pointer_from_event(event)
		if not _viewport_rect().has_point(pointer):
			return
		var uid := _card_at(pointer)
		if uid >= 0 and _by_uid.has(uid):
			_by_uid[uid].grab_focus()
		_pressed = true
		_pressed_uid = uid
		_dragged = false
		_press_position = pointer
		_press_scroll = _scroll.scroll_vertical
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var pointer := _pointer_from_event(event)
		if not _pressed:
			_set_hover(_card_at(pointer))
			return
		var delta := pointer - _press_position
		if not _dragged and delta.length() >= DRAG_DISTANCE:
			_dragged = true
			_cancel_hover()
		if _dragged:
			var bar := _scroll.get_v_scroll_bar()
			_scroll.scroll_vertical = roundi(clampf(_press_scroll - delta.y, 0, maxf(0, bar.max_value - bar.page)))
		get_viewport().set_input_as_handled()
		return
	if not _pressed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var uid := _pressed_uid
		var pointer := _pointer_from_event(event)
		var activate := not _dragged and uid >= 0 and pointer.distance_to(_press_position) < DRAG_DISTANCE and _card_at(pointer) == uid
		_pressed = false
		_pressed_uid = -1
		_dragged = false
		get_viewport().set_input_as_handled()
		if activate:
			_request_select(uid)
		return
	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		cancel_interaction()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_interaction()
		get_viewport().set_input_as_handled()

func _apply_locked_state() -> void:
	for view in _card_views:
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE if _locked else Control.MOUSE_FILTER_STOP
		view.focus_mode = Control.FOCUS_NONE if _locked else Control.FOCUS_ALL

func set_locked(value: bool) -> void:
	if _disposed:
		return
	_locked = value
	if value:
		cancel_interaction()
	_apply_locked_state()

func _stop_tween(uid: int) -> void:
	if _tweens.has(uid):
		var tween: Tween = _tweens[uid]
		if tween.is_valid():
			tween.kill()
		_tweens.erase(uid)

func _cancel_hover() -> void:
	_hovered_uid = -1
	for uid in _tweens.keys():
		_stop_tween(uid)
	_layout_cards(false)

func cancel_interaction() -> void:
	_pressed = false
	_pressed_uid = -1
	_dragged = false
	_cancel_hover()

func _on_scrolled(_value: float) -> void:
	_cancel_hover()

func _on_resized() -> void:
	cancel_interaction()
	_position_cards()
	call_deferred("_position_cards")

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_interaction()

func dispose() -> void:
	if _disposed:
		return
	set_locked(true)
	_disposed = true
	set_process_input(false)

func _exit_tree() -> void:
	cancel_interaction()
	if is_instance_valid(_window) and _window.focus_exited.is_connected(cancel_interaction):
		_window.focus_exited.disconnect(cancel_interaction)
