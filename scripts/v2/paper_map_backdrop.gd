extends Control

const Art = preload("res://scripts/v2/paper_map_theme.gd")

func _init() -> void:
	name = "MapBookBackdrop"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_texture_rect(Art.BACKGROUND, Rect2(Vector2.ZERO, size), false)
	var factor := size / Vector2(1280, 720)
	var font := get_theme_default_font()
	for index in range(Art.KINDS.size()):
		var center := Vector2(105 + index * 88, 613) * factor
		var icon_size := Vector2(51, 51) * factor
		draw_texture_rect(Art.node_texture(Art.KINDS[index]), Rect2(center - icon_size * 0.5, icon_size), false)
		var label: String = Art.LABELS[index]
		var font_size := roundi(18 * factor.y)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(center.x - width / 2, 657 * factor.y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Art.INK)
