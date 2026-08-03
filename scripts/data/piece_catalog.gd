extends Node
class_name PieceCatalog

const BossDefinitionScript := preload("res://scripts/data/boss_definition.gd")
const CollectibleDefinitionScript := preload("res://scripts/data/collectible_definition.gd")
const PIECES_DIR := "res://data/pieces"
const EFFECTS_DIR := "res://data/effects"
const TABLES_DIR := "res://data/tables"
const PIECES_TABLE := TABLES_DIR + "/pieces.csv"
const BOSSES_TABLE := TABLES_DIR + "/bosses.csv"
const COLLECTIBLES_TABLE := TABLES_DIR + "/collectibles.csv"

var pieces: Dictionary = {}
var effects: Dictionary = {}
var bosses: Dictionary = {}
var collectibles: Dictionary = {}
var default_roster: PackedStringArray = PackedStringArray(["diffraction_phoebe", "annihilation_chisaki", "condensation_coletta", "aero_sigrika", "thermal_emis", "conductive_kakaro"])
var hidden_piece_ids: PackedStringArray = PackedStringArray(["diffraction_base", "annihilation_base", "condensation_base", "aero_base", "thermal_base", "conductive_base"])

func load_all() -> void:
	pieces = _load_resource_dir(PIECES_DIR, "piece")
	effects = _load_resource_dir(EFFECTS_DIR, "effect")
	bosses = {}
	collectibles = {}
	_load_piece_table()
	_load_boss_table()
	_load_collectible_table()
	_ensure_default_effects()
	_ensure_default_pieces()
	_ensure_default_bosses()
	_ensure_default_collectibles()

func get_piece(id: String) -> PieceDefinition:
	return pieces.get(id)

func get_effect(id: String) -> SpecialEffectDefinition:
	return effects.get(id)

func get_boss(id: String) -> Resource:
	return bosses.get(id)

func get_default_boss() -> Resource:
	if bosses.has("tuanzi_demon_king"):
		return bosses["tuanzi_demon_king"]
	if bosses.is_empty():
		return null
	var ids: Array = bosses.keys()
	ids.sort()
	return bosses[ids[0]]

func get_collectible(id: String) -> Resource:
	return collectibles.get(id)

func get_collectibles_by_min_rarity(min_rarity: String = "common") -> Array:
	var result: Array = []
	var min_rank: int = rarity_rank(min_rarity)
	for collectible in collectibles.values():
		if rarity_rank(collectible.rarity) >= min_rank:
			result.append(collectible)
	result.sort_custom(func(a: Resource, b: Resource) -> bool: return String(a.get("id")) < String(b.get("id")))
	return result

func rarity_rank(rarity: String) -> int:
	match rarity:
		"rare":
			return 2
		"epic":
			return 3
	return 1

func is_piece_hidden(id: String) -> bool:
	return hidden_piece_ids.has(id)

func get_unlocked_pieces(unlocked_ids: PackedStringArray = PackedStringArray()) -> Array:
	var result: Array = []
	for piece: PieceDefinition in pieces.values():
		if is_piece_hidden(piece.id):
			continue
		if piece.unlocked_by_default or unlocked_ids.has(piece.id):
			result.append(piece)
	result.sort_custom(func(a: PieceDefinition, b: PieceDefinition) -> bool:
		if a.sort_order == b.sort_order:
			return a.id < b.id
		return a.sort_order < b.sort_order
	)
	return result

func get_default_roster() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for id in default_roster:
		if pieces.has(id):
			result.append(id)
	return result

func _ensure_default_effects() -> void:
	if not effects.is_empty():
		return
	_add_effect("none", "无效果", "area", 0, "none", 0, "无", Color(0.8, 0.8, 0.8, 1))
	_add_effect("stripe", "条纹", "line", 0, "auto", 100, "条", Color(1, 0.9, 0.25, 1))
	_add_effect("bomb", "炸弹", "area", 1, "none", 120, "爆", Color(1, 0.35, 0.2, 1))
	_add_effect("rainbow", "彩虹", "color_clear", 0, "none", 150, "彩", Color(0.9, 0.35, 1, 1))

func _ensure_default_pieces() -> void:
	if not pieces.is_empty():
		return
	_add_piece("diffraction_base", "衍射团子", "衍射", "res://assets/pieces/diffraction_base.png", "res://assets/pieces/selected/diffraction_base_selected.png", 30, "", {}, "common", "衍射属性团子。大招：无效果占位。", true, 100)
	_add_piece("annihilation_base", "湮灭团子", "湮灭", "res://assets/pieces/annihilation_base.png", "res://assets/pieces/selected/annihilation_base_selected.png", 45, "", {}, "common", "湮灭属性团子。大招：无效果占位。", true, 101)
	_add_piece("condensation_base", "冷凝团子", "冷凝", "res://assets/pieces/condensation_base.png", "res://assets/pieces/selected/condensation_base_selected.png", 35, "", {}, "common", "冷凝属性团子。大招：无效果占位。", true, 102)
	_add_piece("aero_base", "气动团子", "气动", "res://assets/pieces/aero_base.png", "res://assets/pieces/selected/aero_base_selected.png", 40, "", {}, "common", "气动属性团子。大招：无效果占位。", true, 103)
	_add_piece("thermal_base", "热熔团子", "热熔", "res://assets/pieces/thermal_base.png", "res://assets/pieces/selected/thermal_base_selected.png", 35, "", {}, "common", "热熔属性团子。大招：无效果占位。", true, 104)
	_add_piece("conductive_base", "导电团子", "导电", "res://assets/pieces/conductive_base.png", "res://assets/pieces/selected/conductive_base_selected.png", 50, "", {}, "common", "导电属性团子。大招：无效果占位。", true, 105)

func _ensure_default_bosses() -> void:
	if not bosses.is_empty():
		return
	_add_boss("tuanzi_demon_king", "团子大魔王", 300, "", "boss_random_interference", {"lock_large": 3, "lock_small": 1, "lock_resonance": 10, "break_resonance": 6, "small_resonance": 5}, 3, 0.30, "默认大魔王。")

func _ensure_default_collectibles() -> void:
	if not collectibles.is_empty():
		return
	_add_collectible("score_charm", "计分贝壳", "", "score_mult", {"value": 0.12}, "common", "获得分数提高 12%。", 10, 1, 0)
	_add_collectible("sharp_pearl", "锐光珍珠", "", "damage_mult", {"value": 0.15}, "common", "对 Boss 造成的伤害提高 15%。", 10, 1, 0)
	_add_collectible("warm_tide", "暖潮瓶", "", "start_resonance", {"value": 5}, "common", "每场战斗开始时，所有共鸣槽获得 5 点。", 10, 1, 0)
	_add_collectible("echo_shell", "回声螺", "", "resonance_mult", {"value": 0.25}, "rare", "所有共鸣获取提高 25%。", 16, 1, 0)
	_add_collectible("merchant_badge", "商队徽章", "", "shop_discount", {"value": 0.25}, "rare", "商城价格降低 25%。", 16, 1, 0)
	_add_collectible("safe_anchor", "稳泊锚", "", "heal_after_battle", {"value": 1}, "rare", "每场战斗胜利后恢复 1 点生命。", 16, 1, 0)
	_add_collectible("crown_conch", "冠冕海螺", "", "damage_mult", {"value": 0.35}, "epic", "对 Boss 造成的伤害提高 35%。", 24, 1, 0)

func _add_piece(id: String, display_name: String, attribute: String, icon_path: String, selected_icon_path: String, resonance_cost: int, resonance_effect_id: String, resonance_effect_params: Dictionary, rarity: String, description: String, unlocked_by_default: bool, sort_order: int) -> void:
	var piece: PieceDefinition = PieceDefinition.new()
	piece.id = id
	piece.display_name = display_name
	piece.icon_texture = _load_texture(icon_path)
	piece.selected_icon_texture = _load_texture(selected_icon_path)
	piece.theme_color = _color_for_attribute(attribute)
	piece.multiplier = 1.0
	piece.rarity = rarity
	piece.description = description
	piece.default_special_effect_id = ""
	piece.unlocked_by_default = unlocked_by_default
	piece.tags = PackedStringArray([attribute]) if not attribute.is_empty() else PackedStringArray()
	piece.resonance_cost = resonance_cost
	piece.resonance_effect_id = resonance_effect_id
	piece.resonance_effect_params = resonance_effect_params
	piece.sort_order = sort_order
	pieces[id] = piece

func _add_effect(id: String, display_name: String, effect_type: String, radius: int, direction_strategy: String, base_score: int, marker: String, marker_color: Color) -> void:
	var effect: SpecialEffectDefinition = SpecialEffectDefinition.new()
	effect.id = id
	effect.display_name = display_name
	effect.effect_type = effect_type
	effect.radius = radius
	effect.direction_strategy = direction_strategy
	effect.base_score = base_score
	effect.marker = marker
	effect.marker_color = marker_color
	effects[id] = effect

func _add_boss(id: String, display_name: String, max_hp: int, texture_path: String, skill_effect_id: String, skill_effect_params: Dictionary, skill_interval: int, skill_chance: float, description: String) -> void:
	var boss: Resource = BossDefinitionScript.new()
	boss.id = id
	boss.display_name = display_name
	boss.max_hp = max_hp
	boss.texture = _load_texture(texture_path)
	boss.skill_effect_id = skill_effect_id
	boss.skill_effect_params = skill_effect_params
	boss.skill_interval = skill_interval
	boss.skill_chance = skill_chance
	boss.description = description
	bosses[id] = boss

func _add_collectible(id: String, display_name: String, texture_path: String, effect_id: String, effect_params: Dictionary, rarity: String, description: String, shop_price: int, pool_weight: int, max_stack: int) -> void:
	var collectible: Resource = CollectibleDefinitionScript.new()
	collectible.id = id
	collectible.display_name = display_name
	collectible.texture = _load_texture(texture_path)
	collectible.effect_id = effect_id
	collectible.effect_params = effect_params
	collectible.rarity = rarity
	collectible.description = description
	collectible.shop_price = shop_price
	collectible.pool_weight = pool_weight
	collectible.max_stack = max_stack
	collectibles[id] = collectible

func _load_resource_dir(path: String, expected_kind: String) -> Dictionary:
	var loaded: Dictionary = {}
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_warning("Could not open resource dir: %s" % path)
		return loaded
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = ResourceLoader.load(path.path_join(file_name))
			if res != null and res.get("id") != null and not String(res.get("id")).is_empty():
				if expected_kind == "piece" and res is PieceDefinition:
					loaded[String(res.get("id"))] = res
				elif expected_kind == "effect" and res is SpecialEffectDefinition:
					loaded[String(res.get("id"))] = res
		file_name = dir.get_next()
	dir.list_dir_end()
	return loaded

func _load_piece_table() -> void:
	for row in _load_csv_table(PIECES_TABLE):
		var id: String = String(row.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		var attribute: String = String(row.get("attribute", ""))
		_add_piece(
			id,
			String(row.get("name", "")),
			attribute,
			String(row.get("normal_texture", "")),
			String(row.get("clicked_texture", "")),
			_parse_int(row.get("resonance_cost", "30"), 30),
			String(row.get("resonance_effect_id", "")),
			_parse_json_object(String(row.get("resonance_effect_params", ""))),
			String(row.get("rarity", "common")),
			String(row.get("description", "")),
			_parse_bool(String(row.get("unlocked_by_default", "true")), true),
			_parse_int(row.get("sort_order", "0"), 0)
		)

func _load_boss_table() -> void:
	for row in _load_csv_table(BOSSES_TABLE):
		var id: String = String(row.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		_add_boss(
			id,
			String(row.get("name", "")),
			_parse_int(row.get("hp", "300"), 300),
			String(row.get("texture", "")),
			String(row.get("skill_effect_id", "")),
			_parse_json_object(String(row.get("skill_effect_params", ""))),
			max(1, _parse_int(row.get("skill_interval", "3"), 3)),
			clamp(_parse_float(row.get("skill_chance", "0.3"), 0.3), 0.0, 1.0),
			String(row.get("description", ""))
		)

func _load_collectible_table() -> void:
	for row in _load_csv_table(COLLECTIBLES_TABLE):
		var id: String = String(row.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		_add_collectible(
			id,
			String(row.get("name", "")),
			String(row.get("texture", "")),
			String(row.get("effect_id", "")),
			_parse_json_object(String(row.get("effect_params", ""))),
			String(row.get("rarity", "common")),
			String(row.get("description", "")),
			_parse_int(row.get("shop_price", "10"), 10),
			max(1, _parse_int(row.get("pool_weight", "1"), 1)),
			max(0, _parse_int(row.get("max_stack", "0"), 0))
		)

func _load_csv_table(path: String) -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(path):
		return rows
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open CSV table: %s" % path)
		return rows
	if file.eof_reached():
		return rows
	var headers: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var values: PackedStringArray = file.get_csv_line()
		if values.size() == 0:
			continue
		var empty: bool = true
		for value in values:
			if not String(value).strip_edges().is_empty():
				empty = false
				break
		if empty:
			continue
		var row: Dictionary = {}
		for index in range(headers.size()):
			row[String(headers[index]).strip_edges()] = String(values[index]).strip_edges() if index < values.size() else ""
		rows.append(row)
	return rows

func _load_texture(path: String) -> Texture2D:
	path = path.strip_edges()
	if path.is_empty():
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource == null or not (resource is Texture2D):
		push_warning("Could not load texture from table: %s" % path)
		return null
	return resource

func _parse_json_object(text: String) -> Dictionary:
	text = text.strip_edges()
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("Expected JSON object in table params, got: %s" % text)
	return {}

func _parse_bool(text: String, default_value: bool) -> bool:
	match text.strip_edges().to_lower():
		"true", "1", "yes", "y", "是":
			return true
		"false", "0", "no", "n", "否":
			return false
	return default_value

func _parse_int(value: Variant, default_value: int) -> int:
	var text: String = String(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	return default_value

func _parse_float(value: Variant, default_value: float) -> float:
	var text: String = String(value).strip_edges()
	if text.is_valid_float():
		return float(text)
	return default_value

func _color_for_attribute(attribute: String) -> Color:
	match attribute:
		"衍射":
			return Color(0.45, 0.75, 1, 1)
		"湮灭":
			return Color(0.7, 0.35, 1, 1)
		"冷凝":
			return Color(0.35, 0.9, 1, 1)
		"气动":
			return Color(0.6, 1, 0.55, 1)
		"热熔":
			return Color(1, 0.38, 0.18, 1)
		"导电":
			return Color(1, 0.9, 0.18, 1)
	return Color.WHITE
