extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const CatalogScript := preload("res://scripts/data/piece_catalog.gd")
const BoardScript := preload("res://scripts/game/board_model.gd")

func _initialize() -> void:
	var game = MainScript.new()
	game.catalog = CatalogScript.new()
	game.catalog.load_all()
	game.board = BoardScript.new()
	game.board.setup(game.catalog, game.catalog.get_default_roster())
	var types := ["battle", "elite", "boss"]
	var hp := [120, 240, 420]
	var damage := [18, 16, 15]
	var intervals := [4, 3, 3]
	for i in range(3):
		var node := {"type": types[i], "floor": 1}
		game.current_boss = game._enemy_for_node(node)
		assert(game.current_boss.texture != null)
		assert(game._run_boss_hp_for_node(node) == hp[i])
		node["floor"] = 3
		assert(game._run_boss_hp_for_node(node) == roundi(hp[i] * 1.4))
		game.boss_hp = hp[i]
		game.boss_max_hp = hp[i]
		game.boss_hp_infinite = false
		assert(game._enemy_check_interval() == intervals[i])
		assert(game._calculate_boss_damage([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]) == damage[i])
		game._trigger_enemy_effect()
		assert(game._locked_cell_count() == (1 if i == 0 else 2))
		game.board.tick_locks()
		assert(game._locked_cell_count() == (1 if i == 0 else 2))
		game.board.setup(game.catalog, game.catalog.get_default_roster())
		game.boss_hp = 1
		assert(game._enemy_is_enraged() == (i == 2))
	game.combo = 8
	game._trigger_enemy_extra_skill()
	assert(game._locked_cell_count() == 3 and game.combo == 0)
	assert(game._enemy_check_interval() == 2)
	game.boss_hp_infinite = true
	assert(not game._enemy_is_enraged())
	assert(game._enemy_for_node({"type": "boss", "boss_id": "tuanzi_demon_king"}).id == "tuanzi_demon_king")
	# Verify behavior follows resource configuration, not a hard-coded boss ID.
	game.current_boss = game.catalog.get_boss("tuanzi_scout")
	game.current_boss.hp_growth_per_floor = 0.5
	assert(game._run_boss_hp_for_node({"type": "battle", "floor": 2}) == 180)
	game.current_boss.enrage_hp_ratio = 0.5
	game.current_boss.enrage_skill_interval = 5
	game.current_boss.enrage_skill_chance = 0.4
	game.current_boss.enrage_skill_effect_id = "lock_cells"
	game.current_boss.enrage_skill_effect_params = {"count": 4}
	game.boss_hp_infinite = false
	game.boss_max_hp = 120
	game.boss_hp = 60
	assert(game._enemy_is_enraged())
	assert(game._enemy_check_interval() == 5)
	assert(is_equal_approx(game._enemy_effect_chance(), 0.4))
	game.board.setup(game.catalog, game.catalog.get_default_roster())
	game.combo = 8
	game._trigger_enemy_extra_skill()
	assert(game._locked_cell_count() == 4 and game.combo == 8)
	game.boss_hp = 61
	assert(not game._enemy_is_enraged())
	game.free()
	print("enemy tier tests passed")
	quit()
