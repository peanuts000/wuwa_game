extends Control

const PieceView = preload("res://scripts/v2/piece_view.gd")
const Catalog = preload("res://scripts/v2/catalog.gd")
const BOARD_SIZE := 8
# Keep the timing and easing of the original board in scripts/main.gd.
const SWAP_ANIM_SECONDS := 0.21
const CLEAR_ANIM_SECONDS := 0.34
const SPECIAL_CREATE_SECONDS := 0.13
const DROP_BASE_SECONDS := 0.18
const DROP_SECONDS_PER_ROW := 0.085
const DROP_COLUMN_STAGGER_SECONDS := 0.022
const DROP_SPAWN_DELAY_SECONDS := 0.06
const DROP_SPAWN_EXTRA_ROWS := 2
const DROP_SETTLE_SECONDS := 0.075
const POST_CLEAR_PAUSE_SECONDS := 0.02
const POST_DROP_PAUSE_SECONDS := 0.03
const CLEAR_DROP_OVERLAP_RATIO := 0.58

var visuals: Dictionary = {}
var fading_visuals: Array[Control] = []
var active := false
var _generation := 0
var _grid: Control
var _base_size := Vector2.ONE
var _slot_rects: Array[Rect2] = []
var _tweens: Array[Tween] = []

func configure(grid: Control, buttons: Array, cells: Array) -> void:
	name = "BoardAnimation"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	clip_contents = true
	_grid = grid
	_base_size = grid.size
	_base_size.x = maxf(1.0, _base_size.x)
	_base_size.y = maxf(1.0, _base_size.y)
	size = _base_size
	global_position = grid.global_position
	for button in buttons:
		_slot_rects.append(Rect2(button.global_position - grid.global_position, button.size))
	active = true
	for index in range(cells.size()):
		if cells[index] != null:
			_add_visual(cells[index], index)

func _process(_delta: float) -> void:
	# The hidden grid still lays out its buttons. Follow it during a window resize
	# without restarting an in-flight tween or sampling a fading piece's bounds.
	if active and is_instance_valid(_grid):
		global_position = _grid.global_position
		scale = _grid.size / _base_size

func animate_step(before_cells: Array, after_cells: Array, step: Dictionary, swap_before: Array = [], swap_indices: Array = []) -> void:
	if not active:
		return
	var generation := _generation
	if swap_indices.size() == 2 and not swap_before.is_empty():
		await _animate_swap(swap_before, int(swap_indices[0]), int(swap_indices[1]), generation)
		if not _is_current(generation):
			return
	await _animate_specials(before_cells, generation)
	if not _is_current(generation):
		return
	var removed: Array = step.get("removed", [])
	if not removed.is_empty():
		await _animate_clear(before_cells, removed, generation)
	else:
		await _animate_drop(before_cells, after_cells, generation)

func animate_invalid_swap(cells: Array, a: int, b: int) -> void:
	var generation := _generation
	await _animate_swap(cells, a, b, generation)
	if not _is_current(generation):
		return
	var swapped := cells.duplicate(true)
	var cell: Variant = swapped[a]
	swapped[a] = swapped[b]
	swapped[b] = cell
	await _animate_swap(swapped, a, b, generation)

func _animate_swap(cells: Array, a: int, b: int, generation: int) -> void:
	if not _is_current(generation) or a < 0 or b < 0 or a >= cells.size() or b >= cells.size() or cells[a] == null or cells[b] == null:
		return
	var first: Control = visuals.get(int(cells[a].uid))
	var second: Control = visuals.get(int(cells[b].uid))
	if not is_instance_valid(first) or not is_instance_valid(second):
		return
	var tween := _new_tween()
	tween.tween_property(first, "position", _slot_rects[b].position, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(second, "position", _slot_rects[a].position, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait_tween(tween, generation)
	if _is_current(generation):
		first.set_meta("board_index", b)
		second.set_meta("board_index", a)

func _animate_specials(cells: Array, generation: int) -> void:
	var created: Array[Control] = []
	for index in range(cells.size()):
		var cell: Variant = cells[index]
		if cell == null:
			continue
		var visual: Control = visuals.get(int(cell.uid))
		if not is_instance_valid(visual):
			continue
		var old: Dictionary = visual.get_meta("cell")
		if str(cell.special) != "" and (str(old.special) != str(cell.special) or str(old.axis) != str(cell.axis)):
			_configure_visual(visual, cell)
			created.append(visual)
	if created.is_empty():
		return
	var tween := _new_tween()
	for visual in created:
		visual.scale = Vector2(0.72, 0.72)
		visual.modulate = Color(1.28, 1.18, 0.72, 1.0)
		tween.tween_property(visual, "scale", Vector2.ONE, SPECIAL_CREATE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual, "modulate", Color.WHITE, SPECIAL_CREATE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait_tween(tween, generation)

func _animate_clear(cells: Array, removed: Array, generation: int) -> void:
	var disappearing: Array[Control] = []
	for index in removed:
		if index < 0 or index >= cells.size() or cells[index] == null:
			continue
		var uid := int(cells[index].uid)
		var visual: Control = visuals.get(uid)
		if is_instance_valid(visual):
			visuals.erase(uid)
			fading_visuals.append(visual)
			disappearing.append(visual)
	if disappearing.is_empty():
		return
	var tween := _new_tween()
	for visual in disappearing:
		var sink := visual.position + Vector2(0, visual.size.y * 0.10)
		tween.tween_property(visual, "position", sink, CLEAR_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(visual, "scale", Vector2(0.15, 0.15), CLEAR_ANIM_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(visual, "modulate:a", 0.0, CLEAR_ANIM_SECONDS)
	tween.finished.connect(func():
		for visual in disappearing:
			fading_visuals.erase(visual)
			if is_instance_valid(visual):
				visual.queue_free())
	# Keep these ghosts alive during the start of gravity, just as the old board
	# kept its fading buttons below the separate falling-piece overlay.
	await _wait_seconds(CLEAR_ANIM_SECONDS * CLEAR_DROP_OVERLAP_RATIO + POST_CLEAR_PAUSE_SECONDS, generation)

func _animate_drop(before: Array, after: Array, generation: int) -> void:
	var old_by_uid: Dictionary = {}
	var target_uids: Dictionary = {}
	for index in range(before.size()):
		if before[index] != null:
			old_by_uid[int(before[index].uid)] = index
	for cell in after:
		if cell != null:
			target_uids[int(cell.uid)] = true
	# A board with no legal move is regenerated by the model. Fade its survivors
	# before the replacement pieces enter from above, instead of teleporting them.
	var replaced: Array = []
	for uid in visuals.keys():
		if not target_uids.has(uid) and old_by_uid.has(uid):
			replaced.append(old_by_uid[uid])
	if not replaced.is_empty():
		await _animate_clear(before, replaced, generation)
		if not _is_current(generation):
			return
	var entries: Array = []
	var spawn_counts: Dictionary = {}
	# Visit bottom to top so the first new piece starts at row -1, as in the
	# original column-compaction routine.
	for y in range(BOARD_SIZE - 1, -1, -1):
		for x in range(BOARD_SIZE):
			var index := y * BOARD_SIZE + x
			if index >= after.size() or after[index] == null:
				continue
			var cell: Dictionary = after[index]
			var uid := int(cell.uid)
			var spawned := not old_by_uid.has(uid)
			var from_index: int = int(old_by_uid.get(uid, index))
			var visual: Control = visuals.get(uid)
			if not is_instance_valid(visual):
				# Specials detected after gravity appear only once the board lands.
				var initial_cell := cell.duplicate(true)
				if spawned:
					initial_cell.special = ""
				visual = _add_visual(initial_cell, index)
			visual.set_meta("board_index", index)
			if not spawned and from_index == index:
				continue
			var target: Rect2 = _slot_rects[index]
			var from_y := from_index / BOARD_SIZE
			var spawn_index := int(spawn_counts.get(x, 0))
			if spawned:
				spawn_counts[x] = spawn_index + 1
				from_y = -1 - spawn_index
			var row_delta := from_y - y
			if spawned:
				row_delta -= DROP_SPAWN_EXTRA_ROWS
				var stride := _slot_rects[BOARD_SIZE].position.y - _slot_rects[0].position.y
				visual.position = target.position + Vector2(0, row_delta * stride)
				visual.modulate.a = 0.0
				visual.scale = Vector2(0.96, 1.04)
			else:
				visual.position = _slot_rects[from_index].position
			var duration := DROP_BASE_SECONDS + sqrt(float(maxi(1, absi(row_delta)))) * DROP_SECONDS_PER_ROW + DROP_SETTLE_SECONDS
			var delay := float(x) * DROP_COLUMN_STAGGER_SECONDS + float(BOARD_SIZE - 1 - y) * 0.012
			if spawned:
				delay += DROP_SPAWN_DELAY_SECONDS + float(spawn_index) * 0.025
			entries.append({"visual": visual, "target": target.position, "duration": duration, "delay": delay, "spawn": spawned})
	if not entries.is_empty():
		var tween := _new_tween()
		for entry in entries:
			var visual: Control = entry.visual
			var duration: float = entry.duration
			var delay: float = entry.delay
			if entry.spawn:
				tween.tween_property(visual, "modulate:a", 1.0, minf(0.16, (duration - DROP_SETTLE_SECONDS) * 0.38)).set_delay(delay)
			tween.tween_property(visual, "position", entry.target, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(visual, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await _wait_tween(tween, generation)
		if not _is_current(generation):
			return
		await _wait_seconds(POST_DROP_PAUSE_SECONDS, generation)
	if _is_current(generation):
		await _animate_specials(after, generation)

func _add_visual(cell: Dictionary, index: int) -> Control:
	var visual := Control.new()
	visual.name = "GhostPiece%d" % int(cell.uid)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.set_meta("board_index", index)
	add_child(visual)
	visual.position = _slot_rects[index].position
	visual.size = _slot_rects[index].size
	visual.pivot_offset = visual.size * 0.5
	var piece := PieceView.new()
	visual.add_child(piece)
	_configure_visual(visual, cell)
	visuals[int(cell.uid)] = visual
	return visual

func _configure_visual(visual: Control, cell: Dictionary) -> void:
	visual.set_meta("cell", cell.duplicate(true))
	var piece: Control = visual.get_node("PieceView")
	piece.configure(cell)
	if piece.get_texture() == null:
		var fallback := visual.get_node_or_null("Fallback") as Label
		if fallback == null:
			fallback = Label.new()
			fallback.name = "Fallback"
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			visual.add_child(fallback)
		fallback.text = {"star": "★", "guard": "盾"}.get(cell.kind, str(Catalog.NAMES.get(cell.kind, "?" )).left(1))
		fallback.add_theme_font_size_override("font_size", maxi(18, roundi(visual.size.x * 0.42)))

func _new_tween() -> Tween:
	var tween := create_tween().set_parallel(true)
	_tweens.append(tween)
	tween.finished.connect(func(): _tweens.erase(tween))
	return tween

func _wait_tween(tween: Tween, generation: int) -> void:
	# Tween.kill() does not emit finished. Polling frames lets a disposed battle
	# cancel safely without leaving the caller suspended forever on that signal.
	while _is_current(generation) and tween.is_valid() and tween.is_running():
		await get_tree().process_frame

func _wait_seconds(seconds: float, generation: int) -> void:
	var remaining := seconds
	while _is_current(generation) and remaining > 0.0:
		await get_tree().process_frame
		remaining -= get_process_delta_time()

func _is_current(generation: int) -> bool:
	return active and _generation == generation and is_inside_tree()

func dispose() -> void:
	active = false
	_generation += 1
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	visuals.clear()
	fading_visuals.clear()
	for child in get_children():
		child.free()
