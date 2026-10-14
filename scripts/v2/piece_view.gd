extends Control

const TEXTURE_ROOT := "res://assets/ui/board/"
const ACCENT := Color("79dbc8")
const RAINBOW_COLORS := [Color("ff7676"), Color("ffc36c"), Color("ffeb84"), Color("83dfb0"), Color("7dcfff"), Color("c597ff")]
const ELEMENT_KINDS := ["condensation", "thermal", "conductive", "aero", "diffraction", "annihilation"]
const ELEMENT_SHADER := """shader_type canvas_item;
uniform vec4 attribute_color : source_color;
varying vec4 piece_tint;
void vertex() {
	piece_tint = COLOR;
}
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec3 white_delta = vec3(1.0) - attribute_color.rgb;
	float shape_alpha = clamp(dot(pixel.rgb - attribute_color.rgb, white_delta) / max(dot(white_delta, white_delta), 0.0001), 0.0, 1.0);
	COLOR = vec4(attribute_color.rgb * piece_tint.rgb, shape_alpha * pixel.a * piece_tint.a);
}
"""

static var _textures: Dictionary = {}
static var _element_materials: Dictionary = {}
static var _element_shader: Shader

var kind := ""
var special := ""
var axis := ""
var selected := false
var highlighted := false
var focused := false
var hovered := false
var texture_rect: TextureRect
var overlay: Control

class PieceOverlay extends Control:
	var piece: Control

	func _draw() -> void:
		if not is_instance_valid(piece) or piece.get_texture() == null:
			return
		var center := size * 0.5
		var side := minf(size.x, size.y)
		var radius := side * 0.5
		match piece.special:
			"stripe":
				var direction := Vector2.RIGHT if piece.axis == "h" else Vector2.DOWN
				var normal := Vector2.DOWN if piece.axis == "h" else Vector2.RIGHT
				for offset in [-0.06, 0.06]:
					var mid: Vector2 = center + normal * side * float(offset)
					var start: Vector2 = mid - direction * side * 0.32
					var end: Vector2 = mid + direction * side * 0.32
					draw_line(start, end, Color("152237"), maxf(5.0, side * 0.095), true)
					draw_line(start, end, Color("fff7da"), maxf(2.0, side * 0.044), true)
			"bomb":
				var bomb_radius := side * 0.18
				var bomb_center := center + Vector2(-side * 0.025, side * 0.025)
				draw_circle(bomb_center, bomb_radius, Color("122036"))
				draw_arc(bomb_center, bomb_radius, 0.0, TAU, 40, Color("fff4d0"), maxf(2.0, side * 0.035), true)
				var fuse_start := bomb_center + Vector2(bomb_radius * 0.55, -bomb_radius * 0.8)
				var spark := center + Vector2(side * 0.19, -side * 0.20)
				draw_line(fuse_start, spark, Color("152237"), maxf(5.0, side * 0.08), true)
				draw_line(fuse_start, spark, Color("fff4d0"), maxf(2.0, side * 0.035), true)
				for i in range(8):
					var direction := Vector2.from_angle(float(i) * TAU / 8.0)
					draw_line(spark + direction * side * 0.025, spark + direction * side * 0.08, Color("ffcc70"), maxf(2.0, side * 0.03), true)
			"rainbow":
				var ring_radius := side * 0.235
				draw_arc(center, ring_radius, 0.0, TAU, 48, Color("152237"), maxf(7.0, side * 0.13), true)
				for i in range(RAINBOW_COLORS.size()):
					var start := float(i) * TAU / float(RAINBOW_COLORS.size()) - PI * 0.5
					var end := float(i + 1) * TAU / float(RAINBOW_COLORS.size()) - PI * 0.5
					draw_arc(center, ring_radius, start, end, 12, RAINBOW_COLORS[i], maxf(4.0, side * 0.075), true)
				draw_arc(center, ring_radius + side * 0.052, 0.0, TAU, 48, Color("fff7dd"), maxf(1.0, side * 0.015), true)
		if piece.selected or piece.highlighted:
			draw_arc(center, maxf(0.0, radius - 1.5), 0.0, TAU, 64, Color.WHITE, 3.0, true)
		if piece.focused:
			draw_arc(center, maxf(0.0, radius - 6.0), 0.0, TAU, 64, ACCENT, 2.0, true)

func _init() -> void:
	name = "PieceView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect = TextureRect.new()
	texture_rect.name = "PieceTexture"
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(texture_rect)
	overlay = PieceOverlay.new()
	overlay.name = "PieceOverlay"
	overlay.piece = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	resized.connect(func(): overlay.queue_redraw())

func configure(cell: Variant, is_selected: bool = false, is_highlighted: bool = false, is_focused: bool = false) -> void:
	selected = is_selected
	highlighted = is_highlighted
	focused = is_focused
	if cell == null:
		kind = ""
		special = ""
		axis = ""
		texture_rect.texture = null
		texture_rect.material = null
		hide()
	else:
		kind = str(cell.kind)
		special = str(cell.special)
		axis = str(cell.axis)
		texture_rect.texture = _get_kind_texture(kind)
		texture_rect.material = _get_kind_material(kind)
		visible = texture_rect.texture != null
	overlay.queue_redraw()

func get_texture() -> Texture2D:
	return texture_rect.texture

func set_hovered(value: bool) -> void:
	hovered = value
	texture_rect.self_modulate = Color(1.12, 1.12, 1.12) if hovered else Color.WHITE

func set_focused(value: bool) -> void:
	focused = value
	overlay.queue_redraw()

static func _get_kind_texture(piece_kind: String) -> Texture2D:
	if _textures.has(piece_kind):
		return _textures[piece_kind]
	var path := TEXTURE_ROOT + piece_kind + ".png"
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var texture := load(path) as Texture2D
	if texture != null:
		_textures[piece_kind] = texture
	return texture

static func _get_kind_material(piece_kind: String) -> ShaderMaterial:
	if piece_kind not in ELEMENT_KINDS:
		return null
	if _element_materials.has(piece_kind):
		return _element_materials[piece_kind]
	var texture := _get_kind_texture(piece_kind)
	if texture == null:
		return null
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	# These source icons contain a white symbol on a flat attribute color. The
	# transparent corner still stores that color, allowing exact outline extraction.
	var attribute_color := image.get_pixel(0, 0)
	attribute_color.a = 1.0
	if _element_shader == null:
		_element_shader = Shader.new()
		_element_shader.code = ELEMENT_SHADER
	var material := ShaderMaterial.new()
	material.shader = _element_shader
	material.set_shader_parameter("attribute_color", attribute_color)
	_element_materials[piece_kind] = material
	return material
