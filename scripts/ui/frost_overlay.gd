extends TextureRect

const ICE_TEXTURE := preload("res://assets/effects/frost_block.png")
var frozen_cell: Dictionary = {}

func _ready() -> void:
	name = "FrostOverlay"
	texture = ICE_TEXTURE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	z_index = 13
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not frozen_cell.has("frost_vfx_started_msec"):
		frozen_cell["frost_vfx_started_msec"] = Time.get_ticks_msec()
	_process(0.0)

func _process(_delta: float) -> void:
	visible = int(frozen_cell.get("effects", {}).get("frost", 0)) >= 3
	if not visible:
		return
	pivot_offset = size * 0.5
	var elapsed: float = maxf(0.0, float(Time.get_ticks_msec() - int(frozen_cell.get("frost_vfx_started_msec", 0))) / 1000.0)
	var progress: float = clampf(elapsed / 0.4, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.75, 1.0, 1.0 - pow(1.0 - progress, 3.0))
	modulate = Color(1, 1, 1, lerpf(0.05, 0.40, progress))
