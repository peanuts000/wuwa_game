extends Control

const BoardModelScript := preload("res://scripts/game/board_model.gd")
const SaveManagerScript := preload("res://scripts/game/save_manager.gd")
const RunMapCanvasScript := preload("res://scripts/ui/run_map_canvas.gd")
const COLETTA_CRYSTAL_LEFT := "res://assets/ui/coletta_components/T_NorCrystal1.png"
const COLETTA_CRYSTAL_RIGHT := "res://assets/ui/coletta_components/T_NorCrystal2.png"
const COLETTA_CRYSTAL_CORE_LEFT := "res://assets/ui/coletta_components/T_NorCrystalMid1.png"
const COLETTA_CRYSTAL_CORE_RIGHT := "res://assets/ui/coletta_components/T_NorCrystalMid2.png"
const COLETTA_ICE_FRAME := "res://assets/ui/coletta_components/T_NorIceFrameMid.png"
const COLETTA_ICE_FRAME_RED := "res://assets/ui/coletta_components/T_NorIceFrameRed.png"
const COLETTA_RESONANCE_WAVE_TEXTURE := "res://assets/ui/coletta_resonance_wave_generated.png"
const COLETTA_RESONANCE_EMPTY_COMPOSITE := "res://assets/ui/coletta_resonance_empty_cutout.png"
const COLETTA_RESONANCE_READY_COMPOSITE := "res://assets/ui/coletta_resonance_ready_original.png"
const COLETTA_RESONANCE_REMAINING_TEXTURES := {
	4: "res://assets/ui/coletta_resonance_ready_original.png",
	3: "res://assets/ui/coletta_resonance_ready_gray_4.png",
	2: "res://assets/ui/coletta_resonance_ready_gray_3_4.png",
	1: "res://assets/ui/coletta_resonance_ready_gray_2_3_4.png",
}
const COLETTA_READY_CHARGES: Array[String] = [
	"res://assets/ui/coletta_components/T_UltimateCharge1.png",
	"res://assets/ui/coletta_components/T_UltimateCharge2.png",
	"res://assets/ui/coletta_components/T_UltimateCharge3.png",
	"res://assets/ui/coletta_components/T_UltimateCharge4.png",
]
const COLETTA_READY_CHARGE_BACKGROUNDS: Array[String] = [
	"res://assets/ui/coletta_components/T_UltimateCharge1Bg.png",
	"res://assets/ui/coletta_components/T_UltimateCharge2Bg.png",
	"res://assets/ui/coletta_components/T_UltimateCharge3Bg.png",
	"res://assets/ui/coletta_components/T_UltimateCharge4Bg.png",
]
const COLETTA_READY_LIGHT_BLUE := "res://assets/ui/coletta_components/T_UltimateLightBlue.png"
const COLETTA_READY_LIGHT_BLUE_TOP := "res://assets/ui/coletta_components/T_UltimateLightBlueTop.png"
const COLETTA_READY_LIGHT_BLUE_BOTTOM := "res://assets/ui/coletta_components/T_UltimateLightBlueBottom.png"
const COLETTA_READY_LIGHT_PURPLE := "res://assets/ui/coletta_components/T_UltimateLightPurple.png"
const COLETTA_READY_LIGHT_RED := "res://assets/ui/coletta_components/T_UltimateLightRed.png"
const SLOT_ATTRIBUTES: Array[String] = ["衍射", "湮灭", "冷凝", "气动", "热熔", "导电"]
const COLETTA_PIECE_ID := "condensation_coletta"
const COLETTA_RESONANCE_TEXTURE_SIZE := Vector2(640.0, 106.0)
const COLETTA_WAVE_HEIGHT_SCALE := 0.55
const COLETTA_WAVE_BASELINE_RATIO := 0.755
const COLETTA_WAVE_HORIZONTAL_INSET_RATIO := 0.05
const COLETTA_WAVE_FADE_SHADER := """
shader_type canvas_item;

void fragment() {
	float bar_index = floor(UV.x * 62.0);
	float bar_x = (bar_index + 0.5) / 62.0;
	float primary_wave = sin(bar_x * 12.5663706 - TIME * 3.10);
	float secondary_wave = sin(bar_x * 25.1327412 - TIME * 4.35);
	float motion = clamp(0.50 + primary_wave * 0.42 + secondary_wave * 0.08, 0.0, 1.0);
	float height_scale = mix(0.68, 1.0, smoothstep(0.0, 1.0, motion));
	float sample_y = 1.0 - (1.0 - UV.y) / height_scale;
	if (sample_y < 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 color = texture(TEXTURE, vec2(UV.x, sample_y));
		float opacity = mix(0.30, 1.0, smoothstep(0.08, 0.78, UV.y));
		float brightness = mix(0.93, 1.05, motion);
		color.rgb *= brightness;
		color.a *= opacity;
		COLOR = color;
	}
}
"""
const PHOEBE_PIECE_ID := "diffraction_phoebe"
const PHOEBE_RESONANCE_TEXTURE_SIZE := Vector2(640.0, 106.0)
const PHOEBE_RESONANCE_EMPTY := "res://assets/ui/phoebe_resonance_empty_redraw.png"
const PHOEBE_RESONANCE_WAVE_GOLD := "res://assets/ui/phoebe_resonance_wave_gold_redraw.png"
const PHOEBE_RESONANCE_READY_BASE := "res://assets/ui/phoebe_resonance_ready_base_redraw.png"
const PHOEBE_RESONANCE_WAVE_READY := "res://assets/ui/phoebe_resonance_wave_ready_redraw.png"
const PHOEBE_GOLD_WAVE_RECT := Rect2(100.0, 0.0, 440.0, 69.0)
const PHOEBE_GOLD_WAVE_BASELINE := 62.0 / 106.0
const PHOEBE_READY_WAVE_BASELINE := 62.0 / 106.0
const PHOEBE_REDRAW_WAVE_ANIMATION_SHADER := """
shader_type canvas_item;

uniform float baseline_ratio = 0.67;

void fragment() {
	float bar_index = floor(UV.x * 58.0);
	float bar_x = (bar_index + 0.5) / 58.0;
	float broad_wave = sin(bar_x * 18.8495559 - TIME * 4.2);
	float fine_wave = sin(bar_x * 43.9822972 + TIME * 5.6);
	float motion = clamp(0.52 + broad_wave * 0.30 + fine_wave * 0.12, 0.0, 1.0);
	float height_scale = mix(0.70, 1.0, smoothstep(0.0, 1.0, motion));
	float sample_y = baseline_ratio - (baseline_ratio - UV.y) / height_scale;
	if (UV.y > baseline_ratio || sample_y < 0.0 || sample_y > baseline_ratio) {
		COLOR = vec4(0.0);
	} else {
		vec4 color = texture(TEXTURE, vec2(UV.x, sample_y));
		color.rgb *= mix(0.94, 1.08, motion);
		COLOR = color;
	}
}
"""
const PHOEBE_WAVE_ANIMATION_SHADER := """
shader_type canvas_item;

uniform float recolor_strength = 0.0;
uniform vec4 top_color : source_color = vec4(1.00, 0.97, 0.78, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.55, 0.62, 1.00, 1.0);

void fragment() {
	float bar_index = floor(UV.x * 62.0);
	float bar_x = (bar_index + 0.5) / 62.0;
	float primary_wave = sin(bar_x * 12.5663706 - TIME * 3.10);
	float secondary_wave = sin(bar_x * 25.1327412 - TIME * 4.35);
	float motion = clamp(0.50 + primary_wave * 0.42 + secondary_wave * 0.08, 0.0, 1.0);
	float height_scale = mix(0.68, 1.0, smoothstep(0.0, 1.0, motion));
	float sample_y = 1.0 - (1.0 - UV.y) / height_scale;
	if (sample_y < 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 color = texture(TEXTURE, vec2(UV.x, sample_y));
		vec3 ready_tint = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.05, 1.0, UV.y));
		float brightness = mix(0.93, 1.05, motion);
		color.rgb = mix(color.rgb, ready_tint, recolor_strength) * brightness;
		COLOR = color;
	}
}
"""
const KAKARO_PIECE_ID := "conductive_kakaro"
const KAKARO_RESONANCE_TEXTURE_SIZE := Vector2(640.0, 106.0)
const KAKARO_RESONANCE_EMPTY := "res://assets/ui/kakaro_resonance_empty.png"
const KAKARO_RESONANCE_WAVE := "res://assets/ui/kakaro_resonance_wave.png"
const KAKARO_RESONANCE_READY_WAVE := "res://assets/ui/kakaro_resonance_ready_wave.png"
const KAKARO_RESONANCE_READY_FRAME := "res://assets/ui/kakaro_components/T_EnergyBarMorpKakaluo.png"
const KAKARO_WAVE_RECT := Rect2(95.0, 11.0, 502.0, 45.0)
const KAKARO_READY_WAVE_RECT := Rect2(60.0, 11.0, 523.0, 41.0)
const CHISAKI_PIECE_ID := "annihilation_chisaki"
const CHISAKI_RESONANCE_TEXTURE_SIZE := Vector2(640.0, 106.0)
const CHISAKI_RESONANCE_EMPTY := "res://assets/ui/chisaki_resonance_empty_original.png"
const CHISAKI_RESONANCE_WAVE := "res://assets/ui/chisaki_resonance_wave_original.png"
const CHISAKI_RESONANCE_READY := "res://assets/ui/chisaki_resonance_ready_original.png"
const CHISAKI_RESONANCE_RELEASE_ACTIONS: Array[String] = [
	"res://assets/ui/chisaki_resonance_release_1_original.png",
	"res://assets/ui/chisaki_resonance_release_2_original.png",
	"res://assets/ui/chisaki_resonance_release_3_original.png",
	"res://assets/ui/chisaki_resonance_release_4_original.png",
	"res://assets/ui/chisaki_resonance_release_5_original.png",
]
const CHISAKI_WAVE_RECT := Rect2(90.0, 20.0, 430.0, 52.0)
const SIGRIKA_PIECE_ID := "aero_sigrika"
const SIGRIKA_RESONANCE_TEXTURE_SIZE := Vector2(640.0, 106.0)
const SIGRIKA_RESONANCE_NORMAL: Array[String] = [
	"res://assets/ui/sigrika_resonance_normal_0.png",
	"res://assets/ui/sigrika_resonance_normal_1.png",
	"res://assets/ui/sigrika_resonance_normal_2.png",
	"res://assets/ui/sigrika_resonance_normal_3.png",
	"res://assets/ui/sigrika_resonance_normal_4.png",
]
const SIGRIKA_RESONANCE_ENHANCED: Array[String] = [
	"res://assets/ui/sigrika_resonance_enhanced_0.png",
	"res://assets/ui/sigrika_resonance_enhanced_1.png",
	"res://assets/ui/sigrika_resonance_enhanced_2.png",
	"res://assets/ui/sigrika_resonance_enhanced_3.png",
	"res://assets/ui/sigrika_resonance_enhanced_4.png",
]
const SIGRIKA_RESONANCE_ANIMATION_SHADER := """
shader_type canvas_item;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float peak = max(original.r, max(original.g, original.b));
	float floor_color = min(original.r, min(original.g, original.b));
	float colorful = smoothstep(0.10, 0.30, peak - floor_color) * smoothstep(0.18, 0.52, peak);
	float upper_zone = 1.0 - smoothstep(0.70, 0.88, UV.y);
	float animated_mask = colorful * upper_zone;
	float vertical_offset = sin(UV.x * 30.0 - TIME * 6.0) * 0.027 * animated_mask;
	vec4 moved = texture(TEXTURE, vec2(UV.x, clamp(UV.y + vertical_offset, 0.0, 1.0)));
	float traveling_light = 0.82 + 0.34 * (0.5 + 0.5 * sin(UV.x * 20.0 - TIME * 4.8));
	vec4 color = mix(original, moved, animated_mask * 0.92);
	color.rgb *= mix(1.0, traveling_light, animated_mask);
	COLOR = color;
}
"""
const EMIS_PIECE_ID := "thermal_emis"
const EMIS_STAR_COST := 10
const EMIS_STAR_MAX := 4
const EMIS_RESONANCE_TEXTURE_SIZE := Vector2(640.0, 106.0)
const EMIS_RESONANCE_STAR_BACKGROUNDS: Array[String] = [
	"res://assets/ui/emis_resonance_stars_0.png",
	"res://assets/ui/emis_resonance_stars_1.png",
	"res://assets/ui/emis_resonance_stars_2.png",
	"res://assets/ui/emis_resonance_stars_3.png",
]
const EMIS_RESONANCE_WAVE := "res://assets/ui/emis_resonance_wave.png"
const EMIS_RESONANCE_READY := "res://assets/ui/emis_resonance_ready.png"
const EMIS_WAVE_RECT := Rect2(70.0, 0.0, 500.0, 106.0)
const DANIYA_PIECE_ID := "thermal_daniya"
const DANIYA_RESONANCE_TEXTURE_SIZE := Vector2(640.0, 106.0)
const DANIYA_RESONANCE_EMPTY := "res://assets/ui/daniya_resonance_empty.png"
const DANIYA_RESONANCE_WAVE := "res://assets/ui/daniya_resonance_wave.png"
const DANIYA_RESONANCE_READY := "res://assets/ui/daniya_resonance_ready.png"
const DANIYA_RESONANCE_READY_BASE := "res://assets/ui/daniya_resonance_ready_base.png"
const DANIYA_RESONANCE_ACTIVE := "res://assets/ui/daniya_resonance_active.png"
const DANIYA_RESONANCE_ACTIVE_BASE := "res://assets/ui/daniya_resonance_active_base.png"
const DANIYA_RESONANCE_ACTIVE_WAVE := "res://assets/ui/daniya_resonance_active_wave.png"
const DANIYA_RESONANCE_EXHAUSTED := "res://assets/ui/daniya_resonance_exhausted.png"
const DANIYA_WAVE_ANIMATION_SHADER := """
shader_type canvas_item;

uniform float baseline_ratio = 0.60;

void fragment() {
	float bar_index = floor(UV.x * 64.0);
	float bar_x = (bar_index + 0.5) / 64.0;
	float broad_wave = sin(bar_x * 18.8495559 - TIME * 4.0);
	float fine_wave = sin(bar_x * 43.9822972 + TIME * 5.4);
	float pulse = sin(TIME * 2.2 + bar_x * 6.2831853);
	float motion = clamp(0.52 + broad_wave * 0.28 + fine_wave * 0.12 + pulse * 0.06, 0.0, 1.0);
	float height_scale = mix(0.42, 1.10, smoothstep(0.0, 1.0, motion));
	float sample_y = baseline_ratio - (baseline_ratio - UV.y) / height_scale;
	if (UV.y > baseline_ratio || sample_y < 0.0 || sample_y > baseline_ratio) {
		COLOR = vec4(0.0);
	} else {
		vec4 color = texture(TEXTURE, vec2(UV.x, sample_y));
		color.rgb *= mix(0.94, 1.10, motion);
		COLOR = color;
	}
}
"""
const SIGRIKA_RUNE_TEXTURES := {
	"aero_rune_blue": "res://assets/ui/runes/sigrika_rune_blue.png",
	"aero_rune_gold": "res://assets/ui/runes/sigrika_rune_gold.png",
}
const SIGRIKA_RUNE_TARGET_PER_TYPE := 4
const SIGRIKA_SPECIAL_ENERGY_MAX := 4
const RESONANCE_MAX_VALUES: Array[int] = [30, 45, 35, 40, 35, 50]
const SWAP_ANIM_SECONDS := 0.21
const CLEAR_ANIM_SECONDS := 0.34
const ELECTROMAGNETIC_MOVE_SECONDS := 0.40
const SPECIAL_CREATE_SECONDS := 0.13
const DROP_BASE_SECONDS := 0.18
const DROP_SECONDS_PER_ROW := 0.085
const DROP_COLUMN_STAGGER_SECONDS := 0.022
const DROP_SPAWN_DELAY_SECONDS := 0.06
const DROP_SPAWN_EXTRA_ROWS := 2
const DROP_LANDING_OVERSHOOT := 9.0
const DROP_SETTLE_SECONDS := 0.075
const POST_CLEAR_PAUSE_SECONDS := 0.02
const POST_DROP_PAUSE_SECONDS := 0.03
const CLEAR_DROP_OVERLAP_RATIO := 0.58
const ROSTER_SLOT_SIZE := 156.0
const MAIN_MENU_ROSTER_SLOT_SIZE := 190.0
const PIECE_CARD_SIZE := 260.0
const BATTLE_ROSTER_SLOT_SIZE := 156.0
const BATTLE_ROSTER_HIT_PADDING := 10.0
const BOSS_MAX_HP := 300
const BOSS_SEGMENTS := 3
const BOSS_INFINITE_HP_TEXT := "∞ / ∞"
const ATTACK_FLY_SECONDS := 0.32
const ATTACK_FLY_STAGGER_SECONDS := 0.016
const RUN_MAX_LIVES := 3
const RUN_MAX_ACTIONS := 30
const RUN_BATTLE_ACTION_RECOVERY := 5
const EFFECT_EXPLOSIVE_BOSS_DAMAGE := 30
const EFFECT_PHOTO_DAMAGE_PER_STACK := 5
const EFFECT_LIMITS := {
	"conductive": 6,
	"annihilation": 6,
	"explosive": 10,
	"photo": 10,
	"frost": 3,
	"aero": 3,
}
const EFFECT_NAMES := {
	"conductive": "电磁",
	"annihilation": "湮灭",
	"explosive": "聚爆",
	"photo": "光燥",
	"frost": "霜渐",
	"aero": "风蚀",
}
const RUN_TOTAL_FLOORS := 5
const RUN_MAP_ROWS := 5
const RUN_MAP_MIN_LANES := 2
const RUN_MAP_MAX_LANES := 3
const RUN_PRE_BOSS_MIN_SUPPLIES := 3
const RUN_PRE_BOSS_MAX_SUPPLIES := 5
const RUN_MIN_SHOPS := 2
const RUN_MAX_SHOPS := 3

var catalog: PieceCatalog = PieceCatalog.new()
var save: SaveManager
var board: BoardModel
var current_boss: Resource
var selected_cell: Vector2i = Vector2i(-1, -1)
var coletta_targeting_slot: int = -1
var coletta_target_orientation: String = "horizontal"
var coletta_hovered_cell: Vector2i = Vector2i(-1, -1)
var coletta_release_active: bool = false
var kakaro_targeting_slot: int = -1
var kakaro_hovered_cell: Vector2i = Vector2i(-1, -1)
var kakaro_release_active: bool = false
var kakaro_releases_remaining: int = 0
var chisaki_release_active: bool = false
var chisaki_releases_remaining: int = 0
var chisaki_activation_action_pending: bool = false
var daniya_release_active: bool = false
var daniya_actions_remaining: int = 0
var daniya_activation_action_pending: bool = false
var player_action_in_progress: bool = false
var sigrika_resonance_enhanced: bool = false
var sigrika_special_energy: int = 0
var sigrika_pending_sun_spirits: int = 0
var sigrika_targeting_slot: int = -1
var sigrika_hovered_cell: Vector2i = Vector2i(-1, -1)
var current_roster: PackedStringArray = PackedStringArray()
var score: int = 0
var combo: int = 0
var max_combo: int = 0
var boss_hp: int = BOSS_MAX_HP
var boss_max_hp: int = BOSS_MAX_HP
var boss_hp_infinite: bool = false
var boss_effects: Dictionary = {}
var boss_frozen: bool = false
var moves_since_enemy: int = 0
var skip_bonus_pending: bool = false
var suppress_next_enemy_effect: bool = false
var resonance_values: Array[int] = []
var emis_pending_random_lines: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stats: Dictionary = {
	"normal": 0,
	"special": 0,
	"combo": 0,
}
var run_active: bool = false
var run_state: Dictionary = {}
var current_run_node: Dictionary = {}
var pending_run_reward_items: Array = []

@onready var root: VBoxContainer = VBoxContainer.new()
var page: PanelContainer
var content_margin: MarginContainer
var screen_title: Label
var board_grid: GridContainer
var board_area: CenterContainer
var score_label: Label
var combo_label: Label
var boss_label: Label
var boss_name_label: Label
var boss_avatar: Label
var boss_avatar_texture: TextureRect
var boss_hp_label: Label
var boss_hp_segments: HBoxContainer
var boss_status_text: String = "团子大魔王：观察中"
var roster_bar: HBoxContainer
var current_screen: String = ""
var roster_slot_buttons: Array = []
var selected_roster_slot: int = 0
var has_selected_roster_slot: bool = false
var preserve_roster_slot_selection: bool = false
var roster_detail_label: Label
var is_animating_board: bool = false
var cheat_panel: PanelContainer
var cheat_cell_label: Label
var cheat_x_spin: SpinBox
var cheat_y_spin: SpinBox
var cheat_piece_option: OptionButton
var cheat_effect_option: OptionButton
var cheat_direction_option: OptionButton
var cheat_lock_spin: SpinBox
var cheat_effect_stack_option: OptionButton
var cheat_effect_stack_spin: SpinBox
var cheat_boss_effect_stack_spin: SpinBox
var cheat_resonance_slot_option: OptionButton
var cheat_resonance_spin: SpinBox
var cheat_pick_cell_pending: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	_apply_global_theme()
	rng.randomize()
	catalog.load_all()
	save = SaveManagerScript.new()
	save.load_save(catalog.get_default_roster())
	current_roster = _sanitize_roster(save.roster_ids)
	if save.roster_ids != current_roster:
		save.roster_ids = current_roster
		save.save()
	_ensure_default_pieces_in_bag()
	_build_root()
	_show_main_menu()

func _input(event: InputEvent) -> void:
	if sigrika_targeting_slot >= 0:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_cancel_sigrika_targeting()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_sigrika_targeting()
			get_viewport().set_input_as_handled()
			return
	if kakaro_targeting_slot >= 0:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_cancel_kakaro_targeting()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_kakaro_targeting()
			get_viewport().set_input_as_handled()
			return
	if coletta_targeting_slot >= 0:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_cancel_coletta_targeting()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_coletta_targeting()
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				coletta_target_orientation = "vertical" if coletta_target_orientation == "horizontal" else "horizontal"
				_set_boss_status(_coletta_targeting_hint(), "冷凝")
				_redraw_game()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		if current_screen == "game" and board != null:
			_toggle_cheat_panel()
			get_viewport().set_input_as_handled()

func _apply_global_theme() -> void:
	var theme: Theme = Theme.new()
	theme.set_font_size("font_size", "Label", 26)
	theme.set_font_size("font_size", "Button", 26)
	theme.set_font_size("font_size", "CheckButton", 24)
	theme.set_font_size("font_size", "OptionButton", 24)
	theme.set_font_size("font_size", "HSlider", 24)
	theme.set_font_size("font_size", "GridContainer", 24)
	theme.set_font_size("font_size", "PanelContainer", 24)
	set_theme(theme)

func _build_root() -> void:
	page = PanelContainer.new()
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.size = get_viewport_rect().size
	page.custom_minimum_size = get_viewport_rect().size
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin = MarginContainer.new()
	page.add_child(content_margin)
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.size = get_viewport_rect().size
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 28)
	content_margin.add_theme_constant_override("margin_top", 32)
	content_margin.add_theme_constant_override("margin_right", 28)
	content_margin.add_theme_constant_override("margin_bottom", 32)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(root)
	root.add_theme_constant_override("separation", 14)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, get_viewport_rect().size.y - 64.0)

func _clear_screen() -> void:
	if cheat_panel != null:
		cheat_panel.queue_free()
	cheat_panel = null
	cheat_cell_label = null
	cheat_x_spin = null
	cheat_y_spin = null
	cheat_piece_option = null
	cheat_effect_option = null
	cheat_direction_option = null
	cheat_lock_spin = null
	cheat_resonance_slot_option = null
	cheat_resonance_spin = null
	cheat_pick_cell_pending = false
	coletta_targeting_slot = -1
	coletta_target_orientation = "horizontal"
	coletta_hovered_cell = Vector2i(-1, -1)
	kakaro_targeting_slot = -1
	kakaro_hovered_cell = Vector2i(-1, -1)
	_set_page_margins(28, 32, 28, 32)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	# Screen changes can happen while an awaited board animation is still
	# finishing.  Do not leave the battle HUD variables pointing at controls
	# which will be freed at the end of this frame.
	board_area = null
	board_grid = null
	score_label = null
	combo_label = null
	boss_label = null
	boss_name_label = null
	boss_avatar = null
	boss_avatar_texture = null
	boss_hp_label = null
	boss_hp_segments = null
	roster_bar = null
	selected_cell = Vector2i(-1, -1)

func _add_title(text: String) -> Label:
	screen_title = Label.new()
	screen_title.text = text
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title.add_theme_font_size_override("font_size", 34)
	screen_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(screen_title)
	return screen_title

func _make_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _make_menu_button(text: String, callback: Callable) -> Button:
	var button: Button = _make_button(text, callback)
	button.custom_minimum_size = Vector2(0, 92)
	button.add_theme_font_size_override("font_size", 32)
	return button

func _show_main_menu() -> void:
	_clear_daniya_release_state()
	_clear_screen()
	current_screen = "menu"
	var viewport_size: Vector2 = get_viewport_rect().size
	var menu_margin_x: int = roundi(clamp(viewport_size.x * 0.02, 16.0, 48.0))
	var menu_margin_y: int = roundi(clamp(viewport_size.y * 0.025, 12.0, 36.0))
	_set_page_margins(menu_margin_x, menu_margin_y, menu_margin_x, menu_margin_y)
	root.add_theme_constant_override("separation", 0)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var roster_grid_width: float = _roster_slot_size() * 3.0 + 24.0
	var menu_layout: HBoxContainer = HBoxContainer.new()
	menu_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_layout.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.035, 28.0, 72.0)))
	menu_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(menu_layout)
	var roster_center: CenterContainer = CenterContainer.new()
	roster_center.custom_minimum_size = Vector2(roster_grid_width + 24.0, _roster_slot_size() * 2.0 + 24.0)
	roster_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	roster_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layout.add_child(roster_center)
	roster_slot_buttons = []
	roster_center.add_child(_make_roster_slots_bar(func(slot_index: int) -> void:
		selected_roster_slot = slot_index
		has_selected_roster_slot = true
		preserve_roster_slot_selection = true
		_show_roster_select()
	))
	var actions: VBoxContainer = VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	actions.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.28, 260.0, 520.0), 0)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_layout.add_child(actions)
	screen_title = Label.new()
	screen_title.text = "团子三消"
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title.add_theme_font_size_override("font_size", 60)
	screen_title.custom_minimum_size = Vector2(0, 92)
	actions.add_child(screen_title)
	var subtitle: Label = Label.new()
	subtitle.text = "最高分：%d" % save.high_score
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	actions.add_child(subtitle)
	actions.add_child(_make_spacer(16))
	actions.add_child(_make_menu_button("开始探索", Callable(self, "_start_run")))
	actions.add_child(_make_menu_button("开始游戏", Callable(self, "_start_game")))
	actions.add_child(_make_menu_button("设置", func() -> void: _show_settings(Callable(self, "_show_main_menu"))))
	actions.add_child(_make_menu_button("退出游戏", Callable(self, "_quit_game")))

func _quit_game() -> void:
	if save != null:
		save.save()
	get_tree().quit()

func _show_roster_select() -> void:
	_clear_screen()
	current_screen = "roster"
	var viewport_size: Vector2 = get_viewport_rect().size
	var roster_margin_x: int = roundi(clamp(viewport_size.x * 0.02, 14.0, 32.0))
	var roster_margin_y: int = roundi(clamp(viewport_size.y * 0.02, 8.0, 24.0))
	_set_page_margins(roster_margin_x, roster_margin_y, roster_margin_x, roster_margin_y)
	root.add_theme_constant_override("separation", 0)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var selector_layout: HBoxContainer = HBoxContainer.new()
	selector_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_layout.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.018, 12.0, 28.0)))
	selector_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(selector_layout)
	var all_pieces: Array = catalog.get_unlocked_pieces(save.unlocked_piece_ids)
	if not preserve_roster_slot_selection:
		has_selected_roster_slot = false
	preserve_roster_slot_selection = false
	var bag_panel: PanelContainer = PanelContainer.new()
	bag_panel.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.52, 360.0, 980.0), 0)
	bag_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_panel.size_flags_stretch_ratio = 1.6
	selector_layout.add_child(bag_panel)
	var selector_scroll: ScrollContainer = ScrollContainer.new()
	selector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_panel.add_child(selector_scroll)
	var list: GridContainer = GridContainer.new()
	list.columns = 2 if viewport_size.x < 1400.0 else 3
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_theme_constant_override("h_separation", 12)
	list.add_theme_constant_override("v_separation", 12)
	selector_scroll.add_child(list)
	var side_panel: VBoxContainer = VBoxContainer.new()
	side_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	side_panel.add_theme_constant_override("separation", roundi(clamp(viewport_size.y * 0.018, 8.0, 16.0)))
	side_panel.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.32, 280.0, 520.0), 0)
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_stretch_ratio = 0.9
	selector_layout.add_child(side_panel)
	screen_title = Label.new()
	screen_title.text = "选择初始出战团子"
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.052, 24.0, 34.0)))
	screen_title.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.075, 36.0, 58.0))
	side_panel.add_child(screen_title)
	roster_slot_buttons = []
	side_panel.add_child(_make_roster_slots_bar(func(slot_index: int) -> void:
		selected_roster_slot = slot_index
		has_selected_roster_slot = true
		_refresh_roster_slot_buttons()
		_update_roster_detail()
	))
	var available_count: int = 0
	for piece in all_pieces:
		var piece_id: String = String(piece.get("id"))
		if not _piece_matches_slot(piece, selected_roster_slot):
			continue
		available_count += 1
		var captured_piece: PieceDefinition = piece
		var captured_piece_id: String = piece_id
		var status_text: String = "已出战" if current_roster.has(piece_id) else ""
		var select_piece_callable: Callable = func() -> void:
			current_roster[selected_roster_slot] = captured_piece_id
			_refresh_roster_slot_buttons()
			_update_roster_detail(captured_piece)
		list.add_child(_make_piece_card(piece, select_piece_callable, status_text))
	if available_count == 0:
		var empty_label: Label = Label.new()
		empty_label.text = "无可用团子"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0, 180)
		empty_label.add_theme_font_size_override("font_size", 24)
		list.add_child(empty_label)
	roster_detail_label = Label.new()
	roster_detail_label.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.20, 72.0, 160.0))
	roster_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	roster_detail_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.036, 16.0, 24.0)))
	side_panel.add_child(roster_detail_label)
	_update_roster_detail()
	var save_button: Button = _make_button("保存", func() -> void:
		save.roster_ids = current_roster
		save.save()
		_show_main_menu()
	)
	save_button.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.10, 46.0, 68.0))
	side_panel.add_child(save_button)
	var back_button: Button = _make_button("返回", Callable(self, "_show_main_menu"))
	back_button.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.10, 46.0, 68.0))
	side_panel.add_child(back_button)

func _make_roster_slots_bar(callback: Callable) -> GridContainer:
	return _make_roster_display_grid(true, callback)

func _make_roster_display_grid(interactive: bool, callback: Callable = Callable()) -> GridContainer:
	var slots: GridContainer = GridContainer.new()
	slots.columns = 3
	slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slots.add_theme_constant_override("h_separation", 12)
	slots.add_theme_constant_override("v_separation", 12)
	var slot_size: float = _roster_slot_size()
	for index in range(6):
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(slot_size, slot_size)
		slot_button.add_theme_font_size_override("font_size", max(18, int(slot_size * 0.15)))
		slot_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_configure_roster_slot_button(slot_button, index)
		if interactive:
			var slot_callable: Callable = func(slot_index: int) -> void:
				callback.call(slot_index)
			slot_button.pressed.connect(slot_callable.bind(index))
		else:
			slot_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots.add_child(slot_button)
		if interactive:
			roster_slot_buttons.append(slot_button)
	return slots

func _make_piece_card(piece: PieceDefinition, callback: Callable, status_text: String = "") -> Button:
	var button: Button = Button.new()
	var card_size: float = _piece_card_size()
	button.custom_minimum_size = Vector2(card_size, card_size)
	button.add_theme_font_size_override("font_size", max(18, int(card_size * 0.092)))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = ""
	_apply_piece_button_style(button, piece)
	button.pressed.connect(callback)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_top = 10
	box.offset_right = -10
	box.offset_bottom = -10
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	button.add_child(box)
	var texture: Texture2D = _piece_preview_texture(piece)
	if texture != null:
		box.add_child(_make_piece_texture_rect(texture, Vector2(card_size * 0.64, card_size * 0.64)))
	var name_label: Label = _make_piece_ui_label(piece.display_name, max(16, int(card_size * 0.092)))
	name_label.custom_minimum_size = Vector2(0, 30)
	box.add_child(name_label)
	var meta_label: Label = _make_piece_ui_label("x%.1f  %s" % [piece.multiplier, piece.rarity], max(12, int(card_size * 0.062)))
	meta_label.custom_minimum_size = Vector2(0, 22)
	box.add_child(meta_label)
	if not status_text.is_empty():
		var status_label: Label = _make_piece_ui_label(status_text, max(12, int(card_size * 0.062)))
		status_label.custom_minimum_size = Vector2(0, 22)
		box.add_child(status_label)
	return button

func _refresh_roster_slot_buttons() -> void:
	for index in range(roster_slot_buttons.size()):
		var button: Button = roster_slot_buttons[index]
		_configure_roster_slot_button(button, index)

func _configure_roster_slot_button(button: Button, index: int) -> void:
	_clear_control_children(button)
	button.text = ""
	var id: String = ""
	if index >= 0 and index < current_roster.size():
		id = current_roster[index]
	var piece: PieceDefinition = catalog.get_piece(id)
	var active: bool = has_selected_roster_slot and index == selected_roster_slot
	_apply_piece_button_style(button, piece, active)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 8
	box.offset_right = -8
	box.offset_bottom = -8
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	button.add_child(box)
	var prefix: String = "出战%d" % (index + 1)
	if index >= 0 and index < SLOT_ATTRIBUTES.size():
		prefix = SLOT_ATTRIBUTES[index]
	var label_size: int = max(17, int(button.custom_minimum_size.x * 0.12))
	var title_label: Label = _make_piece_ui_label(prefix, label_size)
	title_label.custom_minimum_size = Vector2(0, max(22.0, button.custom_minimum_size.x * 0.15))
	box.add_child(title_label)
	var texture: Texture2D = _piece_preview_texture(piece, active)
	if texture != null:
		var icon_size: float = clamp(button.custom_minimum_size.x * 0.60, 52.0, 118.0)
		box.add_child(_make_piece_texture_rect(texture, Vector2(icon_size, icon_size)))
	var name_label: Label = _make_piece_ui_label(piece.display_name if piece != null else "空", label_size)
	name_label.custom_minimum_size = Vector2(0, max(24.0, button.custom_minimum_size.x * 0.15))
	box.add_child(name_label)

func _slot_text(index: int) -> String:
	var id: String = ""
	if index >= 0 and index < current_roster.size():
		id = current_roster[index]
	var piece: PieceDefinition = catalog.get_piece(id)
	var label: String = "空"
	if piece != null:
		label = piece.display_name
	var prefix: String = "出战%d" % (index + 1)
	if index >= 0 and index < SLOT_ATTRIBUTES.size():
		prefix = SLOT_ATTRIBUTES[index]
	return "%s\n%s" % [prefix, label]

func _update_roster_detail(piece: PieceDefinition = null) -> void:
	if roster_detail_label == null:
		return
	var target_piece: PieceDefinition = piece
	if target_piece == null and has_selected_roster_slot and selected_roster_slot < current_roster.size():
		target_piece = catalog.get_piece(current_roster[selected_roster_slot])
	if target_piece == null:
		roster_detail_label.text = "选择一个团子查看特殊消除效果。"
		return
	var effect_name: String = ""
	if not target_piece.default_special_effect_id.is_empty():
		var effect: SpecialEffectDefinition = catalog.get_effect(target_piece.default_special_effect_id)
		if effect != null:
			effect_name = effect.display_name
	var resonance_gain: String = target_piece.resonance_gain_description
	if resonance_gain.is_empty():
		resonance_gain = target_piece.resonance_gain_id
	if resonance_gain.is_empty():
		resonance_gain = "none"
	roster_detail_label.text = "攻击力：%d\n共鸣能量：%d\n能量获取方式：%s\n技能：%s\n%s\n属性：%s" % [
		target_piece.attack,
		target_piece.resonance_cost,
		resonance_gain,
		effect_name,
		target_piece.description,
		String(",").join(target_piece.tags),
	]

func _piece_matches_slot(piece: PieceDefinition, slot_index: int) -> bool:
	if piece == null or slot_index < 0 or slot_index >= SLOT_ATTRIBUTES.size():
		return false
	return piece.tags.has(SLOT_ATTRIBUTES[slot_index])

func _clear_control_children(control: Control) -> void:
	for child in control.get_children():
		control.remove_child(child)
		child.queue_free()

func _piece_preview_texture(piece: PieceDefinition, use_selected: bool = false) -> Texture2D:
	if piece == null:
		return null
	if use_selected and piece.selected_icon_texture != null:
		return piece.selected_icon_texture
	return piece.icon_texture

func _make_piece_texture_rect(texture: Texture2D, min_size: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = min_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon

func _make_piece_ui_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _apply_piece_button_style(button: Button, piece: PieceDefinition, active: bool = false) -> void:
	var bg_color: Color = Color(0.12, 0.12, 0.12, 0.18)
	var border_color: Color = Color(1, 1, 1, 0.20)
	if piece != null:
		var button_texture: Texture2D = _button_texture_for_piece_id(piece.id)
		if button_texture != null:
			_apply_piece_button_texture_style(button, button_texture, active)
			return
		bg_color = _button_background_color_for_piece(piece, active)
		border_color = _selection_color_for_piece_id(piece.id)
		if border_color == Color.TRANSPARENT:
			border_color = piece.theme_color.lightened(0.18)
		border_color.a = 0.78 if active else 0.36
	var border_width: int = 3 if active else 1
	var hover_bg: Color = bg_color.lightened(0.12)
	var pressed_bg: Color = bg_color.darkened(0.10)
	var disabled_bg: Color = bg_color
	disabled_bg.a *= 0.65
	button.add_theme_stylebox_override("normal", _make_piece_button_style(bg_color, border_color, border_width))
	button.add_theme_stylebox_override("hover", _make_piece_button_style(hover_bg, border_color, border_width))
	button.add_theme_stylebox_override("pressed", _make_piece_button_style(pressed_bg, border_color, border_width))
	button.add_theme_stylebox_override("focus", _make_piece_button_style(hover_bg, border_color, border_width))
	button.add_theme_stylebox_override("disabled", _make_piece_button_style(disabled_bg, border_color, border_width))

func _apply_piece_button_texture_style(button: Button, texture: Texture2D, active: bool) -> void:
	var normal: StyleBoxTexture = _make_piece_button_texture_style(texture, active)
	var hover: StyleBoxTexture = _make_piece_button_texture_style(texture, true)
	var pressed: StyleBoxTexture = _make_piece_button_texture_style(texture, true)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)

func _make_piece_button_texture_style(texture: Texture2D, active: bool) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.content_margin_left = 5
	style.content_margin_top = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
	style.expand_margin_left = 0
	style.expand_margin_top = 0
	style.expand_margin_right = 0
	style.expand_margin_bottom = 0
	if active:
		style.modulate_color = Color(1.18, 1.18, 1.18, 1)
	return style

func _button_texture_for_piece_id(piece_id: String) -> Texture2D:
	return _background_texture_for_piece_id(piece_id)

func _button_background_color_for_piece(piece: PieceDefinition, active: bool) -> Color:
	var color: Color = _background_color_for_piece_id(piece.id)
	if color == Color.TRANSPARENT:
		color = piece.theme_color
	color.a = 0.46 if active else 0.34
	return color

func _make_piece_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

func _show_settings(back_callback: Callable) -> void:
	_clear_screen()
	current_screen = "settings"
	root.add_theme_constant_override("separation", 14)
	_add_title("设置")
	root.add_child(_make_slider_row("音效", save.sfx_volume, func(value: float) -> void:
		save.sfx_volume = value
		save.save()
	))
	root.add_child(_make_slider_row("音乐", save.music_volume, func(value: float) -> void:
		save.music_volume = value
		save.save()
	))
	root.add_child(_make_button("返回", back_callback))

func _make_slider_row(label_text: String, value: float, callback: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 32)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(260, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(label)
	row.add_child(slider)
	return row

func _make_spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _start_run() -> void:
	run_active = true
	score = 0
	combo = 0
	max_combo = 0
	stats = {"normal": 0, "special": 0, "combo": 0}
	current_roster = _sanitize_roster(current_roster)
	run_state = {
		"floor": 1,
		"lives": RUN_MAX_LIVES,
		"actions": RUN_MAX_ACTIONS,
		"shells": 0,
		"collectibles": [],
		"completed_nodes": 0,
		"map_nodes": [],
		"available_node_ids": [],
		"current_node_id": "",
		"shop_items": [],
	}
	current_run_node = {}
	pending_run_reward_items = []
	_generate_floor_map(1)
	_show_run_map()

func _generate_floor_map(run_floor: int) -> void:
	var map_nodes: Array = []
	var rows: Array = []
	var middle_nodes: Array = []
	for row_index in range(RUN_MAP_ROWS):
		var row_nodes: Array = []
		var lane_count: int = rng.randi_range(RUN_MAP_MIN_LANES, RUN_MAP_MAX_LANES)
		if row_index == RUN_MAP_ROWS - 1:
			lane_count = rng.randi_range(RUN_PRE_BOSS_MIN_SUPPLIES, RUN_PRE_BOSS_MAX_SUPPLIES)
		for lane_index in range(lane_count):
			var node_type: String = _run_node_type_for_initial_map(row_index)
			var node: Dictionary = {
				"id": "f%d_r%d_l%d" % [run_floor, row_index, lane_index],
				"type": node_type,
				"title": _run_node_title(node_type, run_floor),
				"floor": run_floor,
				"row": row_index,
				"lane": lane_index,
				"links": [],
				"completed": false,
				"elite": node_type == "elite",
			}
			row_nodes.append(node)
			map_nodes.append(node)
			if row_index > 0 and row_index < RUN_MAP_ROWS - 1:
				middle_nodes.append(node)
		rows.append(row_nodes)
	_assign_shop_nodes(middle_nodes, run_floor)
	var boss_node: Dictionary = {
		"id": "f%d_boss" % run_floor,
		"type": "boss",
		"title": _run_node_title("boss", run_floor),
		"boss_id": _default_boss_id(),
		"floor": run_floor,
		"row": RUN_MAP_ROWS,
		"lane": 1,
		"links": [],
		"completed": false,
		"elite": true,
	}
	_assign_reachable_tree_links(rows)
	for node in rows[RUN_MAP_ROWS - 1]:
		node["links"] = [String(boss_node.get("id", ""))]
	map_nodes.append(boss_node)
	run_state["map_nodes"] = map_nodes
	run_state["available_node_ids"] = _ids_for_row(rows[0])
	run_state["current_node_id"] = ""

func _run_node_type_for_initial_map(row_index: int) -> String:
	if row_index == 0:
		return "battle"
	if row_index == RUN_MAP_ROWS - 1:
		return "supply"
	var node_types: Array[String] = ["battle", "battle", "elite", "event"]
	return node_types[rng.randi_range(0, node_types.size() - 1)]

func _assign_shop_nodes(candidates: Array, run_floor: int) -> void:
	if candidates.is_empty():
		return
	var shop_count: int = min(candidates.size(), rng.randi_range(RUN_MIN_SHOPS, RUN_MAX_SHOPS))
	candidates.shuffle()
	for index in range(shop_count):
		var node: Dictionary = candidates[index]
		node["type"] = "shop"
		node["title"] = _run_node_title("shop", run_floor)
		node["elite"] = false

func _assign_reachable_tree_links(rows: Array) -> void:
	for row in rows:
		for node in row:
			node["links"] = []
	for row_index in range(rows.size() - 1):
		var current_row: Array = rows[row_index]
		var next_row: Array = rows[row_index + 1]
		_assign_primary_tree_links(current_row, next_row)
		_trim_tree_row_links(current_row, next_row)

func _assign_primary_tree_links(current_row: Array, next_row: Array) -> void:
	var incoming_by_id: Dictionary = {}
	for next_node in next_row:
		incoming_by_id[String(next_node.get("id", ""))] = 0
	for source_index in range(current_row.size()):
		var target_index: int = _tree_target_index_for_source(source_index, current_row.size(), next_row.size())
		var target_id: String = String(next_row[target_index].get("id", ""))
		_add_tree_link(current_row[source_index], target_id, incoming_by_id)
	for next_index in range(next_row.size()):
		var target_id: String = String(next_row[next_index].get("id", ""))
		if int(incoming_by_id.get(target_id, 0)) > 0:
			continue
		var source_index: int = _tree_source_index_for_target(next_index, next_row.size(), current_row.size())
		_add_tree_link(current_row[source_index], target_id, incoming_by_id)

func _tree_source_index_for_target(target_index: int, target_count: int, source_count: int) -> int:
	if target_count <= 1 or source_count <= 1:
		return 0
	return clamp(roundi(float(target_index) * float(source_count - 1) / float(target_count - 1)), 0, source_count - 1)

func _tree_target_index_for_source(source_index: int, source_count: int, target_count: int) -> int:
	if source_count <= 1 or target_count <= 1:
		return 0
	return clamp(roundi(float(source_index) * float(target_count - 1) / float(source_count - 1)), 0, target_count - 1)

func _add_tree_link(source_node: Dictionary, target_id: String, incoming_by_id: Dictionary) -> void:
	if target_id.is_empty() or int(incoming_by_id.get(target_id, 0)) >= 2:
		return
	var links: Array = _node_links(source_node)
	if links.has(target_id) or links.size() >= 2:
		return
	links.append(target_id)
	links.sort_custom(func(a: String, b: String) -> bool: return a < b)
	source_node["links"] = links
	incoming_by_id[target_id] = int(incoming_by_id.get(target_id, 0)) + 1

func _trim_tree_row_links(current_row: Array, next_row: Array) -> void:
	var allowed_ids: Array = _ids_for_row(next_row)
	var incoming_by_id: Dictionary = {}
	for target_id in allowed_ids:
		incoming_by_id[target_id] = 0
	for node in current_row:
		var node_data: Dictionary = node
		var trimmed_links: Array = []
		for target_id in _node_links(node_data):
			var normalized_id: String = String(target_id)
			if not allowed_ids.has(normalized_id) or trimmed_links.has(normalized_id) or trimmed_links.size() >= 2:
				continue
			if int(incoming_by_id.get(normalized_id, 0)) >= 2:
				continue
			trimmed_links.append(normalized_id)
			incoming_by_id[normalized_id] = int(incoming_by_id.get(normalized_id, 0)) + 1
		node_data["links"] = trimmed_links

func _ids_for_row(row_nodes: Array) -> Array:
	var ids: Array = []
	for node in row_nodes:
		ids.append(String(node.get("id", "")))
	return ids

func _make_legacy_run_node(node_type: String, run_floor: int) -> Dictionary:
	return {
			"id": "",
			"type": node_type,
			"title": _run_node_title(node_type, run_floor),
			"floor": run_floor,
			"row": 0,
			"lane": 0,
			"links": [],
			"completed": false,
			"elite": node_type == "elite",
		}

func _run_node_title(node_type: String, run_floor: int) -> String:
	match node_type:
		"battle":
			return "第 %d 层 普通战斗" % run_floor
		"elite":
			return "第 %d 层 精英战斗" % run_floor
		"supply":
			return "第 %d 层 补给" % run_floor
		"shop":
			return "第 %d 层 商城" % run_floor
		"event":
			return "第 %d 层 事件" % run_floor
		"boss":
			return "第 %d 层 最终首领" % run_floor
	return "第 %d 层 未知节点" % run_floor

func _show_run_map() -> void:
	_clear_screen()
	current_screen = "run_map"
	_add_title("探索路线")
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 12)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(top_bar)
	var bag_button: Button = _make_button("藏品背包", Callable(self, "_show_run_collectible_bag"))
	bag_button.custom_minimum_size = Vector2(160, 60)
	bag_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_bar.add_child(bag_button)
	var summary: Label = Label.new()
	summary.text = "层数：%d / %d    生命：%d / %d    行动：%d / %d    贝币：%d    藏品：%d    分数：%d" % [
		int(run_state.get("floor", 1)),
		RUN_TOTAL_FLOORS,
		int(run_state.get("lives", RUN_MAX_LIVES)),
		RUN_MAX_LIVES,
		int(run_state.get("actions", RUN_MAX_ACTIONS)),
		RUN_MAX_ACTIONS,
		int(run_state.get("shells", 0)),
		_run_collectibles().size(),
		score,
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(summary)
	var settings_button: Button = _make_button("设置", Callable(self, "_show_run_pause"))
	settings_button.custom_minimum_size = Vector2(160, 60)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_bar.add_child(settings_button)
	var map_scroll: ScrollContainer = ScrollContainer.new()
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.custom_minimum_size = Vector2(0, clamp(get_viewport_rect().size.y * 0.84, 520.0, 860.0))
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(map_scroll)
	var canvas_size: Vector2 = Vector2(max(1600.0, get_viewport_rect().size.x * 1.16), map_scroll.custom_minimum_size.y)
	var node_positions: Dictionary = _run_map_node_positions(canvas_size)
	var map_canvas: Control = RunMapCanvasScript.new()
	map_canvas.custom_minimum_size = canvas_size
	map_canvas.size = canvas_size
	map_canvas.setup(_run_map_nodes(), _run_available_node_ids(), node_positions)
	map_scroll.add_child(map_canvas)
	for node in _run_map_nodes():
		var node_data: Dictionary = node
		var node_id: String = String(node_data.get("id", ""))
		var captured_node_id: String = node_id
		var button: Button = _make_run_map_node_button(node_data)
		button.position = node_positions.get(node_id, Vector2.ZERO) - button.custom_minimum_size * 0.5
		button.disabled = not _is_run_node_available(node_id) or bool(node_data.get("completed", false))
		button.pressed.connect(func() -> void:
			_enter_run_node_by_id(captured_node_id)
		)
		map_canvas.add_child(button)

func _run_node_hint(node_type: String) -> String:
	match node_type:
		"battle":
			return "胜利获得贝币，可能获得藏品"
		"elite":
			return "更强 Boss，固定获得藏品"
		"supply":
			return "获得一个补给包"
		"shop":
			return "花费贝币购买藏品"
		"event":
			return "选择一个随机事件"
		"boss":
			return "通关探索"
	return ""

func _enter_run_node_by_id(node_id: String) -> void:
	if not _is_run_node_available(node_id):
		_show_run_map()
		return
	var node: Dictionary = _find_run_node(node_id)
	if node.is_empty():
		_show_run_map()
		return
	_enter_run_node(node)

func _enter_run_node(node: Dictionary) -> void:
	current_run_node = node.duplicate(true)
	run_state["current_node_id"] = String(current_run_node.get("id", ""))
	match String(current_run_node.get("type", "")):
		"battle", "elite", "boss":
			_start_battle_node(current_run_node)
		"supply":
			_show_supply_node()
		"shop":
			run_state["shop_items"] = _generate_shop_items()
			_show_shop_node()
		"event":
			_show_event_node()
		_:
			_show_run_map()

func _start_game() -> void:
	run_active = false
	current_run_node = {}
	pending_run_reward_items = []
	score = 0
	combo = 0
	max_combo = 0
	current_boss = catalog.get_default_boss()
	_reset_boss_effects()
	boss_max_hp = _current_boss_base_hp()
	boss_hp = boss_max_hp
	boss_hp_infinite = true
	moves_since_enemy = 0
	skip_bonus_pending = false
	suppress_next_enemy_effect = false
	resonance_values = []
	emis_pending_random_lines = 0
	coletta_release_active = false
	kakaro_release_active = false
	kakaro_releases_remaining = 0
	chisaki_release_active = false
	chisaki_releases_remaining = 0
	chisaki_activation_action_pending = false
	_clear_daniya_release_state()
	player_action_in_progress = false
	sigrika_resonance_enhanced = false
	sigrika_special_energy = 0
	sigrika_pending_sun_spirits = 0
	sigrika_targeting_slot = -1
	sigrika_hovered_cell = Vector2i(-1, -1)
	for i in range(SLOT_ATTRIBUTES.size()):
		resonance_values.append(0)
	boss_status_text = "团子大魔王：观察中"
	stats = {"normal": 0, "special": 0, "combo": 0}
	current_roster = _sanitize_roster(current_roster)
	_show_game_shell("棋盘生成中...")
	call_deferred("_create_board")

func _start_battle_node(node: Dictionary) -> void:
	combo = 0
	max_combo = 0
	current_boss = catalog.get_boss(String(node.get("boss_id", "")))
	if current_boss == null:
		current_boss = catalog.get_default_boss()
	_reset_boss_effects()
	boss_max_hp = _run_boss_hp_for_node(node)
	boss_hp = boss_max_hp
	boss_hp_infinite = false
	moves_since_enemy = 0
	skip_bonus_pending = false
	suppress_next_enemy_effect = false
	resonance_values = []
	emis_pending_random_lines = 0
	coletta_release_active = false
	kakaro_release_active = false
	kakaro_releases_remaining = 0
	chisaki_release_active = false
	chisaki_releases_remaining = 0
	chisaki_activation_action_pending = false
	_clear_daniya_release_state()
	player_action_in_progress = false
	sigrika_resonance_enhanced = false
	sigrika_special_energy = 0
	sigrika_pending_sun_spirits = 0
	sigrika_targeting_slot = -1
	sigrika_hovered_cell = Vector2i(-1, -1)
	for i in range(SLOT_ATTRIBUTES.size()):
		resonance_values.append(0)
	var start_charge: int = int(_collectible_total("start_resonance"))
	if start_charge > 0:
		for i in range(SLOT_ATTRIBUTES.size()):
			resonance_values[i] = min(_resonance_cost(i), start_charge)
	coletta_release_active = _is_coletta_fully_charged()
	_activate_kakaro_release_if_full()
	boss_status_text = "探索战斗开始"
	current_roster = _sanitize_roster(current_roster)
	_show_game_shell("探索战斗准备中...")
	call_deferred("_create_board")

func _run_boss_hp_for_node(node: Dictionary) -> int:
	var run_floor: int = int(node.get("floor", int(run_state.get("floor", 1))))
	var node_type: String = String(node.get("type", "battle"))
	var hp: int = _current_boss_base_hp() + (run_floor - 1) * 45
	if node_type == "elite":
		hp += 90
	elif node_type == "boss":
		hp += 180
	return hp

func _default_boss_id() -> String:
	var boss: Resource = catalog.get_default_boss()
	return boss.id if boss != null else ""

func _current_boss_base_hp() -> int:
	if current_boss != null:
		return max(1, current_boss.max_hp)
	return BOSS_MAX_HP

func _current_boss_name() -> String:
	if current_boss != null and not current_boss.display_name.is_empty():
		return current_boss.display_name
	return "团子大魔王"

func _create_board() -> void:
	board = BoardModelScript.new()
	board.setup(catalog, current_roster)
	var sigrika_slot: int = _slot_index_for_piece_id(SIGRIKA_PIECE_ID)
	if sigrika_slot >= 0:
		sigrika_pending_sun_spirits = int(_resonance_value(sigrika_slot) / 2)
	_maintain_sigrika_board_state()
	_redraw_game()

func _show_game() -> void:
	_show_game_shell(boss_status_text)
	_redraw_game()

func _show_game_shell(boss_text: String = "团子大魔王：观察中") -> void:
	_clear_screen()
	current_screen = "game"
	var viewport_size: Vector2 = get_viewport_rect().size
	var game_margin_x: int = roundi(clamp(viewport_size.x * 0.018, 12.0, 24.0))
	var game_margin_y: int = roundi(clamp(viewport_size.y * 0.018, 8.0, 18.0))
	_set_page_margins(game_margin_x, game_margin_y, game_margin_x, game_margin_y)
	root.add_theme_constant_override("separation", 12)
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	var board_pixel_size: float = _board_cell_size() * float(BoardModel.WIDTH) + 2.0 * float(BoardModel.WIDTH - 1)
	var roster_grid_width: float = _battle_roster_hit_size() * 3.0 + 16.0
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.014, 8.0, 18.0)))
	top.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.12, 52.0, 72.0))
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(top)
	score_label = Label.new()
	combo_label = Label.new()
	score_label.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.14, 120.0, 260.0), 42)
	combo_label.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.12, 120.0, 220.0), 42)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(score_label)
	top.add_child(combo_label)
	var hud_spacer: Control = Control.new()
	hud_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hud_spacer)
	var pause_button: Button = _make_button("暂停", Callable(self, "_show_pause"))
	pause_button.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.12, 96.0, 180.0), clamp(viewport_size.y * 0.10, 46.0, 64.0))
	pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(pause_button)
	var battle_layout: HBoxContainer = HBoxContainer.new()
	battle_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_layout.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.014, 10.0, 24.0)))
	battle_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(battle_layout)
	board_area = CenterContainer.new()
	board_area.custom_minimum_size = Vector2(max(280.0, board_pixel_size), 0)
	board_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.size_flags_stretch_ratio = 1.8
	battle_layout.add_child(board_area)
	board_grid = GridContainer.new()
	board_grid.columns = BoardModel.WIDTH
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_grid.add_theme_constant_override("h_separation", 2)
	board_grid.add_theme_constant_override("v_separation", 2)
	board_area.add_child(board_grid)
	var right_column: VBoxContainer = VBoxContainer.new()
	right_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_column.add_theme_constant_override("separation", roundi(clamp(viewport_size.y * 0.018, 8.0, 18.0)))
	right_column.custom_minimum_size = Vector2(max(260.0, roster_grid_width + 24.0), 0)
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.size_flags_stretch_ratio = 1.0
	battle_layout.add_child(right_column)
	var boss_panel: PanelContainer = PanelContainer.new()
	boss_panel.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.48, 190.0, 420.0))
	boss_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boss_panel.size_flags_stretch_ratio = 1.0
	right_column.add_child(boss_panel)
	var boss_box: VBoxContainer = VBoxContainer.new()
	boss_box.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_box.add_theme_constant_override("separation", 18)
	boss_panel.add_child(boss_box)
	boss_avatar = Label.new()
	boss_avatar.text = "魔王"
	boss_avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_avatar.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.09, 92.0, 180.0), clamp(viewport_size.y * 0.14, 70.0, 150.0))
	boss_avatar.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.05, 22.0, 30.0)))
	if current_boss != null and current_boss.texture != null:
		boss_avatar_texture = TextureRect.new()
		boss_avatar_texture.texture = current_boss.texture
		boss_avatar_texture.custom_minimum_size = boss_avatar.custom_minimum_size
		boss_avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		boss_avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		boss_box.add_child(boss_avatar_texture)
	else:
		boss_avatar_texture = null
		boss_box.add_child(boss_avatar)
	boss_hp_segments = HBoxContainer.new()
	boss_hp_segments.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_hp_segments.add_theme_constant_override("separation", 4)
	boss_hp_segments.custom_minimum_size = Vector2(0, 18)
	boss_hp_segments.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(boss_hp_segments)
	boss_hp_label = Label.new()
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.028, 14.0, 20.0)))
	boss_box.add_child(boss_hp_label)
	var boss_text_box: VBoxContainer = VBoxContainer.new()
	boss_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(boss_text_box)
	boss_name_label = Label.new()
	boss_name_label.text = _current_boss_name()
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	boss_name_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.052, 22.0, 32.0)))
	boss_text_box.add_child(boss_name_label)
	boss_label = Label.new()
	boss_label.text = boss_text
	boss_status_text = boss_text
	boss_label.custom_minimum_size = Vector2(0, clamp(viewport_size.y * 0.28, 88.0, 180.0))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	boss_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.043, 18.0, 26.0)))
	boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	boss_text_box.add_child(boss_label)
	roster_bar = HBoxContainer.new()
	roster_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	roster_bar.add_theme_constant_override("separation", 12)
	roster_bar.custom_minimum_size = Vector2(0, _battle_roster_hit_size() * 2.0 + 28.0)
	roster_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	right_column.add_child(roster_bar)
	_build_cheat_panel()

func _redraw_game() -> void:
	# Awaited animation callbacks may resume after the player has left the
	# battle screen.  In that case all HUD controls belong to the old screen.
	if current_screen != "game":
		return
	if not is_instance_valid(score_label) or not is_instance_valid(combo_label):
		return
	if not is_instance_valid(board_grid) or not is_instance_valid(roster_bar):
		return
	if board == null or board.cells.is_empty():
		if is_instance_valid(score_label):
			score_label.text = "分数：%d  " % score
		if is_instance_valid(combo_label):
			combo_label.text = "Combo：%d  " % combo
		if is_instance_valid(boss_label):
			boss_label.text = "棋盘初始化失败"
		var error_label: Label = Label.new()
		error_label.text = "棋盘初始化失败：没有可用团子。请检查 data/pieces 或 PieceCatalog 默认配置。"
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		root.add_child(error_label)
		return
	score_label.text = "分数：%d%s  " % [score, "  行动：%d/%d" % [int(run_state.get("actions", RUN_MAX_ACTIONS)), RUN_MAX_ACTIONS] if run_active else ""]
	combo_label.text = "Combo：%d  " % combo
	_update_boss_hp_ui()
	for child in board_grid.get_children():
		# A redraw can run from the button's own signal callback, where immediate
		# free() is forbidden because the object is locked. Detach synchronously
		# so stale buttons stop rendering and cannot be found, then defer memory
		# release safely.
		board_grid.remove_child(child)
		child.queue_free()
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			board_grid.add_child(_make_cell_button(pos))
	for child in roster_bar.get_children():
		child.queue_free()
	roster_bar.add_child(_make_battle_roster_bar())
	_update_cheat_panel_from_selection()

func _update_boss_hp_ui() -> void:
	if is_instance_valid(boss_hp_label):
		var hp_text: String = BOSS_INFINITE_HP_TEXT if boss_hp_infinite else "%d / %d" % [max(0, boss_hp), boss_max_hp]
		boss_hp_label.text = "%s  防御:%d%s" % [hp_text, _effective_boss_defense(), _boss_effects_text()]
	if not is_instance_valid(boss_hp_segments):
		return
	for child in boss_hp_segments.get_children():
		child.queue_free()
	var segment_max: float = 1.0 if boss_hp_infinite else float(boss_max_hp) / float(BOSS_SEGMENTS)
	for index in range(BOSS_SEGMENTS):
		var segment: ProgressBar = ProgressBar.new()
		segment.min_value = 0
		segment.max_value = segment_max
		segment.value = segment_max if boss_hp_infinite else clamp(float(boss_hp) - segment_max * float(index), 0.0, segment_max)
		segment.show_percentage = false
		segment.custom_minimum_size = Vector2(0, 14)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boss_hp_segments.add_child(segment)

func _boss_phase() -> int:
	if boss_hp_infinite:
		return 3
	var hp_ratio: float = float(boss_hp) / float(boss_max_hp)
	if hp_ratio > 0.6667:
		return 3
	if hp_ratio > 0.3334:
		return 2
	return 1

func _reset_boss_effects() -> void:
	boss_effects = {}
	boss_frozen = false

func _boss_effect_stacks(effect_id: String) -> int:
	return int(boss_effects.get(effect_id, 0))

func _boss_effect_limit(effect_id: String) -> int:
	if not EFFECT_LIMITS.has(effect_id):
		return 0
	var limit: int = int(EFFECT_LIMITS[effect_id])
	var slot_index: int = _slot_index_for_piece_id(CHISAKI_PIECE_ID)
	if slot_index < 0 or catalog == null:
		return limit
	var chisaki: PieceDefinition = catalog.get_piece(CHISAKI_PIECE_ID)
	if chisaki == null or chisaki.passive_skill_id != "boss_effect_limit_bonus":
		return limit
	if effect_id == _param_text(chisaki.passive_skill_params, "exclude_effect_id", "frost"):
		return limit
	return limit + max(0, _param_int(chisaki.passive_skill_params, "amount", 3))

func _set_boss_effect_stacks(effect_id: String, amount: int) -> int:
	if not EFFECT_LIMITS.has(effect_id):
		return 0
	var limit: int = _boss_effect_limit(effect_id)
	var value: int = clamp(amount, 0, limit)
	if value <= 0:
		boss_effects.erase(effect_id)
	else:
		boss_effects[effect_id] = value
	if effect_id == "frost" and value >= limit:
		boss_frozen = true
	if effect_id == "explosive" and value >= limit and not daniya_release_active:
		_apply_direct_boss_damage(EFFECT_EXPLOSIVE_BOSS_DAMAGE, "聚爆")
		boss_effects.erase(effect_id)
		value = 0
	return value

func _add_boss_effect_stacks(effect_id: String, amount: int) -> int:
	return _set_boss_effect_stacks(effect_id, _boss_effect_stacks(effect_id) + amount)

func _add_player_boss_effect_stacks(effect_id: String, amount: int) -> int:
	if amount <= 0:
		return _boss_effect_stacks(effect_id)
	_charge_chisaki_for_boss_effect_attempt(amount)
	return _add_boss_effect_stacks(effect_id, amount)

func _charge_chisaki_for_boss_effect_attempt(attempted_stacks: int) -> void:
	if attempted_stacks <= 0 or chisaki_release_active:
		return
	var slot_index: int = _slot_index_for_piece_id(CHISAKI_PIECE_ID)
	if slot_index < 0 or catalog == null:
		return
	var chisaki: PieceDefinition = catalog.get_piece(CHISAKI_PIECE_ID)
	if chisaki == null or chisaki.resonance_gain_id != "apply_boss_effect_attempt":
		return
	_add_resonance(slot_index, attempted_stacks * max(1, _param_int(chisaki.resonance_gain_params, "amount", 1)), "向大魔王施加效应")

func _effective_boss_defense() -> int:
	var base_defense: int = 20 if current_boss == null else max(0, int(current_boss.defense))
	return max(0, roundi(float(base_defense) * (1.0 - 0.02 * float(_boss_effect_stacks("annihilation")))))

func _apply_direct_boss_damage(amount: int, source: String) -> int:
	if amount <= 0 or (not boss_hp_infinite and boss_hp <= 0):
		return 0
	if boss_hp_infinite:
		_set_boss_status("%s造成 %d 点直接伤害；Boss生命无限。" % [source, amount], source)
		return amount
	var actual: int = min(boss_hp, amount)
	boss_hp = max(0, boss_hp - amount)
	_update_boss_hp_ui()
	_set_boss_status("%s造成 %d 点直接伤害。" % [source, actual], source)
	return actual

func _transfer_cleared_effects_to_boss(targets: Array) -> void:
	for pos in targets:
		if board == null or not board.in_bounds(pos):
			continue
		var cell: Variant = board.get_cell(pos)
		if cell == null:
			continue
		var effects: Dictionary = cell.get("effects", {})
		for effect_id in EFFECT_LIMITS.keys():
			var amount: int = int(effects.get(effect_id, 0))
			if amount > 0:
				_add_player_boss_effect_stacks(String(effect_id), amount)

func _filter_clear_targets(targets: Array, resonance_clear: bool = false) -> Array:
	var result: Array = []
	for pos in _unique_in_bounds_targets(targets):
		var cell: Variant = board.get_cell(pos)
		if cell == null:
			continue
		if not board.is_piece_cell(cell):
			continue
		if board.effect_stacks(cell, "annihilation") >= int(EFFECT_LIMITS["annihilation"]) and not resonance_clear:
			continue
		if board.effect_stacks(cell, "frost") >= int(EFFECT_LIMITS["frost"]):
			board.set_effect_stacks(pos, "frost", 0)
			continue
		result.append(pos)
	return result

func _damage_boss(cleared_positions: Array, damage_multiplier: float = 1.0) -> void:
	if (not boss_hp_infinite and boss_hp <= 0) or cleared_positions.is_empty():
		return
	var damage: int = _calculate_boss_damage(cleared_positions, damage_multiplier)
	if boss_hp_infinite:
		_update_boss_hp_ui()
		_set_boss_status("团子命中%s，造成 %d 点伤害。Boss 血量无限。" % [_current_boss_name(), damage], "受击")
		return
	boss_hp = max(0, boss_hp - damage)
	_update_boss_hp_ui()
	if boss_hp <= 0:
		_set_boss_status("%s倒下了，关卡完成！" % _current_boss_name(), "胜利")
	else:
		_set_boss_status("团子命中%s，造成 %d 点伤害。" % [_current_boss_name(), damage], "受击")

func _calculate_boss_damage(cleared_positions: Array, damage_multiplier: float = 1.0) -> int:
	if cleared_positions.is_empty():
		return 0
	var defense: int = _effective_boss_defense()
	var defense_factor: float = 100.0 / (100.0 + float(defense))
	var base_damage: float = 0.0
	for target_pos in cleared_positions:
		var cell: Dictionary = board.get_cell(target_pos) if board != null else {}
		var piece: PieceDefinition = catalog.get_piece(String(cell.get("piece_id", ""))) if catalog != null else null
		var attack: int = 6 if piece == null else max(0, piece.attack)
		base_damage += float(attack) * defense_factor
	var collectible_multiplier: float = 1.0 + _collectible_total("damage_mult")
	return roundi(base_damage * max(0.0, damage_multiplier) * collectible_multiplier)

func _finish_battle() -> void:
	_clear_chisaki_release_state()
	_clear_daniya_release_state()
	if run_active:
		_on_run_battle_won()
		return
	save.high_score = max(save.high_score, score)
	save.save()
	_clear_screen()
	_add_title("关卡完成")
	var summary: Label = Label.new()
	summary.text = "大魔王血量归零\n得分：%d\n最高分：%d\n最高 Combo：%d" % [
		score,
		save.high_score,
		max_combo,
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(summary)
	root.add_child(_make_button("再来一局", Callable(self, "_start_game")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _make_battle_roster_bar() -> GridContainer:
	var slots: GridContainer = GridContainer.new()
	slots.columns = 3
	slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slots.add_theme_constant_override("h_separation", 8)
	slots.add_theme_constant_override("v_separation", 8)
	for index in range(SLOT_ATTRIBUTES.size()):
		slots.add_child(_make_battle_roster_slot(index))
	return slots

func _make_battle_roster_slot(index: int) -> Button:
	var piece: PieceDefinition = catalog.get_piece(current_roster[index]) if index < current_roster.size() else null
	var button: Button = Button.new()
	var slot_size: float = _battle_roster_slot_size()
	var hit_size: float = _battle_roster_hit_size()
	button.custom_minimum_size = Vector2(hit_size, hit_size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = ""
	button.disabled = is_animating_board
	_apply_battle_roster_button_style(button, _is_resonance_ready(index) or coletta_targeting_slot == index or kakaro_targeting_slot == index or sigrika_targeting_slot == index)
	button.pressed.connect(func() -> void: _on_battle_roster_pressed(index))
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = BATTLE_ROSTER_HIT_PADDING + 6.0
	box.offset_top = BATTLE_ROSTER_HIT_PADDING + 5.0
	box.offset_right = -BATTLE_ROSTER_HIT_PADDING - 6.0
	box.offset_bottom = -BATTLE_ROSTER_HIT_PADDING - 5.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)
	var texture: Texture2D = _piece_preview_texture(piece, _is_resonance_ready(index))
	var is_coletta: bool = piece != null and piece.id == COLETTA_PIECE_ID
	var is_phoebe: bool = piece != null and piece.id == PHOEBE_PIECE_ID
	var is_kakaro: bool = piece != null and piece.id == KAKARO_PIECE_ID
	var is_chisaki: bool = piece != null and piece.id == CHISAKI_PIECE_ID
	var is_sigrika: bool = piece != null and piece.id == SIGRIKA_PIECE_ID
	var is_emis: bool = piece != null and piece.id == EMIS_PIECE_ID
	var is_daniya: bool = piece != null and piece.id == DANIYA_PIECE_ID
	if texture != null:
		var icon_scale: float = 0.64 if is_coletta or is_phoebe or is_kakaro or is_chisaki or is_sigrika or is_emis or is_daniya else 0.78
		box.add_child(_make_piece_texture_rect(texture, Vector2(slot_size * icon_scale, slot_size * icon_scale)))
	if is_coletta:
		box.add_child(_make_coletta_resonance_bar(index, slot_size))
	elif is_phoebe:
		box.add_child(_make_phoebe_resonance_bar(index, slot_size))
	elif is_kakaro:
		box.add_child(_make_kakaro_resonance_bar(index, slot_size))
	elif is_chisaki:
		box.add_child(_make_chisaki_resonance_bar(index, slot_size))
	elif is_sigrika:
		box.add_child(_make_sigrika_resonance_bar(index, slot_size))
	elif is_emis:
		box.add_child(_make_emis_resonance_bar(index, slot_size))
	elif is_daniya:
		box.add_child(_make_daniya_resonance_bar(index, slot_size))
	else:
		var progress: ProgressBar = ProgressBar.new()
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.min_value = 0
		progress.max_value = _resonance_cost(index)
		progress.value = _resonance_value(index)
		progress.show_percentage = false
		progress.custom_minimum_size = Vector2(0, 10)
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(progress)
	var value_label: Label = Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", max(11, int(slot_size * 0.08)))
	value_label.text = "共鸣 %d/%d" % [_resonance_value(index), _resonance_cost(index)]
	if is_coletta and coletta_targeting_slot == index:
		value_label.text = "瞄准%s（滚轮切换）" % ("行" if coletta_target_orientation == "horizontal" else "列")
	elif is_coletta and coletta_release_active:
		value_label.text = "可释放 %d 次" % _resonance_value(index)
	elif is_kakaro and kakaro_targeting_slot == index:
		value_label.text = "瞄准十字"
	elif is_kakaro and kakaro_release_active:
		value_label.text = "可释放 %d 次" % kakaro_releases_remaining
	elif is_chisaki and chisaki_release_active:
		value_label.text = "效应转移：剩余 %d 次行动" % chisaki_releases_remaining
	elif is_sigrika:
		value_label.text = "普通 %d / 特殊 %d" % [_resonance_value(index), sigrika_special_energy]
		if sigrika_targeting_slot == index:
			value_label.text = "瞄准5×5范围"
		elif sigrika_special_energy >= 4:
			value_label.text = "共鸣解放"
	elif is_emis:
		var emis_value: int = _resonance_value(index)
		if emis_value >= _resonance_cost(index):
			value_label.text = "共鸣解放"
		else:
			value_label.text = "星 %d/4 · 进度 %d/10" % [floori(float(emis_value) / float(EMIS_STAR_COST)), emis_value % EMIS_STAR_COST]
	elif is_daniya and daniya_release_active:
		value_label.text = "聚爆引爆：剩余 %d 次行动" % daniya_actions_remaining
	elif _is_resonance_ready(index):
		value_label.text = "共鸣解放"
	box.add_child(value_label)
	return button

func _make_coletta_resonance_bar(index: int, slot_size: float) -> Control:
	var wrapper: Control = Control.new()
	var width: float = max(58.0, slot_size * 0.92)
	var height: float = max(10.0, width * COLETTA_RESONANCE_TEXTURE_SIZE.y / COLETTA_RESONANCE_TEXTURE_SIZE.x)
	wrapper.custom_minimum_size = Vector2(width, height)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	var remaining: int = _resonance_value(index)
	if coletta_release_active and remaining > 0:
		_make_coletta_ready_layers(wrapper, remaining)
		return wrapper
	_make_coletta_normal_background(wrapper)
	var resonance_ratio: float = clamp(float(_resonance_value(index)) / float(_resonance_cost(index)), 0.0, 1.0)
	if resonance_ratio > 0.0:
		var wave_track: Control = Control.new()
		wave_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.add_child(wave_track)
		var wave_clip: Control = Control.new()
		wave_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wave_clip.clip_contents = true
		wave_track.add_child(wave_clip)
		wrapper.resized.connect(func() -> void:
			var horizontal_inset: float = wrapper.size.x * COLETTA_WAVE_HORIZONTAL_INSET_RATIO
			wave_track.position = Vector2(horizontal_inset, 0.0)
			wave_track.size = Vector2(wrapper.size.x - horizontal_inset * 2.0, wrapper.size.y)
			wave_clip.position = Vector2.ZERO
			wave_clip.size = Vector2(wave_track.size.x * resonance_ratio, wave_track.size.y)
		)
		_make_coletta_wave_layers(wave_clip)
		wrapper.call_deferred("emit_signal", "resized")
	return wrapper

func _make_coletta_normal_background(parent: Control) -> void:
	_add_coletta_full_texture(parent, COLETTA_RESONANCE_EMPTY_COMPOSITE)

func _make_coletta_wave_layers(parent: Control) -> void:
	var wave: TextureRect = TextureRect.new()
	wave.texture = load(COLETTA_RESONANCE_WAVE_TEXTURE) as Texture2D
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wave.stretch_mode = TextureRect.STRETCH_SCALE
	wave.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var fade_shader: Shader = Shader.new()
	fade_shader.code = COLETTA_WAVE_FADE_SHADER
	var fade_material: ShaderMaterial = ShaderMaterial.new()
	fade_material.shader = fade_shader
	wave.material = fade_material
	parent.add_child(wave)
	parent.resized.connect(func() -> void:
		var full_bar: Control = parent.get_parent() as Control
		var wave_y: float = full_bar.size.y * COLETTA_WAVE_BASELINE_RATIO * (1.0 - COLETTA_WAVE_HEIGHT_SCALE)
		wave.position = Vector2(0.0, wave_y)
		wave.size = Vector2(full_bar.size.x, full_bar.size.y * COLETTA_WAVE_HEIGHT_SCALE)
	)
	parent.call_deferred("emit_signal", "resized")

func _make_coletta_ready_layers(parent: Control, remaining: int) -> void:
	var texture_path: String = String(COLETTA_RESONANCE_REMAINING_TEXTURES.get(remaining, COLETTA_RESONANCE_READY_COMPOSITE))
	_add_coletta_full_texture(parent, texture_path)

func _add_coletta_full_texture(parent: Control, texture_path: String) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		rect.position = Vector2.ZERO
		rect.size = parent.size
	)
	parent.call_deferred("emit_signal", "resized")

func _add_coletta_component(parent: Control, texture_path: String, logical_position: Vector2, component_scale: float = 1.0, flip_horizontal: bool = false) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.flip_h = flip_horizontal
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		var scale_factor: float = min(parent.size.x / COLETTA_RESONANCE_TEXTURE_SIZE.x, parent.size.y / COLETTA_RESONANCE_TEXTURE_SIZE.y)
		var offset: Vector2 = (parent.size - COLETTA_RESONANCE_TEXTURE_SIZE * scale_factor) * 0.5
		rect.position = offset + logical_position * scale_factor
		rect.size = texture.get_size() * scale_factor * component_scale
	)
	parent.call_deferred("emit_signal", "resized")

func _make_phoebe_resonance_bar(index: int, slot_size: float) -> Control:
	var wrapper: Control = Control.new()
	var width: float = round(max(58.0, slot_size * 0.92))
	var height: float = round(max(10.0, width * PHOEBE_RESONANCE_TEXTURE_SIZE.y / PHOEBE_RESONANCE_TEXTURE_SIZE.x))
	wrapper.custom_minimum_size = Vector2(width, height)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	if _is_resonance_ready(index):
		_add_phoebe_full_texture(wrapper, PHOEBE_RESONANCE_READY_BASE)
		_add_phoebe_wave_layer(wrapper, PHOEBE_RESONANCE_WAVE_READY, PHOEBE_READY_WAVE_BASELINE)
		return wrapper
	_add_phoebe_full_texture(wrapper, PHOEBE_RESONANCE_EMPTY)
	var resonance_ratio: float = clamp(float(_resonance_value(index)) / float(_resonance_cost(index)), 0.0, 1.0)
	if resonance_ratio > 0.0:
		_add_phoebe_progress_wave(wrapper, resonance_ratio)
	return wrapper

func _make_phoebe_redraw_wave_material(baseline_ratio: float) -> ShaderMaterial:
	var wave_shader: Shader = Shader.new()
	wave_shader.code = PHOEBE_REDRAW_WAVE_ANIMATION_SHADER
	var wave_material: ShaderMaterial = ShaderMaterial.new()
	wave_material.shader = wave_shader
	wave_material.set_shader_parameter("baseline_ratio", baseline_ratio)
	return wave_material

func _make_phoebe_wave_material(is_ready_state: bool) -> ShaderMaterial:
	var wave_shader: Shader = Shader.new()
	wave_shader.code = PHOEBE_WAVE_ANIMATION_SHADER
	var wave_material: ShaderMaterial = ShaderMaterial.new()
	wave_material.shader = wave_shader
	wave_material.set_shader_parameter("recolor_strength", 1.0 if is_ready_state else 0.0)
	return wave_material

func _add_phoebe_progress_wave(parent: Control, progress_ratio: float) -> void:
	var wave_clip: Control = Control.new()
	wave_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_clip.clip_contents = true
	parent.add_child(wave_clip)
	parent.resized.connect(func() -> void:
		var scale_factor: Vector2 = parent.size / PHOEBE_RESONANCE_TEXTURE_SIZE
		wave_clip.position = Vector2.ZERO
		var visible_width: float = PHOEBE_GOLD_WAVE_RECT.position.x + PHOEBE_GOLD_WAVE_RECT.size.x * progress_ratio
		wave_clip.size = Vector2(visible_width * scale_factor.x, parent.size.y)
	)
	_add_phoebe_wave_layer(wave_clip, PHOEBE_RESONANCE_WAVE_GOLD, PHOEBE_GOLD_WAVE_BASELINE, parent)
	parent.call_deferred("emit_signal", "resized")

func _add_phoebe_full_texture(parent: Control, texture_path: String) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	# Match the downsampling used by the other character resonance bars.
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		rect.position = Vector2.ZERO
		rect.size = parent.size.round()
	)
	parent.call_deferred("emit_signal", "resized")

func _add_phoebe_wave_layer(parent: Control, texture_path: String, baseline_ratio: float, size_source: Control = null) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.material = _make_phoebe_redraw_wave_material(baseline_ratio)
	parent.add_child(rect)
	var source: Control = size_source if size_source != null else parent
	source.resized.connect(func() -> void:
		rect.position = Vector2.ZERO
		rect.size = source.size.round()
	)
	source.call_deferred("emit_signal", "resized")

func _make_kakaro_resonance_bar(index: int, slot_size: float) -> Control:
	var wrapper: Control = Control.new()
	var width: float = max(58.0, slot_size * 0.92)
	var height: float = max(10.0, width * KAKARO_RESONANCE_TEXTURE_SIZE.y / KAKARO_RESONANCE_TEXTURE_SIZE.x)
	wrapper.custom_minimum_size = Vector2(width, height)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	if _is_resonance_ready(index):
		_add_kakaro_layer(wrapper, KAKARO_RESONANCE_READY_FRAME, Rect2(Vector2.ZERO, KAKARO_RESONANCE_TEXTURE_SIZE))
		_add_kakaro_ready_wave(wrapper, _kakaro_release_ratio())
		return wrapper
	_add_kakaro_layer(wrapper, KAKARO_RESONANCE_EMPTY, Rect2(Vector2.ZERO, KAKARO_RESONANCE_TEXTURE_SIZE))
	var resonance_ratio: float = clamp(float(_resonance_value(index)) / float(_resonance_cost(index)), 0.0, 1.0)
	if resonance_ratio > 0.0:
		_add_kakaro_progress_wave(wrapper, resonance_ratio)
	return wrapper

func _kakaro_release_ratio() -> float:
	var piece: PieceDefinition = catalog.get_piece(KAKARO_PIECE_ID)
	var release_count: int = max(1, _param_int(piece.resonance_effect_params, "release_count", 5)) if piece != null else 5
	return clamp(float(kakaro_releases_remaining) / float(release_count), 0.0, 1.0)

func _add_kakaro_ready_wave(parent: Control, remaining_ratio: float) -> void:
	if remaining_ratio <= 0.0:
		return
	var wave_track: Control = Control.new()
	wave_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wave_track)
	var wave_clip: Control = Control.new()
	wave_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_clip.clip_contents = true
	wave_track.add_child(wave_clip)
	parent.resized.connect(func() -> void:
		var scale_factor: Vector2 = parent.size / KAKARO_RESONANCE_TEXTURE_SIZE
		wave_track.position = KAKARO_READY_WAVE_RECT.position * scale_factor
		wave_track.size = KAKARO_READY_WAVE_RECT.size * scale_factor
		wave_clip.position = Vector2.ZERO
		wave_clip.size = Vector2(wave_track.size.x * remaining_ratio, wave_track.size.y)
	)
	_add_kakaro_ready_wave_to_clip(wave_clip)
	parent.call_deferred("emit_signal", "resized")

func _add_kakaro_ready_wave_to_clip(parent: Control) -> void:
	var texture: Texture2D = load(KAKARO_RESONANCE_READY_WAVE) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.material = _make_kakaro_wave_material(false)
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		var full_track: Control = parent.get_parent() as Control
		rect.position = Vector2.ZERO
		rect.size = full_track.size
	)
	parent.call_deferred("emit_signal", "resized")

func _make_kakaro_wave_material(is_ready_state: bool) -> ShaderMaterial:
	var wave_shader: Shader = Shader.new()
	wave_shader.code = PHOEBE_WAVE_ANIMATION_SHADER
	var wave_material: ShaderMaterial = ShaderMaterial.new()
	wave_material.shader = wave_shader
	wave_material.set_shader_parameter("recolor_strength", 1.0 if is_ready_state else 0.0)
	wave_material.set_shader_parameter("top_color", Color(0.72, 0.76, 1.0, 1.0))
	wave_material.set_shader_parameter("bottom_color", Color(0.57, 0.24, 0.95, 1.0))
	return wave_material

func _add_kakaro_progress_wave(parent: Control, progress_ratio: float) -> void:
	var wave_track: Control = Control.new()
	wave_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wave_track)
	var wave_clip: Control = Control.new()
	wave_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_clip.clip_contents = true
	wave_track.add_child(wave_clip)
	parent.resized.connect(func() -> void:
		var scale_factor: Vector2 = parent.size / KAKARO_RESONANCE_TEXTURE_SIZE
		wave_track.position = KAKARO_WAVE_RECT.position * scale_factor
		wave_track.size = KAKARO_WAVE_RECT.size * scale_factor
		wave_clip.position = Vector2.ZERO
		wave_clip.size = Vector2(wave_track.size.x * progress_ratio, wave_track.size.y)
	)
	_add_kakaro_wave_to_clip(wave_clip)
	parent.call_deferred("emit_signal", "resized")

func _add_kakaro_wave_to_clip(parent: Control) -> void:
	var texture: Texture2D = load(KAKARO_RESONANCE_WAVE) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.material = _make_kakaro_wave_material(false)
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		var full_track: Control = parent.get_parent() as Control
		rect.position = Vector2.ZERO
		rect.size = full_track.size
	)
	parent.call_deferred("emit_signal", "resized")

func _add_kakaro_layer(parent: Control, texture_path: String, logical_rect: Rect2, layer_material: Material = null) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.material = layer_material
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		var scale_factor: Vector2 = parent.size / KAKARO_RESONANCE_TEXTURE_SIZE
		rect.position = logical_rect.position * scale_factor
		rect.size = logical_rect.size * scale_factor
	)
	parent.call_deferred("emit_signal", "resized")

func _make_chisaki_resonance_bar(index: int, slot_size: float) -> Control:
	var wrapper: Control = Control.new()
	var width: float = max(58.0, slot_size * 0.92)
	var height: float = max(10.0, width * CHISAKI_RESONANCE_TEXTURE_SIZE.y / CHISAKI_RESONANCE_TEXTURE_SIZE.x)
	wrapper.custom_minimum_size = Vector2(width, height)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	if chisaki_release_active:
		var state_index: int = clamp(chisaki_releases_remaining - 1, 0, CHISAKI_RESONANCE_RELEASE_ACTIONS.size() - 1)
		_add_chisaki_full_texture(wrapper, CHISAKI_RESONANCE_RELEASE_ACTIONS[state_index])
		return wrapper
	if _resonance_value(index) >= _resonance_cost(index):
		_add_chisaki_full_texture(wrapper, CHISAKI_RESONANCE_READY)
		return wrapper
	_add_chisaki_full_texture(wrapper, CHISAKI_RESONANCE_EMPTY)
	var resonance_ratio: float = clamp(float(_resonance_value(index)) / float(_resonance_cost(index)), 0.0, 1.0)
	if resonance_ratio > 0.0:
		_add_chisaki_progress_wave(wrapper, resonance_ratio)
	return wrapper

func _add_chisaki_full_texture(parent: Control, texture_path: String) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		rect.position = Vector2.ZERO
		rect.size = parent.size
	)
	parent.call_deferred("emit_signal", "resized")

func _add_chisaki_progress_wave(parent: Control, progress_ratio: float) -> void:
	var wave_track: Control = Control.new()
	wave_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wave_track)
	var wave_clip: Control = Control.new()
	wave_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_clip.clip_contents = true
	wave_track.add_child(wave_clip)
	parent.resized.connect(func() -> void:
		var scale_factor: Vector2 = parent.size / CHISAKI_RESONANCE_TEXTURE_SIZE
		wave_track.position = CHISAKI_WAVE_RECT.position * scale_factor
		wave_track.size = CHISAKI_WAVE_RECT.size * scale_factor
		wave_clip.position = Vector2.ZERO
		wave_clip.size = Vector2(wave_track.size.x * progress_ratio, wave_track.size.y)
	)
	_add_chisaki_wave_to_clip(wave_clip)
	parent.call_deferred("emit_signal", "resized")

func _add_chisaki_wave_to_clip(parent: Control) -> void:
	var texture: Texture2D = load(CHISAKI_RESONANCE_WAVE) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.material = _make_phoebe_wave_material(false)
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		var full_track: Control = parent.get_parent() as Control
		rect.position = Vector2.ZERO
		rect.size = full_track.size
	)
	parent.call_deferred("emit_signal", "resized")

func _make_sigrika_resonance_bar(index: int, slot_size: float) -> Control:
	var wrapper: Control = Control.new()
	var width: float = max(58.0, slot_size * 0.92)
	var height: float = max(10.0, width * SIGRIKA_RESONANCE_TEXTURE_SIZE.y / SIGRIKA_RESONANCE_TEXTURE_SIZE.x)
	wrapper.custom_minimum_size = Vector2(width, height)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	var normal_energy: int = clamp(_resonance_value(index), 0, 4)
	var special_energy: int = clamp(sigrika_special_energy, 0, 4)
	var total_energy: int = clamp(normal_energy + special_energy, 0, 4)
	_add_sigrika_full_texture(wrapper, SIGRIKA_RESONANCE_NORMAL[total_energy])
	if special_energy > 0:
		var clip: Control = Control.new()
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		wrapper.add_child(clip)
		wrapper.resized.connect(func() -> void:
			clip.position = Vector2.ZERO
			clip.size = Vector2(wrapper.size.x * float(special_energy) / 4.0, wrapper.size.y)
		)
		var enhanced_rect: TextureRect = TextureRect.new()
		enhanced_rect.texture = load(SIGRIKA_RESONANCE_ENHANCED[total_energy]) as Texture2D
		enhanced_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enhanced_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		enhanced_rect.stretch_mode = TextureRect.STRETCH_SCALE
		enhanced_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		enhanced_rect.material = _make_sigrika_resonance_material()
		clip.add_child(enhanced_rect)
		wrapper.resized.connect(func() -> void:
			enhanced_rect.position = Vector2.ZERO
			enhanced_rect.size = wrapper.size
		)
		wrapper.call_deferred("emit_signal", "resized")
	return wrapper

func _add_sigrika_full_texture(parent: Control, texture_path: String) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.material = _make_sigrika_resonance_material()
	parent.add_child(rect)
	parent.resized.connect(func() -> void:
		rect.position = Vector2.ZERO
		rect.size = parent.size
	)
	parent.call_deferred("emit_signal", "resized")

func _make_sigrika_resonance_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SIGRIKA_RESONANCE_ANIMATION_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material

func _make_emis_resonance_bar(index: int, slot_size: float) -> Control:
	var wrapper: Control = Control.new()
	var width: float = max(58.0, slot_size * 0.92)
	var height: float = max(10.0, width * EMIS_RESONANCE_TEXTURE_SIZE.y / EMIS_RESONANCE_TEXTURE_SIZE.x)
	wrapper.custom_minimum_size = Vector2(width, height)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	var value: int = clamp(_resonance_value(index), 0, EMIS_STAR_COST * EMIS_STAR_MAX)
	if value >= EMIS_STAR_COST * EMIS_STAR_MAX:
		_add_chisaki_full_texture(wrapper, EMIS_RESONANCE_READY)
		return wrapper
	var progress: int = value % EMIS_STAR_COST
	if progress > 0:
		_add_emis_progress_wave(wrapper, float(progress) / float(EMIS_STAR_COST))
	var stars: int = clamp(floori(float(value) / float(EMIS_STAR_COST)), 0, EMIS_RESONANCE_STAR_BACKGROUNDS.size() - 1)
	_add_chisaki_full_texture(wrapper, EMIS_RESONANCE_STAR_BACKGROUNDS[stars])
	return wrapper

func _add_emis_progress_wave(parent: Control, progress_ratio: float) -> void:
	var texture: Texture2D = load(EMIS_RESONANCE_WAVE) as Texture2D
	if texture == null:
		return
	var clip: Control = Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	parent.add_child(clip)
	var wave: TextureRect = TextureRect.new()
	wave.texture = texture
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wave.stretch_mode = TextureRect.STRETCH_SCALE
	wave.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	wave.material = _make_sigrika_resonance_material()
	clip.add_child(wave)
	parent.resized.connect(func() -> void:
		var scale_factor: Vector2 = parent.size / EMIS_RESONANCE_TEXTURE_SIZE
		var track_position: Vector2 = EMIS_WAVE_RECT.position * scale_factor
		var track_size: Vector2 = EMIS_WAVE_RECT.size * scale_factor
		clip.position = track_position
		clip.size = Vector2(track_size.x * progress_ratio, track_size.y)
		wave.position = -track_position
		wave.size = parent.size
	)
	parent.call_deferred("emit_signal", "resized")

func _make_daniya_resonance_bar(index: int, slot_size: float) -> Control:
	var wrapper: Control = Control.new()
	var width: float = max(58.0, slot_size * 0.92)
	var height: float = max(10.0, width * DANIYA_RESONANCE_TEXTURE_SIZE.y / DANIYA_RESONANCE_TEXTURE_SIZE.x)
	wrapper.custom_minimum_size = Vector2(width, height)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	if daniya_release_active:
		if daniya_actions_remaining >= 5:
			_add_chisaki_full_texture(wrapper, DANIYA_RESONANCE_ACTIVE_BASE)
			_add_daniya_clipped_layer(wrapper, DANIYA_RESONANCE_ACTIVE_WAVE, 1.0)
		else:
			_add_chisaki_full_texture(wrapper, DANIYA_RESONANCE_EXHAUSTED)
			var remaining_ratio: float = clamp(float(daniya_actions_remaining) / 5.0, 0.0, 1.0)
			_add_daniya_clipped_layer(wrapper, DANIYA_RESONANCE_ACTIVE_BASE, remaining_ratio)
			_add_daniya_clipped_layer(wrapper, DANIYA_RESONANCE_ACTIVE_WAVE, remaining_ratio)
		return wrapper
	if _resonance_value(index) >= _resonance_cost(index):
		_add_chisaki_full_texture(wrapper, DANIYA_RESONANCE_READY_BASE)
		_add_daniya_clipped_layer(wrapper, DANIYA_RESONANCE_WAVE, 1.0)
		return wrapper
	_add_chisaki_full_texture(wrapper, DANIYA_RESONANCE_EMPTY)
	var ratio: float = clamp(float(_resonance_value(index)) / float(_resonance_cost(index)), 0.0, 1.0)
	if ratio > 0.0:
		_add_daniya_clipped_layer(wrapper, DANIYA_RESONANCE_WAVE, ratio)
	return wrapper

func _add_daniya_clipped_layer(parent: Control, texture_path: String, ratio: float) -> void:
	if ratio <= 0.0:
		return
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var clip: Control = Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	parent.add_child(clip)
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if texture_path in [DANIYA_RESONANCE_WAVE, DANIYA_RESONANCE_ACTIVE_WAVE]:
		rect.material = _make_daniya_wave_material()
	clip.add_child(rect)
	parent.resized.connect(func() -> void:
		clip.position = Vector2.ZERO
		clip.size = Vector2(parent.size.x * ratio, parent.size.y)
		rect.position = Vector2.ZERO
		rect.size = parent.size
	)
	parent.call_deferred("emit_signal", "resized")

func _make_daniya_wave_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = DANIYA_WAVE_ANIMATION_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("baseline_ratio", 0.60)
	return material

func _set_sigrika_resonance_enhanced(enabled: bool) -> void:
	if sigrika_resonance_enhanced == enabled:
		return
	sigrika_resonance_enhanced = enabled
	_redraw_game()

func _apply_battle_roster_button_style(button: Button, active: bool) -> void:
	var normal: StyleBoxFlat = _make_transparent_button_style(0.0)
	var hover: StyleBoxFlat = _make_transparent_button_style(0.08)
	var pressed: StyleBoxFlat = _make_transparent_button_style(0.14)
	var focus: StyleBoxFlat = _make_transparent_button_style(0.10)
	var disabled: StyleBoxFlat = _make_transparent_button_style(0.0)
	if active:
		normal = _make_transparent_button_style(0.10)
		focus = _make_transparent_button_style(0.16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)

func _make_transparent_button_style(alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, alpha)
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _on_battle_roster_pressed(slot_index: int) -> void:
	if is_animating_board:
		return
	var piece: PieceDefinition = catalog.get_piece(current_roster[slot_index]) if slot_index < current_roster.size() else null
	if sigrika_targeting_slot >= 0 and (piece == null or piece.id != SIGRIKA_PIECE_ID):
		sigrika_targeting_slot = -1
		sigrika_hovered_cell = Vector2i(-1, -1)
	if piece != null and piece.id == COLETTA_PIECE_ID:
		if kakaro_targeting_slot >= 0:
			kakaro_targeting_slot = -1
			kakaro_hovered_cell = Vector2i(-1, -1)
		if coletta_targeting_slot == slot_index:
			_cancel_coletta_targeting()
			return
		if not _is_resonance_ready(slot_index):
			_set_boss_status("柯莱塔回路：%d/%d，充满后才可释放" % [_resonance_value(slot_index), _resonance_cost(slot_index)], "共鸣")
			return
		coletta_targeting_slot = slot_index
		coletta_target_orientation = "horizontal"
		coletta_hovered_cell = Vector2i(-1, -1)
		selected_cell = Vector2i(-1, -1)
		_set_boss_status(_coletta_targeting_hint(), "冷凝")
		_redraw_game()
		return
	if piece != null and piece.id == KAKARO_PIECE_ID:
		if coletta_targeting_slot >= 0:
			coletta_targeting_slot = -1
			coletta_hovered_cell = Vector2i(-1, -1)
		if kakaro_targeting_slot == slot_index:
			_cancel_kakaro_targeting()
			return
		if not _is_resonance_ready(slot_index):
			_set_boss_status("卡卡罗回路：%d/%d，充满后才可释放" % [_resonance_value(slot_index), _resonance_cost(slot_index)], "共鸣")
			return
		kakaro_targeting_slot = slot_index
		kakaro_hovered_cell = Vector2i(-1, -1)
		selected_cell = Vector2i(-1, -1)
		_set_boss_status("卡卡罗瞄准：点击格子清除十字；右键或 Esc 取消", "导电")
		_redraw_game()
		return
	if piece != null and piece.id == SIGRIKA_PIECE_ID:
		if sigrika_targeting_slot == slot_index:
			_cancel_sigrika_targeting()
			return
		if not _is_resonance_ready(slot_index):
			_set_boss_status("西格莉卡特殊能量：%d/4" % sigrika_special_energy, "气动")
			return
		sigrika_targeting_slot = slot_index
		sigrika_hovered_cell = Vector2i(-1, -1)
		selected_cell = Vector2i(-1, -1)
		_set_boss_status("西格莉卡瞄准：点击格子清除5×5范围；右键或 Esc 取消", "气动")
		_redraw_game()
		return
	if not _is_resonance_ready(slot_index):
		_set_boss_status("%s回路：%d/%d" % [SLOT_ATTRIBUTES[slot_index], _resonance_value(slot_index), _resonance_cost(slot_index)], "共鸣")
		return
	_release_resonance(slot_index)

func _make_cell_button(pos: Vector2i) -> Button:
	var cell: Variant = board.get_cell(pos)
	var piece: PieceDefinition = null if cell == null or not board.is_piece_cell(cell) else catalog.get_piece(String(cell.get("piece_id", "")))
	var echo: EchoDefinition = null if cell == null or not board.is_echo_cell(cell) else catalog.get_echo(String(cell.get("echo_id", "")))
	var button: Button = Button.new()
	var cell_size: float = _board_cell_size()
	button.custom_minimum_size = Vector2(cell_size, cell_size)
	button.add_theme_font_size_override("font_size", max(18, int(cell_size * 0.34)))
	button.set_meta("board_pos", pos)
	button.pivot_offset = button.custom_minimum_size * 0.5
	if cell == null:
		button.text = ""
		button.disabled = true
		button.modulate = Color(1, 1, 1, 0)
		return button
	if echo != null and echo.texture != null:
		button.text = ""
		_apply_board_entity_button_style(button)
		_add_board_entity_icon(button, echo.texture, cell_size)
	elif piece != null and piece.icon_texture != null:
		button.text = ""
		_add_piece_background_to_button(button, String(cell["piece_id"]), cell_size)
		_add_piece_icon_to_button(button, _icon_texture_for_cell(piece, pos), cell, piece, cell_size)
	else:
		_apply_piece_background(button, String(cell["piece_id"]))
		button.text = _cell_text(cell, piece)
	_add_effect_badge_to_button(button, cell, cell_size)
	_add_sigrika_rune_to_button(button, cell, cell_size)
	if piece != null and piece.icon_texture == null:
		button.modulate = piece.theme_color
	if piece != null and board.is_immovable(pos):
		button.text += "\n锁"
	if board.effect_stacks(cell, "frost") >= int(EFFECT_LIMITS["frost"]):
		button.modulate = Color(0.65, 0.85, 1.0, 0.82)
	elif board.effect_stacks(cell, "annihilation") >= int(EFFECT_LIMITS["annihilation"]):
		button.modulate = Color(0.62, 0.42, 0.62, 0.82)
	if pos == selected_cell and (piece == null or piece.icon_texture == null):
		button.text = "[%s]" % button.text
	if pos == selected_cell:
		_add_selection_corners_to_button(button, String(cell.get("piece_id", "")), cell_size)
	if _is_coletta_preview_pos(pos):
		_add_coletta_target_overlay(button)
	if _is_kakaro_preview_pos(pos):
		_add_kakaro_target_overlay(button)
	if _is_sigrika_preview_pos(pos):
		_add_sigrika_target_overlay(button)
	button.mouse_entered.connect(func() -> void: _on_cell_hovered(pos))
	button.pressed.connect(func() -> void: _on_cell_pressed(pos))
	return button

func _apply_board_entity_button_style(button: Button) -> void:
	var transparent: StyleBoxEmpty = StyleBoxEmpty.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, transparent)

func _add_board_entity_icon(button: Button, texture: Texture2D, cell_size: float) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset: float = round(cell_size * 0.03)
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	button.add_child(icon)
	return icon

func _add_sigrika_rune_to_button(button: Button, cell: Dictionary, cell_size: float) -> void:
	var rune_id: String = String(cell.get("rune_id", ""))
	if rune_id.is_empty() or not SIGRIKA_RUNE_TEXTURES.has(rune_id):
		return
	var texture: Texture2D = load(String(SIGRIKA_RUNE_TEXTURES[rune_id])) as Texture2D
	if texture == null:
		return
	var rune: TextureRect = TextureRect.new()
	rune.texture = texture
	rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rune.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rune.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rune.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rune.position = Vector2(cell_size * 0.56, cell_size * 0.03)
	rune.size = Vector2(cell_size * 0.38, cell_size * 0.38)
	rune.z_index = 12
	button.add_child(rune)

func _add_coletta_target_overlay(button: Button) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.35, 0.9, 1.0, 0.28)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(overlay)

func _is_coletta_preview_pos(pos: Vector2i) -> bool:
	if coletta_targeting_slot < 0 or coletta_hovered_cell == Vector2i(-1, -1):
		return false
	return pos.y == coletta_hovered_cell.y if coletta_target_orientation == "horizontal" else pos.x == coletta_hovered_cell.x

func _on_cell_hovered(pos: Vector2i) -> void:
	if coletta_targeting_slot >= 0 and coletta_hovered_cell != pos:
		coletta_hovered_cell = pos
		_redraw_game()
	elif kakaro_targeting_slot >= 0 and kakaro_hovered_cell != pos:
		kakaro_hovered_cell = pos
		_redraw_game()
	elif sigrika_targeting_slot >= 0 and sigrika_hovered_cell != pos:
		sigrika_hovered_cell = pos
		_redraw_game()

func _add_kakaro_target_overlay(button: Button) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.68, 0.36, 1.0, 0.30)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(overlay)

func _is_kakaro_preview_pos(pos: Vector2i) -> bool:
	if kakaro_targeting_slot < 0 or kakaro_hovered_cell == Vector2i(-1, -1):
		return false
	return abs(pos.x - kakaro_hovered_cell.x) + abs(pos.y - kakaro_hovered_cell.y) <= 1

func _add_sigrika_target_overlay(button: Button) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.25, 0.75, 1.0, 0.28)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(overlay)

func _is_sigrika_preview_pos(pos: Vector2i) -> bool:
	return sigrika_targeting_slot >= 0 and sigrika_hovered_cell != Vector2i(-1, -1) and _square_targets(sigrika_hovered_cell, 2).has(pos)

func _add_selection_corners_to_button(button: Button, piece_id: String, cell_size: float) -> void:
	var color: Color = _selection_color_for_piece_id(piece_id)
	if color == Color.TRANSPARENT:
		return
	var line_width: float = max(3.0, round(cell_size * 0.055))
	var corner_length: float = max(14.0, round(cell_size * 0.28))
	_add_corner_line(button, color, 0.0, 0.0, 0.0, 0.0, corner_length, line_width)
	_add_corner_line(button, color, 0.0, 0.0, 0.0, 0.0, line_width, corner_length)
	_add_corner_line(button, color, 1.0, 1.0, 0.0, 0.0, -corner_length, line_width)
	_add_corner_line(button, color, 1.0, 1.0, 0.0, 0.0, -line_width, corner_length)
	_add_corner_line(button, color, 0.0, 0.0, 1.0, 1.0, corner_length, -line_width)
	_add_corner_line(button, color, 0.0, 0.0, 1.0, 1.0, line_width, -corner_length)
	_add_corner_line(button, color, 1.0, 1.0, 1.0, 1.0, -corner_length, -line_width)
	_add_corner_line(button, color, 1.0, 1.0, 1.0, 1.0, -line_width, -corner_length)

func _add_corner_line(parent: Control, color: Color, anchor_left: float, anchor_right: float, anchor_top: float, anchor_bottom: float, width: float, height: float) -> void:
	var line: ColorRect = ColorRect.new()
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.anchor_left = anchor_left
	line.anchor_right = anchor_right
	line.anchor_top = anchor_top
	line.anchor_bottom = anchor_bottom
	line.offset_left = min(0.0, width)
	line.offset_right = max(0.0, width)
	line.offset_top = min(0.0, height)
	line.offset_bottom = max(0.0, height)
	parent.add_child(line)

func _selection_color_for_piece_id(piece_id: String) -> Color:
	return _selection_color_for_attribute(_attribute_for_piece_id(piece_id))

func _icon_texture_for_cell(piece: PieceDefinition, pos: Vector2i) -> Texture2D:
	if pos == selected_cell and piece.selected_icon_texture != null:
		return piece.selected_icon_texture
	return piece.icon_texture

func _apply_piece_background(button: Button, piece_id: String) -> void:
	var bg_color: Color = _background_color_for_piece_id(piece_id)
	if bg_color == Color.TRANSPARENT:
		return
	var normal: StyleBoxFlat = _make_piece_background_style(bg_color)
	var hover: StyleBoxFlat = _make_piece_background_style(bg_color.lightened(0.10))
	var pressed: StyleBoxFlat = _make_piece_background_style(bg_color.darkened(0.08))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)

func _add_piece_background_to_button(button: Button, piece_id: String, cell_size: float) -> void:
	var texture: Texture2D = _background_texture_for_piece_id(piece_id)
	if texture != null:
		var normal: StyleBoxTexture = _make_piece_texture_background_style(texture)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", normal)
		button.add_theme_stylebox_override("pressed", normal)
		button.add_theme_stylebox_override("focus", normal)
		button.add_theme_stylebox_override("disabled", normal)
		return
	var bg_color: Color = _background_color_for_piece_id(piece_id)
	if bg_color == Color.TRANSPARENT:
		return
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: float = round(cell_size * 0.08)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = inset
	panel.offset_top = inset
	panel.offset_right = -inset
	panel.offset_bottom = -inset
	panel.add_theme_stylebox_override("panel", _make_piece_circle_background_style(bg_color))
	button.add_child(panel)

func _background_texture_for_piece_id(piece_id: String) -> Texture2D:
	return _background_texture_for_attribute(_attribute_for_piece_id(piece_id))

func _make_piece_texture_background_style(texture: Texture2D) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style

func _make_piece_background_style(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(3)
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style

func _make_piece_circle_background_style(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(999)
	return style

func _background_color_for_piece_id(piece_id: String) -> Color:
	return _background_color_for_attribute(_attribute_for_piece_id(piece_id))

func _attribute_for_piece_id(piece_id: String) -> String:
	var piece: PieceDefinition = catalog.get_piece(piece_id)
	if piece != null and not piece.tags.is_empty():
		return String(piece.tags[0])
	match piece_id:
		"diffraction_base", "diffraction_phoebe":
			return "衍射"
		"annihilation_base", "annihilation_chisaki":
			return "湮灭"
		"condensation_base", "condensation_coletta":
			return "冷凝"
		"aero_base", "aero_sigrika":
			return "气动"
		"thermal_base", "thermal_emis":
			return "热熔"
		"conductive_base", "conductive_kakaro":
			return "导电"
	return ""

func _background_texture_for_attribute(attribute: String) -> Texture2D:
	match attribute:
		"衍射":
			return load("res://assets/pieces/backgrounds/diffraction_bg.png")
		"湮灭":
			return load("res://assets/pieces/backgrounds/annihilation_bg.png")
		"冷凝":
			return load("res://assets/pieces/backgrounds/condensation_bg.png")
		"气动":
			return load("res://assets/pieces/backgrounds/aero_bg.png")
		"热熔":
			return load("res://assets/pieces/backgrounds/thermal_bg.png")
		"导电":
			return load("res://assets/pieces/backgrounds/conductive_bg.png")
	return null

func _selection_color_for_attribute(attribute: String) -> Color:
	match attribute:
		"衍射":
			return Color(0.72, 0.72, 0.31, 1.0)
		"湮灭":
			return Color(0.70, 0.26, 0.52, 1.0)
		"冷凝":
			return Color(0.42, 0.58, 0.70, 1.0)
		"气动":
			return Color(0.34, 0.72, 0.62, 1.0)
		"热熔":
			return Color(0.74, 0.20, 0.32, 1.0)
		"导电":
			return Color(0.66, 0.34, 0.72, 1.0)
	return Color.TRANSPARENT

func _background_color_for_attribute(attribute: String) -> Color:
	match attribute:
		"衍射":
			return Color(1.0, 0.82, 0.12, 0.34)
		"湮灭":
			return Color(0.46, 0.02, 0.04, 0.42)
		"冷凝":
			return Color(0.18, 0.58, 1.0, 0.34)
		"气动":
			return Color(0.18, 0.86, 0.28, 0.34)
		"热熔":
			return Color(1.0, 0.18, 0.12, 0.34)
		"导电":
			return Color(0.62, 0.20, 1.0, 0.34)
	return Color.TRANSPARENT

func _add_piece_icon_to_button(button: Button, texture: Texture2D, cell: Dictionary, piece: PieceDefinition, cell_size: float) -> void:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: float = round(cell_size * 0.03)
	icon.anchor_left = 0.0
	icon.anchor_top = 0.0
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	button.add_child(icon)

	var overlay_text: String = _cell_text(cell, piece)
	if overlay_text.is_empty():
		return
	var overlay: Label = Label.new()
	overlay.text = overlay_text
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_theme_font_size_override("font_size", max(16, int(cell_size * 0.30)))
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(overlay)

func _board_cell_size() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var side_columns_width: float = clamp(viewport_size.x * 0.32, 280.0, 520.0) if current_screen == "game" else 0.0
	var horizontal_margin: float = clamp(viewport_size.x * 0.06, 44.0, 96.0) if current_screen == "game" else 72.0
	var usable_width: float = max(240.0, viewport_size.x - side_columns_width - horizontal_margin)
	var reserved_height: float = clamp(viewport_size.y * 0.22, 96.0, 118.0) if current_screen == "game" else 120.0
	var usable_height: float = max(240.0, viewport_size.y - reserved_height)
	var gap_total: float = 2.0 * float(BoardModel.WIDTH - 1)
	var width_cell: float = (usable_width - gap_total) / float(BoardModel.WIDTH)
	var height_cell: float = (usable_height - gap_total) / float(BoardModel.HEIGHT)
	return floor(min(128.0, min(width_cell, height_cell)))

func _roster_slot_size() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var landscape_scale: float = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	if current_screen == "menu":
		landscape_scale = min(viewport_size.x / 960.0, viewport_size.y / 540.0)
		return floor(clamp(MAIN_MENU_ROSTER_SLOT_SIZE * landscape_scale, 136.0, MAIN_MENU_ROSTER_SLOT_SIZE))
	elif current_screen != "roster":
		landscape_scale = min(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	return floor(clamp(ROSTER_SLOT_SIZE * landscape_scale, 92.0, ROSTER_SLOT_SIZE))

func _piece_card_size() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var landscape_scale: float = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	return floor(clamp(PIECE_CARD_SIZE * landscape_scale, 126.0, PIECE_CARD_SIZE))

func _battle_roster_slot_size() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var landscape_scale: float = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	return floor(clamp(BATTLE_ROSTER_SLOT_SIZE * landscape_scale, 64.0, BATTLE_ROSTER_SLOT_SIZE))

func _battle_roster_hit_size() -> float:
	return _battle_roster_slot_size() + BATTLE_ROSTER_HIT_PADDING * 2.0

func _set_page_margins(left: int, top: int, right: int, bottom: int) -> void:
	if content_margin == null:
		return
	content_margin.add_theme_constant_override("margin_left", left)
	content_margin.add_theme_constant_override("margin_top", top)
	content_margin.add_theme_constant_override("margin_right", right)
	content_margin.add_theme_constant_override("margin_bottom", bottom)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		size = get_viewport_rect().size
		if page != null:
			page.size = get_viewport_rect().size
			page.custom_minimum_size = get_viewport_rect().size
		if content_margin != null:
			content_margin.size = get_viewport_rect().size
		if root != null:
			root.custom_minimum_size = Vector2(0, get_viewport_rect().size.y - 64.0)
		if current_screen == "menu":
			_show_main_menu()
		elif current_screen == "roster":
			_show_roster_select()
		elif current_screen == "game" and board_grid != null:
			_show_game_shell(boss_status_text)
			_redraw_game()

func _cell_text(cell: Dictionary, piece: PieceDefinition) -> String:
	var piece_label: String = "?"
	if piece != null:
		piece_label = piece.display_name.left(1)
	var effect_id: String = String(cell["special_effect_id"])
	var parts: Array[String] = []
	if piece == null or piece.icon_texture == null:
		parts.append(piece_label)
	if effect_id.is_empty():
		return "\n".join(parts)
	var effect: SpecialEffectDefinition = catalog.get_effect(effect_id)
	if effect == null:
		return "\n".join(parts)
	parts.append(effect.marker)
	return "\n".join(parts)

func _add_effect_badge_to_button(button: Button, cell: Dictionary, cell_size: float) -> void:
	var status_text: String = _piece_effects_text(cell)
	if status_text.is_empty():
		return
	var badge: Label = Label.new()
	badge.name = "EffectBadge"
	badge.text = status_text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	badge.add_theme_font_size_override("font_size", max(10, int(cell_size * 0.13)))
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.02
	badge.anchor_top = 0.02
	badge.anchor_right = 0.98
	badge.anchor_bottom = 0.34
	badge.offset_left = 0
	badge.offset_top = 0
	badge.offset_right = 0
	badge.offset_bottom = 0
	button.add_child(badge)

func _refresh_piece_effect_badges(positions: Array) -> void:
	for pos in positions:
		var button: Button = _get_cell_button(pos)
		if button == null:
			continue
		var old_badge: Node = button.get_node_or_null("EffectBadge")
		if old_badge != null:
			button.remove_child(old_badge)
			old_badge.queue_free()
		var cell: Variant = board.get_cell(pos)
		if cell != null:
			_add_effect_badge_to_button(button, cell, _board_cell_size())

func _piece_effects_text(cell: Dictionary) -> String:
	var parts: Array[String] = []
	var effects: Dictionary = cell.get("effects", {})
	for effect_id in EFFECT_LIMITS.keys():
		var stacks: int = int(effects.get(effect_id, 0))
		if stacks > 0:
			parts.append("%s%d%s" % [String(EFFECT_NAMES[effect_id]).left(1), stacks, "!" if stacks >= int(EFFECT_LIMITS[effect_id]) else ""])
	return " ".join(parts)

func _boss_effects_text() -> String:
	var parts: Array[String] = []
	for effect_id in EFFECT_LIMITS.keys():
		var stacks: int = _boss_effect_stacks(String(effect_id))
		if stacks > 0:
			parts.append("%s%d" % [EFFECT_NAMES[effect_id], stacks])
	if boss_frozen:
		parts.append("冻结待触发")
	return "  [" + " / ".join(parts) + "]" if not parts.is_empty() else ""

func _on_cell_pressed(pos: Vector2i) -> void:
	if is_animating_board:
		return
	if coletta_targeting_slot >= 0:
		var slot_index: int = coletta_targeting_slot
		var orientation: String = coletta_target_orientation
		coletta_targeting_slot = -1
		coletta_hovered_cell = Vector2i(-1, -1)
		_release_resonance(slot_index, pos, orientation)
		return
	if kakaro_targeting_slot >= 0:
		var slot_index: int = kakaro_targeting_slot
		kakaro_targeting_slot = -1
		kakaro_hovered_cell = Vector2i(-1, -1)
		_release_resonance(slot_index, pos)
		return
	if sigrika_targeting_slot >= 0:
		var slot_index: int = sigrika_targeting_slot
		sigrika_targeting_slot = -1
		sigrika_hovered_cell = Vector2i(-1, -1)
		_release_resonance(slot_index, pos)
		return
	if cheat_pick_cell_pending:
		cheat_pick_cell_pending = false
		selected_cell = pos
		if cheat_panel != null:
			cheat_panel.visible = true
		_update_cheat_panel_from_selection()
		_redraw_game()
		return
	if cheat_panel != null and cheat_panel.visible:
		selected_cell = pos
		_update_cheat_panel_from_selection()
		_redraw_game()
		return
	var cell: Dictionary = board.get_cell(pos)
	if board.is_echo_cell(cell):
		var echo: EchoDefinition = catalog.get_echo(String(cell.get("echo_id", "")))
		if echo != null and not echo.click_effect_id.is_empty():
			_activate_echo(pos)
			return
	if int(cell["locked_turns"]) > 0:
		boss_label.text = "团子大魔王：该格被锁定"
		return
	if selected_cell == Vector2i(-1, -1):
		if not String(cell["special_effect_id"]).is_empty():
			_activate_special(pos)
		else:
			selected_cell = pos
			_redraw_game()
		return
	if selected_cell == pos:
		selected_cell = Vector2i(-1, -1)
		_redraw_game()
		return
	if not board.are_adjacent(selected_cell, pos):
		selected_cell = pos
		_redraw_game()
		return
	_try_swap(selected_cell, pos)

func _coletta_targeting_hint() -> String:
	var target_name: String = "横行" if coletta_target_orientation == "horizontal" else "竖列"
	return "柯莱塔瞄准：点击格子消除%s；滚轮切换行列，右键或 Esc 取消" % target_name

func _cancel_coletta_targeting() -> void:
	if coletta_targeting_slot < 0:
		return
	coletta_targeting_slot = -1
	coletta_hovered_cell = Vector2i(-1, -1)
	_set_boss_status("已取消柯莱塔共鸣解放", "冷凝")
	_redraw_game()

func _cancel_kakaro_targeting() -> void:
	if kakaro_targeting_slot < 0:
		return
	kakaro_targeting_slot = -1
	kakaro_hovered_cell = Vector2i(-1, -1)
	_set_boss_status("已取消卡卡罗共鸣解放", "导电")
	_redraw_game()

func _cancel_sigrika_targeting() -> void:
	if sigrika_targeting_slot < 0:
		return
	sigrika_targeting_slot = -1
	sigrika_hovered_cell = Vector2i(-1, -1)
	_set_boss_status("已取消西格莉卡共鸣解放", "气动")
	_redraw_game()

func _activate_echo(pos: Vector2i) -> void:
	if board == null or not board.in_bounds(pos):
		return
	var cell: Variant = board.get_cell(pos)
	if not board.is_echo_cell(cell):
		return
	var echo: EchoDefinition = catalog.get_echo(String(cell.get("echo_id", "")))
	if echo == null or echo.click_effect_id != "clear_area_and_convert_energy":
		return
	var slot_index: int = _slot_index_for_piece_id(SIGRIKA_PIECE_ID)
	var normal_cost: int = max(1, _param_int(echo.click_effect_params, "normal_cost", 2))
	var special_gain: int = max(1, _param_int(echo.click_effect_params, "special_gain", 2))
	if slot_index < 0 or _resonance_value(slot_index) < normal_cost:
		_set_boss_status("日灵需要 %d 格普通能量", "气动")
		_redraw_game()
		return
	is_animating_board = true
	var radius: int = max(0, _param_int(echo.click_effect_params, "radius", 1))
	var targets: Array = _piece_targets_in_square(pos, radius)
	targets = _filter_clear_targets(targets, true)
	board.set_cell(pos, null)
	resonance_values[slot_index] = max(0, _resonance_value(slot_index) - normal_cost)
	sigrika_special_energy = min(SIGRIKA_SPECIAL_ENERGY_MAX, sigrika_special_energy + special_gain)
	sigrika_resonance_enhanced = sigrika_special_energy > 0
	if sigrika_special_energy >= SIGRIKA_SPECIAL_ENERGY_MAX:
		sigrika_pending_sun_spirits = 0
		for extra_pos in _sigrika_sun_spirit_positions():
			if extra_pos != pos:
				board.set_cell(extra_pos, null)
	# Remove the echo from both the model and the live board before any clear or
	# drop animation samples source buttons. Hiding the stale button alone leaves
	# the animation layer out of sync with the collapsed board.
	_redraw_game()
	await get_tree().process_frame
	if not targets.is_empty():
		_charge_resonance_for_cleared_targets(targets)
		_transfer_cleared_effects_to_boss(targets)
		await _animate_clear(targets)
		_animate_attack_boss(targets)
		_damage_boss(targets)
		if boss_hp <= 0:
			is_animating_board = false
			_finish_battle()
			return
		board.clear_positions(targets)
		_add_score(100 + targets.size() * 5)
	await _collapse_refill_and_animate()
	await _resolve_cascades()
	if boss_hp <= 0:
		return
	_maintain_sigrika_board_state()
	is_animating_board = false
	_set_boss_status("日灵发动：普通能量转化为特殊能量", "气动")
	_redraw_game()

func _piece_targets_in_square(center: Vector2i, radius: int) -> Array:
	var result: Array = []
	for pos in _square_targets(center, radius):
		if board.is_piece_cell(board.get_cell(pos)):
			result.append(pos)
	return result

func _try_swap(a: Vector2i, b: Vector2i) -> void:
	selected_cell = Vector2i(-1, -1)
	var a_cell: Dictionary = board.get_cell(a)
	var b_cell: Dictionary = board.get_cell(b)
	if board.is_immovable(a) or board.is_immovable(b):
		_redraw_game()
		return
	if not String(a_cell["special_effect_id"]).is_empty() or not String(b_cell["special_effect_id"]).is_empty():
		_play_swap_then_special_combo(a, b)
		return
	_play_swap_then_resolve(a, b)

func _play_swap_then_resolve(a: Vector2i, b: Vector2i) -> void:
	is_animating_board = true
	await _animate_swap(a, b, false)
	board.swap(a, b)
	await _sync_board_ui_after_swap()
	var matches: Array = board.find_matches()
	if matches.is_empty():
		await _animate_swap_back(a, b)
		board.swap(a, b)
		combo = 0
		is_animating_board = false
		_redraw_game()
		return
	_consume_run_action()
	await _resolve_matches(matches, _preferred_spawn_after_swap(matches, a, b))
	if boss_hp <= 0:
		return
	is_animating_board = false
	_after_player_move()

func _preferred_spawn_after_swap(matches: Array, first_pos: Vector2i, second_pos: Vector2i) -> Vector2i:
	# After swapping, the piece selected first is now at second_pos and the
	# piece selected second is at first_pos. Preserve whichever swapped cell
	# actually participates in the resulting match. This keeps the moved
	# matching piece rather than an unrelated piece or an arbitrary group head.
	for group in matches:
		var positions: Array = group.get("positions", [])
		if positions.has(first_pos) and not positions.has(second_pos):
			return first_pos
		if positions.has(second_pos) and not positions.has(first_pos):
			return second_pos
	# Intersections can contain both swapped cells. Prefer the second selected
	# destination for compatibility with the existing interaction behavior.
	for group in matches:
		var positions: Array = group.get("positions", [])
		if positions.has(second_pos):
			return second_pos
		if positions.has(first_pos):
			return first_pos
	return Vector2i(-1, -1)

func _play_swap_then_special_combo(a: Vector2i, b: Vector2i) -> void:
	is_animating_board = true
	await _animate_swap(a, b, false)
	board.swap(a, b)
	await _sync_board_ui_after_swap()
	await _activate_special_combo(a, b)
	is_animating_board = false

func _activate_special(pos: Vector2i) -> void:
	is_animating_board = true
	var source_cell: Dictionary = board.get_cell(pos)
	var targets: Array = _filter_clear_targets(board.collect_effect_targets(pos))
	if targets.is_empty():
		is_animating_board = false
		_redraw_game()
		return
	_consume_run_action()
	_charge_special_resonance(String(source_cell["piece_id"]), String(source_cell["special_effect_id"]), targets)
	_charge_resonance_for_cleared_targets(targets)
	_transfer_cleared_effects_to_boss(targets)
	await _animate_clear(targets)
	_animate_attack_boss(targets)
	_damage_boss(targets)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return
	board.clear_positions(targets)
	_add_score(120 + targets.size() * 5)
	stats["special"] += 1
	await _collapse_refill_and_animate()
	await _resolve_cascades()
	if boss_hp <= 0:
		return
	is_animating_board = false
	_after_player_move()

func _activate_special_combo(a: Vector2i, b: Vector2i) -> void:
	var a_cell: Dictionary = board.get_cell(a)
	var b_cell: Dictionary = board.get_cell(b)
	var targets: Array = []
	var a_effect: String = String(a_cell["special_effect_id"])
	var b_effect: String = String(b_cell["special_effect_id"])
	if a_effect == "rainbow":
		targets = board.collect_effect_targets(a, String(b_cell["piece_id"]))
	elif b_effect == "rainbow":
		targets = board.collect_effect_targets(b, String(a_cell["piece_id"]))
	elif a_effect == "stripe" and b_effect == "stripe":
		targets = board.collect_effect_targets(a)
		for pos in board.collect_effect_targets(b):
			if not targets.has(pos):
				targets.append(pos)
	elif a_effect == "bomb" and b_effect == "bomb":
		targets = _square_targets(a, 2)
	elif (a_effect == "stripe" and b_effect == "bomb") or (a_effect == "bomb" and b_effect == "stripe"):
		for offset in [-1, 0, 1]:
			var row_pos: Vector2i = Vector2i(a.x, clamp(a.y + offset, 0, BoardModel.HEIGHT - 1))
			for x in range(BoardModel.WIDTH):
				var p: Vector2i = Vector2i(x, row_pos.y)
				if not targets.has(p):
					targets.append(p)
	else:
		targets = board.collect_effect_targets(a)
	targets = _filter_clear_targets(targets)
	if targets.is_empty():
		_redraw_game()
		return
	_consume_run_action()
	_charge_special_resonance(String(a_cell["piece_id"]), a_effect, targets)
	_charge_special_resonance(String(b_cell["piece_id"]), b_effect, targets)
	_charge_resonance_for_cleared_targets(targets)
	_transfer_cleared_effects_to_boss(targets)
	await _animate_clear(targets)
	_animate_attack_boss(targets)
	_damage_boss(targets)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return
	board.clear_positions(targets)
	_add_score(200 + targets.size() * 5)
	stats["combo"] += 1
	await _collapse_refill_and_animate()
	await _resolve_cascades()
	if boss_hp <= 0:
		return
	_after_player_move()

func _resolve_matches(matches: Array, preferred_spawn: Vector2i, resolve_after: bool = true) -> void:
	var cleared: Array = []
	var spawn_specs: Array = []
	for group in matches:
		var positions: Array = group["positions"]
		var spawn_pos: Vector2i = preferred_spawn if positions.has(preferred_spawn) else positions[0]
		var effect_id: String = _effect_for_group(group)
		for pos in positions:
			if not cleared.has(pos):
				cleared.append(pos)
		if not effect_id.is_empty():
			spawn_specs.append({"pos": spawn_pos, "effect_id": effect_id, "direction": _direction_for_group(group)})
		var piece: PieceDefinition = catalog.get_piece(String(group["piece_id"]))
		var multiplier: float = 1.0 if piece == null else piece.multiplier
		var base: int = 10
		if effect_id == "stripe":
			base = 30
		elif effect_id == "rainbow":
			base = 50
		elif effect_id == "bomb":
			base = 40
		_add_score(roundi(base * multiplier * max(1, positions.size() - 2)))
	stats["normal"] += 1
	# Convert the chosen surviving instance in place. It keeps its piece id,
	# stacked effects, and other runtime state; only its special behavior changes.
	# Excluding it from the clear set also makes the icon visible before collapse.
	for spec in spawn_specs:
		var spawn_pos: Vector2i = spec["pos"]
		if cleared.has(spawn_pos):
			cleared.erase(spawn_pos)
		var spawn_cell: Variant = board.get_cell(spawn_pos)
		if spawn_cell != null:
			spawn_cell["special_effect_id"] = spec["effect_id"]
			spawn_cell["special_direction"] = spec["direction"]
			board.set_cell(spawn_pos, spawn_cell)
	if not spawn_specs.is_empty():
		await _animate_special_creation(spawn_specs)
	cleared = _filter_clear_targets(cleared)
	if cleared.is_empty():
		return
	_charge_resonance_for_cleared_targets(cleared)
	_transfer_cleared_effects_to_boss(cleared)
	await _animate_clear(cleared)
	_animate_attack_boss(cleared)
	_damage_boss(cleared)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return
	board.clear_positions(cleared)
	await _collapse_refill_and_animate()
	if resolve_after:
		await _resolve_cascades()

func _animate_special_creation(spawn_specs: Array) -> void:
	var created_buttons: Array[Button] = []
	for spec in spawn_specs:
		var pos: Vector2i = spec["pos"]
		var old_button: Button = _get_cell_button(pos)
		if old_button == null:
			continue
		var child_index: int = old_button.get_index()
		board_grid.remove_child(old_button)
		old_button.queue_free()
		var special_button: Button = _make_cell_button(pos)
		board_grid.add_child(special_button)
		board_grid.move_child(special_button, child_index)
		created_buttons.append(special_button)
	if created_buttons.is_empty():
		return
	await get_tree().process_frame
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for button in created_buttons:
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2(0.72, 0.72)
		button.modulate = Color(1.28, 1.18, 0.72, 1.0)
		tween.tween_property(button, "scale", Vector2.ONE, SPECIAL_CREATE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", Color.WHITE, SPECIAL_CREATE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func _resolve_cascades() -> void:
	while true:
		if boss_hp <= 0:
			return
		var matches: Array = board.find_matches()
		if not matches.is_empty():
			combo += 1
			max_combo = max(max_combo, combo)
			await _resolve_matches(matches, Vector2i(-1, -1), false)
			if boss_hp <= 0:
				return
			continue
		if emis_pending_random_lines > 0:
			await _resolve_next_emis_random_line()
			continue
		break

func _resolve_next_emis_random_line() -> void:
	emis_pending_random_lines = max(0, emis_pending_random_lines - 1)
	var horizontal: bool = rng.randi_range(0, 1) == 0
	var line_index: int = rng.randi_range(0, BoardModel.HEIGHT - 1 if horizontal else BoardModel.WIDTH - 1)
	var targets: Array = _emis_line_piece_targets(horizontal, line_index)
	if targets.is_empty():
		return
	_transfer_cleared_effects_to_boss(targets)
	await _animate_clear(targets)
	_animate_attack_boss(targets)
	_damage_boss(targets)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return
	board.clear_positions(targets)
	_add_score(120 + targets.size() * 5)
	await _collapse_refill_and_animate()
	_set_boss_status("爱弥斯星能：随机清除%s" % ("整行" if horizontal else "整列"), "热熔")

func _emis_line_piece_targets(horizontal: bool, line_index: int) -> Array:
	var targets: Array = []
	if horizontal:
		if line_index < 0 or line_index >= BoardModel.HEIGHT:
			return targets
		for x in range(BoardModel.WIDTH):
			var pos := Vector2i(x, line_index)
			if board.is_piece_cell(board.get_cell(pos)):
				targets.append(pos)
	else:
		if line_index < 0 or line_index >= BoardModel.WIDTH:
			return targets
		for y in range(BoardModel.HEIGHT):
			var pos := Vector2i(line_index, y)
			if board.is_piece_cell(board.get_cell(pos)):
				targets.append(pos)
	return _filter_clear_targets(targets, true)

func _animate_swap(a: Vector2i, b: Vector2i, reset_after: bool = true) -> void:
	var button_a: Button = _get_cell_button(a)
	var button_b: Button = _get_cell_button(b)
	if button_a == null or button_b == null:
		return
	var start_a: Vector2 = button_a.position
	var start_b: Vector2 = button_b.position
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(button_a, "position", start_b, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button_b, "position", start_a, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if reset_after:
		button_a.position = start_a
		button_b.position = start_b

func _animate_swap_back(a: Vector2i, b: Vector2i) -> void:
	var button_a: Button = _get_cell_button(a)
	var button_b: Button = _get_cell_button(b)
	if button_a == null or button_b == null:
		return
	var home_a: Vector2 = button_b.position
	var home_b: Vector2 = button_a.position
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(button_a, "position", home_a, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button_b, "position", home_b, SWAP_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func _remap_swapped_cell_buttons(a: Vector2i, b: Vector2i) -> void:
	var button_a: Button = _get_cell_button(a)
	var button_b: Button = _get_cell_button(b)
	if button_a == null or button_b == null:
		return
	button_a.set_meta("board_pos", b)
	button_b.set_meta("board_pos", a)

func _sync_board_ui_after_swap() -> void:
	# GridContainer places children by child order, not by board_pos metadata.
	# Rebuilding from the swapped model keeps both the matching piece and the
	# non-matching piece at their actual destination before clear animations.
	_redraw_game()
	await get_tree().process_frame

func _animate_clear(positions: Array) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var animated: bool = false
	for pos in positions:
		var button: Button = _get_cell_button(pos)
		if button == null:
			continue
		animated = true
		button.pivot_offset = button.size * 0.5
		var sink_position: Vector2 = button.position + Vector2(0, button.size.y * 0.10)
		tween.tween_property(button, "position", sink_position, CLEAR_ANIM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(button, "scale", Vector2(0.15, 0.15), CLEAR_ANIM_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(button, "modulate:a", 0.0, CLEAR_ANIM_SECONDS)
	if animated:
		# Release the gameplay flow before the fade finishes so collapse can
		# begin during the final part of the clear animation. The old buttons
		# remain visible until the drop overlay covers the transition.
		await get_tree().create_timer(CLEAR_ANIM_SECONDS * CLEAR_DROP_OVERLAP_RATIO).timeout
		await get_tree().create_timer(POST_CLEAR_PAUSE_SECONDS).timeout

func _animate_attack_boss(positions: Array) -> void:
	if positions.is_empty() or boss_avatar == null:
		return
	var target_rect: Rect2 = boss_avatar.get_global_rect()
	var target_center: Vector2 = target_rect.position + target_rect.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var animated: bool = false
	var cell_size: float = _board_cell_size()
	for index in range(positions.size()):
		var pos: Vector2i = positions[index]
		var button: Button = _get_cell_button(pos)
		if button == null:
			continue
		var cell: Variant = board.get_cell(pos)
		if cell == null:
			continue
		var piece: PieceDefinition = catalog.get_piece(String(cell["piece_id"]))
		var projectile: Control
		var projectile_size: Vector2 = Vector2(cell_size * 0.48, cell_size * 0.48)
		if piece != null and piece.icon_texture != null:
			var icon: TextureRect = TextureRect.new()
			icon.texture = piece.icon_texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			projectile = icon
		else:
			var label: Label = Label.new()
			label.text = _cell_text(cell, piece)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", max(16, int(cell_size * 0.24)))
			projectile = label
		projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		projectile.custom_minimum_size = projectile_size
		projectile.size = projectile_size
		projectile.z_index = 80
		add_child(projectile)
		var start_rect: Rect2 = button.get_global_rect()
		projectile.global_position = start_rect.position + start_rect.size * 0.5 - projectile_size * 0.5
		projectile.pivot_offset = projectile_size * 0.5
		animated = true
		var end_position: Vector2 = target_center - projectile_size * 0.5
		var delay: float = float(index) * ATTACK_FLY_STAGGER_SECONDS
		tween.tween_property(projectile, "global_position", end_position, ATTACK_FLY_SECONDS).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(projectile, "scale", Vector2(0.34, 0.34), ATTACK_FLY_SECONDS).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(projectile, "modulate:a", 0.0, ATTACK_FLY_SECONDS * 0.35).set_delay(delay + ATTACK_FLY_SECONDS * 0.65)
		tween.tween_callback(Callable(projectile, "queue_free")).set_delay(delay + ATTACK_FLY_SECONDS)
	if animated:
		await tween.finished

func _collapse_refill_and_animate() -> void:
	var drop_specs: Array = _collapse_refill_with_drop_specs()
	await _animate_drop_specs(drop_specs)
	_redraw_game()
	# Newly added GridContainer children keep their default position until the
	# next layout pass. Cascades can begin immediately after this function, so
	# wait one frame before any clear animation reads their positions.
	await get_tree().process_frame

func _collapse_refill_with_drop_specs() -> Array:
	var specs: Array = []
	for x in range(BoardModel.WIDTH):
		var survivors: Array = []
		for y in range(BoardModel.HEIGHT - 1, -1, -1):
			if board.cells[y][x] != null:
				survivors.append({"cell": board.cells[y][x], "from_y": y})
		var survivor_index: int = 0
		var spawn_index: int = 0
		for y in range(BoardModel.HEIGHT - 1, -1, -1):
			if survivor_index < survivors.size():
				var survivor: Dictionary = survivors[survivor_index]
				board.cells[y][x] = survivor["cell"]
				var from_y: int = int(survivor["from_y"])
				if from_y != y:
					specs.append({"from": Vector2i(x, from_y), "to": Vector2i(x, y), "spawn": false})
				survivor_index += 1
			else:
				board.cells[y][x] = board._new_cell(board._random_piece_id())
				specs.append({"from": Vector2i(x, -1 - spawn_index), "to": Vector2i(x, y), "spawn": true})
				spawn_index += 1
	return specs

func _animate_drop_specs(specs: Array) -> void:
	if board_grid == null or specs.is_empty():
		return
	var overlay: Control = Control.new()
	overlay.name = "DropAnimationOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)
	var cell_size: float = _board_cell_size()
	var buttons_by_pos: Dictionary = {}
	var rects_by_pos: Dictionary = {}
	var grid_cell_size: Vector2 = Vector2(cell_size, cell_size)
	var grid_gap: Vector2 = Vector2(
		float(board_grid.get_theme_constant("h_separation")),
		float(board_grid.get_theme_constant("v_separation"))
	)
	for child in board_grid.get_children():
		if child is Button and child.has_meta("board_pos"):
			var grid_pos: Vector2i = child.get_meta("board_pos")
			buttons_by_pos[grid_pos] = child
			# Derive the slot rect from its row/column. The old button can still be
			# scaled, faded, or shifted by the clear animation at this point.
			var slot_offset: Vector2 = Vector2(grid_pos.x, grid_pos.y) * (grid_cell_size + grid_gap)
			rects_by_pos[grid_pos] = Rect2(board_grid.global_position + slot_offset, grid_cell_size)
	var animation_entries: Array = []
	var animated: bool = false
	for spec in specs:
		var to_pos: Vector2i = spec["to"]
		var from_pos: Vector2i = spec["from"]
		var target_rect: Rect2 = rects_by_pos.get(to_pos, Rect2(board_grid.global_position + Vector2(to_pos.x, to_pos.y) * (cell_size + 2.0), Vector2(cell_size, cell_size)))
		# Build the visual from the final piece instance at the destination.
		# A match-created special already exists in the model before collapse;
		# duplicating the old source button would keep showing its normal artwork
		# until the final redraw instead of revealing the special before it falls.
		var visual: Button = _make_cell_button(to_pos)
		if not bool(spec.get("spawn", false)):
			var source_button: Button = buttons_by_pos.get(from_pos)
			if source_button == null:
				visual.free()
				continue
			source_button.modulate.a = 0.0
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		# GridContainer may compress buttons below their custom minimum size.
		# A duplicated button outside the container otherwise expands again and
		# makes its artwork appear offset until the final redraw.
		visual.custom_minimum_size = Vector2.ZERO
		visual.size = target_rect.size
		overlay.add_child(visual)
		var row_delta: int = from_pos.y - to_pos.y
		if bool(spec.get("spawn", false)):
			row_delta -= DROP_SPAWN_EXTRA_ROWS
		var final_position: Vector2 = target_rect.position - overlay.global_position
		var source_rect: Rect2 = rects_by_pos.get(from_pos, target_rect)
		var start_position: Vector2 = source_rect.position - overlay.global_position
		if bool(spec.get("spawn", false)):
			start_position = final_position + Vector2(0, row_delta * (cell_size + 2.0))
			visual.modulate.a = 0.0
		visual.position = start_position
		visual.size = target_rect.size
		visual.pivot_offset = visual.size * 0.5
		visual.scale = Vector2(0.96, 1.04) if bool(spec.get("spawn", false)) else Vector2.ONE
		animated = true
		var drop_rows: int = abs(row_delta)
		var duration: float = DROP_BASE_SECONDS + sqrt(float(max(1, drop_rows))) * DROP_SECONDS_PER_ROW
		var delay: float = float(to_pos.x) * DROP_COLUMN_STAGGER_SECONDS + float(BoardModel.HEIGHT - 1 - to_pos.y) * 0.012
		if bool(spec.get("spawn", false)):
			delay += DROP_SPAWN_DELAY_SECONDS + float(-from_pos.y - 1) * 0.025
		animation_entries.append({
			"visual": visual,
			"final_position": final_position,
			"duration": duration,
			"delay": delay,
			"spawn": bool(spec.get("spawn", false)),
		})
	if animated:
		# Let Godot draw the newly created final-state visuals once before any
		# movement begins. Match-created specials are therefore visibly created
		# at their source slot instead of first appearing mid-fall.
		await get_tree().process_frame
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		for entry in animation_entries:
			var visual: Button = entry["visual"]
			var duration: float = entry["duration"]
			var delay: float = entry["delay"]
			if bool(entry["spawn"]):
				tween.tween_property(visual, "modulate:a", 1.0, min(0.16, duration * 0.38)).set_delay(delay)
			tween.tween_property(visual, "position", entry["final_position"], duration + DROP_SETTLE_SECONDS).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(visual, "scale", Vector2.ONE, duration + DROP_SETTLE_SECONDS).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
		await get_tree().create_timer(POST_DROP_PAUSE_SECONDS).timeout
	# Remove the animation layer synchronously so the final board redraw in the
	# caller replaces it in the same frame without a one-frame double image.
	overlay.free()

func _get_cell_button(pos: Vector2i) -> Button:
	if board_grid == null:
		return null
	for child in board_grid.get_children():
		if child is Button and not child.is_queued_for_deletion() and child.has_meta("board_pos") and child.get_meta("board_pos") == pos:
			return child
	return null

func _effect_for_group(group: Dictionary) -> String:
	if group["directions"].size() > 1:
		return "bomb"
	if group["positions"].size() >= 5:
		return "rainbow"
	if group["positions"].size() == 4:
		return "stripe"
	return ""

func _direction_for_group(group: Dictionary) -> String:
	if group["directions"].is_empty():
		return "horizontal"
	var dir: Vector2i = group["directions"][0]
	return "vertical" if dir.y != 0 else "horizontal"

func _add_score(amount: int) -> void:
	var final_amount: int = amount
	if skip_bonus_pending:
		final_amount = roundi(float(final_amount) * 1.1)
		skip_bonus_pending = false
	final_amount = roundi(float(final_amount) * (1.0 + min(combo, 5) * 0.2))
	if run_active:
		final_amount = roundi(float(final_amount) * (1.0 + _collectible_total("score_mult")))
	score += final_amount

func _after_player_move() -> void:
	if not _settle_player_action():
		player_action_in_progress = false
		return
	_settle_chisaki_action_duration()
	player_action_in_progress = false
	_maintain_sigrika_board_state()
	combo += 1
	max_combo = max(max_combo, combo)
	moves_since_enemy += 1
	board.tick_locks()
	if not board.has_possible_move():
		_end_game()
		return
	var enemy_interval: int = _enemy_check_interval()
	if moves_since_enemy >= enemy_interval:
		moves_since_enemy = 0
		if suppress_next_enemy_effect:
			suppress_next_enemy_effect = false
			_set_boss_status("冷凝共鸣：抵消了团子大魔王的干扰", "冷凝")
			_redraw_game()
			return
		if rng.randf() <= _enemy_effect_chance():
			if boss_frozen:
				boss_frozen = false
				_set_boss_effect_stacks("frost", 0)
				_set_boss_status("霜渐使Boss跳过了本次行动。", "霜渐")
				_redraw_game()
				return
			if _boss_phase() == 1 and rng.randf() <= 0.45:
				_trigger_enemy_extra_skill()
			else:
				_trigger_enemy_effect()
			return
	_redraw_game()

func _settle_player_action() -> bool:
	_settle_daniya_action_effect()
	var photo_stacks: int = _boss_effect_stacks("photo")
	if photo_stacks > 0:
		_apply_direct_boss_damage(photo_stacks * EFFECT_PHOTO_DAMAGE_PER_STACK, "光燥")
		_set_boss_effect_stacks("photo", photo_stacks - 1)
	var aero_stacks: int = _boss_effect_stacks("aero")
	if aero_stacks > 0 and boss_hp > 0:
		var aero_damage: int = max(1, roundi(float(boss_hp) * float(aero_stacks) / 100.0))
		_apply_direct_boss_damage(aero_damage, "风蚀")
		_set_boss_effect_stacks("aero", aero_stacks - 1)
	if not boss_hp_infinite and boss_hp <= 0:
		_finish_battle()
		return false
	if run_active and int(run_state.get("actions", 0)) <= 0:
		_on_run_battle_lost()
		return false
	return true

func _consume_run_action() -> void:
	player_action_in_progress = true
	if run_active:
		run_state["actions"] = max(0, int(run_state.get("actions", RUN_MAX_ACTIONS)) - 1)

func _refund_run_action() -> void:
	player_action_in_progress = false
	if run_active:
		run_state["actions"] = min(RUN_MAX_ACTIONS, int(run_state.get("actions", 0)) + 1)

func _enemy_check_interval() -> int:
	if current_boss != null:
		return max(1, current_boss.skill_interval)
	if _boss_phase() <= 2:
		return 2
	return 3

func _enemy_effect_chance() -> float:
	if current_boss != null:
		return clamp(current_boss.skill_chance, 0.0, 1.0)
	match _boss_phase():
		3:
			return 0.30
		2:
			return 0.55
	return 0.70

func _trigger_enemy_extra_skill() -> void:
	_set_boss_status("%s进入濒危阶段，额外技能已触发。" % _current_boss_name(), "蓄力")
	_redraw_game()

func _trigger_enemy_effect() -> void:
	if current_boss != null and not current_boss.skill_effect_id.is_empty():
		_apply_boss_skill_effect(current_boss.skill_effect_id, current_boss.skill_effect_params)
		return
	var roll: int = rng.randi_range(0, 2)
	if roll == 0:
		board.lock_random_cells(3)
		_set_boss_status("团子大魔王：锁定了 3 个格子", "攻击")
		_redraw_game()
	elif roll == 1:
		combo = 0
		_set_boss_status("团子大魔王：打断了 Combo", "怒")
		_redraw_game()
	else:
		board.lock_random_cells(1)
		_set_boss_status("团子大魔王：制造了锁定干扰", "扰")
		_redraw_game()

func _apply_boss_skill_effect(effect_id: String, params: Dictionary) -> void:
	match effect_id:
		"boss_random_interference":
			var roll: int = rng.randi_range(0, 2)
			if roll == 0:
				_apply_boss_lock_cells(_param_int(params, "lock_large", 3), _param_int(params, "lock_resonance", 10), "%s：锁定了 %d 个格子")
			elif roll == 1:
				_apply_boss_break_combo(_param_int(params, "break_resonance", 6))
			else:
				_apply_boss_lock_cells(_param_int(params, "lock_small", 1), _param_int(params, "small_resonance", 5), "%s：制造了锁定干扰")
		"lock_cells":
			_apply_boss_lock_cells(_param_int(params, "count", 1), _param_int(params, "resonance", 5), _param_text(params, "status", "%s：锁定了 %d 个格子"))
		"break_combo":
			_apply_boss_break_combo(_param_int(params, "resonance", 6))
		"none", "":
			_redraw_game()
		_:
			push_warning("Unsupported boss skill effect_id: %s" % effect_id)
			_redraw_game()

func _apply_boss_lock_cells(count: int, resonance: int, status_template: String) -> void:
	count = max(1, count)
	board.lock_random_cells(count)
	if status_template.contains("%d"):
		_set_boss_status(status_template % [_current_boss_name(), count], "攻击")
	elif status_template.contains("%s"):
		_set_boss_status(status_template % _current_boss_name(), "攻击")
	else:
		_set_boss_status(status_template, "攻击")
	_redraw_game()

func _apply_boss_break_combo(resonance: int) -> void:
	combo = 0
	_set_boss_status("%s：打断了 Combo" % _current_boss_name(), "怒")
	_redraw_game()

func _resonance_value(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= resonance_values.size():
		return 0
	return resonance_values[slot_index]

func _resonance_cost(slot_index: int) -> int:
	if slot_index >= 0 and slot_index < current_roster.size():
		var piece: PieceDefinition = catalog.get_piece(current_roster[slot_index])
		if piece != null and piece.resonance_cost > 0:
			return piece.resonance_cost
	if slot_index >= 0 and slot_index < RESONANCE_MAX_VALUES.size():
		return RESONANCE_MAX_VALUES[slot_index]
	return 30

func _is_resonance_ready(slot_index: int) -> bool:
	if slot_index >= 0 and slot_index < current_roster.size() and current_roster[slot_index] == COLETTA_PIECE_ID:
		return coletta_release_active and _resonance_value(slot_index) > 0
	if slot_index >= 0 and slot_index < current_roster.size() and current_roster[slot_index] == KAKARO_PIECE_ID:
		return kakaro_release_active and kakaro_releases_remaining > 0
	if slot_index >= 0 and slot_index < current_roster.size() and current_roster[slot_index] == CHISAKI_PIECE_ID:
		return not chisaki_release_active and _resonance_value(slot_index) >= _resonance_cost(slot_index)
	if slot_index >= 0 and slot_index < current_roster.size() and current_roster[slot_index] == DANIYA_PIECE_ID:
		return not daniya_release_active and _resonance_value(slot_index) >= _resonance_cost(slot_index)
	if slot_index >= 0 and slot_index < current_roster.size() and current_roster[slot_index] == SIGRIKA_PIECE_ID:
		return sigrika_special_energy >= SIGRIKA_SPECIAL_ENERGY_MAX
	return slot_index >= 0 and slot_index < SLOT_ATTRIBUTES.size() and _resonance_value(slot_index) >= _resonance_cost(slot_index)

func _is_coletta_fully_charged() -> bool:
	var slot_index: int = _slot_index_for_piece_id(COLETTA_PIECE_ID)
	return slot_index >= 0 and _resonance_value(slot_index) >= _resonance_cost(slot_index)

func _activate_kakaro_release_if_full() -> void:
	var slot_index: int = _slot_index_for_piece_id(KAKARO_PIECE_ID)
	if slot_index < 0 or kakaro_release_active or _resonance_value(slot_index) < _resonance_cost(slot_index):
		return
	var piece: PieceDefinition = catalog.get_piece(KAKARO_PIECE_ID)
	kakaro_release_active = true
	kakaro_releases_remaining = _param_int(piece.resonance_effect_params, "release_count", 5) if piece != null else 5

func _add_resonance(slot_index: int, amount: int, _reason: String = "") -> void:
	if slot_index < 0 or slot_index >= SLOT_ATTRIBUTES.size() or amount <= 0:
		return
	if slot_index < current_roster.size() and current_roster[slot_index] == KAKARO_PIECE_ID and kakaro_release_active:
		return
	if slot_index < current_roster.size() and current_roster[slot_index] == CHISAKI_PIECE_ID and chisaki_release_active:
		return
	if slot_index < current_roster.size() and current_roster[slot_index] == DANIYA_PIECE_ID and daniya_release_active:
		return
	if run_active:
		amount = max(1, roundi(float(amount) * (1.0 + _collectible_total("resonance_mult"))))
	while resonance_values.size() < SLOT_ATTRIBUTES.size():
		resonance_values.append(0)
	if slot_index < current_roster.size() and current_roster[slot_index] == SIGRIKA_PIECE_ID:
		_add_sigrika_normal_energy_raw(slot_index, amount)
		return
	resonance_values[slot_index] = min(_resonance_cost(slot_index), resonance_values[slot_index] + amount)
	if slot_index < current_roster.size() and current_roster[slot_index] == COLETTA_PIECE_ID and resonance_values[slot_index] >= _resonance_cost(slot_index):
		coletta_release_active = true
	if slot_index < current_roster.size() and current_roster[slot_index] == KAKARO_PIECE_ID:
		_activate_kakaro_release_if_full()

func _slot_index_for_piece_id(piece_id: String) -> int:
	for index in range(current_roster.size()):
		if current_roster[index] == piece_id:
			return index
	return -1

func _charge_resonance_for_cleared_targets(targets: Array) -> void:
	_apply_clear_passives(targets)
	_charge_sigrika_for_cleared_runes(targets)
	var cleared_counts: Dictionary = {}
	for pos in _unique_in_bounds_targets(targets):
		var cell: Variant = board.get_cell(pos)
		if cell == null:
			continue
		if not board.is_piece_cell(cell):
			continue
		var piece_id: String = String(cell.get("piece_id", ""))
		cleared_counts[piece_id] = int(cleared_counts.get(piece_id, 0)) + 1
	for slot_index in range(current_roster.size()):
		var piece: PieceDefinition = catalog.get_piece(current_roster[slot_index])
		if piece == null or piece.resonance_gain_id not in ["clear_self", "clear_self_star"]:
			continue
		var cleared_count: int = int(cleared_counts.get(piece.id, 0))
		if cleared_count > 0:
			var amount: int = cleared_count * _param_int(piece.resonance_gain_params, "amount", 1)
			if piece.id == EMIS_PIECE_ID and piece.resonance_gain_id == "clear_self_star":
				_add_emis_progress(slot_index, amount)
			else:
				_add_resonance(slot_index, amount, "消除%s" % piece.display_name)

func _add_emis_progress(slot_index: int, amount: int) -> void:
	if slot_index < 0 or amount <= 0:
		return
	while resonance_values.size() < SLOT_ATTRIBUTES.size():
		resonance_values.append(0)
	var old_value: int = _resonance_value(slot_index)
	var new_value: int = min(_resonance_cost(slot_index), old_value + amount)
	resonance_values[slot_index] = new_value
	for star_threshold in [2, 4]:
		var point_threshold: int = star_threshold * EMIS_STAR_COST
		if old_value < point_threshold and new_value >= point_threshold:
			emis_pending_random_lines += 1

func _charge_sigrika_for_cleared_runes(targets: Array) -> void:
	var slot_index: int = _slot_index_for_piece_id(SIGRIKA_PIECE_ID)
	if slot_index < 0:
		return
	var piece: PieceDefinition = catalog.get_piece(SIGRIKA_PIECE_ID)
	if piece == null or piece.resonance_gain_id != "clear_rune":
		return
	var rune_count: int = 0
	for pos in _unique_in_bounds_targets(targets):
		var cell: Variant = board.get_cell(pos)
		if board.is_piece_cell(cell) and not String(cell.get("rune_id", "")).is_empty():
			rune_count += 1
	if rune_count > 0:
		_add_resonance(slot_index, rune_count * max(1, _param_int(piece.resonance_gain_params, "amount", 1)), "消除符文团子")

func _add_sigrika_normal_energy_raw(slot_index: int, amount: int) -> void:
	var old_value: int = _resonance_value(slot_index)
	var capacity: int = max(0, SIGRIKA_SPECIAL_ENERGY_MAX - sigrika_special_energy)
	var new_value: int = min(capacity, old_value + max(0, amount))
	resonance_values[slot_index] = new_value
	for threshold in [2, 4]:
		if old_value < threshold and new_value >= threshold:
			sigrika_pending_sun_spirits += 1

func _maintain_sigrika_board_state() -> void:
	if board == null or _slot_index_for_piece_id(SIGRIKA_PIECE_ID) < 0:
		return
	_spawn_pending_sun_spirits()
	_maintain_sigrika_runes()

func _spawn_pending_sun_spirits() -> void:
	if sigrika_pending_sun_spirits <= 0:
		return
	var slot_index: int = _slot_index_for_piece_id(SIGRIKA_PIECE_ID)
	if slot_index < 0:
		return
	var existing_count: int = _sigrika_sun_spirit_positions().size()
	var allowed_count: int = int(_resonance_value(slot_index) / 2)
	var spawn_count: int = min(sigrika_pending_sun_spirits, max(0, allowed_count - existing_count))
	if spawn_count <= 0:
		return
	var candidates: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos := Vector2i(x, y)
			if board.is_piece_cell(board.get_cell(pos)):
				candidates.append(pos)
	candidates.shuffle()
	var echo_ids: Array = ["sun_spirit_gold", "sun_spirit_blue"]
	for index in range(min(spawn_count, candidates.size())):
		board.set_cell(candidates[index], board.new_echo_cell(String(echo_ids[rng.randi_range(0, echo_ids.size() - 1)])))
		sigrika_pending_sun_spirits -= 1

func _sigrika_sun_spirit_positions() -> Array:
	var result: Array = []
	if board == null:
		return result
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos := Vector2i(x, y)
			var cell: Variant = board.get_cell(pos)
			if board.is_echo_cell(cell) and String(cell.get("echo_id", "")).begins_with("sun_spirit_"):
				result.append(pos)
	return result

func _maintain_sigrika_runes() -> void:
	if board == null or _slot_index_for_piece_id(SIGRIKA_PIECE_ID) < 0:
		return
	var sigrika: PieceDefinition = catalog.get_piece(SIGRIKA_PIECE_ID)
	if sigrika == null or sigrika.passive_skill_id != "maintain_runes":
		return
	var rune_ids: Array = sigrika.passive_skill_params.get("rune_ids", ["aero_rune_blue", "aero_rune_gold"])
	var target_per_type: int = max(0, _param_int(sigrika.passive_skill_params, "count_each", SIGRIKA_RUNE_TARGET_PER_TYPE))
	var candidates: Array = []
	var counts: Dictionary = {}
	for rune_id in rune_ids:
		counts[rune_id] = 0
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos := Vector2i(x, y)
			var cell: Variant = board.get_cell(pos)
			if not board.is_piece_cell(cell):
				continue
			var rune_id: String = String(cell.get("rune_id", ""))
			if counts.has(rune_id):
				counts[rune_id] = int(counts[rune_id]) + 1
			elif rune_id.is_empty():
				candidates.append(pos)
	candidates.shuffle()
	for rune_id in rune_ids:
		var deficit: int = target_per_type - int(counts.get(rune_id, 0))
		for _index in range(max(0, deficit)):
			if candidates.is_empty():
				return
			var pos: Vector2i = candidates.pop_back()
			var cell: Dictionary = board.get_cell(pos)
			cell["rune_id"] = String(rune_id)
			board.set_cell(pos, cell)

func _apply_clear_passives(targets: Array) -> void:
	var cleared_targets: Array = _unique_in_bounds_targets(targets)
	var cleared_lookup: Dictionary = {}
	for pos in cleared_targets:
		cleared_lookup[pos] = true
	var resonance_attempts: Dictionary = {}
	var pending_effects: Dictionary = {}
	for source_pos in cleared_targets:
		var source_cell: Variant = board.get_cell(source_pos)
		if source_cell == null:
			continue
		var piece: PieceDefinition = catalog.get_piece(String(source_cell["piece_id"]))
		if piece == null or piece.passive_skill_id not in ["photo_adjacent_on_clear", "explosive_adjacent_on_clear"]:
			continue
		var default_effect_id: String = "explosive" if piece.passive_skill_id == "explosive_adjacent_on_clear" else "photo"
		var effect_id: String = _param_text(piece.passive_skill_params, "effect_id", default_effect_id)
		var amount: int = max(1, _param_int(piece.passive_skill_params, "amount", 1))
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var target_pos: Vector2i = source_pos + delta
			if not board.in_bounds(target_pos) or cleared_lookup.has(target_pos) or not board.is_piece_cell(board.get_cell(target_pos)):
				continue
			var pending_key: String = "%s|%s" % [target_pos, effect_id]
			pending_effects[pending_key] = {
				"pos": target_pos,
				"effect_id": effect_id,
				"amount": int(pending_effects.get(pending_key, {}).get("amount", 0)) + amount,
			}
			if piece.resonance_gain_id == "apply_effect_attempt" and _param_text(piece.resonance_gain_params, "effect_id", effect_id) == effect_id:
				var slot_index: int = _slot_index_for_piece_id(piece.id)
				if slot_index >= 0 and not (piece.id == DANIYA_PIECE_ID and daniya_release_active):
					resonance_attempts[slot_index] = int(resonance_attempts.get(slot_index, 0)) + amount * _param_int(piece.resonance_gain_params, "amount", 1)
	for slot_index in resonance_attempts.keys():
		_add_resonance(int(slot_index), int(resonance_attempts[slot_index]), "施加团子效应")
	var affected_positions: Array = []
	for pending in pending_effects.values():
		var target_pos: Vector2i = pending["pos"]
		var redirected: bool = _add_player_piece_effect_stacks(target_pos, String(pending["effect_id"]), int(pending["amount"]))
		if not redirected and not affected_positions.has(target_pos):
			affected_positions.append(target_pos)
	_refresh_piece_effect_badges(affected_positions)

func _charge_special_resonance(_piece_id: String, effect_id: String, _targets: Array) -> void:
	if effect_id.is_empty():
		return
	for slot_index in range(current_roster.size()):
		var piece: PieceDefinition = catalog.get_piece(current_roster[slot_index])
		if piece == null or piece.resonance_gain_id != "use_special":
			continue
		if _param_text(piece.resonance_gain_params, "special_effect_id", "") == effect_id:
			_add_resonance(slot_index, _param_int(piece.resonance_gain_params, "amount", 1), "使用%s团子" % effect_id)

func _release_resonance(slot_index: int, release_target_cell: Vector2i = Vector2i(-1, -1), target_orientation: String = "horizontal") -> void:
	if board == null or is_animating_board or not _is_resonance_ready(slot_index):
		return
	is_animating_board = true
	if release_target_cell == Vector2i(-1, -1):
		release_target_cell = selected_cell
	selected_cell = Vector2i(-1, -1)
	var released: bool = false
	_consume_run_action()
	var piece: PieceDefinition = catalog.get_piece(current_roster[slot_index]) if slot_index < current_roster.size() else null
	if piece != null:
		released = await _apply_resonance_effect(piece, release_target_cell, target_orientation)
	if released:
		if piece != null and piece.id == COLETTA_PIECE_ID:
			resonance_values[slot_index] = max(0, resonance_values[slot_index] - 1)
			if resonance_values[slot_index] <= 0:
				coletta_release_active = false
		elif piece != null and piece.id == KAKARO_PIECE_ID:
			_consume_kakaro_release(slot_index, piece)
		elif piece != null and piece.id == CHISAKI_PIECE_ID:
			resonance_values[slot_index] = 0
		elif piece != null and piece.id == SIGRIKA_PIECE_ID:
			resonance_values[slot_index] = 0
			sigrika_special_energy = 0
			sigrika_pending_sun_spirits = 0
			sigrika_resonance_enhanced = false
		elif piece != null and piece.id == EMIS_PIECE_ID:
			resonance_values[slot_index] = 0
			emis_pending_random_lines = 0
		else:
			resonance_values[slot_index] = 0
		if boss_hp <= 0:
			return
		is_animating_board = false
		_after_player_move()
	else:
		_refund_run_action()
		is_animating_board = false
		if piece != null and piece.resonance_effect_id == "spread_photo":
			_set_boss_status("场上没有附着光燥效应的团子，无法释放菲比共鸣解放", "衍射")
		else:
			_set_boss_status("%s共鸣解放没有合法目标" % SLOT_ATTRIBUTES[slot_index], "共鸣")
		_redraw_game()

func _consume_kakaro_release(slot_index: int, piece: PieceDefinition = null) -> void:
	if not kakaro_release_active or kakaro_releases_remaining <= 0:
		return
	if piece == null:
		piece = catalog.get_piece(KAKARO_PIECE_ID)
	kakaro_releases_remaining = max(0, kakaro_releases_remaining - 1)
	var release_count: int = max(1, _param_int(piece.resonance_effect_params, "release_count", 5)) if piece != null else 5
	resonance_values[slot_index] = roundi(float(_resonance_cost(slot_index) * kakaro_releases_remaining) / float(release_count))
	if kakaro_releases_remaining <= 0:
		kakaro_release_active = false
		resonance_values[slot_index] = 0

func _settle_chisaki_action_duration() -> void:
	if not chisaki_release_active:
		return
	if chisaki_activation_action_pending:
		chisaki_activation_action_pending = false
		return
	chisaki_releases_remaining = max(0, chisaki_releases_remaining - 1)
	if chisaki_releases_remaining <= 0:
		chisaki_release_active = false
		_set_boss_status("千咲共鸣解放状态结束", "湮灭")

func _clear_chisaki_release_state() -> void:
	chisaki_release_active = false
	chisaki_releases_remaining = 0
	chisaki_activation_action_pending = false
	player_action_in_progress = false

func _clear_daniya_release_state() -> void:
	daniya_release_active = false
	daniya_actions_remaining = 0
	daniya_activation_action_pending = false

func _settle_daniya_action_effect() -> void:
	if not daniya_release_active:
		return
	if daniya_activation_action_pending:
		daniya_activation_action_pending = false
		return
	var daniya: PieceDefinition = catalog.get_piece(DANIYA_PIECE_ID) if catalog != null else null
	var damage_per_stack: int = max(0, _param_int(daniya.resonance_effect_params, "damage_per_stack", 3)) if daniya != null else 3
	var stacks: int = _boss_effect_stacks("explosive")
	if stacks > 0 and damage_per_stack > 0:
		_apply_direct_boss_damage(stacks * damage_per_stack, "达妮娅聚爆")
	daniya_actions_remaining = max(0, daniya_actions_remaining - 1)
	if daniya_actions_remaining <= 0:
		daniya_release_active = false
		_set_boss_status("达妮娅共鸣解放状态结束", "达妮娅")

func _apply_resonance_effect(piece: PieceDefinition, release_target_cell: Vector2i, target_orientation: String = "horizontal") -> bool:
	var params: Dictionary = piece.resonance_effect_params
	match piece.resonance_effect_id:
		"redirect_piece_effects":
			return _release_redirect_piece_effects(params)
		"trigger_boss_explosive_actions":
			return _release_daniya_explosive_actions(params)
		"spread_photo":
			return _release_spread_photo(params)
		"create_special_pieces":
			return _release_create_special_pieces(params)
		"clear_most_common":
			return await _release_clear_targets(_targets_for_most_common_piece(), _param_int(params, "score", 180), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "共鸣"))
		"cleanse_locks":
			return _release_cleanse_locks(params)
		"shuffle_board":
			return _release_shuffle_board(params)
		"clear_area":
			var center: Vector2i = release_target_cell if release_target_cell != Vector2i(-1, -1) else Vector2i(rng.randi_range(0, BoardModel.WIDTH - 1), rng.randi_range(0, BoardModel.HEIGHT - 1))
			return await _release_clear_targets(_square_targets(center, _param_int(params, "radius", 1)), _param_int(params, "score", 160), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "共鸣"))
		"clear_piece_area":
			if release_target_cell == Vector2i(-1, -1):
				return false
			return await _release_clear_targets(_piece_targets_in_square(release_target_cell, _param_int(params, "radius", 2)), _param_int(params, "score", 220), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "气动"))
		"clear_center_piece_area":
			return await _release_clear_targets(_center_piece_targets(_param_int(params, "size", 6)), _param_int(params, "score", 260), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "热熔"))
		"clear_random_cross":
			return await _release_clear_targets(_targets_for_random_cross(), _param_int(params, "score", 170), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "共鸣"))
		"clear_line":
			if release_target_cell == Vector2i(-1, -1):
				return false
			return await _release_clear_targets(_targets_for_line(release_target_cell, target_orientation), _param_int(params, "score", 120), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "冷凝"))
		"clear_target_cross":
			if release_target_cell == Vector2i(-1, -1):
				return false
			return await _release_clear_targets(_targets_for_small_cross(release_target_cell), _param_int(params, "score", 120), _param_text(params, "status", "%s共鸣解放" % piece.display_name), _param_text(params, "avatar", "导电"), _param_float(params, "damage_multiplier", 2.0))
		"none", "":
			return false
	push_warning("Unsupported resonance effect_id: %s" % piece.resonance_effect_id)
	return false

func _release_redirect_piece_effects(params: Dictionary) -> bool:
	if chisaki_release_active:
		return false
	chisaki_release_active = true
	chisaki_releases_remaining = max(1, _param_int(params, "action_count", 5))
	chisaki_activation_action_pending = true
	_set_boss_status(_param_text(params, "status", "千咲共鸣解放：团子效应转移至大魔王"), _param_text(params, "avatar", "湮灭"))
	_redraw_game()
	return true

func _release_daniya_explosive_actions(params: Dictionary) -> bool:
	if daniya_release_active:
		return false
	daniya_release_active = true
	daniya_actions_remaining = max(1, _param_int(params, "action_count", 5))
	daniya_activation_action_pending = true
	_set_boss_status(_param_text(params, "status", "达妮娅共鸣解放：五次行动内持续引爆聚爆"), _param_text(params, "avatar", "达妮娅"))
	_redraw_game()
	return true

func _release_spread_photo(params: Dictionary) -> bool:
	var effect_id: String = _param_text(params, "effect_id", "photo")
	var source_stacks: Dictionary = {}
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			var cell: Variant = board.get_cell(pos)
			if cell == null:
				continue
			var stacks: int = board.effect_stacks(cell, effect_id)
			if stacks > 0:
				source_stacks[pos] = stacks
	if source_stacks.is_empty():
		return false
	var proposals: Dictionary = {}
	for source_pos in source_stacks.keys():
		var contribution: int = _photo_spread_contribution(int(source_stacks[source_pos]))
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var target_pos: Vector2i = source_pos + delta
			if not board.in_bounds(target_pos):
				continue
			var target_cell: Variant = board.get_cell(target_pos)
			if target_cell == null or board.effect_stacks(target_cell, effect_id) > 0:
				continue
			proposals[target_pos] = max(int(proposals.get(target_pos, 0)), contribution)
	for target_pos in proposals.keys():
		_add_player_piece_effect_stacks(target_pos, effect_id, int(proposals[target_pos]))
	_set_boss_status(_param_text(params, "status", "菲比共鸣解放：光燥向相邻团子扩散"), _param_text(params, "avatar", "衍射"))
	_redraw_game()
	return true

func _photo_spread_contribution(source_stacks: int) -> int:
	return ceili(float(max(0, source_stacks)) / 2.0)

func _release_create_special_pieces(params: Dictionary) -> bool:
	var candidates: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			var cell: Dictionary = board.get_cell(pos)
			if String(cell["special_effect_id"]).is_empty() and int(cell["locked_turns"]) <= 0:
				candidates.append(pos)
	if candidates.is_empty():
		return false
	candidates.shuffle()
	var count: int = min(_param_int(params, "count", 2), candidates.size())
	for i in range(count):
		var pos: Vector2i = candidates[i]
		var cell: Dictionary = board.get_cell(pos)
		cell["special_effect_id"] = _param_text(params, "special_effect_id", "stripe")
		cell["special_direction"] = "horizontal" if rng.randi_range(0, 1) == 0 else "vertical"
		board.set_cell(pos, cell)
	_add_score(_param_int(params, "score", 120))
	_set_boss_status(_param_text(params, "status", "共鸣解放：生成了特殊团子"), _param_text(params, "avatar", "共鸣"))
	_redraw_game()
	return true

func _release_cleanse_locks(params: Dictionary) -> bool:
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			board.cells[y][x]["locked_turns"] = 0
	suppress_next_enemy_effect = bool(params.get("suppress_next_enemy", true))
	_add_score(_param_int(params, "score", 100))
	_set_boss_status(_param_text(params, "status", "共鸣解放：解除锁定"), _param_text(params, "avatar", "共鸣"))
	_redraw_game()
	return true

func _release_shuffle_board(params: Dictionary) -> bool:
	_shuffle_movable_piece_instances()
	_add_score(_param_int(params, "score", 120))
	_set_boss_status(_param_text(params, "status", "共鸣解放：重排棋盘"), _param_text(params, "avatar", "共鸣"))
	_redraw_game()
	return true

func _param_int(params: Dictionary, key: String, default_value: int) -> int:
	var value: Variant = params.get(key, default_value)
	if value is int:
		return value
	if value is float:
		return roundi(value)
	var text: String = String(value)
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return roundi(float(text))
	return default_value

func _param_float(params: Dictionary, key: String, default_value: float) -> float:
	var value: Variant = params.get(key, default_value)
	if value is int or value is float:
		return float(value)
	var text: String = String(value)
	if text.is_valid_float():
		return float(text)
	return default_value

func _param_text(params: Dictionary, key: String, default_value: String) -> String:
	var value: String = String(params.get(key, default_value))
	return default_value if value.is_empty() else value

func _release_diffraction() -> bool:
	var candidates: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			var cell: Dictionary = board.get_cell(pos)
			if String(cell["special_effect_id"]).is_empty() and int(cell["locked_turns"]) <= 0:
				candidates.append(pos)
	if candidates.is_empty():
		return false
	candidates.shuffle()
	var count: int = min(2, candidates.size())
	for i in range(count):
		var pos: Vector2i = candidates[i]
		var cell: Dictionary = board.get_cell(pos)
		cell["special_effect_id"] = "stripe"
		cell["special_direction"] = "horizontal" if rng.randi_range(0, 1) == 0 else "vertical"
		board.set_cell(pos, cell)
	_add_score(120)
	_set_boss_status("衍射共鸣解放：生成了条纹团子", "衍射")
	_redraw_game()
	return true

func _release_condensation() -> bool:
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			board.cells[y][x]["locked_turns"] = 0
	suppress_next_enemy_effect = true
	_add_score(100)
	_set_boss_status("冷凝共鸣解放：解除锁定并抵消下一次干扰", "冷凝")
	_redraw_game()
	return true

func _release_aero() -> bool:
	_shuffle_movable_piece_instances()
	_add_score(120)
	_set_boss_status("气动共鸣解放：重排棋盘", "气动")
	_redraw_game()
	return true

func _shuffle_movable_piece_instances() -> void:
	var positions: Array = []
	var shuffled_cells: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			if not board.is_immovable(pos):
				positions.append(pos)
				shuffled_cells.append(board.get_cell(pos))
	shuffled_cells.shuffle()
	for index in range(positions.size()):
		board.set_cell(positions[index], shuffled_cells[index])

func _release_clear_targets(targets: Array, base_score: int, status_text: String, avatar_text: String = "共鸣", damage_multiplier: float = 1.0) -> bool:
	targets = _filter_clear_targets(targets, true)
	if targets.is_empty():
		return false
	_charge_resonance_for_cleared_targets(targets)
	_transfer_cleared_effects_to_boss(targets)
	await _animate_clear(targets)
	_animate_attack_boss(targets)
	_damage_boss(targets, damage_multiplier)
	if boss_hp <= 0:
		is_animating_board = false
		_finish_battle()
		return true
	board.clear_positions(targets)
	_add_score(base_score + targets.size() * 8)
	await _collapse_refill_and_animate()
	await _resolve_cascades()
	_set_boss_status(status_text, avatar_text)
	return true

func _targets_for_most_common_piece() -> Array:
	var counts: Dictionary = {}
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var piece_id: String = String(board.cells[y][x]["piece_id"])
			counts[piece_id] = int(counts.get(piece_id, 0)) + 1
	var best_id: String = ""
	var best_count: int = 0
	for piece_id in counts.keys():
		if int(counts[piece_id]) > best_count:
			best_id = String(piece_id)
			best_count = int(counts[piece_id])
	var targets: Array = []
	if best_id.is_empty():
		return targets
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			if String(board.cells[y][x]["piece_id"]) == best_id:
				targets.append(Vector2i(x, y))
	return targets

func _targets_for_random_cross() -> Array:
	var targets: Array = []
	var row: int = rng.randi_range(0, BoardModel.HEIGHT - 1)
	var column: int = rng.randi_range(0, BoardModel.WIDTH - 1)
	for x in range(BoardModel.WIDTH):
		targets.append(Vector2i(x, row))
	for y in range(BoardModel.HEIGHT):
		targets.append(Vector2i(column, y))
	return _unique_in_bounds_targets(targets)

func _targets_for_line(target_cell: Vector2i, orientation: String) -> Array:
	var targets: Array = []
	if orientation == "vertical":
		for y in range(BoardModel.HEIGHT):
			targets.append(Vector2i(target_cell.x, y))
	else:
		for x in range(BoardModel.WIDTH):
			targets.append(Vector2i(x, target_cell.y))
	return targets

func _center_piece_targets(area_size: int) -> Array:
	var targets: Array = []
	var width: int = clamp(area_size, 1, BoardModel.WIDTH)
	var height: int = clamp(area_size, 1, BoardModel.HEIGHT)
	var start_x: int = floori(float(BoardModel.WIDTH - width) / 2.0)
	var start_y: int = floori(float(BoardModel.HEIGHT - height) / 2.0)
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			var pos := Vector2i(x, y)
			if board.is_piece_cell(board.get_cell(pos)):
				targets.append(pos)
	return targets

func _targets_for_small_cross(center: Vector2i) -> Array:
	return _unique_in_bounds_targets([
		center,
		center + Vector2i.LEFT,
		center + Vector2i.RIGHT,
		center + Vector2i.UP,
		center + Vector2i.DOWN,
	])

func _unique_in_bounds_targets(targets: Array) -> Array:
	var result: Array = []
	for pos in targets:
		if board.in_bounds(pos) and not result.has(pos):
			result.append(pos)
	return result

func _locked_cell_count() -> int:
	if board == null or board.cells.is_empty():
		return 0
	var count: int = 0
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			if int(board.cells[y][x]["locked_turns"]) > 0:
				count += 1
	return count

func _set_boss_status(text: String, avatar_text: String = "魔王") -> void:
	boss_status_text = text
	if is_instance_valid(boss_label):
		boss_label.text = text
	if is_instance_valid(boss_avatar):
		boss_avatar.text = avatar_text

func _build_cheat_panel() -> void:
	cheat_panel = PanelContainer.new()
	cheat_panel.visible = false
	cheat_panel.z_index = 100
	cheat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	cheat_panel.anchor_left = 0.04
	cheat_panel.anchor_top = 0.08
	cheat_panel.anchor_right = 0.96
	cheat_panel.anchor_bottom = 0.96
	cheat_panel.offset_left = 0
	cheat_panel.offset_top = 0
	cheat_panel.offset_right = 0
	cheat_panel.offset_bottom = 0
	add_child(cheat_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cheat_panel.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "战斗作弊器"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	cheat_cell_label = Label.new()
	cheat_cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cheat_cell_label)
	var coord_row: HBoxContainer = HBoxContainer.new()
	coord_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coord_row.add_theme_constant_override("separation", 10)
	box.add_child(coord_row)
	coord_row.add_child(_make_cheat_label("X"))
	cheat_x_spin = _make_cheat_spin(0, BoardModel.WIDTH - 1)
	coord_row.add_child(cheat_x_spin)
	coord_row.add_child(_make_cheat_label("Y"))
	cheat_y_spin = _make_cheat_spin(0, BoardModel.HEIGHT - 1)
	coord_row.add_child(cheat_y_spin)
	coord_row.add_child(_make_button("应用坐标", Callable(self, "_cheat_select_coord")))
	coord_row.add_child(_make_button("点棋盘选格", Callable(self, "_cheat_pick_cell_from_board")))
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	box.add_child(action_row)
	action_row.add_child(_make_button("应用到格子", Callable(self, "_cheat_apply_cell")))
	action_row.add_child(_make_button("清为普通", Callable(self, "_cheat_clear_cell_special")))
	var edit_grid: GridContainer = GridContainer.new()
	edit_grid.columns = 2
	edit_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(edit_grid)
	edit_grid.add_child(_make_cheat_label("棋盘实体"))
	cheat_piece_option = OptionButton.new()
	cheat_piece_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for piece: PieceDefinition in catalog.get_unlocked_pieces(save.unlocked_piece_ids):
		cheat_piece_option.add_item(piece.display_name)
		cheat_piece_option.set_item_metadata(cheat_piece_option.get_item_count() - 1, piece.id)
	for echo: EchoDefinition in catalog.echoes.values():
		cheat_piece_option.add_item("声骸：%s" % echo.display_name)
		cheat_piece_option.set_item_metadata(cheat_piece_option.get_item_count() - 1, "echo:%s" % echo.id)
	edit_grid.add_child(cheat_piece_option)
	edit_grid.add_child(_make_cheat_label("状态"))
	cheat_effect_option = OptionButton.new()
	cheat_effect_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_effect_option.add_item("普通")
	cheat_effect_option.set_item_metadata(0, "")
	for effect_id in ["stripe", "bomb", "rainbow"]:
		var effect: SpecialEffectDefinition = catalog.get_effect(effect_id)
		if effect != null:
			cheat_effect_option.add_item(effect.display_name)
			cheat_effect_option.set_item_metadata(cheat_effect_option.get_item_count() - 1, effect.id)
	edit_grid.add_child(cheat_effect_option)
	edit_grid.add_child(_make_cheat_label("方向"))
	cheat_direction_option = OptionButton.new()
	cheat_direction_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_direction_option.add_item("横向")
	cheat_direction_option.set_item_metadata(0, "horizontal")
	cheat_direction_option.add_item("纵向")
	cheat_direction_option.set_item_metadata(1, "vertical")
	edit_grid.add_child(cheat_direction_option)
	edit_grid.add_child(_make_cheat_label("锁定回合"))
	cheat_lock_spin = _make_cheat_spin(0, 9)
	edit_grid.add_child(cheat_lock_spin)
	edit_grid.add_child(_make_cheat_label("叠层效应"))
	cheat_effect_stack_option = OptionButton.new()
	for effect_id in EFFECT_LIMITS.keys():
		cheat_effect_stack_option.add_item(String(EFFECT_NAMES[effect_id]))
		cheat_effect_stack_option.set_item_metadata(cheat_effect_stack_option.get_item_count() - 1, effect_id)
	cheat_effect_stack_option.item_selected.connect(func(_index: int) -> void: _update_cheat_effect_spins())
	edit_grid.add_child(cheat_effect_stack_option)
	edit_grid.add_child(_make_cheat_label("效应层数"))
	cheat_effect_stack_spin = _make_cheat_spin(0, 10)
	edit_grid.add_child(cheat_effect_stack_spin)
	edit_grid.add_child(_make_cheat_label("Boss层数"))
	cheat_boss_effect_stack_spin = _make_cheat_spin(0, 10)
	edit_grid.add_child(cheat_boss_effect_stack_spin)
	var effect_row: HBoxContainer = HBoxContainer.new()
	effect_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(effect_row)
	effect_row.add_child(_make_button("应用团子效应", Callable(self, "_cheat_apply_piece_effect")))
	effect_row.add_child(_make_button("清空团子效应", Callable(self, "_cheat_clear_piece_effects")))
	effect_row.add_child(_make_button("应用Boss效应", Callable(self, "_cheat_apply_boss_effect")))
	effect_row.add_child(_make_button("清空Boss效应", Callable(self, "_cheat_clear_boss_effects")))
	var resonance_grid: GridContainer = GridContainer.new()
	resonance_grid.columns = 2
	resonance_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(resonance_grid)
	resonance_grid.add_child(_make_cheat_label("共鸣团子"))
	cheat_resonance_slot_option = OptionButton.new()
	cheat_resonance_slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_resonance_slot_option.item_selected.connect(func(_index: int) -> void:
		_update_cheat_resonance_spin_from_slot()
	)
	resonance_grid.add_child(cheat_resonance_slot_option)
	resonance_grid.add_child(_make_cheat_label("共鸣能量"))
	cheat_resonance_spin = _make_cheat_spin(0, 999)
	resonance_grid.add_child(cheat_resonance_spin)
	var resonance_row: HBoxContainer = HBoxContainer.new()
	resonance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	resonance_row.add_theme_constant_override("separation", 10)
	box.add_child(resonance_row)
	resonance_row.add_child(_make_button("应用共鸣能量", Callable(self, "_cheat_apply_resonance")))
	resonance_row.add_child(_make_button("共鸣充满", Callable(self, "_cheat_fill_resonance")))
	resonance_row.add_child(_make_button("共鸣清空", Callable(self, "_cheat_clear_resonance")))
	var boss_row: HBoxContainer = HBoxContainer.new()
	boss_row.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_row.add_theme_constant_override("separation", 10)
	box.add_child(boss_row)
	boss_row.add_child(_make_button("大魔王锁3格", Callable(self, "_cheat_boss_lock_three")))
	boss_row.add_child(_make_button("大魔王断Combo", Callable(self, "_cheat_boss_break_combo")))
	boss_row.add_child(_make_button("Boss血量清0", Callable(self, "_cheat_boss_kill")))
	boss_row.add_child(_make_button("随机干扰", Callable(self, "_trigger_enemy_effect")))
	_update_cheat_panel_from_selection()

func _make_cheat_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _make_cheat_spin(minimum: int, maximum: int) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.rounded = true
	spin.custom_minimum_size = Vector2(90, 56)
	return spin

func _toggle_cheat_panel() -> void:
	if cheat_panel == null:
		return
	cheat_panel.visible = not cheat_panel.visible
	_update_cheat_panel_from_selection()

func _cheat_target_pos() -> Vector2i:
	var pos: Vector2i = selected_cell
	if pos == Vector2i(-1, -1) and cheat_x_spin != null and cheat_y_spin != null:
		pos = Vector2i(int(cheat_x_spin.value), int(cheat_y_spin.value))
	return pos

func _cheat_select_coord() -> void:
	selected_cell = Vector2i(int(cheat_x_spin.value), int(cheat_y_spin.value))
	_update_cheat_panel_from_selection()
	_redraw_game()

func _cheat_pick_cell_from_board() -> void:
	cheat_pick_cell_pending = true
	if cheat_panel != null:
		cheat_panel.visible = false
	_set_boss_status("作弊器：点击棋盘上的目标格子", "选格")

func _cheat_apply_cell() -> void:
	var pos: Vector2i = _cheat_target_pos()
	if board == null or not board.in_bounds(pos):
		return
	selected_cell = pos
	var entity_id: String = String(cheat_piece_option.get_selected_metadata())
	var effect_id: String = String(cheat_effect_option.get_selected_metadata())
	var direction: String = String(cheat_direction_option.get_selected_metadata())
	var previous_cell: Dictionary = board.get_cell(pos)
	if entity_id.begins_with("echo:"):
		board.set_cell(pos, board.new_echo_cell(entity_id.trim_prefix("echo:")))
	else:
		board.set_cell(pos, {
		"entity_kind": "piece",
		"piece_id": entity_id,
		"echo_id": "",
		"rune_id": String(previous_cell.get("rune_id", "")) if board.is_piece_cell(previous_cell) else "",
		"special_effect_id": effect_id,
		"special_direction": direction,
		"locked_turns": int(cheat_lock_spin.value),
		"effects": previous_cell.get("effects", {}).duplicate(true),
		})
	_set_boss_status("作弊器：已修改 (%d,%d)" % [pos.x, pos.y], "作弊")
	_redraw_game()

func _cheat_clear_cell_special() -> void:
	var pos: Vector2i = _cheat_target_pos()
	if board == null or not board.in_bounds(pos):
		return
	var cell: Dictionary = board.get_cell(pos)
	cell["special_effect_id"] = ""
	cell["special_direction"] = "horizontal"
	cell["locked_turns"] = 0
	board.set_cell(pos, cell)
	selected_cell = pos
	_set_boss_status("作弊器：已清除 (%d,%d) 状态" % [pos.x, pos.y], "作弊")
	_redraw_game()

func _selected_stack_effect_id() -> String:
	if cheat_effect_stack_option == null or cheat_effect_stack_option.get_item_count() <= 0:
		return ""
	return String(cheat_effect_stack_option.get_selected_metadata())

func _cheat_apply_piece_effect() -> void:
	var pos: Vector2i = _cheat_target_pos()
	var effect_id: String = _selected_stack_effect_id()
	if board == null or not board.in_bounds(pos) or effect_id.is_empty():
		return
	_set_piece_effect_stacks(pos, effect_id, int(cheat_effect_stack_spin.value))

func _set_piece_effect_stacks(pos: Vector2i, effect_id: String, amount: int, resolve_triggers: bool = true) -> int:
	if board == null:
		return 0
	var value: int = board.set_effect_stacks(pos, effect_id, amount)
	if resolve_triggers:
		_resolve_piece_effect_triggers()
	return value

func _add_piece_effect_stacks(pos: Vector2i, effect_id: String, amount: int, resolve_triggers: bool = true) -> int:
	if board == null or not board.in_bounds(pos):
		return 0
	var cell: Dictionary = board.get_cell(pos)
	return _set_piece_effect_stacks(pos, effect_id, board.effect_stacks(cell, effect_id) + amount, resolve_triggers)

func _add_player_piece_effect_stacks(pos: Vector2i, effect_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if chisaki_release_active and player_action_in_progress:
		_add_player_boss_effect_stacks(effect_id, amount)
		return true
	if board != null and board.in_bounds(pos) and board.get_cell(pos) != null:
		board.add_effect_stacks(pos, effect_id, amount)
	return false

func _cheat_clear_piece_effects() -> void:
	var pos: Vector2i = _cheat_target_pos()
	if board == null or not board.in_bounds(pos):
		return
	var cell: Dictionary = board.get_cell(pos)
	cell["effects"] = {}
	board.set_cell(pos, cell)
	_redraw_game()

func _cheat_apply_boss_effect() -> void:
	var effect_id: String = _selected_stack_effect_id()
	if effect_id.is_empty():
		return
	_set_boss_effect_stacks(effect_id, int(cheat_boss_effect_stack_spin.value))
	if boss_hp <= 0 and not boss_hp_infinite:
		_finish_battle()
	else:
		_redraw_game()

func _cheat_clear_boss_effects() -> void:
	_reset_boss_effects()
	_redraw_game()

func _update_cheat_effect_spins() -> void:
	var effect_id: String = _selected_stack_effect_id()
	if effect_id.is_empty():
		return
	var piece_limit: int = int(EFFECT_LIMITS[effect_id])
	if cheat_effect_stack_spin != null:
		cheat_effect_stack_spin.max_value = piece_limit
	if cheat_boss_effect_stack_spin != null:
		cheat_boss_effect_stack_spin.max_value = _boss_effect_limit(effect_id)
	var pos: Vector2i = _cheat_target_pos()
	if cheat_effect_stack_spin != null and board != null and board.in_bounds(pos):
		cheat_effect_stack_spin.value = board.effect_stacks(board.get_cell(pos), effect_id)
	if cheat_boss_effect_stack_spin != null:
		cheat_boss_effect_stack_spin.value = _boss_effect_stacks(effect_id)

func _resolve_piece_effect_triggers() -> void:
	if board == null or is_animating_board:
		return
	is_animating_board = true
	var guard: int = 0
	while guard < BoardModel.WIDTH * BoardModel.HEIGHT:
		guard += 1
		var explosive_pos: Vector2i = _find_full_effect_piece("explosive")
		if explosive_pos == Vector2i(-1, -1):
			break
		for y in range(explosive_pos.y - 2, explosive_pos.y + 3):
			for x in range(explosive_pos.x - 2, explosive_pos.x + 3):
				var ring_pos: Vector2i = Vector2i(x, y)
				if board.in_bounds(ring_pos) and max(abs(x - explosive_pos.x), abs(y - explosive_pos.y)) == 2:
					_add_player_piece_effect_stacks(ring_pos, "explosive", 2)
		var targets: Array = _filter_clear_targets(_square_targets(explosive_pos, 1))
		if not targets.has(explosive_pos):
			board.set_effect_stacks(explosive_pos, "explosive", 0)
		if not targets.is_empty():
			_transfer_cleared_effects_to_boss(targets)
			_charge_resonance_for_cleared_targets(targets)
			await _animate_clear(targets)
			_animate_attack_boss(targets)
			_damage_boss(targets)
			if boss_hp <= 0 and not boss_hp_infinite:
				is_animating_board = false
				_finish_battle()
				return
			board.clear_positions(targets)
			await _collapse_refill_and_animate()
	await _resolve_conductive_gather()
	await _resolve_cascades()
	is_animating_board = false
	_redraw_game()

func _find_full_effect_piece(effect_id: String) -> Vector2i:
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			var cell: Variant = board.get_cell(pos)
			if cell != null and board.effect_stacks(cell, effect_id) >= int(EFFECT_LIMITS[effect_id]):
				return pos
	return Vector2i(-1, -1)

func _resolve_conductive_gather() -> void:
	var sources: Array = []
	for y in range(BoardModel.HEIGHT):
		for x in range(BoardModel.WIDTH):
			var pos: Vector2i = Vector2i(x, y)
			var cell: Variant = board.get_cell(pos)
			if cell != null and board.effect_stacks(cell, "conductive") >= int(EFFECT_LIMITS["conductive"]):
				sources.append(pos)
	if sources.size() < 2:
		return
	var pairs: Array = _pair_conductive_sources(sources)
	var path_targets: Array = []
	var destinations: Array = []
	for pair in pairs:
		var first: Vector2i = pair[0]
		var second: Vector2i = pair[1]
		var attraction: Dictionary = _electromagnetic_attraction(first, second)
		destinations.append([attraction["first_destination"], attraction["second_destination"]])
		for target in attraction["cleared_path"]:
			if not sources.has(target) and not path_targets.has(target):
				path_targets.append(target)
	path_targets = _filter_clear_targets(path_targets)
	await _animate_electromagnetic_attraction(pairs, destinations, path_targets)
	if not path_targets.is_empty():
		_transfer_cleared_effects_to_boss(path_targets)
		_charge_resonance_for_cleared_targets(path_targets)
		await _animate_clear(path_targets)
		_animate_attack_boss(path_targets)
		_damage_boss(path_targets)
		board.clear_positions(path_targets)
	var preserved_pieces: Array = []
	for pair_index in range(pairs.size()):
		var pair: Array = pairs[pair_index]
		var first: Vector2i = pair[0]
		var second: Vector2i = pair[1]
		var first_piece: Dictionary = board.get_cell(first).duplicate(true)
		var second_piece: Dictionary = board.get_cell(second).duplicate(true)
		first_piece["effects"].erase("conductive")
		second_piece["effects"].erase("conductive")
		preserved_pieces.append([first_piece, second_piece, destinations[pair_index][0], destinations[pair_index][1]])
		board.set_cell(first, null)
		board.set_cell(second, null)
	await _collapse_refill_and_animate()
	for preserved in preserved_pieces:
		board.set_cell(preserved[2], preserved[0])
		board.set_cell(preserved[3], preserved[1])
	_redraw_game()

func _animate_electromagnetic_attraction(pairs: Array, destinations: Array, path_targets: Array) -> void:
	if board_grid == null:
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var animated: bool = false
	for pair_index in range(pairs.size()):
		var pair: Array = pairs[pair_index]
		var pair_destinations: Array = destinations[pair_index]
		for piece_index in range(2):
			var source: Vector2i = pair[piece_index]
			var destination: Vector2i = pair_destinations[piece_index]
			var source_button: Button = _get_cell_button(source)
			var destination_button: Button = _get_cell_button(destination)
			if source_button == null or destination_button == null:
				continue
			animated = true
			source_button.z_index = 40
			source_button.pivot_offset = source_button.size * 0.5
			tween.tween_property(source_button, "position", destination_button.position, ELECTROMAGNETIC_MOVE_SECONDS).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(source_button, "scale", Vector2(1.12, 1.12), ELECTROMAGNETIC_MOVE_SECONDS * 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(source_button, "scale", Vector2.ONE, ELECTROMAGNETIC_MOVE_SECONDS * 0.52).set_delay(ELECTROMAGNETIC_MOVE_SECONDS * 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(source_button, "modulate", Color(0.72, 0.92, 1.25, 1.0), ELECTROMAGNETIC_MOVE_SECONDS * 0.45)
			tween.tween_property(source_button, "modulate", Color.WHITE, ELECTROMAGNETIC_MOVE_SECONDS * 0.55).set_delay(ELECTROMAGNETIC_MOVE_SECONDS * 0.45)
	for target in path_targets:
		var path_button: Button = _get_cell_button(target)
		if path_button == null:
			continue
		animated = true
		path_button.pivot_offset = path_button.size * 0.5
		tween.tween_property(path_button, "modulate", Color(0.34, 0.62, 0.92, 0.42), ELECTROMAGNETIC_MOVE_SECONDS * 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(path_button, "scale", Vector2(0.82, 0.82), ELECTROMAGNETIC_MOVE_SECONDS * 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if animated:
		await tween.finished
		await get_tree().create_timer(0.08).timeout

func _pair_conductive_sources(sources: Array) -> Array:
	var remaining: Array = sources.duplicate()
	var pairs: Array = []
	while remaining.size() >= 2:
		var first: Vector2i = remaining.pop_front()
		var nearest_index: int = 0
		var nearest_distance: int = 999999
		for index in range(remaining.size()):
			var candidate: Vector2i = remaining[index]
			var distance: int = abs(first.x - candidate.x) + abs(first.y - candidate.y)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_index = index
		var second: Vector2i = remaining.pop_at(nearest_index)
		pairs.append([first, second])
	return pairs

func _horizontal_then_vertical_path(start: Vector2i, destination: Vector2i) -> Array:
	var result: Array = []
	var cursor: Vector2i = start
	while cursor.x != destination.x:
		cursor.x += 1 if destination.x > cursor.x else -1
		result.append(cursor)
	while cursor.y != destination.y:
		cursor.y += 1 if destination.y > cursor.y else -1
		result.append(cursor)
	return result

func _electromagnetic_attraction(first: Vector2i, second: Vector2i) -> Dictionary:
	var full_path: Array = [first]
	full_path.append_array(_horizontal_then_vertical_path(first, second))
	var first_index: int = (full_path.size() - 2) / 2
	var second_index: int = first_index + 1
	return {
		"first_destination": full_path[first_index],
		"second_destination": full_path[second_index],
		"cleared_path": full_path.slice(1, full_path.size() - 1),
	}

func _cheat_selected_resonance_slot() -> int:
	if cheat_resonance_slot_option == null or cheat_resonance_slot_option.get_item_count() <= 0:
		return -1
	return int(cheat_resonance_slot_option.get_selected_metadata())

func _update_cheat_resonance_options() -> void:
	if cheat_resonance_slot_option == null:
		return
	var selected_metadata: Variant = null
	if cheat_resonance_slot_option.get_item_count() > 0:
		selected_metadata = cheat_resonance_slot_option.get_selected_metadata()
	cheat_resonance_slot_option.clear()
	for slot_index in range(current_roster.size()):
		var piece: PieceDefinition = catalog.get_piece(current_roster[slot_index])
		var piece_name: String = piece.display_name if piece != null else "空槽"
		cheat_resonance_slot_option.add_item("%d. %s" % [slot_index + 1, piece_name])
		cheat_resonance_slot_option.set_item_metadata(cheat_resonance_slot_option.get_item_count() - 1, slot_index)
	if cheat_resonance_slot_option.get_item_count() <= 0:
		return
	_select_option_by_metadata(cheat_resonance_slot_option, selected_metadata)
	_update_cheat_resonance_spin_from_slot()

func _update_cheat_resonance_spin_from_slot() -> void:
	if cheat_resonance_spin == null:
		return
	var slot_index: int = _cheat_selected_resonance_slot()
	if slot_index < 0:
		cheat_resonance_spin.value = 0
		return
	cheat_resonance_spin.max_value = _resonance_cost(slot_index)
	if slot_index < current_roster.size() and current_roster[slot_index] == SIGRIKA_PIECE_ID:
		cheat_resonance_spin.max_value = max(0, SIGRIKA_SPECIAL_ENERGY_MAX - sigrika_special_energy)
	cheat_resonance_spin.value = _resonance_value(slot_index)

func _cheat_set_resonance(slot_index: int, value: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_ATTRIBUTES.size():
		return
	while resonance_values.size() < SLOT_ATTRIBUTES.size():
		resonance_values.append(0)
	var cost: int = _resonance_cost(slot_index)
	resonance_values[slot_index] = clamp(value, 0, cost)
	if slot_index < current_roster.size() and current_roster[slot_index] == COLETTA_PIECE_ID:
		coletta_release_active = resonance_values[slot_index] >= cost
	if slot_index < current_roster.size() and current_roster[slot_index] == KAKARO_PIECE_ID:
		kakaro_release_active = false
		kakaro_releases_remaining = 0
		_activate_kakaro_release_if_full()
	if slot_index < current_roster.size() and current_roster[slot_index] == CHISAKI_PIECE_ID:
		_clear_chisaki_release_state()
	if slot_index < current_roster.size() and current_roster[slot_index] == DANIYA_PIECE_ID:
		_clear_daniya_release_state()
	if slot_index < current_roster.size() and current_roster[slot_index] == SIGRIKA_PIECE_ID:
		if value <= 0:
			sigrika_special_energy = 0
		resonance_values[slot_index] = min(resonance_values[slot_index], SIGRIKA_SPECIAL_ENERGY_MAX - sigrika_special_energy)
		sigrika_pending_sun_spirits = max(0, int(resonance_values[slot_index] / 2) - _sigrika_sun_spirit_positions().size())
		_maintain_sigrika_board_state()
	_set_boss_status("作弊器：%s共鸣能量调整为 %d/%d" % [SLOT_ATTRIBUTES[slot_index], resonance_values[slot_index], cost], "作弊")
	_redraw_game()

func _cheat_apply_resonance() -> void:
	if cheat_resonance_spin == null:
		return
	_cheat_set_resonance(_cheat_selected_resonance_slot(), int(cheat_resonance_spin.value))

func _cheat_fill_resonance() -> void:
	var slot_index: int = _cheat_selected_resonance_slot()
	_cheat_set_resonance(slot_index, _resonance_cost(slot_index))

func _cheat_clear_resonance() -> void:
	_cheat_set_resonance(_cheat_selected_resonance_slot(), 0)

func _cheat_boss_lock_three() -> void:
	board.lock_random_cells(3)
	_set_boss_status("作弊器：团子大魔王锁定了 3 个格子", "攻击")
	_redraw_game()

func _cheat_boss_break_combo() -> void:
	combo = 0
	_set_boss_status("作弊器：团子大魔王打断了 Combo", "怒")
	_redraw_game()

func _cheat_boss_kill() -> void:
	if board == null or is_animating_board or (not boss_hp_infinite and boss_hp <= 0):
		return
	boss_hp_infinite = false
	boss_hp = 0
	_update_boss_hp_ui()
	_set_boss_status("作弊器：Boss 血量已清 0", "胜利")
	_finish_battle()

func _update_cheat_panel_from_selection() -> void:
	if cheat_panel == null or board == null:
		return
	var pos: Vector2i = _cheat_target_pos()
	if not board.in_bounds(pos):
		pos = Vector2i(0, 0)
	if cheat_x_spin != null:
		cheat_x_spin.value = pos.x
	if cheat_y_spin != null:
		cheat_y_spin.value = pos.y
	var cell: Variant = board.get_cell(pos)
	if cell == null:
		if cheat_cell_label != null:
			cheat_cell_label.text = "当前格子：(%d,%d)，正在下落" % [pos.x, pos.y]
		return
	if cheat_cell_label != null:
		cheat_cell_label.text = "当前格子：(%d,%d)，点击棋盘可选格" % [pos.x, pos.y]
	_select_option_by_metadata(cheat_piece_option, "echo:%s" % String(cell.get("echo_id", "")) if board.is_echo_cell(cell) else String(cell.get("piece_id", "")))
	_select_option_by_metadata(cheat_effect_option, String(cell["special_effect_id"]))
	_select_option_by_metadata(cheat_direction_option, String(cell["special_direction"]))
	if cheat_lock_spin != null:
		cheat_lock_spin.value = int(cell["locked_turns"])
	_update_cheat_effect_spins()
	_update_cheat_resonance_options()

func _select_option_by_metadata(option: OptionButton, value: Variant) -> void:
	if option == null:
		return
	for i in range(option.get_item_count()):
		var item_metadata: Variant = option.get_item_metadata(i)
		if item_metadata == value or str(item_metadata) == str(value):
			option.select(i)
			return
	option.select(0)

func _on_run_battle_won() -> void:
	var node_type: String = String(current_run_node.get("type", "battle"))
	run_state["actions"] = clamp(int(run_state.get("actions", RUN_MAX_ACTIONS)) + RUN_BATTLE_ACTION_RECOVERY, 0, RUN_MAX_ACTIONS)
	_apply_run_heal_after_battle()
	if node_type == "boss":
		_advance_run_after_node()
		return
	var reward_items: Array = _battle_reward_for_node(current_run_node)
	_show_run_reward("战斗胜利", reward_items)

func _on_run_battle_lost() -> void:
	_clear_chisaki_release_state()
	_clear_daniya_release_state()
	run_state["lives"] = max(0, int(run_state.get("lives", RUN_MAX_LIVES)) - 1)
	if int(run_state.get("lives", 0)) <= 0:
		_finish_run_failed()
		return
	# Spending a life starts a fresh retry; otherwise an action-exhaustion loss
	# would return to the map with zero actions and could never be retried.
	run_state["actions"] = RUN_MAX_ACTIONS
	_clear_screen()
	current_screen = "run_loss"
	_add_title("战斗失利")
	var label: Label = Label.new()
	label.text = "损失 1 点生命。\n剩余生命：%d / %d" % [int(run_state.get("lives", 0)), RUN_MAX_LIVES]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)
	root.add_child(_make_button("回到路线", Callable(self, "_show_run_map")))

func _battle_reward_for_node(node: Dictionary) -> Array:
	var run_floor: int = int(node.get("floor", int(run_state.get("floor", 1))))
	var node_type: String = String(node.get("type", "battle"))
	var reward_items: Array = [_make_shell_reward(8 + run_floor * 2)]
	if node_type == "elite":
		reward_items[0] = _make_shell_reward(14 + run_floor * 3)
		reward_items.append(_make_collectible_reward(_random_collectible("rare")))
	elif rng.randf() <= 0.35:
		reward_items.append(_make_collectible_reward(_random_collectible("common")))
	return reward_items

func _show_supply_node() -> void:
	var roll: int = rng.randi_range(0, 2)
	var reward_items: Array = []
	if roll == 0:
		reward_items.append(_make_life_reward(1))
	elif roll == 1:
		reward_items.append(_make_shell_reward(12 + int(run_state.get("floor", 1)) * 2))
	else:
		reward_items.append(_make_collectible_reward(_random_collectible("common")))
	_show_run_reward("补给包", reward_items)

func _show_shop_node() -> void:
	if _run_shop_items().is_empty():
		run_state["shop_items"] = _generate_shop_items()
	_clear_screen()
	current_screen = "run_shop"
	_add_title("贝币商城")
	var summary: Label = Label.new()
	summary.text = "当前贝币：%d。可以连续购买多个藏品，完成后跳过商城继续探索。" % int(run_state.get("shells", 0))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(summary)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)
	var shop_items: Array = _run_shop_items()
	for index in range(shop_items.size()):
		var item: Dictionary = shop_items[index]
		var collectible: Dictionary = _shop_item_collectible(item)
		var price: int = int(item.get("price", _shop_price(collectible)))
		var sold: bool = bool(item.get("sold", false))
		var captured_index: int = index
		var sold_text: String = "\n已售罄" if sold else ""
		var button: Button = _make_button("%s\n%s\n价格：%d 贝币" % [
			_collectible_name(collectible),
			_collectible_description(collectible) + sold_text,
			price,
		], func() -> void:
			_buy_shop_item(captured_index)
		)
		button.custom_minimum_size = Vector2(330, 190)
		button.disabled = sold or int(run_state.get("shells", 0)) < price
		row.add_child(button)
	root.add_child(_make_button("跳过商城", Callable(self, "_advance_run_after_node")))

func _show_event_node() -> void:
	_clear_screen()
	current_screen = "run_event"
	_add_title("随机事件")
	var info: Label = Label.new()
	info.text = "选择一个事件结果。若事件产生奖励，会作为奖励包展示。"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info)
	root.add_child(_make_button("冒险打捞：失去 1 生命，获得贝币和稀有藏品", Callable(self, "_event_danger_dive")))
	root.add_child(_make_button("潮声祝福：恢复 1 生命", Callable(self, "_event_tide_blessing")))
	root.add_child(_make_button("空手离开", Callable(self, "_advance_run_after_node")))

func _event_danger_dive() -> void:
	if int(run_state.get("lives", 0)) <= 1:
		_show_run_reward("谨慎打捞", [_make_shell_reward(10)])
		return
	run_state["lives"] = int(run_state.get("lives", 0)) - 1
	_show_run_reward("冒险打捞", [_make_shell_reward(18), _make_collectible_reward(_random_collectible("rare"))])

func _event_tide_blessing() -> void:
	_show_run_reward("潮声祝福", [_make_life_reward(1)])

func _show_run_reward(title: String, reward_items: Array) -> void:
	pending_run_reward_items = []
	for item in reward_items:
		var reward_item: Dictionary = item
		if not reward_item.has("accepted"):
			reward_item["accepted"] = null
		pending_run_reward_items.append(reward_item)
	_clear_screen()
	current_screen = "run_reward"
	_add_title(title)
	var label: Label = Label.new()
	label.text = "逐项决定是否收下奖励。"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(label)
	var viewport_size: Vector2 = get_viewport_rect().size
	var reward_grid: GridContainer = GridContainer.new()
	reward_grid.columns = max(1, min(pending_run_reward_items.size(), 2 if viewport_size.x < 1180.0 else 3))
	reward_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reward_grid.add_theme_constant_override("h_separation", 14)
	reward_grid.add_theme_constant_override("v_separation", 14)
	root.add_child(reward_grid)
	var card_width: float = floor(clamp((viewport_size.x - 120.0) / max(1.0, float(reward_grid.columns)), 300.0, 420.0))
	for index in range(pending_run_reward_items.size()):
		var item_data: Dictionary = pending_run_reward_items[index]
		var card: VBoxContainer = VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_theme_constant_override("separation", 8)
		card.custom_minimum_size = Vector2(card_width, 250)
		reward_grid.add_child(card)
		var item_label: Label = Label.new()
		item_label.text = _run_reward_item_text(item_data)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		item_label.custom_minimum_size = Vector2(card_width, 130)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(item_label)
		var state_label: Label = Label.new()
		state_label.text = _reward_choice_state_text(item_data)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state_label.custom_minimum_size = Vector2(card_width, 32)
		state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(state_label)
		var choice_row: HBoxContainer = HBoxContainer.new()
		choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
		choice_row.add_theme_constant_override("separation", 8)
		choice_row.custom_minimum_size = Vector2(card_width, 56)
		choice_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(choice_row)
		var captured_index: int = index
		choice_row.add_child(_make_reward_choice_button("收下", func() -> void: _choose_reward_item(captured_index, true)))
		choice_row.add_child(_make_reward_choice_button("丢弃", func() -> void: _choose_reward_item(captured_index, false)))
	if _all_reward_items_chosen():
		root.add_child(_make_button("继续探索", Callable(self, "_continue_after_reward_choices")))

func _make_reward_choice_button(text: String, callback: Callable) -> Button:
	var button: Button = _make_button(text, callback)
	button.custom_minimum_size = Vector2(128, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	return button

func _choose_reward_item(index: int, accepted: bool) -> void:
	if index < 0 or index >= pending_run_reward_items.size():
		return
	pending_run_reward_items[index]["accepted"] = accepted
	_show_run_reward("奖励确认", pending_run_reward_items)

func _continue_after_reward_choices() -> void:
	for item in pending_run_reward_items:
		var reward_item: Dictionary = item
		if bool(reward_item.get("accepted", false)):
			_apply_run_reward_item(reward_item)
	pending_run_reward_items = []
	_advance_run_after_node()

func _apply_run_reward_item(item: Dictionary) -> void:
	match String(item.get("type", "")):
		"shells":
			run_state["shells"] = int(run_state.get("shells", 0)) + int(item.get("amount", 0))
		"life":
			run_state["lives"] = clamp(int(run_state.get("lives", RUN_MAX_LIVES)) + int(item.get("amount", 0)), 0, RUN_MAX_LIVES)
		"collectible":
			var collectible: Dictionary = _reward_item_collectible(item)
			if not collectible.is_empty():
				var collectibles: Array = _run_collectibles()
				collectibles.append(collectible)
				run_state["collectibles"] = collectibles
				_mark_collectible_seen(String(collectible.get("id", "")))

func _generate_shop_items() -> Array:
	var items: Array = []
	for i in range(3):
		var collectible: Dictionary = _random_collectible("common")
		items.append({
			"collectible": collectible,
			"price": _shop_price(collectible),
			"sold": false,
		})
	return items

func _run_shop_items() -> Array:
	var items: Variant = run_state.get("shop_items", [])
	if items is Array:
		return items
	return []

func _shop_item_collectible(item: Dictionary) -> Dictionary:
	var collectible: Variant = item.get("collectible", {})
	if collectible is Dictionary:
		return collectible
	return {}

func _buy_shop_item(index: int) -> void:
	var shop_items: Array = _run_shop_items()
	if index < 0 or index >= shop_items.size():
		_show_shop_node()
		return
	var item: Dictionary = shop_items[index]
	if bool(item.get("sold", false)):
		_show_shop_node()
		return
	var collectible: Dictionary = _shop_item_collectible(item)
	var price: int = int(item.get("price", _shop_price(collectible)))
	if int(run_state.get("shells", 0)) < price:
		_show_shop_node()
		return
	run_state["shells"] = int(run_state.get("shells", 0)) - price
	var collectibles: Array = _run_collectibles()
	collectibles.append(collectible)
	run_state["collectibles"] = collectibles
	_mark_collectible_seen(String(collectible.get("id", "")))
	item["sold"] = true
	shop_items[index] = item
	run_state["shop_items"] = shop_items
	_show_shop_node()

func _advance_run_after_node() -> void:
	run_state["shop_items"] = []
	run_state["completed_nodes"] = int(run_state.get("completed_nodes", 0)) + 1
	var current_node_id: String = String(run_state.get("current_node_id", ""))
	var completed_node: Dictionary = _find_run_node(current_node_id)
	if completed_node.is_empty():
		_show_run_map()
		return
	_mark_run_node_completed(current_node_id)
	if String(completed_node.get("type", "")) == "boss":
		_start_next_floor_or_finish()
		return
	run_state["available_node_ids"] = _node_links(completed_node)
	run_state["current_node_id"] = ""
	_show_run_map()

func _start_next_floor_or_finish() -> void:
	var next_floor: int = int(run_state.get("floor", 1)) + 1
	if next_floor > RUN_TOTAL_FLOORS:
		_finish_run_complete()
		return
	run_state["floor"] = next_floor
	_generate_floor_map(next_floor)
	_show_run_map()

func _finish_run_complete() -> void:
	_finish_run(true)

func _finish_run_failed() -> void:
	_finish_run(false)

func _finish_run(completed: bool) -> void:
	save.high_score = max(save.high_score, score)
	save.run_best_floor = max(save.run_best_floor, int(run_state.get("floor", 1)))
	save.run_total_shells += int(run_state.get("shells", 0))
	save.save()
	_clear_screen()
	current_screen = "run_end"
	_add_title("探索完成" if completed else "探索结束")
	var summary: Label = Label.new()
	summary.text = "抵达层数：%d / %d\n分数：%d\n贝币：%d\n藏品：%d\n历史最高层：%d\n累计贝币：%d" % [
		int(run_state.get("floor", 1)),
		RUN_TOTAL_FLOORS,
		score,
		int(run_state.get("shells", 0)),
		_run_collectibles().size(),
		save.run_best_floor,
		save.run_total_shells,
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(summary)
	run_active = false
	run_state = {}
	current_run_node = {}
	pending_run_reward_items = []
	root.add_child(_make_button("再来一次探索", Callable(self, "_start_run")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _run_map_nodes() -> Array:
	var nodes: Variant = run_state.get("map_nodes", [])
	if nodes is Array:
		return nodes
	return []

func _run_nodes_for_row(row_index: int) -> Array:
	var result: Array = []
	for node in _run_map_nodes():
		var node_data: Dictionary = node
		if int(node_data.get("row", -1)) == row_index:
			result.append(node_data)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("lane", 0)) < int(b.get("lane", 0))
	)
	return result

func _run_node_short_label(node: Dictionary) -> String:
	if String(node.get("type", "")) == "boss":
		return "BOSS"
	return "%d-%d" % [int(node.get("row", 0)) + 1, int(node.get("lane", 0)) + 1]

func _run_map_node_positions(canvas_size: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var column_gap: float = canvas_size.x / float(RUN_MAP_ROWS + 1)
	var lane_y: Array[float] = [
		canvas_size.y * 0.22,
		canvas_size.y * 0.50,
		canvas_size.y * 0.78,
	]
	for node in _run_map_nodes():
		var node_data: Dictionary = node
		var row_index: int = int(node_data.get("row", 0))
		var lane_index: int = int(node_data.get("lane", 0))
		var x: float = column_gap * (float(row_index) + 0.5)
		var y: float = canvas_size.y * 0.5
		if String(node_data.get("type", "")) != "boss":
			var row_nodes: Array = _run_nodes_for_row(row_index)
			var row_count: int = max(1, row_nodes.size())
			if row_count == 2:
				y = canvas_size.y * (0.34 if lane_index == 0 else 0.66)
			else:
				y = lane_y[clamp(lane_index, 0, lane_y.size() - 1)]
		positions[String(node_data.get("id", ""))] = Vector2(x, y)
	return positions

func _make_run_map_node_button(node: Dictionary) -> Button:
	var node_type: String = String(node.get("type", "battle"))
	var node_id: String = String(node.get("id", ""))
	var available: bool = _is_run_node_available(node_id)
	var completed: bool = bool(node.get("completed", false))
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(250, 96 if node_type != "boss" else 118)
	button.text = "%s\n%s" % [_run_node_icon(node_type), _run_node_map_label(node)]
	button.add_theme_font_size_override("font_size", 22 if node_type != "boss" else 26)
	button.add_theme_stylebox_override("normal", _make_run_node_style(node_type, available, completed, false))
	button.add_theme_stylebox_override("hover", _make_run_node_style(node_type, true, completed, true))
	button.add_theme_stylebox_override("pressed", _make_run_node_style(node_type, true, completed, true))
	button.add_theme_stylebox_override("disabled", _make_run_node_style(node_type, false, completed, false))
	return button

func _run_node_icon(node_type: String) -> String:
	match node_type:
		"battle":
			return "× 作战"
		"elite":
			return "!! 精英作战"
		"supply":
			return "+ 补给"
		"shop":
			return "$ 商城"
		"event":
			return "? 不期而遇"
		"boss":
			return "▲ 层级首领"
	return "· 节点"

func _run_node_map_label(node: Dictionary) -> String:
	var status: String = "DONE" if bool(node.get("completed", false)) else ("READY" if _is_run_node_available(String(node.get("id", ""))) else "LOCKED")
	return "%s    %s" % [_run_node_short_label(node), status]

func _make_run_node_style(node_type: String, available: bool, completed: bool, hover: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var color: Color = Color(0.10, 0.12, 0.12, 0.88)
	if node_type == "boss":
		color = Color(0.20, 0.12, 0.11, 0.92)
	elif node_type == "shop":
		color = Color(0.16, 0.11, 0.24, 0.90)
	elif node_type == "supply":
		color = Color(0.08, 0.20, 0.20, 0.90)
	elif node_type == "event":
		color = Color(0.13, 0.18, 0.13, 0.90)
	if completed:
		color = Color(0.08, 0.16, 0.11, 0.82)
	elif not available:
		color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 0.58)
	elif hover:
		color = color.lightened(0.18)
	style.bg_color = color
	style.border_color = Color(0.95, 0.98, 0.92, 0.95) if available else Color(0.55, 0.58, 0.56, 0.45)
	style.set_border_width_all(2 if available else 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _run_row_links_text(row_index: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node in _run_nodes_for_row(row_index):
		var node_data: Dictionary = node
		var targets: PackedStringArray = PackedStringArray()
		for target_id in _node_links(node_data):
			var target: Dictionary = _find_run_node(String(target_id))
			if not target.is_empty():
				targets.append(_run_node_short_label(target))
		if not targets.is_empty():
			parts.append("%s -> %s" % [_run_node_short_label(node_data), String(", ").join(targets)])
	if parts.is_empty():
		return ""
	return "路线：%s" % String(" / ").join(parts)

func _find_run_node(node_id: String) -> Dictionary:
	for node in _run_map_nodes():
		var node_data: Dictionary = node
		if String(node_data.get("id", "")) == node_id:
			return node_data
	return {}

func _is_run_node_available(node_id: String) -> bool:
	var available_ids: Variant = run_state.get("available_node_ids", [])
	return available_ids is Array and available_ids.has(node_id)

func _run_available_node_ids() -> Array:
	var available_ids: Variant = run_state.get("available_node_ids", [])
	if available_ids is Array:
		return available_ids
	return []

func _mark_run_node_completed(node_id: String) -> void:
	var nodes: Array = _run_map_nodes()
	for index in range(nodes.size()):
		var node_data: Dictionary = nodes[index]
		if String(node_data.get("id", "")) == node_id:
			node_data["completed"] = true
			nodes[index] = node_data
			break
	run_state["map_nodes"] = nodes

func _node_links(node: Dictionary) -> Array:
	var links: Variant = node.get("links", [])
	if links is Array:
		return links.duplicate()
	return []

func _run_collectibles() -> Array:
	var collectibles: Variant = run_state.get("collectibles", [])
	if collectibles is Array:
		return collectibles.duplicate()
	return []

func _show_run_collectible_bag(selected_index: int = -1) -> void:
	_clear_screen()
	current_screen = "run_collectible_bag"
	var viewport_size: Vector2 = get_viewport_rect().size
	var margin_x: int = roundi(clamp(viewport_size.x * 0.02, 16.0, 36.0))
	var margin_y: int = roundi(clamp(viewport_size.y * 0.02, 12.0, 28.0))
	_set_page_margins(margin_x, margin_y, margin_x, margin_y)
	root.add_theme_constant_override("separation", 12)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_title("藏品背包")
	var layout: HBoxContainer = HBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", roundi(clamp(viewport_size.x * 0.02, 14.0, 32.0)))
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(layout)
	var list_panel: PanelContainer = PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.56, 380.0, 1040.0), 0)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 1.55
	layout.add_child(list_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2 if viewport_size.x < 1200.0 else 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var collectibles: Array = _run_collectibles()
	if collectibles.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "暂无藏品"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(320, 160)
		empty_label.add_theme_font_size_override("font_size", 28)
		grid.add_child(empty_label)
	else:
		for index in range(collectibles.size()):
			var collectible: Dictionary = collectibles[index]
			var captured_index: int = index
			grid.add_child(_make_collectible_bag_card(collectible, index == selected_index, func() -> void:
				_show_run_collectible_bag(captured_index)
			))
	var side_panel: VBoxContainer = VBoxContainer.new()
	side_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	side_panel.add_theme_constant_override("separation", 14)
	side_panel.custom_minimum_size = Vector2(clamp(viewport_size.x * 0.30, 300.0, 560.0), 0)
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_stretch_ratio = 0.9
	layout.add_child(side_panel)
	var detail_label: Label = Label.new()
	detail_label.text = _collectible_detail_text(collectibles[selected_index]) if selected_index >= 0 and selected_index < collectibles.size() else "选择左侧藏品查看效果。"
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", roundi(clamp(viewport_size.y * 0.034, 18.0, 26.0)))
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(detail_label)
	var back_button: Button = _make_button("返回路线", Callable(self, "_show_run_map"))
	back_button.custom_minimum_size = Vector2(0, 68)
	side_panel.add_child(back_button)

func _make_collectible_bag_card(collectible: Dictionary, active: bool, callback: Callable) -> Button:
	var button: Button = Button.new()
	var viewport_size: Vector2 = get_viewport_rect().size
	var card_size: float = floor(clamp(min(viewport_size.x / 1920.0, viewport_size.y / 1080.0) * 230.0, 140.0, 230.0))
	button.custom_minimum_size = Vector2(card_size, card_size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = ""
	button.pressed.connect(callback)
	_apply_collectible_button_style(button, str(collectible.get("rarity", "common")), active)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_top = 10
	box.offset_right = -10
	box.offset_bottom = -10
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	button.add_child(box)
	var name_label: Label = _make_piece_ui_label(_collectible_name(collectible), max(18, int(card_size * 0.13)))
	name_label.custom_minimum_size = Vector2(0, card_size * 0.44)
	box.add_child(name_label)
	var rarity_label: Label = _make_piece_ui_label(str(collectible.get("rarity", "common")), max(14, int(card_size * 0.085)))
	rarity_label.custom_minimum_size = Vector2(0, card_size * 0.20)
	box.add_child(rarity_label)
	var effect_label: Label = _make_piece_ui_label(_collectible_effect_id(collectible), max(12, int(card_size * 0.075)))
	effect_label.custom_minimum_size = Vector2(0, card_size * 0.20)
	box.add_child(effect_label)
	return button

func _apply_collectible_button_style(button: Button, rarity: String, active: bool = false) -> void:
	var bg_color: Color = Color(0.12, 0.14, 0.15, 0.92)
	var border_color: Color = Color(0.78, 0.82, 0.76, 0.55)
	match rarity:
		"rare":
			bg_color = Color(0.08, 0.18, 0.22, 0.94)
			border_color = Color(0.40, 0.88, 1.0, 0.70)
		"epic":
			bg_color = Color(0.20, 0.12, 0.24, 0.94)
			border_color = Color(0.92, 0.62, 1.0, 0.72)
		_:
			bg_color = Color(0.13, 0.16, 0.14, 0.92)
			border_color = Color(0.78, 0.88, 0.68, 0.58)
	if active:
		border_color.a = 0.98
	var hover_bg: Color = bg_color.lightened(0.12)
	var pressed_bg: Color = bg_color.darkened(0.10)
	var border_width: int = 3 if active else 1
	button.add_theme_stylebox_override("normal", _make_collectible_button_stylebox(bg_color, border_color, border_width))
	button.add_theme_stylebox_override("hover", _make_collectible_button_stylebox(hover_bg, border_color, border_width))
	button.add_theme_stylebox_override("pressed", _make_collectible_button_stylebox(pressed_bg, border_color, border_width))
	button.add_theme_stylebox_override("focus", _make_collectible_button_stylebox(hover_bg, border_color, border_width))

func _make_collectible_button_stylebox(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _collectible_detail_text(collectible: Dictionary) -> String:
	var effect_id: String = _collectible_effect_id(collectible)
	var params: Dictionary = _collectible_effect_params(collectible)
	var param_parts: PackedStringArray = PackedStringArray()
	for key in params.keys():
		param_parts.append("%s: %s" % [str(key), str(params[key])])
	param_parts.sort()
	var params_text: String = ", ".join(param_parts) if not param_parts.is_empty() else "无"
	return "%s\n\n稀有度：%s\n效果：%s\n参数：%s\n\n%s" % [
		_collectible_name(collectible),
		str(collectible.get("rarity", "common")),
		effect_id if not effect_id.is_empty() else "无",
		params_text,
		_collectible_description(collectible),
	]

func _make_shell_reward(amount: int) -> Dictionary:
	return {
		"type": "shells",
		"amount": amount,
		"label": "贝币 +%d" % amount,
		"description": "用于在商城购买藏品。",
	}

func _make_life_reward(amount: int) -> Dictionary:
	return {
		"type": "life",
		"amount": amount,
		"label": "生命 +%d" % amount,
		"description": "恢复探索生命，不能超过上限。",
	}

func _make_collectible_reward(collectible: Dictionary) -> Dictionary:
	return {
		"type": "collectible",
		"collectible": collectible,
		"label": "藏品：%s" % _collectible_name(collectible),
		"description": "%s\n%s" % [
			String(collectible.get("rarity", "common")),
			_collectible_description(collectible),
		],
	}

func _reward_item_collectible(item: Dictionary) -> Dictionary:
	var collectible: Variant = item.get("collectible", {})
	if collectible is Dictionary:
		return collectible
	return {}

func _run_reward_item_text(item: Dictionary) -> String:
	return "%s\n%s" % [String(item.get("label", "奖励")), String(item.get("description", ""))]

func _reward_choice_state_text(item: Dictionary) -> String:
	var accepted: Variant = item.get("accepted", null)
	if accepted == null:
		return "未选择"
	return "已收下" if bool(accepted) else "已丢弃"

func _all_reward_items_chosen() -> bool:
	if pending_run_reward_items.is_empty():
		return true
	for item in pending_run_reward_items:
		var reward_item: Dictionary = item
		if reward_item.get("accepted", null) == null:
			return false
	return true

func _random_collectible(min_rarity: String = "common") -> Dictionary:
	var candidates: Array = catalog.get_collectibles_by_min_rarity(min_rarity)
	if candidates.is_empty():
		candidates = catalog.get_collectibles_by_min_rarity("common")
	if candidates.is_empty():
		return {}
	var total_weight: int = 0
	for collectible in candidates:
		total_weight += max(1, collectible.pool_weight)
	var roll: int = rng.randi_range(1, max(1, total_weight))
	var running: int = 0
	for collectible in candidates:
		running += max(1, collectible.pool_weight)
		if roll <= running:
			return _collectible_to_run_data(collectible)
	return _collectible_to_run_data(candidates[0])

func _rarity_rank(rarity: String) -> int:
	return catalog.rarity_rank(rarity)

func _collectible_total(effect_id: String) -> float:
	if not run_active:
		return 0.0
	var total: float = 0.0
	for collectible in _run_collectibles():
		var data: Dictionary = collectible
		if _collectible_effect_id(data) == effect_id:
			var params: Dictionary = _collectible_effect_params(data)
			total += _param_float(params, "value", float(data.get("value", 0.0)))
	return total

func _shop_price(collectible: Dictionary) -> int:
	var base_price: int = int(collectible.get("shop_price", 0))
	if base_price <= 0:
		match String(collectible.get("rarity", "common")):
			"rare":
				base_price = 16
			"epic":
				base_price = 24
			_:
				base_price = 10
	var discount: float = clamp(_collectible_total("shop_discount"), 0.0, 0.75)
	return max(1, roundi(float(base_price) * (1.0 - discount)))

func _apply_run_heal_after_battle() -> void:
	var heal: int = int(_collectible_total("heal_after_battle"))
	if heal <= 0:
		return
	run_state["lives"] = clamp(int(run_state.get("lives", RUN_MAX_LIVES)) + heal, 0, RUN_MAX_LIVES)

func _mark_collectible_seen(collectible_id: String) -> void:
	if collectible_id.is_empty() or save.seen_collectible_ids.has(collectible_id):
		return
	save.seen_collectible_ids.append(collectible_id)

func _collectible_to_run_data(collectible: Resource) -> Dictionary:
	return {
		"id": collectible.id,
		"name": collectible.display_name,
		"description": collectible.description,
		"rarity": collectible.rarity,
		"effect_id": collectible.effect_id,
		"effect": collectible.effect_id,
		"effect_params": collectible.effect_params.duplicate(true),
		"value": float(collectible.effect_params.get("value", 0.0)),
		"shop_price": collectible.shop_price,
		"pool_weight": collectible.pool_weight,
		"max_stack": collectible.max_stack,
	}

func _collectible_name(collectible: Dictionary) -> String:
	var collectible_name: String = String(collectible.get("name", ""))
	return collectible_name if not collectible_name.is_empty() else String(collectible.get("display_name", "藏品"))

func _collectible_description(collectible: Dictionary) -> String:
	return String(collectible.get("description", ""))

func _collectible_effect_id(collectible: Dictionary) -> String:
	var effect_id: String = String(collectible.get("effect_id", ""))
	return effect_id if not effect_id.is_empty() else String(collectible.get("effect", ""))

func _collectible_effect_params(collectible: Dictionary) -> Dictionary:
	var params: Variant = collectible.get("effect_params", {})
	if params is Dictionary:
		return params
	return {"value": float(collectible.get("value", 0.0))}

func _show_pause() -> void:
	_clear_screen()
	_add_title("暂停")
	root.add_child(_make_slider_row("音效", save.sfx_volume, func(value: float) -> void:
		save.sfx_volume = value
		save.save()
	))
	root.add_child(_make_slider_row("音乐", save.music_volume, func(value: float) -> void:
		save.music_volume = value
		save.save()
	))
	root.add_child(_make_button("继续游戏", Callable(self, "_show_game")))
	root.add_child(_make_button("重新开始", Callable(self, "_start_game")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _show_run_pause() -> void:
	_clear_screen()
	current_screen = "run_pause"
	_add_title("设置")
	root.add_child(_make_slider_row("音效", save.sfx_volume, func(value: float) -> void:
		save.sfx_volume = value
		save.save()
	))
	root.add_child(_make_slider_row("音乐", save.music_volume, func(value: float) -> void:
		save.music_volume = value
		save.save()
	))
	root.add_child(_make_button("继续探索", Callable(self, "_show_run_map")))
	root.add_child(_make_button("放弃探索", Callable(self, "_finish_run_failed")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _end_game() -> void:
	_clear_chisaki_release_state()
	_clear_daniya_release_state()
	if run_active:
		_on_run_battle_lost()
		return
	save.high_score = max(save.high_score, score)
	save.save()
	_clear_screen()
	_add_title("游戏结束")
	var summary: Label = Label.new()
	summary.text = "得分：%d\n最高分：%d\n最高 Combo：%d\n普通消除：%d\n特殊消除：%d\n组合触发：%d" % [
		score,
		save.high_score,
		max_combo,
		stats["normal"],
		stats["special"],
		stats["combo"],
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(summary)
	root.add_child(_make_button("再来一局", Callable(self, "_start_game")))
	root.add_child(_make_button("返回主页", Callable(self, "_show_main_menu")))

func _square_targets(center: Vector2i, radius: int) -> Array:
	var targets: Array = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var pos: Vector2i = Vector2i(x, y)
			if board.in_bounds(pos):
				targets.append(pos)
	return targets

func _ensure_default_pieces_in_bag() -> void:
	if save == null:
		return
	var changed: bool = false
	for piece_id in catalog.get_default_roster():
		if save.unlocked_piece_ids.has(piece_id):
			continue
		save.unlocked_piece_ids.append(piece_id)
		changed = true
	if changed:
		save.save()

func _sanitize_roster(ids: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var defaults: PackedStringArray = catalog.get_default_roster()
	for slot_index in range(SLOT_ATTRIBUTES.size()):
		var chosen_id: String = ""
		if slot_index < ids.size():
			var saved_id: String = ids[slot_index]
			var saved_piece: PieceDefinition = catalog.get_piece(saved_id)
			if saved_piece != null and not catalog.is_piece_hidden(saved_id) and _piece_matches_slot(saved_piece, slot_index):
				chosen_id = saved_id
		if chosen_id.is_empty() and slot_index < defaults.size():
			chosen_id = defaults[slot_index]
		if chosen_id.is_empty():
			for piece in catalog.get_unlocked_pieces(save.unlocked_piece_ids if save != null else PackedStringArray()):
				if _piece_matches_slot(piece, slot_index):
					chosen_id = piece.id
					break
		result.append(chosen_id)
	return result
