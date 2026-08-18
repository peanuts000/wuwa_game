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
	print("board entity tests passed")
	quit(0)
