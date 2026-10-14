extends SceneTree

const MapScrollView = preload("res://scripts/v2/map_scroll_view.gd")
var checks := 0
var failures := 0
var selected: Array = []
var map_scroll

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("REWARD_MAP_UI: " + message)

func _fixture() -> Dictionary:
	return {
		"nodes": {
			"reward_next": {"id": "reward_next", "type": "reward", "row": 1, "col": 0, "next": ["reward_done"]},
			"reward_done": {"id": "reward_done", "type": "reward", "row": 2, "col": 1, "next": ["reward_later"]},
			"reward_later": {"id": "reward_later", "type": "reward", "row": 11, "col": 2, "next": []},
			"battle_next": {"id": "battle_next", "type": "battle", "row": 1, "col": 3, "next": []},
		},
		"available": ["reward_next", "battle_next"],
		"visited": ["reward_done"],
		"current": "reward_done",
		"phase": "map",
	}

func _button(id: String) -> Button:
	for child in map_scroll.map_view.get_children():
		if child.get_meta("node_id", "") == id:
			return child
	return null

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _motion(point: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	root.push_input(event, true)
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var state := _fixture()
	map_scroll = MapScrollView.new()
	map_scroll.position = Vector2(100, 80)
	map_scroll.size = Vector2(800, 600)
	root.add_child(map_scroll)
	map_scroll.configure(state)
	map_scroll.node_selected.connect(func(id: String): selected.append(id))
	await process_frame
	await process_frame
	var available := _button("reward_next")
	var visited := _button("reward_done")
	var unavailable := _button("reward_later")
	var battle := _button("battle_next")
	check(available != null and visited != null and unavailable != null, "Scroll map renders each reward node with a stable identity")
	check(available.text == "奖励" and visited.text == "✓ 奖励", "Reward labels retain the visited checkmark")
	check(available.size == battle.size and available.size == Vector2(72, 72), "Reward nodes use the established node dimensions")
	check(available.tooltip_text.begins_with("第 1 层 · 奖励"), "Reward hover identifies its floor and type")
	check(available.tooltip_text.contains("无需战斗") and available.tooltip_text.contains("无代价"), "Reward hover clearly describes a free benefit without combat")
	check(available.tooltip_text.contains("直接获得贝币"), "Reward hover describes its guaranteed currency")
	check(available.tooltip_text.contains("未拥有的藏品二选一") and available.tooltip_text.contains("仅剩一件时直接领取") and available.tooltip_text.contains("藏品集齐后额外获得贝币"), "Reward hover explains useful candidates and both fallback cases")
	check(not available.disabled and bool(available.get_meta("available")) and available.get_meta("map_state") == "available", "Available reward nodes retain gold highlighting and interaction")
	check(visited.disabled and visited.get_meta("map_state") == "current", "Current reward nodes retain the hero marker and completed state")
	check(unavailable.disabled and not bool(unavailable.get_meta("available")) and unavailable.get_meta("map_state") == "future", "Unreachable reward nodes remain disabled without availability highlighting")
	check(battle.text == "战斗" and battle.tooltip_text == "第 1 层 · 战斗", "Existing battle labels and hover stay intact")
	available.pressed.emit()
	check(selected == ["reward_next"], "Keyboard activation forwards an available reward node")
	selected.clear()
	var point: Vector2 = available.get_global_rect().get_center()
	await _mouse(point, true)
	await _mouse(point, false)
	check(selected == ["reward_next"], "An ordinary mouse click forwards the reward node")
	selected.clear()
	await _mouse(point, true)
	await _motion(point - Vector2(32, 0), Vector2(-32, 0))
	await _mouse(point - Vector2(0, 32), false)
	check(selected.is_empty() and map_scroll.scroll_horizontal >= 24, "Dragging a reward node scrolls without selecting it")
	map_scroll.scroll_horizontal = 0
	await process_frame
	map_scroll.set_locked(true)
	available.pressed.emit()
	await _mouse(point, true)
	await _mouse(point, false)
	check(selected.is_empty(), "Locked map ignores reward clicks and keyboard activation")
	map_scroll.set_locked(false)
	state.phase = "reward"
	map_scroll.configure(state)
	await process_frame
	_button("reward_next").pressed.emit()
	check(_button("reward_next").disabled and not bool(_button("reward_next").get_meta("available")) and selected.is_empty(), "Reward phase disables map activation for route previews")
	map_scroll.dispose()
	root.remove_child(map_scroll)
	map_scroll.queue_free()
	await process_frame
	print("V2_REWARD_MAP_UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
