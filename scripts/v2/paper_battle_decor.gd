extends Control

const Art = preload("res://scripts/v2/paper_battle_theme.gd")
var view: Control

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if not is_instance_valid(view) or view._layout.is_empty():
		return
	var board: Rect2 = view._layout.board
	var outer := Art.dark_style()
	outer.set_border_width_all(3)
	draw_style_box(outer, board.grow(10))
	draw_rect(board.grow(5), Art.GOLD, false, 1)
	var slot := board.size.x / 8.0
	for row in range(8):
		for col in range(8):
			var box := Rect2(board.position + Vector2(col, row) * slot, Vector2.ONE * slot)
			draw_rect(box.grow(-1), Color("241b33") if (row + col) % 2 == 0 else Color("2b2039"))
			draw_rect(box.grow(-1), Color("4e395e"), false, 1)
	for corner in [board.position, Vector2(board.end.x, board.position.y), board.end, Vector2(board.position.x, board.end.y)]:
		draw_texture_rect(Art.MenuArt.STAR, Rect2(corner - Vector2(10, 10), Vector2(20, 20)), false)
	draw_style_box(Art.dark_style(), Rect2(29, 20, 306, 49))
	# The paper surfaces carry native labels; no text is baked into the stage.
	for y in [365, 464]:
		draw_line(Vector2(50, y), Vector2(325, y), Art.GOLD, 1)
