extends Node
class_name PieceCatalog

const PIECES_DIR := "res://data/pieces"
const EFFECTS_DIR := "res://data/effects"

var pieces: Dictionary = {}
var effects: Dictionary = {}
var default_roster: PackedStringArray = PackedStringArray(["diffraction_phoebe", "annihilation_chisaki", "condensation_coletta", "aero_sigrika", "thermal_emis", "conductive_kakaro"])
var hidden_piece_ids: PackedStringArray = PackedStringArray(["diffraction_base", "annihilation_base", "condensation_base", "aero_base", "thermal_base", "conductive_base"])

func load_all() -> void:
	pieces = _load_resource_dir(PIECES_DIR, "piece")
	effects = _load_resource_dir(EFFECTS_DIR, "effect")
	_ensure_default_effects()
	_ensure_default_pieces()

func get_piece(id: String) -> PieceDefinition:
	return pieces.get(id)

func get_effect(id: String) -> SpecialEffectDefinition:
	return effects.get(id)

func is_piece_hidden(id: String) -> bool:
	return hidden_piece_ids.has(id)

func get_unlocked_pieces(unlocked_ids: PackedStringArray = PackedStringArray()) -> Array:
	var result: Array = []
	for piece: PieceDefinition in pieces.values():
		if is_piece_hidden(piece.id):
			continue
		if piece.unlocked_by_default or unlocked_ids.has(piece.id):
			result.append(piece)
	result.sort_custom(func(a: PieceDefinition, b: PieceDefinition) -> bool: return a.id < b.id)
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
	_add_effect("stripe", "条纹", "line", 0, "auto", 100, "⇄", Color(1, 0.9, 0.25, 1))
	_add_effect("bomb", "炸弹", "area", 1, "none", 120, "爆", Color(1, 0.35, 0.2, 1))
	_add_effect("rainbow", "彩虹", "color_clear", 0, "none", 150, "彩", Color(0.9, 0.35, 1, 1))

func _ensure_default_pieces() -> void:
	if not pieces.is_empty():
		return
	_add_piece("diffraction_base", "衍射团子", Color(0.45, 0.75, 1, 1), 1.0, "common", "衍射属性团子。大招：无效果占位。", "none", PackedStringArray(["衍射"]))
	_add_piece("annihilation_base", "湮灭团子", Color(0.7, 0.35, 1, 1), 1.0, "common", "湮灭属性团子。大招：无效果占位。", "none", PackedStringArray(["湮灭"]))
	_add_piece("condensation_base", "冷凝团子", Color(0.35, 0.9, 1, 1), 1.0, "common", "冷凝属性团子。大招：无效果占位。", "none", PackedStringArray(["冷凝"]))
	_add_piece("aero_base", "气动团子", Color(0.6, 1, 0.55, 1), 1.0, "common", "气动属性团子。大招：无效果占位。", "none", PackedStringArray(["气动"]))
	_add_piece("thermal_base", "热熔团子", Color(1, 0.38, 0.18, 1), 1.0, "common", "热熔属性团子。大招：无效果占位。", "none", PackedStringArray(["热熔"]))
	_add_piece("conductive_base", "导电团子", Color(1, 0.9, 0.18, 1), 1.0, "common", "导电属性团子。大招：无效果占位。", "none", PackedStringArray(["导电"]))
	_add_piece("diffraction_phoebe", "菲比", Color(0.45, 0.75, 1, 1), 1.0, "common", "菲比。技能暂未设置。", "", PackedStringArray(["衍射"]))
	_add_piece("annihilation_chisaki", "千咲", Color(0.7, 0.35, 1, 1), 1.0, "common", "千咲。技能暂未设置。", "", PackedStringArray(["湮灭"]))
	_add_piece("condensation_coletta", "柯莱塔", Color(0.35, 0.9, 1, 1), 1.0, "common", "柯莱塔。技能暂未设置。", "", PackedStringArray(["冷凝"]))
	_add_piece("aero_sigrika", "西格莉卡", Color(0.6, 1, 0.55, 1), 1.0, "common", "西格莉卡。技能暂未设置。", "", PackedStringArray(["气动"]))
	_add_piece("thermal_emis", "爱弥斯", Color(1, 0.38, 0.18, 1), 1.0, "common", "爱弥斯。技能暂未设置。", "", PackedStringArray(["热熔"]))
	_add_piece("conductive_kakaro", "卡卡罗", Color(1, 0.9, 0.18, 1), 1.0, "common", "卡卡罗。技能暂未设置。", "", PackedStringArray(["导电"]))

func _add_piece(id: String, display_name: String, color: Color, multiplier: float, rarity: String, description: String, special_id: String, tags: PackedStringArray) -> void:
	var piece: PieceDefinition = PieceDefinition.new()
	piece.id = id
	piece.display_name = display_name
	piece.theme_color = color
	piece.multiplier = multiplier
	piece.rarity = rarity
	piece.description = description
	piece.default_special_effect_id = special_id
	piece.unlocked_by_default = true
	piece.tags = tags
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
