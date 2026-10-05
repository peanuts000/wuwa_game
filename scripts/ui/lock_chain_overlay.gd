extends TextureRect

const CHAIN_TEXTURE := preload("res://assets/effects/lock_chains_x_v2.png")
const SNAP_SECONDS := 0.34
var locked_cell: Dictionary = {}

func _ready() -> void:
	name = "LockChainOverlay"
	texture = CHAIN_TEXTURE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 15
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not locked_cell.has("lock_vfx_started_msec"):
		locked_cell["lock_vfx_started_msec"] = Time.get_ticks_msec()
	_process(0.0)

func _process(_delta: float) -> void:
	visible = int(locked_cell.get("locked_turns", 0)) > 0
	if not visible:
		return
	pivot_offset = size * 0.5
	var elapsed: float = maxf(0.0, float(Time.get_ticks_msec() - int(locked_cell.get("lock_vfx_started_msec", 0))) / 1000.0)
	if elapsed < SNAP_SECONDS:
		var progress: float = elapsed / SNAP_SECONDS
		var settle: float = 1.0 - pow(1.0 - progress, 3.0)
		scale = Vector2.ONE * lerpf(1.24, 1.0, settle)
		rotation = sin(progress * PI * 4.0) * 0.035 * (1.0 - progress)
		modulate = Color(1.0, 1.0, 1.0, lerpf(0.2, 1.0, settle))
	else:
		scale = Vector2.ONE
		rotation = 0.0
		modulate = Color(1.0, 1.0, 1.0, 0.91 + sin(elapsed * TAU / 2.0) * 0.07)
