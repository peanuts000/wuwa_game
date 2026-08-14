extends SceneTree

const PieceCatalogScript := preload("res://scripts/data/piece_catalog.gd")
const BoardModelScript := preload("res://scripts/game/board_model.gd")
const MainScript := preload("res://scripts/main.gd")

func _initialize() -> void:
	var catalog: PieceCatalog = PieceCatalogScript.new()
	catalog.load_all()
	assert(not catalog.pieces.is_empty(), "团子配置表不应为空")
	for piece: PieceDefinition in catalog.pieces.values():
		assert(piece.attack == 6, "%s attack should default to 6" % piece.id)
		assert(not piece.resonance_gain_id.is_empty(), "%s 缺少共鸣获取规则" % piece.id)
		assert(piece.passive_skill_id.is_empty(), "%s 的被动技能当前应为空" % piece.id)
		assert(piece.passive_skill_params.is_empty(), "%s 的被动技能参数当前应为空" % piece.id)
	var coletta: PieceDefinition = catalog.get_piece("condensation_coletta")
	assert(coletta != null, "缺少柯莱塔配置")
	assert(coletta.resonance_cost == 4, "柯莱塔共鸣上限应为 4")
	assert(coletta.resonance_effect_id == "clear_line", "柯莱塔应使用行列清除共鸣解放")
	assert(coletta.resonance_gain_id == "use_special", "柯莱塔应由使用特殊团子获取共鸣")
	assert(coletta.resonance_gain_description == "使用条纹特殊团子", "Coletta should load the localized resonance gain description")
	assert(String(coletta.resonance_gain_params.get("special_effect_id", "")) == "stripe", "柯莱塔应由条形团子充能")
	var kakaro: PieceDefinition = catalog.get_piece("conductive_kakaro")
	assert(kakaro != null, "缺少卡卡罗配置")
	assert(kakaro.resonance_cost == 30, "卡卡罗共鸣上限应为 30")
	assert(kakaro.resonance_effect_id == "clear_target_cross", "卡卡罗应使用定点十字共鸣解放")
	assert(int(kakaro.resonance_effect_params.get("release_count", 0)) == 5, "卡卡罗应有五次释放")
	assert(float(kakaro.resonance_effect_params.get("damage_multiplier", 0.0)) == 2.0, "卡卡罗十字伤害应翻倍")
	var boss: Resource = catalog.get_default_boss()
	assert(boss != null and boss.defense == 20, "default boss defense should be 20")
	_test_runtime_gain_rules(catalog)
	print("resonance config tests passed: %d pieces" % catalog.pieces.size())
	quit(0)

func _test_runtime_gain_rules(catalog: PieceCatalog) -> void:
	var game: Control = MainScript.new()
	game.catalog = catalog
	game.current_roster = catalog.get_default_roster()
	game.resonance_values.clear()
	for _index in range(6):
		game.resonance_values.append(0)
	game.board = BoardModelScript.new()
	game.board.setup(catalog, game.current_roster)
	game.current_boss = catalog.get_default_boss()
	for x in range(3):
		game.board.cells[0][x]["piece_id"] = "diffraction_phoebe"
	game._charge_resonance_for_cleared_targets([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert(game.resonance_values[0] == 3, "消除三个菲比团子应获得 3 点衍射共鸣")
	assert(game.resonance_values[2] == 0, "消除柯莱塔团子不应给柯莱塔充能")
	game._charge_special_resonance("diffraction_phoebe", "stripe", [])
	assert(game.resonance_values[2] == 1, "使用一个条形团子应给柯莱塔 1 点共鸣")
	assert(not game._is_resonance_ready(2), "柯莱塔未充满 4 点时不能释放")
	game._charge_special_resonance("diffraction_phoebe", "stripe", [])
	assert(game.resonance_values[2] == 2, "使用两个条形团子应分别计数")
	assert(not game._is_resonance_ready(2), "柯莱塔只有 2 点时不能释放")
	game._charge_special_resonance("diffraction_phoebe", "stripe", [])
	game._charge_special_resonance("diffraction_phoebe", "stripe", [])
	game._charge_special_resonance("diffraction_phoebe", "stripe", [])
	assert(game.resonance_values[2] == 4, "柯莱塔共鸣不能超过 4 点")
	assert(game._is_resonance_ready(2), "柯莱塔有剩余次数时应可释放")
	game.resonance_values[2] = 3
	assert(game._is_resonance_ready(2), "进入四段解放后剩余 3 次时应继续可释放")
	assert(game._targets_for_line(Vector2i(3, 4), "horizontal").size() == BoardModel.WIDTH, "横向释放应覆盖整行")
	assert(game._targets_for_line(Vector2i(3, 4), "vertical").size() == BoardModel.HEIGHT, "纵向释放应覆盖整列")
	_test_kakaro_runtime(game)
	game.free()

func _test_kakaro_runtime(game: Control) -> void:
	var kakaro_slot: int = 5
	game.resonance_values[kakaro_slot] = 29
	game.kakaro_release_active = false
	game.kakaro_releases_remaining = 0
	assert(not game._is_resonance_ready(kakaro_slot), "卡卡罗 29 点时不能释放")
	game._add_resonance(kakaro_slot, 1, "测试充满")
	assert(game._is_resonance_ready(kakaro_slot), "卡卡罗充满 30 点后应可释放")
	assert(game.kakaro_releases_remaining == 5, "卡卡罗充满后应获得五次释放")
	assert(is_equal_approx(game._kakaro_release_ratio(), 1.0), "卡卡罗五次释放时应显示完整波动条")
	game._add_resonance(kakaro_slot, 5, "激活期间不续充")
	assert(game.resonance_values[kakaro_slot] == 30 and game.kakaro_releases_remaining == 5, "五段释放期间不能补充或延长次数")
	assert(game._targets_for_small_cross(Vector2i(3, 3)).size() == 5, "棋盘内圈十字应清除五格")
	assert(game._targets_for_small_cross(Vector2i(0, 3)).size() == 4, "棋盘边缘十字应清除四格")
	assert(game._targets_for_small_cross(Vector2i(0, 0)).size() == 3, "棋盘角落十字应清除三格")
	for expected_remaining in [4, 3, 2, 1, 0]:
		game._consume_kakaro_release(kakaro_slot)
		assert(game.kakaro_releases_remaining == expected_remaining, "卡卡罗释放次数扣除错误")
		assert(is_equal_approx(game._kakaro_release_ratio(), float(expected_remaining) / 5.0), "卡卡罗波动条应随释放次数按五等分减少")
	assert(not game._is_resonance_ready(kakaro_slot), "卡卡罗五次释放完毕后不能继续释放")
	assert(game.resonance_values[kakaro_slot] == 0, "卡卡罗五次释放完毕后能量应归零")
	game.boss_hp_infinite = false
	game.boss_hp = 300
	game.run_active = false
	var cross_targets: Array = game._targets_for_small_cross(Vector2i(3, 3))
	game._damage_boss(cross_targets, 2.0)
	assert(game.boss_hp == 250, "five attack-6 pieces against defense 20 with 2x damage should deal 50")
	_test_damage_formula(game, cross_targets)

func _test_damage_formula(game: Control, targets: Array) -> void:
	assert(game._calculate_boss_damage([], 2.0) == 0, "empty targets should deal no damage")
	assert(game._calculate_boss_damage(targets.slice(0, 3)) == 15, "three attack-6 pieces against defense 20 should deal 15")
	var original_first_piece_id: String = String(game.board.get_cell(targets[0])["piece_id"])
	var original_second_piece_id: String = String(game.board.get_cell(targets[1])["piece_id"])
	var first_cell: Dictionary = game.board.get_cell(targets[0])
	var second_cell: Dictionary = game.board.get_cell(targets[1])
	first_cell["piece_id"] = "diffraction_phoebe"
	second_cell["piece_id"] = "annihilation_chisaki"
	var first_piece_id: String = "diffraction_phoebe"
	var second_piece_id: String = "annihilation_chisaki"
	var first_piece: PieceDefinition = game.catalog.get_piece(first_piece_id)
	var second_piece: PieceDefinition = game.catalog.get_piece(second_piece_id)
	var first_attack: int = first_piece.attack
	var second_attack: int = second_piece.attack
	first_piece.attack = 6
	second_piece.attack = 12
	assert(game._calculate_boss_damage([targets[0], targets[1]]) == 15, "mixed piece attacks should be calculated per cleared cell")
	first_piece.attack = -5
	assert(game._calculate_boss_damage([targets[0]]) == 0, "negative runtime attack should be clamped to zero")
	first_piece.attack = 12
	second_piece.attack = 12
	game.run_active = true
	game.run_state = {"collectibles": [{"effect_id": "damage_mult", "effect_params": {"value": 0.15}}]}
	assert(game._calculate_boss_damage([targets[0], targets[1]]) == 23, "collectible damage bonuses should multiply defended damage")
	game.run_active = false
	game.run_state = {}
	game.current_boss.defense = -10
	assert(game._calculate_boss_damage([targets[0]]) == 12, "negative runtime defense should be clamped to zero")
	game.current_boss.defense = 20
	first_piece.attack = first_attack
	second_piece.attack = second_attack
	first_cell["piece_id"] = original_first_piece_id
	second_cell["piece_id"] = original_second_piece_id
