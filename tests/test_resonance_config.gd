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
		if piece.id != "diffraction_phoebe" and piece.id != "annihilation_chisaki" and piece.id != "aero_sigrika":
			assert(piece.passive_skill_id.is_empty(), "%s 的被动技能当前应为空" % piece.id)
			assert(piece.passive_skill_params.is_empty(), "%s 的被动技能参数当前应为空" % piece.id)
	var phoebe: PieceDefinition = catalog.get_piece("diffraction_phoebe")
	assert(phoebe != null, "缺少菲比配置")
	assert(phoebe.passive_skill_id == "photo_adjacent_on_clear", "菲比应在消除时向相邻团子施加光燥")
	assert(phoebe.resonance_gain_id == "apply_effect_attempt", "菲比应按光燥施加尝试获取能量")
	assert(phoebe.resonance_effect_id == "spread_photo", "菲比共鸣解放应扩散光燥")
	assert(phoebe.resonance_gain_description == "施加光燥层数", "菲比应载入光燥能量获取说明")
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
	var chisaki: PieceDefinition = catalog.get_piece("annihilation_chisaki")
	assert(chisaki != null, "缺少千咲配置")
	assert(chisaki.resonance_cost == 45, "千咲共鸣上限应为 45")
	assert(chisaki.resonance_effect_id == "redirect_piece_effects", "千咲应启用五行动效应转移")
	assert(int(chisaki.resonance_effect_params.get("action_count", 0)) == 5, "千咲共鸣状态应持续五次行动")
	assert(chisaki.resonance_gain_id == "apply_boss_effect_attempt", "千咲应按向大魔王施效的尝试层数充能")
	assert(chisaki.passive_skill_id == "boss_effect_limit_bonus", "千咲应提高大魔王效应上限")
	var sigrika: PieceDefinition = catalog.get_piece("aero_sigrika")
	assert(sigrika != null and sigrika.resonance_cost == 4, "西格莉卡共鸣上限应为 4")
	assert(sigrika.resonance_gain_id == "clear_rune", "西格莉卡应由符文团子充能")
	assert(sigrika.passive_skill_id == "maintain_runes", "西格莉卡应维持场上符文")
	assert(sigrika.resonance_effect_id == "clear_piece_area" and int(sigrika.resonance_effect_params.get("radius", 0)) == 2, "西格莉卡应清除自选5×5团子范围")
	for echo_id in ["sun_spirit_gold", "sun_spirit_blue"]:
		var echo: EchoDefinition = catalog.get_echo(echo_id)
		assert(echo != null and echo.click_effect_id == "clear_area_and_convert_energy", "%s 声骸配置缺失" % echo_id)
		assert(not echo.can_swap and echo.affected_by_gravity and not echo.can_match, "%s 棋盘行为配置错误" % echo_id)
	var emis: PieceDefinition = catalog.get_piece("thermal_emis")
	assert(emis != null and emis.resonance_cost == 40, "爱弥斯共鸣上限应为40")
	assert(emis.resonance_gain_id == "clear_self_star", "爱弥斯应按自身消除累计星能")
	assert(emis.resonance_effect_id == "clear_center_piece_area" and int(emis.resonance_effect_params.get("size", 0)) == 6, "爱弥斯应固定清除中央6×6范围")
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
	assert(game.resonance_values[0] == 4, "顶部连续消除三个菲比应按四次有效相邻施加获得 4 点共鸣")
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
	_test_phoebe_runtime(game)
	_test_kakaro_runtime(game)
	_test_chisaki_runtime(game)
	_test_sigrika_runtime(game)
	_test_emis_runtime(game)
	game.free()

func _test_emis_runtime(game: Control) -> void:
	var slot_index: int = 4
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			game.board.cells[y][x] = game.board._new_cell("thermal_emis")
	game.resonance_values[slot_index] = 0
	game.emis_pending_random_lines = 0
	game._add_emis_progress(slot_index, 9)
	assert(game.resonance_values[slot_index] == 9 and game.emis_pending_random_lines == 0, "爱弥斯9点时不应获得星或触发清线")
	game._add_emis_progress(slot_index, 1)
	assert(game.resonance_values[slot_index] == 10 and game.emis_pending_random_lines == 0, "爱弥斯10点应获得第一颗星并重置波形")
	game._add_emis_progress(slot_index, 10)
	assert(game.resonance_values[slot_index] == 20 and game.emis_pending_random_lines == 1, "爱弥斯第二颗星应排队一次随机清线")
	game._add_emis_progress(slot_index, 10)
	assert(game.resonance_values[slot_index] == 30 and game.emis_pending_random_lines == 1, "爱弥斯第三颗星不应额外排队清线")
	game._add_emis_progress(slot_index, 10)
	assert(game.resonance_values[slot_index] == 40 and game.emis_pending_random_lines == 2, "爱弥斯第四颗星应再排队一次清线")
	assert(game._is_resonance_ready(slot_index), "爱弥斯四星时应可释放共鸣解放")
	assert(game._center_piece_targets(6).size() == 36, "爱弥斯中央6×6应包含36个团子")
	game.board.set_cell(Vector2i(1, 1), game.board.new_echo_cell("sun_spirit_gold"))
	assert(game._center_piece_targets(6).size() == 35, "爱弥斯中央6×6不能清除声骸")
	assert(game._emis_line_piece_targets(true, 1).size() == 7, "爱弥斯随机横行只能选择团子")
	var ready_bar: Control = game._make_emis_resonance_bar(slot_index, 156.0)
	assert(ready_bar.get_child_count() == 1, "爱弥斯四星时应使用完整满能素材")
	ready_bar.free()
	game.resonance_values[slot_index] = 39
	var progress_bar: Control = game._make_emis_resonance_bar(slot_index, 156.0)
	assert(progress_bar.get_child_count() == 2, "爱弥斯39点时应同时显示波形与三星背景")
	progress_bar.free()
	game.emis_pending_random_lines = 0

func _test_sigrika_runtime(game: Control) -> void:
	var slot_index: int = 3
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			game.board.cells[y][x] = game.board._new_cell(game.current_roster[(x + y) % game.current_roster.size()])
	game.resonance_values[slot_index] = 0
	game.sigrika_special_energy = 0
	game.sigrika_pending_sun_spirits = 0
	game._maintain_sigrika_runes()
	var rune_counts := {"aero_rune_blue": 0, "aero_rune_gold": 0}
	var rune_targets: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var cell: Dictionary = game.board.cells[y][x]
			var rune_id: String = String(cell.get("rune_id", ""))
			if rune_counts.has(rune_id):
				rune_counts[rune_id] = int(rune_counts[rune_id]) + 1
				if rune_targets.size() < 2:
					rune_targets.append(Vector2i(x, y))
	assert(rune_counts["aero_rune_blue"] == 4 and rune_counts["aero_rune_gold"] == 4, "西格莉卡应维持两种符文各四个")
	game._charge_sigrika_for_cleared_runes(rune_targets)
	assert(game.resonance_values[slot_index] == 2 and game.sigrika_pending_sun_spirits == 1, "清除两个符文应获得两格普通能量并排队一个日灵")
	game._maintain_sigrika_board_state()
	assert(game._sigrika_sun_spirit_positions().size() == 1, "越过两格阈值后应生成一个日灵")
	var echo_pos: Vector2i = game._sigrika_sun_spirit_positions()[0]
	assert(game.board.is_immovable(echo_pos) and not game.board.can_match_cell(echo_pos), "日灵不能交换或参与匹配")
	assert(game._piece_targets_in_square(echo_pos, 1).size() <= 8, "日灵3×3范围只能返回团子，不应包含中心声骸")
	game.sigrika_special_energy = 2
	game.resonance_values[slot_index] = 2
	game._add_resonance(slot_index, 5, "共享上限测试")
	assert(game.resonance_values[slot_index] == 2, "普通与特殊能量合计不得超过四格")
	var animated_bar: Control = game._make_sigrika_resonance_bar(slot_index, 156.0)
	assert(animated_bar.get_child_count() == 2, "普通与特殊能量层都应创建动态纹理")
	animated_bar.free()
	game.sigrika_special_energy = 4
	game.resonance_values[slot_index] = 0
	assert(game._is_resonance_ready(slot_index), "四格特殊能量时西格莉卡应可释放")
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			game.board.cells[y][x] = game.board._new_cell(game.current_roster[(x + y) % game.current_roster.size()])
	assert(game._piece_targets_in_square(Vector2i(3, 3), 2).size() == 25, "棋盘内圈5×5应包含25个团子")
	game.board.set_cell(Vector2i(3, 3), game.board.new_echo_cell("sun_spirit_gold"))
	assert(game._piece_targets_in_square(Vector2i(3, 3), 2).size() == 24, "西格莉卡5×5范围必须保留声骸")
	assert(game._piece_targets_in_square(Vector2i(0, 0), 2).size() == 9, "角落5×5范围应正确裁剪")

func _test_chisaki_runtime(game: Control) -> void:
	var chisaki_slot: int = 1
	var chisaki: PieceDefinition = game.catalog.get_piece("annihilation_chisaki")
	game.chisaki_release_active = false
	game.chisaki_releases_remaining = 0
	game.boss_effects = {}
	game.resonance_values[chisaki_slot] = 0
	game._add_player_boss_effect_stacks("photo", 50)
	assert(game.resonance_values[chisaki_slot] == 45, "千咲应按尝试层数充能并封顶 45 点")
	assert(game._boss_effect_stacks("photo") == 13, "大魔王光燥应使用千咲强化后的 13 层上限")
	assert(game._boss_effect_limit("frost") == 3, "千咲不能提高霜渐上限")
	game.resonance_values[chisaki_slot] = 45
	assert(game._is_resonance_ready(chisaki_slot), "千咲必须充满后才能启动共鸣状态")
	assert(game._release_redirect_piece_effects(chisaki.resonance_effect_params), "千咲满能后应能启动效应转移")
	game.resonance_values[chisaki_slot] = 0
	game.player_action_in_progress = true
	var target := Vector2i(0, 0)
	game.board.set_effect_stacks(target, "photo", 0)
	assert(game._add_player_piece_effect_stacks(target, "photo", 2), "状态期间新增团子效应应被转移")
	assert(game.board.effect_stacks(game.board.get_cell(target), "photo") == 0, "被转移的效应不能留在团子上")
	assert(game.resonance_values[chisaki_slot] == 0, "效应转移状态期间千咲应暂停充能")
	game._settle_chisaki_action_duration()
	assert(game.chisaki_releases_remaining == 5, "启动点击不能计入五次行动")
	for expected_remaining in [4, 3, 2, 1, 0]:
		game._settle_chisaki_action_duration()
		assert(game.chisaki_releases_remaining == expected_remaining, "千咲状态行动次数扣除错误")
	assert(not game.chisaki_release_active, "第五次行动结算后千咲状态应结束")
	game.player_action_in_progress = false

func _test_phoebe_runtime(game: Control) -> void:
	var phoebe_slot: int = 0
	for test_value in [0, 1, 15, 29, 30]:
		game.resonance_values[phoebe_slot] = test_value
		var bar: Control = game._make_phoebe_resonance_bar(phoebe_slot, 156.0)
		var expected_layers: int = 1 if test_value == 0 else 2
		assert(bar.get_child_count() == expected_layers, "菲比%d点时共鸣条图层数量错误" % test_value)
		if test_value == 30:
			var ready_wave: TextureRect = bar.get_child(1) as TextureRect
			assert(ready_wave != null and ready_wave.material is ShaderMaterial, "菲比满能时应显示动态蓝白波形")
		elif test_value > 0:
			var progress_clip: Control = bar.get_child(1) as Control
			assert(progress_clip != null and progress_clip.clip_contents, "菲比未满时应裁切金色波形进度")
		bar.free()
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			game.board.cells[y][x]["effects"] = {}
	game.resonance_values[phoebe_slot] = 0
	var first := Vector2i(1, 1)
	var second := Vector2i(3, 1)
	var shared_target := Vector2i(2, 1)
	game.board.cells[first.y][first.x]["piece_id"] = "diffraction_phoebe"
	game.board.cells[second.y][second.x]["piece_id"] = "diffraction_phoebe"
	game._apply_clear_passives([first, second])
	assert(game.board.effect_stacks(game.board.get_cell(shared_target), "photo") == 2, "两个菲比应分别向共同邻格施加光燥")
	assert(game.resonance_values[phoebe_slot] == 8, "两个内圈菲比应按八次施加尝试获得能量")
	game.board.set_effect_stacks(shared_target, "photo", 10)
	game.resonance_values[phoebe_slot] = 0
	game._apply_clear_passives([first, second])
	assert(game.board.effect_stacks(game.board.get_cell(shared_target), "photo") == 10, "光燥层数必须封顶 10")
	assert(game.resonance_values[phoebe_slot] == 8, "目标满层时仍应按施加尝试给菲比能量")
	game.board.set_effect_stacks(shared_target, "photo", 0)
	game.resonance_values[phoebe_slot] = 0
	game._apply_clear_passives([first, shared_target])
	assert(game.board.effect_stacks(game.board.get_cell(shared_target), "photo") == 0, "本次参与清除的邻格不能被添加光燥")
	assert(game._photo_spread_contribution(1) == 1 and game._photo_spread_contribution(2) == 1, "1/2 层来源都应扩散 1 层")
	assert(game._photo_spread_contribution(3) == 2 and game._photo_spread_contribution(4) == 2, "3/4 层来源都应扩散 2 层")
	assert(game._photo_spread_contribution(9) == 5 and game._photo_spread_contribution(10) == 5, "9/10 层来源都应扩散 5 层")
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			game.board.cells[y][x]["effects"] = {}
	game.resonance_values[phoebe_slot] = 0
	assert(not game._release_spread_photo({"effect_id": "photo"}), "场上没有光燥来源时共鸣解放必须失败")
	var weak_source := Vector2i(2, 2)
	var strong_source := Vector2i(4, 2)
	var spread_target := Vector2i(3, 2)
	var no_chain_target := Vector2i(3, 3)
	game.board.set_effect_stacks(weak_source, "photo", 3)
	game.board.set_effect_stacks(strong_source, "photo", 10)
	assert(game._release_spread_photo({"effect_id": "photo"}), "存在光燥来源时共鸣解放应成功")
	assert(game.board.effect_stacks(game.board.get_cell(spread_target), "photo") == 5, "多个来源应只取最大扩散层数")
	assert(game.board.effect_stacks(game.board.get_cell(no_chain_target), "photo") == 0, "同次释放新增的光燥不能继续传播")
	assert(game.resonance_values[phoebe_slot] == 0, "共鸣解放扩散不能为菲比返还能量")

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
