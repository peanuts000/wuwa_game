extends Control

const CHAIN_TEXTURE := preload("res://assets/effects/lock_chains_x_v2.png")
const DURATION := 0.46
var fragment_texture: Texture2D = CHAIN_TEXTURE
var initial_opacity: float = 1.0

func _init() -> void:
	# Keep screen ownership for cleanup, but opt out of Container layout.
	# This must be set before add_child queues a VBoxContainer sort.
	top_level = true

func _ready() -> void:
	name = "LockChainBreak"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	var tween := create_tween().set_parallel(true)
	var texture_half: Vector2 = fragment_texture.get_size() * 0.5
	var fragment_size: Vector2 = size * 0.5
	for y in range(2):
		for x in range(2):
			var fragment := TextureRect.new()
			var atlas := AtlasTexture.new()
			atlas.atlas = fragment_texture
			atlas.region = Rect2(Vector2(x, y) * texture_half, texture_half)
			fragment.texture = atlas
			fragment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			fragment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fragment.size = fragment_size
			fragment.position = Vector2(x, y) * fragment_size
			fragment.pivot_offset = fragment_size * 0.5
			fragment.modulate = Color(1.3, 1.2, 1.4, initial_opacity)
			add_child(fragment)
			var outward := Vector2(float(x * 2 - 1), float(y * 2 - 1))
			var destination: Vector2 = fragment.position + outward * size * 0.32 + Vector2(0, size.y * 0.12)
			tween.tween_property(fragment, "position", destination, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(fragment, "rotation", outward.x * outward.y * 0.48, DURATION)
			tween.tween_property(fragment, "scale", Vector2.ONE * 0.72, DURATION)
			tween.tween_property(fragment, "modulate", Color(1, 1, 1, 0), DURATION - 0.08).set_delay(0.08)
	tween.chain().tween_callback(queue_free)
