extends Control

signal node_selected(id: String)
var run_state
var first_stage := 1
const NodeButton = preload("res://scripts/v2/map_node_button.gd")
const LABELS = {"start": "起点", "battle": "战斗", "boss": "首领", "event": "事件", "shop": "商店", "rest": "休整", "reward": "奖励"}
const REWARD_HINT := "无需战斗，无代价。直接获得贝币，并优先提供未拥有的藏品二选一；仅剩一件时直接领取，藏品集齐后额外获得贝币。"
const STAGE_SPACING := 190.0
const MAP_HEIGHT := 420.0
const NODE_SIZE := Vector2(72, 72)

func configure(value) -> void:
	run_state = value
	first_stage = 1
	for node in run_state.nodes.values():
		first_stage = mini(first_stage, int(node.row))
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var last_stage := 1
	for id in run_state.nodes:
		var node: Dictionary = run_state.nodes[id]
		last_stage = maxi(last_stage, int(node.row))
		var button := NodeButton.new()
		button.name = "Node_" + str(id)
		button.setup(node, id in run_state.visited, id == run_state.current, id in run_state.available and run_state.phase == "map")
		button.size = Vector2(88, 88) if node.type == "boss" else NODE_SIZE
		button.position = point(node) - button.size * 0.5
		button.text = ("✓ " if id in run_state.visited else "") + LABELS[node.type]
		button.tooltip_text = "第 %d 层 · %s" % [node.row, LABELS[node.type]]
		if node.type == "start":
			button.text = "起点"
			button.tooltip_text = "探索起点\n从相连的第一层节点中选择一条路线出发。"
		elif node.type == "reward":
			button.tooltip_text += "\n" + REWARD_HINT
		button.pressed.connect(func(): node_selected.emit(id))
		add_child(button)
	custom_minimum_size = Vector2(maxf(780, 160 + (last_stage - first_stage) * STAGE_SPACING), MAP_HEIGHT)
	queue_redraw()

func point(node: Dictionary) -> Vector2:
	return Vector2(80 + (int(node.row) - first_stage) * STAGE_SPACING, 65 + int(node.col) * 74)

func _draw() -> void:
	if run_state == null:
		return
	# Respect older saved maps: highlight only stages containing reward nodes.
	var reward_stages: Dictionary = {}
	for node in run_state.nodes.values():
		if node.type == "reward":
			reward_stages[int(node.row)] = true
	for stage in reward_stages:
		var x := 80 + (int(stage) - first_stage) * STAGE_SPACING
		draw_rect(Rect2(x - 57, 7, 114, MAP_HEIGHT - 14), Color(0.87, 0.69, 0.33, 0.10))
	for node in run_state.nodes.values():
		for next in node.next:
			if not run_state.nodes.has(next):
				continue
			var start := point(node)
			var finish := point(run_state.nodes[next])
			var direction := (finish - start).normalized()
			start += direction * 41
			finish -= direction * (49 if run_state.nodes[next].type == "boss" else 42)
			var completed: bool = node.id in run_state.visited and next in run_state.visited
			var color := Color("c79957") if completed else Color(0.43, 0.34, 0.50, 0.56)
			if completed:
				draw_line(start, finish, Color("edcf93"), 7, true)
				draw_line(start, finish, color, 3, true)
			else:
				draw_dashed_line(start, finish, color, 3, 9, true)
			var normal := Vector2(-direction.y, direction.x)
			draw_colored_polygon(PackedVector2Array([finish, finish - direction * 10 + normal * 6, finish - direction * 10 - normal * 6]), color)
