extends SceneTree

const PieceCatalogScript := preload("res://scripts/data/piece_catalog.gd")
const BoardModelScript := preload("res://scripts/game/board_model.gd")
const MainScript := preload("res://scripts/main.gd")

func _initialize() -> void:
	var catalog: PieceCatalog = PieceCatalogScript.new()
	catalog.load_all()
	var board: BoardModel = BoardModelScript.new()
	board.setup(catalog, catalog.get_default_roster())
	_test_piece_state(board)
	_test_match_immunity(board)
	_test_boss_runtime(catalog, board)
	print("status effect tests passed")
	quit(0)

func _test_piece_state(board: BoardModel) -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var original: Dictionary = board.get_cell(a)
	assert(board.add_effect_stacks(a, "conductive", 5) == 5)
	assert(board.add_effect_stacks(a, "conductive", 5) == 6, "stacks must clamp to the configured limit")
	board.swap(a, b)
	assert(board.get_cell(b) == original, "the complete piece instance must move during swaps")
	assert(board.effect_stacks(board.get_cell(b), "conductive") == 6, "effects must move with the piece instance")
	board.set_effect_stacks(b, "conductive", 0)
	assert(not board.get_cell(b).get("effects", {}).has("conductive"), "zero stacks should be removed")

func _test_match_immunity(board: BoardModel) -> void:
	for x in range(3):
		board.cells[0][x]["piece_id"] = "diffraction_phoebe"
	board.set_effect_stacks(Vector2i(1, 0), "annihilation", 6)
	assert(board.find_matches().is_empty(), "full annihilation must split match runs")
	assert(board.is_immovable(Vector2i(1, 0)), "full annihilation must be immovable")
	board.set_effect_stacks(Vector2i(1, 0), "annihilation", 0)
	assert(not board.find_matches().is_empty(), "the match should return after annihilation is removed")
	board.set_effect_stacks(Vector2i(1, 0), "frost", 3)
	assert(board.is_immovable(Vector2i(1, 0)), "full frost must be immovable")

func _test_boss_runtime(catalog: PieceCatalog, board: BoardModel) -> void:
	var game: Control = MainScript.new()
	game.catalog = catalog
	game.current_roster = catalog.get_default_roster()
	game.board = board
	game.current_boss = catalog.get_default_boss()
	game.boss_hp_infinite = false
	game.boss_hp = 100
	game.boss_max_hp = 100
	game._reset_boss_effects()
	var swap_matches: Array = [{"positions": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]}]
	assert(game._preferred_spawn_after_swap(swap_matches, Vector2i(3, 0), Vector2i(4, 0)) == Vector2i(3, 0), "the swapped piece that actually joins the match must become special")
	assert(game._preferred_spawn_after_swap(swap_matches, Vector2i(4, 0), Vector2i(3, 0)) == Vector2i(3, 0), "spawn selection must work regardless of click order")
	var pairs: Array = game._pair_conductive_sources([Vector2i(0, 0), Vector2i(5, 5), Vector2i(1, 0)])
	assert(pairs.size() == 1 and pairs[0] == [Vector2i(0, 0), Vector2i(1, 0)], "full electromagnetic pieces should pair with their nearest partner")
	assert(game._horizontal_then_vertical_path(Vector2i(0, 0), Vector2i(2, 1)) == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)], "electromagnetic movement should use a deterministic horizontal-first path")
	var attraction: Dictionary = game._electromagnetic_attraction(Vector2i(0, 0), Vector2i(4, 1))
	assert(attraction["first_destination"] == Vector2i(2, 0) and attraction["second_destination"] == Vector2i(3, 0), "attracted pieces must stop in the two adjacent middle cells")
	assert(attraction["cleared_path"] == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "only the cells crossed before the partner should be clear candidates")
	var first := Vector2i(0, 1)
	var second := Vector2i(1, 1)
	board.set_effect_stacks(first, "conductive", 4)
	board.set_effect_stacks(second, "conductive", 4)
	game._transfer_cleared_effects_to_boss([first, second])
	assert(game._boss_effect_stacks("conductive") == 8, "千咲在队时 Boss 导电应可超过原六层上限")
	board.set_effect_stacks(first, "frost", 3)
	assert(not game._filter_clear_targets([first]).has(first), "the first clear must thaw rather than remove a frozen piece")
	assert(board.effect_stacks(board.get_cell(first), "frost") == 0, "thawing must clear frost stacks")
	board.set_effect_stacks(first, "annihilation", 6)
	assert(not game._filter_clear_targets([first]).has(first), "normal clears must not remove full annihilation")
	assert(game._filter_clear_targets([first], true).has(first), "resonance clears must bypass annihilation immunity")
	board.set_effect_stacks(first, "annihilation", 0)
	game._set_boss_effect_stacks("annihilation", 6)
	assert(game._effective_boss_defense() == 18, "six annihilation stacks should reduce defense 20 by 12 percent")
	game._set_boss_effect_stacks("explosive", 10)
	assert(game.boss_hp == 100 and game._boss_effect_stacks("explosive") == 10, "千咲应将 Boss 聚爆触发点提高到 13")
	game._set_boss_effect_stacks("explosive", 13)
	assert(game.boss_hp == 70 and game._boss_effect_stacks("explosive") == 0, "full boss explosive must deal 30 and clear")
	game.boss_hp = 100
	game._set_boss_effect_stacks("photo", 2)
	game._set_boss_effect_stacks("aero", 3)
	game.run_active = true
	game.run_state = {"actions": 5, "collectibles": []}
	game._consume_run_action()
	assert(game._settle_player_action())
	assert(game.run_state["actions"] == 4, "one valid action must consume one run action")
	assert(game.boss_hp == 87, "photo must resolve before aero using the remaining current hp")
	assert(game._boss_effect_stacks("photo") == 1 and game._boss_effect_stacks("aero") == 2, "ongoing effects must decay once")
	game.free()
