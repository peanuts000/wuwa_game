extends Control

const ICON_SIZE := Vector2(80, 80)
const GOLD := Color("f5d481")
const TEAL := Color("79dbc8")
const DARK := Color("17283d")

var kind := "relic"
var id := ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func configure(item_kind: String, item_id: String) -> void:
	kind = item_kind
	id = item_id
	queue_redraw()

func _draw() -> void:
	var factor := minf(size.x / ICON_SIZE.x, size.y / ICON_SIZE.y)
	if factor <= 0:
		return
	draw_set_transform((size - ICON_SIZE * factor) * 0.5, 0, Vector2.ONE * factor)
	var rim := GOLD if kind == "relic" else TEAL
	draw_circle(Vector2(40, 40), 36, Color("101c2c"))
	draw_arc(Vector2(40, 40), 35, 0, TAU, 64, rim.darkened(0.55), 1.5, true)
	if kind == "supply":
		_draw_vial()
	else:
		match id:
			"r01": _draw_badge()
			"r02": _draw_heatsink()
			"r03": _draw_shield()
			"r04": _draw_prism()
			"r05": _draw_battery()
			_: _draw_prism()

func _outline(points: PackedVector2Array, color: Color, width: float = 2) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _draw_badge() -> void:
	var left := PackedVector2Array([Vector2(22, 48), Vector2(17, 68), Vector2(29, 63), Vector2(35, 70), Vector2(41, 49)])
	var right := PackedVector2Array([Vector2(39, 49), Vector2(45, 70), Vector2(51, 63), Vector2(63, 68), Vector2(58, 48)])
	draw_colored_polygon(left, TEAL.darkened(0.4))
	draw_colored_polygon(right, TEAL.darkened(0.4))
	draw_circle(Vector2(40, 33), 23, GOLD.darkened(0.55))
	draw_circle(Vector2(40, 33), 18, GOLD)
	draw_circle(Vector2(40, 33), 14, DARK)
	var wave := PackedVector2Array([Vector2(29, 34), Vector2(34, 28), Vector2(40, 36), Vector2(46, 29), Vector2(51, 33)])
	draw_polyline(wave, TEAL, 3, true)
	draw_line(Vector2(30, 41), Vector2(50, 41), GOLD, 2, true)

func _draw_heatsink() -> void:
	draw_rect(Rect2(16, 20, 48, 42), GOLD.darkened(0.65), true)
	draw_rect(Rect2(16, 20, 48, 42), GOLD, false, 2)
	for x in [23, 31, 39, 47, 55]:
		draw_rect(Rect2(x, 16, 4, 50), TEAL.darkened(0.35), true)
		draw_line(Vector2(x + 1, 18), Vector2(x + 1, 64), TEAL, 1.5, true)
	draw_line(Vector2(18, 34), Vector2(62, 34), GOLD, 3, true)
	draw_line(Vector2(18, 48), Vector2(62, 48), GOLD, 3, true)

func _draw_shield() -> void:
	var edge := PackedVector2Array([Vector2(40, 12), Vector2(65, 22), Vector2(61, 49), Vector2(52, 61), Vector2(40, 70), Vector2(28, 61), Vector2(19, 49), Vector2(15, 22)])
	draw_colored_polygon(edge, GOLD.darkened(0.75))
	_outline(edge, GOLD, 2.5)
	var inner := PackedVector2Array([Vector2(40, 20), Vector2(56, 27), Vector2(53, 47), Vector2(40, 60), Vector2(27, 47), Vector2(24, 27)])
	draw_colored_polygon(inner, TEAL.darkened(0.55))
	draw_line(Vector2(40, 25), Vector2(40, 56), GOLD, 3, true)
	draw_line(Vector2(30, 39), Vector2(50, 39), GOLD, 3, true)

func _draw_prism() -> void:
	var edge := PackedVector2Array([Vector2(40, 11), Vector2(67, 37), Vector2(40, 70), Vector2(13, 37)])
	draw_colored_polygon(edge, GOLD.darkened(0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(40, 11), Vector2(40, 39), Vector2(13, 37)]), TEAL.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(40, 11), Vector2(67, 37), Vector2(40, 39)]), GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(13, 37), Vector2(40, 39), Vector2(40, 70)]), TEAL.darkened(0.55))
	_outline(edge, GOLD, 2)
	draw_polyline(PackedVector2Array([Vector2(40, 11), Vector2(40, 70), Vector2(67, 37), Vector2(13, 37)]), Color("fff1c3"), 1.5, true)

func _draw_battery() -> void:
	draw_rect(Rect2(13, 24, 51, 34), GOLD.darkened(0.7), true)
	draw_rect(Rect2(13, 24, 51, 34), GOLD, false, 2.5)
	draw_rect(Rect2(65, 34, 6, 14), GOLD, true)
	for x in [20, 33, 46]:
		draw_rect(Rect2(x, 31, 10, 20), TEAL, true)
	var spark := PackedVector2Array([Vector2(42, 17), Vector2(36, 26), Vector2(43, 26), Vector2(38, 34), Vector2(48, 23), Vector2(42, 23)])
	draw_colored_polygon(spark, GOLD)

func _draw_vial() -> void:
	var tint := Color("77d99b") if id == "healing_vial" else (Color("78b8ee") if id == "guard_vial" else Color("bb98ed"))
	var bottle := PackedVector2Array([Vector2(29, 16), Vector2(51, 16), Vector2(51, 30), Vector2(61, 39), Vector2(59, 65), Vector2(52, 70), Vector2(28, 70), Vector2(21, 65), Vector2(19, 39), Vector2(29, 30)])
	draw_colored_polygon(bottle, tint.darkened(0.7))
	_outline(bottle, tint, 2)
	draw_rect(Rect2(27, 10, 26, 9), GOLD.darkened(0.25), true)
	draw_line(Vector2(30, 14), Vector2(50, 14), GOLD, 2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(24, 43), Vector2(56, 43), Vector2(54, 64), Vector2(26, 64)]), tint.darkened(0.2))
	draw_line(Vector2(26, 35), Vector2(24, 57), tint.lightened(0.3), 2, true)
	match id:
		"healing_vial":
			draw_rect(Rect2(36, 45, 8, 18), Color("ecfff4"), true)
			draw_rect(Rect2(31, 50, 18, 8), Color("ecfff4"), true)
		"guard_vial":
			var shield := PackedVector2Array([Vector2(40, 43), Vector2(50, 48), Vector2(47, 59), Vector2(40, 64), Vector2(33, 59), Vector2(30, 48)])
			draw_colored_polygon(shield, Color("d5efff"))
			draw_line(Vector2(40, 48), Vector2(40, 59), tint.darkened(0.4), 2, true)
		_:
			var star := PackedVector2Array()
			for point in range(10):
				var angle := -PI * 0.5 + point * PI / 5
				var radius := 12.0 if point % 2 == 0 else 5.0
				star.append(Vector2(40, 54) + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(star, GOLD)
