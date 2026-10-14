extends Control

signal close_requested()

const DeckView = preload("res://scripts/v2/deck_view.gd")
const COMMON_CATEGORY := "common"
const ACCENT := Color("79dbc8")
const ROLE_PORTRAIT_SIZE := Vector2(128, 128)
const TOGGLE_SIZE := Vector2(124, 60)
const TOGGLE_MARGIN := 24.0

var selected_category := ""
var _catalog
var _roles: Array = []
var _visible_cards: Array = []
var _category_buttons: Array[Button] = []
var _sidebar: Panel
var _character_scroll: ScrollContainer
var _character_categories: VBoxContainer
var _common: Button
var _close: Button
var _deck_view: Control
var _built := false
var _disposed := false

static func layout_toggle_button(button: Button) -> void:
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -TOGGLE_MARGIN - TOGGLE_SIZE.x
	button.offset_right = -TOGGLE_MARGIN
	button.offset_top = -TOGGLE_MARGIN - TOGGLE_SIZE.y
	button.offset_bottom = -TOGGLE_MARGIN
	button.add_theme_font_size_override("font_size", 18)

func _init() -> void:
	name = "CompendiumView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_position_controls)
	if _catalog != null:
		_render_categories()
		_refresh_cards()

func configure(catalog, roles: Array) -> void:
	if _disposed:
		return
	_catalog = catalog
	_roles = roles.duplicate(true)
	selected_category = str(_catalog.data.get("role", {}).get("id", ""))
	if not _has_category(selected_category):
		selected_category = str(_roles[0].get("id", "")) if not _roles.is_empty() else COMMON_CATEGORY
	if is_inside_tree():
		_build()
		_render_categories()
		_refresh_cards()

func select_category(category_id: String) -> void:
	if _disposed or _catalog == null or not _has_category(category_id):
		return
	selected_category = category_id
	if _built:
		_refresh_cards()

func get_visible_cards() -> Array:
	return _visible_cards.duplicate(true)

func get_category_buttons() -> Array[Button]:
	return _category_buttons.duplicate()

func get_card_views() -> Array[Control]:
	return _deck_view.get_card_views() if is_instance_valid(_deck_view) else []

func get_deck_view() -> Control:
	return _deck_view

func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	for button in _category_buttons:
		if is_instance_valid(button):
			button.disabled = true
	if is_instance_valid(_close):
		_close.disabled = true
	if is_instance_valid(_deck_view):
		_deck_view.dispose()

func _build() -> void:
	if _built:
		return
	_built = true
	var background := ColorRect.new()
	background.color = Color("0c1423")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sidebar = Panel.new()
	_sidebar.name = "CompendiumSidebar"
	_sidebar.add_theme_stylebox_override("panel", _panel_style(Color("141f32"), Color("2a3d54")))
	_sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sidebar)
	_character_scroll = ScrollContainer.new()
	_character_scroll.name = "CharacterScroll"
	_character_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_character_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_character_scroll.follow_focus = true
	_sidebar.add_child(_character_scroll)
	_character_categories = VBoxContainer.new()
	_character_categories.name = "CharacterCategories"
	_character_categories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_categories.add_theme_constant_override("separation", 12)
	_character_scroll.add_child(_character_categories)
	_common = _category_button(_sidebar, "通用牌", COMMON_CATEGORY)
	_common.name = "CommonCardsButton"
	_deck_view = DeckView.new()
	add_child(_deck_view)
	_close = Button.new()
	_close.name = "CloseCompendiumButton"
	_close.text = "图鉴"
	_close.tooltip_text = "返回图鉴分类"
	_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close.pressed.connect(_request_close)
	add_child(_close)
	layout_toggle_button(_close)
	_position_controls()

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style

func _category_button(parent: Node, title: String, category_id: String) -> Button:
	var button := Button.new()
	button.text = title
	button.set_meta("category_id", category_id)
	button.custom_minimum_size = Vector2(0, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 21)
	button.toggle_mode = true
	button.pressed.connect(select_category.bind(category_id))
	parent.add_child(button)
	return button

func _render_categories() -> void:
	for child in _character_categories.get_children():
		_character_categories.remove_child(child)
		child.queue_free()
	_category_buttons.clear()
	for value in _roles:
		var role: Dictionary = value
		var category_id := str(role.get("id", ""))
		var button := _category_button(_character_categories, "", category_id)
		button.name = "Category_" + category_id
		button.tooltip_text = str(role.get("name", category_id))
		button.custom_minimum_size = ROLE_PORTRAIT_SIZE
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var portrait := TextureRect.new()
		portrait.name = "RolePortrait"
		portrait.texture = load("res://assets/pieces/%s_base.png" % role.texture)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 8
		portrait.offset_top = 8
		portrait.offset_right = -8
		portrait.offset_bottom = -8
		_category_buttons.append(button)
	_category_buttons.append(_common)
	_character_scroll.scroll_vertical = 0

func _has_category(category_id: String) -> bool:
	if category_id == COMMON_CATEGORY:
		return true
	for value in _roles:
		if str(value.get("id", "")) == category_id:
			return true
	return false

func _cards_for_category(category_id: String) -> Array:
	var cards: Array = []
	var default_role_id := str(_catalog.data.get("role", {}).get("id", ""))
	var entries: Array = _catalog.data.get("cards", [])
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var pool := str(entry.get("pool", ""))
		var belongs := pool == "common" if category_id == COMMON_CATEGORY else pool == "character" and str(entry.get("role_id", entry.get("character_id", default_role_id))) == category_id
		if belongs:
			cards.append({"id": str(entry.id), "uid": i + 1, "upgraded": false})
	return cards

func _refresh_cards() -> void:
	if _disposed or _catalog == null:
		return
	_visible_cards = _cards_for_category(selected_category)
	for button in _category_buttons:
		var selected := str(button.get_meta("category_id", "")) == selected_category
		button.set_pressed_no_signal(selected)
		var style := _panel_style(Color("24453f") if selected else Color("223149"), ACCENT if selected else Color("2a3d54"))
		style.set_content_margin_all(12)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("pressed", style)
	_deck_view.configure(_catalog, _visible_cards, false)
	_deck_view.set_empty_text("暂无通用卡牌" if selected_category == COMMON_CATEGORY else "暂无专属卡牌")
	_deck_view.get_scroll_container().scroll_vertical = 0

func _position_controls() -> void:
	if not _built:
		return
	var edge := Vector2(size.x * 0.02, size.y * 0.03)
	var sidebar_size := Vector2(size.x * 0.165, size.y - edge.y * 2)
	_sidebar.position = edge
	_sidebar.size = sidebar_size
	_character_scroll.position = Vector2(12, 12)
	_character_scroll.size = Vector2(sidebar_size.x - 24, sidebar_size.y - 112)
	_common.position = Vector2(12, sidebar_size.y - 88)
	_common.size = Vector2(sidebar_size.x - 24, 76)
	var card_left := size.x * 0.21
	var card_width := size.x - card_left - edge.x
	var cards_bottom := size.y - TOGGLE_MARGIN - TOGGLE_SIZE.y - 16
	_deck_view.position = Vector2(card_left, edge.y)
	_deck_view.size = Vector2(card_width, maxf(360, cards_bottom - edge.y))

func _request_close() -> void:
	if _disposed:
		return
	_deck_view.cancel_interaction()
	close_requested.emit()
