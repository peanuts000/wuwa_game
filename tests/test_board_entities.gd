extends SceneTree

const PieceCatalogScript := preload("res://scripts/data/piece_catalog.gd")
const BoardModelScript := preload("res://scripts/game/board_model.gd")

func _initialize() -> void:
	var catalog: PieceCatalog = PieceCatalogScript.new()
	catalog.load_all()
	var board: BoardModel = BoardModelScript.new()
	board.setup(catalog, catalog.get_default_roster())
	var echo: EchoDefinition = catalog.get_echo("sun_spirit_gold")
	assert(echo != null and echo.texture != null, "日灵声骸及贴图必须成功载入")
	var echo_cell: Dictionary = board.new_echo_cell(echo.id)
	board.set_cell(Vector2i(3, 3), echo_cell)
	assert(board.is_echo_cell(board.get_cell(Vector2i(3, 3))), "声骸格必须与团子格区分")
	assert(board.is_immovable(Vector2i(3, 3)), "日灵不能交换")
	assert(not board.can_match_cell(Vector2i(3, 3)), "日灵不能参与匹配")
	assert(board.set_effect_stacks(Vector2i(3, 3), "photo", 3) == 0, "声骸不能附着团子状态")
	for y in range(BoardModel.HEIGHT):
		board.set_cell(Vector2i(0, y), null)
	board.set_cell(Vector2i(0, 0), board.new_echo_cell("sun_spirit_blue"))
	board.collapse_and_refill()
	assert(board.is_echo_cell(board.get_cell(Vector2i(0, BoardModel.HEIGHT - 1))), "日灵必须随重力下落")
	var rune_piece: Dictionary = board._new_cell("aero_sigrika")
	rune_piece["rune_id"] = "aero_rune_blue"
	board.set_cell(Vector2i(1, 0), rune_piece)
	board.swap(Vector2i(1, 0), Vector2i(1, 1))
	assert(String(board.get_cell(Vector2i(1, 1)).get("rune_id", "")) == "aero_rune_blue", "符文必须随团子实例移动")
	_test_transitive_match_merge(board)
	_test_unique_random_locks(board)
	print("board entity tests passed")
	quit(0)

func _test_transitive_match_merge(board: BoardModel) -> void:
	var matched_id := "diffraction_phoebe"
	var fillers: PackedStringArray = PackedStringArray([
		"annihilation_chisaki",
		"condensation_coletta",
		"aero_sigrika",
		"thermal_emis",
		"conductive_kakaro",
	])
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			board.cells[y][x] = board._new_cell(fillers[(x + 2 * y) % fillers.size()])
	for x in range(4):
		board.cells[1][x]["piece_id"] = matched_id
		board.cells[3][x]["piece_id"] = matched_id
	for y in range(1, 4):
		board.cells[y][1]["piece_id"] = matched_id
	var matches: Array = board.find_matches()
	assert(matches.size() == 1, "通过后续竖线相连的两条横线必须合并成一个匹配组")
	assert(matches[0]["positions"].size() == 9, "传递合并后的匹配组必须包含全部九个唯一位置")
	assert(matches[0]["directions"].size() == 3, "合并组必须保留两条横线和一条竖线的方向信息")

func _test_unique_random_locks(board: BoardModel) -> void:
	for row in board.cells:
		for cell in row:
			cell["locked_turns"] = 0
	board.rng.seed = 8
	assert(board.lock_random_cells(3) == 3, "存在足够候选时应锁定三个不同格子")
	var locked_count: int = 0
	for row in board.cells:
		for cell in row:
			if int(cell["locked_turns"]) > 0:
				locked_count += 1
	assert(locked_count == 3, "随机锁格不得重复命中同一格")
	assert(board.lock_random_cells(100) == BoardModel.WIDTH * BoardModel.HEIGHT - 3, "锁格数量应受剩余候选数量限制")
