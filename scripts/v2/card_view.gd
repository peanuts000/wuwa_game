extends Control

signal pointer_pressed(uid: int, pointer: Vector2)
signal activation_requested(uid: int)

const CARD_SIZE := Vector2(150, 210)
const CARD_BACKGROUND = preload("res://assets/ui/cards/card_frame_bg.png")
const PieceView = preload("res://scripts/v2/piece_view.gd")
const Combat = preload("res://scripts/v2/combat.gd")
const PaperArt = preload("res://scripts/v2/paper_battle_theme.gd")
const CARD_FRAME = preload("res://assets/ui/cards/astral/frame.png")

var uid := -1
var full_text := ""
var card: Dictionary = {}
var available := false
var unavailable_reason := ""
var paper_style := true
var _catalog
var _combat
var _base_combat = Combat.new()
var _accent := Color("79dbc8")
var _emphasized := false
var _type := "技能"
var _title: Label
var _type_label: Label
var _effect: Label
var _cost_row: VBoxContainer
var _extended_costs := false

func _ready() -> void:
	_build_face()
	_refresh_face()

func configure(catalog, value: Dictionary, combat = null) -> void:
	_catalog = catalog
	_combat = combat
	card = value.duplicate(true)
	uid = int(card.get("uid", -1))
	name = "Card_%d" % uid
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	if is_node_ready():
		_refresh_face()

func set_available(value: bool, reason: String = "") -> void:
	available = value
	unavailable_reason = reason
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_HELP
	_refresh_tooltip()
	queue_redraw()

func set_emphasized(value: bool) -> void:
	_emphasized = value
	queue_redraw()

func _build_face() -> void:
	if is_instance_valid(_title):
		return
	_title = _make_label(Vector2(41, 8), Vector2(68, 26), 12)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_row = VBoxContainer.new()
	_cost_row.name = "AttributeCosts"
	_cost_row.position = Vector2(7, 7)
	_cost_row.size = Vector2(32, 0)
	_cost_row.add_theme_constant_override("separation", 3)
	_cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_row.z_index = 1
	add_child(_cost_row)
	_type_label = _make_label(Vector2(12, 103), Vector2(126, 17), 11)
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect = _make_label(Vector2(10, 125), Vector2(130, 78), 11)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect.add_theme_constant_override("line_spacing", -2)
	if paper_style:
		_title.position = Vector2(44, 7)
		_title.size = Vector2(92, 18)
		_cost_row.position = Vector2(6, 8)
		_cost_row.size = Vector2(28, 0)
		_type_label.position = Vector2(18, 135)
		_type_label.size = Vector2(114, 14)
		_effect.position = Vector2(12, 153)
		_effect.size = Vector2(126, 44)

func _make_label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("edf4ff"))
	label.add_theme_color_override("font_outline_color", Color("101820"))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label

func _refresh_face() -> void:
	if _catalog == null or not is_instance_valid(_title) or card.is_empty():
		return
	var entry: Dictionary = _catalog.cards.get(card.get("id", ""), {})
	if entry.is_empty():
		return
	full_text = _catalog.card_text(card)
	_title.text = str(entry.name) + (" +" if card.get("upgraded", false) else "")
	_effect.text = _description_text(entry)
	_type = _catalog.card_type(card)
	_type_label.text = _type
	var cost: Dictionary = _catalog.cost(card)
	var reserved_column := cost.size() > 3
	_extended_costs = reserved_column
	_type_label.position.x = 43 if reserved_column else 18
	_type_label.size.x = 95 if reserved_column else 114
	_effect.position.x = 43 if reserved_column else 12
	_effect.size.x = 95 if reserved_column else 126
	_accent = _catalog.COLORS.get(cost.keys()[0], Color("79dbc8")) if not cost.is_empty() else Color("79dbc8")
	_type_label.add_theme_color_override("font_color", _accent.lightened(0.2))
	if paper_style:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		for label in [_title, _effect]:
			label.add_theme_color_override("font_color", PaperArt.INK)
			label.add_theme_constant_override("outline_size", 0)
		_type_label.add_theme_color_override("font_color", PaperArt.CREAM)
		_type_label.add_theme_constant_override("outline_size", 0)
		_fit_effect_text()
	for child in _cost_row.get_children():
		_cost_row.remove_child(child)
		child.queue_free()
	_cost_row.size = Vector2(28, 0)
	var badge_side := minf(28.0, floorf((192.0 - maxf(0, cost.size() - 1) * 3.0) / maxf(1, cost.size())))
	for kind in cost:
		var badge := Panel.new()
		badge.name = "Cost_" + str(kind)
		badge.custom_minimum_size = Vector2(28, badge_side)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color("271c38")
		badge_style.set_corner_radius_all(7)
		badge.add_theme_stylebox_override("panel", badge_style)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cost_row.add_child(badge)
		var icon := PieceView.new()
		badge.add_child(icon)
		icon.configure({"kind": kind, "special": "", "axis": ""})
		var amount := Label.new()
		amount.text = str(int(cost[kind]))
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount.add_theme_font_size_override("font_size", mini(21, int(badge_side * 0.7)))
		amount.add_theme_color_override("font_color", Color("fff8e5"))
		amount.add_theme_color_override("font_outline_color", Color("0a101b"))
		amount.add_theme_constant_override("outline_size", 5)
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(amount)
		amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh_tooltip()
	queue_redraw()

func _fit_effect_text() -> void:
	# Keep long upgraded descriptions within the selected frame's fixed paper area.
	var font := _effect.get_theme_font("font")
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	for font_size in [11, 10, 9, 8]:
		var measured := font.get_multiline_string_size(_effect.text, HORIZONTAL_ALIGNMENT_LEFT, _effect.size.x, font_size, -1, flags)
		_effect.add_theme_font_size_override("font_size", font_size)
		if measured.y <= 44.0:
			break
	_effect.size.y = 44.0

func _description_text(entry: Dictionary) -> String:
	var source = _combat if _combat != null else _base_combat
	var values: Dictionary = source.card_values(card)
	var upgraded: bool = card.get("upgraded", false)
	var damage := int(values.damage)
	var block := int(values.block)
	match card.id:
		"c01", "c06", "g11":
			return "造成 %d 点伤害。" % damage
		"c02", "g05", "g10":
			return "获得 %d 格挡。" % block
		"c03":
			return "造成 %d 点伤害，然后获得 %d 格挡。" % [damage, block]
		"c04", "g04":
			return "造成 %d 点伤害。\n每张已出牌使伤害倍率 +0.25，最多计入 %d 张。" % [damage, 3 if card.id == "c04" else 4]
		"c05":
			var threshold := 4 if upgraded else 6
			var condition := "格挡条件已满足，加成已计入。" if source.guard >= threshold else "格挡 ≥%d 时额外增加 %d 点伤害。" % [threshold, source.attack()]
			return "造成 %d 点伤害。\n%s" % [damage, condition]
		"g01":
			return "本玩家回合攻击力 +%d，可叠加。" % int(values.attack_gain)
		"g02":
			return "本回合下一张伤害牌追加 %s 点伤害。" % str(values.extra_damage)
		"g03":
			return "造成 %d 点伤害。\n%s" % [damage, "连续出牌加成已计入。" if source.played >= 2 else "此前已出 ≥2 张牌时伤害翻倍。"]
		"g06":
			return "获得 %d 格挡；本回合下一张直接获得格挡的牌额外获得 %d 格挡。" % [block, 4 if upgraded else 3]
		"g07":
			return "消耗至多 %d 点当前格挡，造成 %d 点伤害。" % [12 if upgraded else 8, damage]
		"g08":
			return "获得 %d 格挡，然后造成 %d 点伤害。" % [block, damage]
		"g09":
			return "本回合下一张伤害牌无视敌人格挡，并追加 %s 点伤害。" % str(values.extra_damage)
		"g12":
			return "造成 %d 点伤害。\n%s" % [damage, "敌人无格挡，额外伤害已计入。" if source.enemy_guard == 0 else "敌人无格挡时额外造成 2 点伤害。"]
	var divider := full_text.find("\n\n")
	return full_text.substr(divider + 2) if divider >= 0 else str(entry.effect)

func _refresh_tooltip() -> void:
	tooltip_text = "" if available else unavailable_reason

func _draw() -> void:
	if paper_style:
		_draw_paper_card()
		return
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("17283b") if available else Color("18202e")
	frame.border_color = _accent if available else _accent.darkened(0.55)
	if _emphasized or has_focus():
		frame.border_color = _accent.lightened(0.35)
	frame.set_border_width_all(3 if _emphasized else 2)
	frame.set_corner_radius_all(5)
	frame.shadow_color = Color(0, 0, 0, 0.5)
	frame.shadow_size = 6
	frame.shadow_offset = Vector2(0, 3)
	draw_style_box(frame, Rect2(Vector2.ZERO, CARD_SIZE))
	draw_texture_rect(CARD_BACKGROUND, Rect2(Vector2(3, 3), CARD_SIZE - Vector2(6, 6)), false)
	# A translucent text panel keeps the original frame visible beneath long effects.
	draw_rect(Rect2(4, 100, 142, 106), Color(0.04, 0.07, 0.11, 0.72))
	draw_line(Vector2(10, 122), Vector2(140, 122), _accent.darkened(0.25), 1)

func _draw_paper_card() -> void:
	var frame := PaperArt.dark_style()
	frame.border_color = Color("ffe5a6") if _emphasized or has_focus() else PaperArt.GOLD
	frame.set_border_width_all(3 if _emphasized or has_focus() else 2)
	frame.shadow_size = 9 if _emphasized else 5
	# Native focus/hover outline surrounds the shared image skin, never its labels.
	draw_style_box(frame, Rect2(Vector2.ZERO, CARD_SIZE).grow(1 if _emphasized or has_focus() else 0))
	draw_texture_rect(PaperArt.card_art(str(card.get("id", "c01"))), Rect2(5, 26, 140, 109), false,
		Color.WHITE if available else Color(0.72, 0.70, 0.78))
	draw_texture_rect(CARD_FRAME, Rect2(Vector2.ZERO, CARD_SIZE), false)
	if _extended_costs:
		var rail := PaperArt.dark_style()
		rail.bg_color = Color("271c38")
		rail.set_border_width_all(1)
		rail.shadow_size = 0
		draw_style_box(rail, Rect2(4, 5, 33, 198))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		accept_event()
		pointer_pressed.emit(uid, get_global_mouse_position())
	elif event is InputEventKey and event.is_action_pressed("ui_accept") and not event.echo:
		accept_event()
		activation_requested.emit(uid)
