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
	var board = game.board
	var unlock_events: Array = []
	var thaw_events: Array = []
	board.cell_thawed.connect(func(pos: Vector2i) -> void: thaw_events.append(pos))
	board.cell_unlocked.connect(func(pos: Vector2i) -> void: unlock_events.append(pos))
	var center := Vector2i(3, 3)
	var right := center + Vector2i.RIGHT
	var original: Dictionary = board.get_cell(center)
	original["locked_turns"] = 1
	for i in range(10):
		board.tick_locks()
	assert(board.is_locked(center) and board.is_immovable(center))
	assert(not board.can_match_cell(center))
	assert(game._filter_clear_targets([center]).is_empty())
	assert(game._filter_clear_targets([center], true).is_empty(), "共鸣也不能直接消除锁定团子")
	board.clear_positions([center, center + Vector2i(1, 1)])
	assert(board.is_locked(center), "对角消除不能解锁")
	board.clear_positions([Vector2i(-1, 0), center + Vector2i(1, 1)])
	assert(board.is_locked(center), "空格和越界格不算消除")
	board.get_cell(right)["locked_turns"] = 1
	board.clear_positions([center, right])
	assert(board.is_locked(center) and board.is_locked(right), "锁定格不能互相解锁")
	board.clear_positions([center, right, center + Vector2i.LEFT])
	assert(unlock_events == [center], "每个实际解锁只触发一次破碎动画事件")
	assert(not board.is_locked(center) and board.get_cell(center) == original)
	assert(board.is_locked(right), "本批仅解锁的格子不能继续传播解锁")
	board.clear_positions([center])
	assert(board.get_cell(center) == null and not board.is_locked(right))
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		board.setup(game.catalog, game.catalog.get_default_roster())
		board.get_cell(center)["locked_turns"] = 1
		board.clear_positions([center + direction])
		assert(not board.is_locked(center))
	board.setup(game.catalog, game.catalog.get_default_roster())
	board.get_cell(center)["locked_turns"] = 1
	var frozen := center + Vector2i.UP
	board.set_effect_stacks(frozen, "frost", 3)
	board.clear_positions(game._filter_clear_targets([frozen], true))
	assert(thaw_events == [frozen], "破冰仅触发一次动画事件")
	board.set_effect_stacks(frozen, "frost", 0)
	assert(thaw_events.size() == 1, "重复清零不应重播破冰")
	board.set_effect_stacks(frozen, "frost", 2)
	board.set_effect_stacks(frozen, "frost", 0)
	assert(thaw_events.size() == 1, "未冻结时减少霜渐不播放破冰")
	assert(board.is_locked(center), "仅解除霜渐但未消除不能解锁邻居")
	game._release_cleanse_locks({})
	assert(board.is_locked(center), "旧净化入口不能绕过相邻消除规则")
	game.free()
	print("persistent lock tests passed")
	quit()
