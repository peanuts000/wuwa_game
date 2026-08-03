extends Control
class_name RunMapCanvas

var nodes: Array = []
var available_node_ids: Array = []
var node_positions: Dictionary = {}

func setup(map_nodes: Array, available_ids: Array, positions: Dictionary) -> void:
	nodes = map_nodes
	available_node_ids = available_ids
	node_positions = positions
	queue_redraw()

func _draw() -> void:
	_draw_links()

func _draw_links() -> void:
	for node in nodes:
		var node_data: Dictionary = node
		var from_id: String = String(node_data.get("id", ""))
		if not node_positions.has(from_id):
			continue
		var from_pos: Vector2 = node_positions[from_id]
		for target_id in _node_links(node_data):
			var to_id: String = String(target_id)
			if not node_positions.has(to_id):
				continue
			var to_pos: Vector2 = node_positions[to_id]
			var active: bool = bool(node_data.get("completed", false)) or available_node_ids.has(from_id)
			var color: Color = Color(1, 1, 1, 0.85) if active else Color(0.72, 0.76, 0.74, 0.28)
			_draw_curve(from_pos + Vector2(118, 0), to_pos - Vector2(118, 0), color, 5.0 if active else 3.0)

func _draw_curve(from_pos: Vector2, to_pos: Vector2, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var control_offset: float = max(80.0, abs(to_pos.x - from_pos.x) * 0.45)
	var c1: Vector2 = from_pos + Vector2(control_offset, 0)
	var c2: Vector2 = to_pos - Vector2(control_offset, 0)
	for i in range(28):
		var t: float = float(i) / 27.0
		points.append(_bezier(from_pos, c1, c2, to_pos, t))
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width, true)

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t

func _node_links(node: Dictionary) -> Array:
	var links: Variant = node.get("links", [])
	if links is Array:
		return links
	return []
