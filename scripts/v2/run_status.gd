extends Control

const LifeHearts := preload("res://scripts/v2/life_hearts.gd")
const COIN_TEXTURE := preload("res://assets/ui/status/shell_coin.png")

var hearts: LifeHearts
var coin: TextureRect
var amount: Label
var _compact := false
var _layout_initialized := false

func _init() -> void:
	name = "RunStatus"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts = LifeHearts.new()
	add_child(hearts)
	coin = TextureRect.new()
	coin.name = "ShellIcon"
	coin.texture = COIN_TEXTURE
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.tooltip_text = "贝币"
	add_child(coin)
	amount = Label.new()
	amount.name = "ShellAmount"
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.add_theme_color_override("font_color", Color("edf4ff"))
	add_child(amount)
	hearts.loss_finished.connect(func(_index: int): _position_controls())
	set_compact(false)

func _ready() -> void:
	resized.connect(_position_controls)
	_position_controls()

func configure(lives: int, shells: int, animate: bool = false) -> void:
	hearts.set_lives(lives, animate)
	amount.text = str(shells)
	amount.tooltip_text = "贝币 %d" % shells
	set_meta("shells", shells)
	_position_controls()

func get_hearts() -> LifeHearts:
	return hearts

func set_compact(value: bool) -> void:
	if _layout_initialized and _compact == value:
		return
	_layout_initialized = true
	_compact = value
	custom_minimum_size = Vector2(212, 24) if _compact else Vector2(300, 52)
	hearts.set_heart_size(Vector2(26, 21) if _compact else Vector2(40, 32), 4.0 if _compact else 6.0)
	amount.add_theme_font_size_override("font_size", 14 if _compact else 20)
	_position_controls()
	# Label minimum sizes update after the font change; lay out once more so
	# the compact row can shrink from the previous normal font's height.
	call_deferred("_position_controls")

func is_compact() -> bool:
	return _compact

func _position_controls() -> void:
	var height := 24.0 if _compact else 52.0
	var heart_count := maxi(3, hearts.get_visible_heart_count())
	var heart_width := float(heart_count) * (hearts.get_heart_size().x + hearts.get_spacing()) - hearts.get_spacing()
	hearts.position = Vector2.ZERO
	hearts.size = Vector2(heart_width, height)
	var coin_size := 28.0 if _compact else 44.0
	var coin_x := maxf(112.0 if _compact else 164.0, heart_width + (26.0 if _compact else 32.0))
	coin.position = Vector2(coin_x, (height - coin_size) * 0.5)
	coin.size = Vector2(coin_size, coin_size)
	var amount_x := coin_x + coin_size + (8.0 if _compact else 10.0)
	amount.position = Vector2(amount_x, 0)
	amount.size = Vector2(maxf(64.0, size.x - amount_x), height)
