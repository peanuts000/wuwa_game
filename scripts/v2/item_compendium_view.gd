extends Control

signal close_requested()

const ItemGrid = preload("res://scripts/v2/compendium_item_grid.gd")
const CompendiumView = preload("res://scripts/v2/compendium_view.gd")
const PaperMenuTheme = preload("res://scripts/v2/paper_menu_theme.gd")

var group := "relics"
var _catalog
var _grid: Control
var _close: Button
var _disposed := false

func configure(catalog, item_group: String) -> void:
	_catalog = catalog
	group = item_group

func _ready() -> void:
	name = "ItemCompendiumView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := ColorRect.new()
	background.color = Color("0c1423")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid = ItemGrid.new()
	_grid.name = "ItemCompendiumGrid"
	_grid.item_kind = "supply" if group == "supplies" else "relic"
	add_child(_grid)
	var items: Array = []
	for entry in _catalog.data.get(group, []):
		items.append({"id": str(entry.id), "uid": items.size() + 1})
	_grid.configure(_catalog, items, false)
	_grid.set_empty_text("暂无补给品" if group == "supplies" else "暂无藏品")
	_close = Button.new()
	_close.name = "CloseCompendiumButton"
	_close.text = "图鉴"
	_close.tooltip_text = "返回图鉴分类"
	_close.pressed.connect(_request_close)
	add_child(_close)
	CompendiumView.layout_toggle_button(_close)
	PaperMenuTheme.style_button(_close, 3)
	PaperMenuTheme.add_corner_icon(_close, false)
	resized.connect(_position_controls)
	_position_controls()

func get_item_views() -> Array[Control]:
	return _grid.get_card_views() if is_instance_valid(_grid) else []

func get_grid() -> Control:
	return _grid

func _position_controls() -> void:
	_grid.position = Vector2(24, 108)
	_grid.size = Vector2(size.x - 48, maxf(360, size.y - 208))

func _request_close() -> void:
	if _disposed:
		return
	_grid.cancel_interaction()
	close_requested.emit()

func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	_close.disabled = true
	_grid.dispose()
