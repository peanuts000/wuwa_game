extends Control

signal buy_requested(index: int)
signal leave_requested()

const CardView = preload("res://scripts/v2/card_view.gd")
const ShopItemIcon = preload("res://scripts/v2/shop_item_icon.gd")
const CARD_SIZE := Vector2(150, 210)
const DRAG_DISTANCE := 8.0
const CARD_SCALE := 1.32
const ACCENT := Color("79dbc8")
const MUTED := Color("a6b6cc")

class CoinBadge:
	extends TextureRect
	func _init() -> void:
		texture = preload("res://assets/ui/status/shell_coin.png")
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

var content: Control
var _catalog
var _stock: Array = []
var _shells := 0
var _card_views: Array[Control] = []
var _item_buttons: Array[Button] = []
var _price_labels: Array[Label] = []
var _price_rows: Dictionary = {}
var _products: Dictionary = {}
var _card_homes: Dictionary = {}
var _price_homes: Dictionary = {}
var _card_tweens: Dictionary = {}
var _table: Panel
var _leave: Button
var _tooltip: PanelContainer
var _tooltip_label: Label
var _tooltip_index := -1
var _hovered_index := -1
var _locked := false
var _disposed := false
var _pressed := false
var _dragged := false
var _pressed_product := -1
var _press_position := Vector2.ZERO
var _window: Window

func _init() -> void:
	name = "ShopView"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	_window = get_window()
	_window.focus_exited.connect(cancel_interaction)
	_position_products()

func configure(catalog, stock: Array, shells: int) -> void:
	if _disposed:
		return
	cancel_interaction()
	_catalog = catalog
	_stock = stock.duplicate(true)
	_shells = shells
	_card_views.clear()
	_item_buttons.clear()
	_price_labels.clear()
	_price_rows.clear()
	_products.clear()
	_card_homes.clear()
	_price_homes.clear()
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	if is_instance_valid(_leave):
		remove_child(_leave)
		_leave.queue_free()
	content = Control.new()
	content.name = "ShopContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.resized.connect(_position_products)
	_table = Panel.new()
	_table.name = "ShopTable"
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var table_style := StyleBoxFlat.new()
	table_style.bg_color = Color("142238")
	table_style.border_color = Color("30435b")
	table_style.set_border_width_all(2)
	table_style.set_corner_radius_all(24)
	_table.add_theme_stylebox_override("panel", table_style)
	content.add_child(_table)
	for i in range(_stock.size()):
		var item: Dictionary = _stock[i]
		if item.type == "card":
			var card := CardView.new()
			card.configure(_catalog, {"id": item.id, "uid": i + 1, "upgraded": false})
			card.set_available(_can_buy(i))
			_tag_product(card, i)
			card.activation_requested.connect(_on_card_activation.bind(i, card))
			card.focus_entered.connect(_set_hover.bind(i))
			card.focus_exited.connect(_on_focus_exited.bind(i))
			content.add_child(card)
			_card_views.append(card)
			_products[i] = card
		else:
			var button := Button.new()
			button.name = "ShopItem%d" % i
			button.size = Vector2(90, 90)
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			for state in ["normal", "hover", "pressed", "disabled"]:
				button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			var focus := StyleBoxFlat.new()
			focus.bg_color = Color.TRANSPARENT
			focus.border_color = ACCENT
			focus.set_border_width_all(2)
			focus.set_corner_radius_all(45)
			button.add_theme_stylebox_override("focus", focus)
			_tag_product(button, i)
			button.pressed.connect(_request_buy.bind(i, button))
			button.focus_entered.connect(_show_item_tooltip.bind(i))
			button.focus_exited.connect(_on_focus_exited.bind(i))
			var badge := ShopItemIcon.new()
			badge.configure(str(item.type), str(item.id))
			badge.position = Vector2(5, 5)
			badge.size = Vector2(80, 80)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(badge)
			content.add_child(button)
			_item_buttons.append(button)
			_products[i] = button
		_products[i].modulate = Color("717d8e") if item.sold else Color.WHITE
		_create_price(i)
	_leave = Button.new()
	_leave.name = "LeaveButton"
	_leave.text = "离开商店  →"
	_leave.add_theme_font_size_override("font_size", 20)
	_leave.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_leave.pressed.connect(_request_leave.bind(_leave))
	add_child(_leave)
	_leave.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_leave.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_leave.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_leave.offset_left = -240
	_leave.offset_top = -68
	_leave.offset_right = -20
	_leave.offset_bottom = -20
	_build_tooltip()
	_apply_locked_state()
	_position_products()

func _tag_product(control: Control, index: int) -> void:
	var item: Dictionary = _stock[index]
	control.set_meta("stock_index", index)
	for key in ["type", "id", "price", "sold"]:
		control.set_meta(key, item[key])
	var text: String = _catalog.card_text({"id": item.id}) if item.type == "card" else str((_catalog.relics[item.id] if item.type == "relic" else _catalog.supplies[item.id]).name) + "\n\n" + str((_catalog.relics[item.id] if item.type == "relic" else _catalog.supplies[item.id]).effect)
	control.set_meta("full_text", text)
	control.tooltip_text = ""

func _create_price(index: int) -> void:
	var item: Dictionary = _stock[index]
	var row := Control.new()
	row.name = "ShopPrice%d" % index
	row.size = Vector2(180, 34)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)
	var coin := CoinBadge.new()
	coin.position = Vector2(8, 1)
	coin.size = Vector2(32, 32)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.modulate = Color("717d8e") if item.sold else Color.WHITE
	row.add_child(coin)
	var label := Label.new()
	label.name = "PriceLabel%d" % index
	label.position = Vector2(40, 0)
	label.size = Vector2(136, 34)
	label.text = "%d%s" % [item.price, " · 已售出" if item.sold else ""]
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", MUTED if item.sold else (Color("f5d481") if _can_buy(index) else Color("db9693")))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["type", "id", "price", "sold"]:
		label.set_meta(key, item[key])
	label.set_meta("stock_index", index)
	row.add_child(label)
	_price_labels.append(label)
	_price_rows[index] = row

func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = "ShopTooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15263b")
	style.border_color = ACCENT.darkened(0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	_tooltip.add_theme_stylebox_override("panel", style)
	content.add_child(_tooltip)
	_tooltip_label = Label.new()
	_tooltip_label.custom_minimum_size.x = 262
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.add_theme_font_size_override("font_size", 17)
	_tooltip_label.add_theme_color_override("font_color", Color("edf4ff"))
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_label)
	_tooltip.hide()

func get_card_views() -> Array[Control]:
	return _card_views.duplicate()

func get_item_buttons() -> Array[Button]:
	return _item_buttons.duplicate()

func get_price_labels() -> Array[Label]:
	return _price_labels.duplicate()

func get_leave_button() -> Button:
	return _leave

func get_shop_tooltip_text() -> String:
	return _tooltip_label.text if is_instance_valid(_tooltip_label) else ""

func get_tooltip_panel() -> Control:
	return _tooltip

func _position_products() -> void:
	if _disposed or not is_instance_valid(content) or not is_instance_valid(_table):
		return
	var table_width := minf(1120, maxf(0, content.size.x - 160))
	var left := (content.size.x - table_width) * 0.5
	_table.position = Vector2(left, 16)
	_table.size = Vector2(table_width, maxf(0, content.size.y - 92))
	var card_column := 0
	var item_column := 0
	for i in range(_stock.size()):
		var column: int = card_column if _stock[i].type == "card" else item_column
		var center_x := left + table_width * (column + 0.5) / 4.0
		if _stock[i].type == "card":
			var home := Transform2D.IDENTITY
			home.x *= CARD_SCALE
			home.y *= CARD_SCALE
			home.origin = Vector2(center_x, 190)
			_card_homes[i] = home
			_price_homes[i] = Vector2(center_x - 90, 345)
			card_column += 1
		else:
			_products[i].position = Vector2(center_x - 45, 405)
			_products[i].size = Vector2(90, 90)
			_price_homes[i] = Vector2(center_x - 90, 510)
			_price_rows[i].position = _price_homes[i]
			item_column += 1
	_layout_cards(false)
	_position_tooltip()

func _layout_cards(animated: bool) -> void:
	if _disposed or not is_instance_valid(content):
		return
	for card in _card_views:
		var index := int(card.get_meta("stock_index"))
		if not _card_homes.has(index):
			continue
		var home: Transform2D = _card_homes[index]
		var center := home.origin
		var hovered := index == _hovered_index
		var factor := CARD_SCALE * (1.12 if hovered else 1.0)
		if hovered:
			center.y -= 40
			var half := CARD_SIZE * factor * 0.5
			center.x = clampf(center.x, half.x + 12, maxf(half.x + 12, size.x - half.x - 12))
			center.y = clampf(center.y, half.y + 12, maxf(half.y + 12, size.y - half.y - 48))
		var at := center - CARD_SIZE * 0.5
		var price_at: Vector2 = _price_homes[index]
		if hovered:
			price_at = Vector2(center.x - 90, center.y + CARD_SIZE.y * factor * 0.5 + 12)
		card.z_index = 20 if hovered else 1
		_price_rows[index].z_index = 21 if hovered else 2
		card.set_emphasized(hovered)
		_stop_tween(index)
		if animated and is_inside_tree():
			var tween := create_tween().set_parallel(true)
			_card_tweens[index] = tween
			tween.tween_property(card, "position", at, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale", Vector2.ONE * factor, 0.16)
			tween.tween_property(_price_rows[index], "position", price_at, 0.16)
		else:
			card.position = at
			card.scale = Vector2.ONE * factor
			_price_rows[index].position = price_at

func _set_hover(index: int) -> void:
	if index < 0:
		index = -1
	if _locked or _disposed or _pressed:
		return
	if (_hovered_index == index and _tooltip_index == -1) or (_tooltip_index == index and _hovered_index == -1):
		return
	_hovered_index = index if index >= 0 and _stock[index].type == "card" else -1
	_layout_cards(true)
	if index >= 0 and _stock[index].type != "card":
		_show_item_tooltip(index)
	else:
		_tooltip_index = -1
		if is_instance_valid(_tooltip):
			_tooltip.hide()

func _show_item_tooltip(index: int) -> void:
	if _locked or _disposed or _pressed or not _products.has(index) or _stock[index].type == "card":
		return
	_tooltip_index = index
	_tooltip_label.text = str(_products[index].get_meta("full_text", ""))
	_tooltip.size = Vector2(290, 0)
	_tooltip.show()
	_position_tooltip()
	call_deferred("_position_tooltip")

func _position_tooltip() -> void:
	if _disposed or _tooltip_index < 0 or not is_instance_valid(_tooltip) or not _tooltip.visible:
		return
	var owner: Control = _products[_tooltip_index]
	var dimensions := Vector2(290, maxf(88, _tooltip.get_combined_minimum_size().y))
	_tooltip.size = dimensions
	var x := owner.position.x + owner.size.x + 16
	if x + dimensions.x > size.x - 12:
		x = owner.position.x - dimensions.x - 16
	x = clampf(x, 12, maxf(12, size.x - dimensions.x - 12))
	var y := clampf(owner.position.y, 12, maxf(12, size.y - dimensions.y - 12))
	_tooltip.position = Vector2(x, y)

func _on_focus_exited(index: int) -> void:
	if _hovered_index == index or _tooltip_index == index:
		_set_hover(-1)

func _can_buy(index: int) -> bool:
	return index >= 0 and index < _stock.size() and not _stock[index].sold and int(_stock[index].price) <= _shells

func _on_card_activation(_uid: int, index: int, source: Control) -> void:
	_request_buy(index, source)

func _request_buy(index: int, source: Control = null) -> void:
	if not _can_interact() or not _can_buy(index) or (source != null and _products.get(index) != source):
		return
	set_locked(true)
	buy_requested.emit(index)

func _request_leave(source: Control = null) -> void:
	if not _can_interact() or (source != null and source != _leave):
		return
	set_locked(true)
	leave_requested.emit()

func _can_interact() -> bool:
	return not _locked and not _disposed and is_inside_tree() and is_visible_in_tree() and is_instance_valid(content)

func _pointer_from_event(event: InputEventMouse) -> Vector2:
	var local := get_global_transform_with_canvas().affine_inverse() * event.position
	return get_global_transform() * local

func _product_at(pointer: Vector2) -> int:
	if not get_global_rect().has_point(pointer):
		return -1
	var local := content.get_global_transform().affine_inverse() * pointer
	if _hovered_index >= 0 and _products.has(_hovered_index):
		var view: Control = _products[_hovered_index]
		if Rect2(Vector2.ZERO, CARD_SIZE).has_point(view.get_transform().affine_inverse() * local):
			return _hovered_index
	for card in _card_views:
		var index := int(card.get_meta("stock_index"))
		if _card_homes.has(index) and Rect2(-CARD_SIZE * 0.5, CARD_SIZE).has_point(_card_homes[index].affine_inverse() * local):
			return index
	for index in _price_rows:
		if _price_rows[index].get_rect().has_point(local) or Rect2(_price_homes.get(index, Vector2.ZERO), Vector2(180, 34)).has_point(local):
			return index
	for item in _item_buttons:
		if item.get_rect().has_point(local):
			return int(item.get_meta("stock_index"))
	if is_instance_valid(_leave) and _leave.get_rect().has_point(local):
		return -2
	return -1

func _input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if get_global_rect().has_point(_pointer_from_event(event)):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pointer := _pointer_from_event(event)
		if not get_global_rect().has_point(pointer):
			return
		_pressed = true
		_dragged = false
		_pressed_product = _product_at(pointer)
		_press_position = pointer
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var pointer := _pointer_from_event(event)
		if not _pressed:
			_set_hover(_product_at(pointer))
			return
		var delta := pointer - _press_position
		if not _dragged and delta.length() >= DRAG_DISTANCE:
			_dragged = true
		get_viewport().set_input_as_handled()
		return
	if not _pressed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var index := _pressed_product
		var pointer := _pointer_from_event(event)
		var activate := not _dragged and pointer.distance_to(_press_position) < DRAG_DISTANCE and _product_at(pointer) == index
		cancel_interaction()
		get_viewport().set_input_as_handled()
		if activate and index >= 0:
			_request_buy(index)
		elif activate and index == -2:
			_request_leave()
		return
	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		cancel_interaction()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_interaction()
		get_viewport().set_input_as_handled()

func _apply_locked_state() -> void:
	for card in _card_views:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE if _locked else Control.MOUSE_FILTER_STOP
		card.focus_mode = Control.FOCUS_NONE if _locked else Control.FOCUS_ALL
	for item in _item_buttons:
		item.disabled = _locked or not _can_buy(int(item.get_meta("stock_index")))
	if is_instance_valid(_leave):
		_leave.disabled = _locked

func set_locked(value: bool) -> void:
	if _disposed:
		return
	_locked = value
	if value:
		cancel_interaction()
	_apply_locked_state()

func _stop_tween(index: int) -> void:
	if _card_tweens.has(index):
		var tween: Tween = _card_tweens[index]
		if tween.is_valid():
			tween.kill()
		_card_tweens.erase(index)

func cancel_interaction() -> void:
	_pressed = false
	_dragged = false
	_pressed_product = -1
	_hovered_index = -1
	_tooltip_index = -1
	if is_instance_valid(_tooltip):
		_tooltip.hide()
	for index in _card_tweens.keys():
		_stop_tween(index)
	_layout_cards(false)

func _on_resized() -> void:
	cancel_interaction()
	_position_products()

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
