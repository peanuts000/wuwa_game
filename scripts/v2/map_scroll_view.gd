extends ScrollContainer

signal node_selected(id: String)

const MapView = preload("res://scripts/v2/map_view.gd")
const DRAG_DISTANCE := 8.0

var run_state
var map_view: Control
var content: Control
var _locked := false
var _disposed := false
var _pressed := false
var _dragged := false
var _pressed_node := ""
var _press_position := Vector2.ZERO
var _press_scroll := Vector2.ZERO
var _window: Window
var paper_backdrop := true
var _focus_pending := false

func _init() -> void:
	name = "MapScrollView"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	clip_contents = true
	follow_focus = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	resized.connect(cancel_interaction)
	visibility_changed.connect(_on_visibility_changed)
	_window = get_window()
	_window.focus_exited.connect(cancel_interaction)
	_position_map()

func configure(value) -> void:
	if _disposed:
		return
	cancel_interaction()
	run_state = value
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	content.name = "MapContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	map_view = MapView.new()
	map_view.name = "MapView"
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(map_view)
	map_view.configure(run_state)
	content.custom_minimum_size = map_view.custom_minimum_size
	content.resized.connect(_position_map)
	map_view.node_selected.connect(_on_map_node_selected.bind(map_view))
	# Keep MapView's keyboard activation, but route mouse releases through the
	# scroll view so a drag that starts on a node cannot also enter that node.
	var index := 0
	for id in run_state.nodes:
		var button: Button = map_view.get_child(index)
		button.name = "Node_" + str(id)
		button.set_meta("node_id", str(id))
		button.set_meta("available", not button.disabled)
		button.focus_entered.connect(func(): ensure_control_visible(button))
		index += 1
	_position_map()
	_focus_pending = true
	set_process(true)

func _process(_delta: float) -> void:
	if not _focus_pending or _disposed or not is_instance_valid(map_view):
		set_process(false)
		return
	if size.x <= 0 or get_h_scroll_bar().page <= 0:
		return
	_focus_pending = false
	set_process(false)
	if run_state.current != "" and run_state.nodes.has(run_state.current):
		var x: float = map_view.point(run_state.nodes[run_state.current]).x
		scroll_horizontal = roundi(clampf(x - size.x * 0.3, 0, get_h_scroll_bar().max_value - get_h_scroll_bar().page))

func _draw() -> void:
	if paper_backdrop:
		draw_rect(Rect2(Vector2.ZERO, size), Color("f1e3c9"))

func _position_map() -> void:
	if not is_instance_valid(map_view) or not is_instance_valid(content):
		return
	map_view.size = map_view.custom_minimum_size
	map_view.position = (content.size - map_view.size).max(Vector2.ZERO) * 0.5

func _on_map_node_selected(id: String, source: Control) -> void:
	if source != map_view or not _can_interact() or _pressed or not _node_available(id):
		return
	node_selected.emit(id)

func _node_available(id: String) -> bool:
	return run_state != null and run_state.phase == "map" and id in run_state.available

func _can_interact() -> bool:
	return not _locked and not _disposed and is_inside_tree() and is_visible_in_tree() and is_instance_valid(map_view)

func _node_at(pointer: Vector2) -> String:
	if not get_global_rect().has_point(pointer):
		return ""
	for child in map_view.get_children():
		if child is Button and child.is_visible_in_tree() and child.get_global_rect().has_point(pointer):
			return str(child.get_meta("node_id", ""))
	return ""

func _pointer_from_event(event: InputEventMouse) -> Vector2:
	var local := get_global_transform_with_canvas().affine_inverse() * event.position
	return get_global_transform() * local

func _input(event: InputEvent) -> void:
	if not _can_interact():
		cancel_interaction()
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if get_global_rect().has_point(_pointer_from_event(event)):
			if event.pressed:
				var direction := -1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1
				scroll_horizontal = roundi(clampf(scroll_horizontal + direction * 80, 0, get_h_scroll_bar().max_value - get_h_scroll_bar().page))
			get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(Vector2.ZERO, size).has_point(pointer):
			scroll_horizontal = roundi(clampf(scroll_horizontal + (event.delta.x + event.delta.y) * 36, 0, get_h_scroll_bar().max_value - get_h_scroll_bar().page))
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pointer := _pointer_from_event(event)
		if not get_global_rect().has_point(pointer):
			return
		_pressed = true
		_dragged = false
		_pressed_node = _node_at(pointer)
		_press_position = pointer
		_press_scroll = Vector2(scroll_horizontal, scroll_vertical)
		get_viewport().set_input_as_handled()
		return
	if not _pressed:
		return
	if event is InputEventMouseMotion:
		var delta := _pointer_from_event(event) - _press_position
		if not _dragged and delta.length() >= DRAG_DISTANCE:
			_dragged = true
		if _dragged:
			var target := _press_scroll - delta
			scroll_horizontal = roundi(clampf(target.x, 0.0, get_h_scroll_bar().max_value - get_h_scroll_bar().page))
			scroll_vertical = 0
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var id := _pressed_node
		var pointer := _pointer_from_event(event)
		var activate := not _dragged and pointer.distance_to(_press_position) < DRAG_DISTANCE and id != "" and _node_at(pointer) == id and _node_available(id)
		cancel_interaction()
		# A node callback may synchronously dispose this view and detach it.
		get_viewport().set_input_as_handled()
		if activate:
			node_selected.emit(id)
		return
	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		cancel_interaction()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_interaction()
		get_viewport().set_input_as_handled()

func set_locked(value: bool) -> void:
	_locked = value
	if value:
		cancel_interaction()

func cancel_interaction() -> void:
	_pressed = false
	_dragged = false
	_pressed_node = ""

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_interaction()

func dispose() -> void:
	_disposed = true
	_locked = true
	cancel_interaction()
	set_process_input(false)

func _exit_tree() -> void:
	cancel_interaction()
	if is_instance_valid(_window) and _window.focus_exited.is_connected(cancel_interaction):
		_window.focus_exited.disconnect(cancel_interaction)
