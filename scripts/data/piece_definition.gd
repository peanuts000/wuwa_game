extends Resource
class_name PieceDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var icon_texture: Texture2D
@export var selected_icon_texture: Texture2D
@export var theme_color: Color = Color.WHITE
@export var multiplier: float = 1.0
@export var attack: int = 6
@export var rarity: String = "common"
@export_multiline var description: String = ""
@export var default_special_effect_id: String = ""
@export var unlocked_by_default: bool = true
@export var tags: PackedStringArray = PackedStringArray()
@export var resonance_cost: int = 30
@export var resonance_effect_id: String = ""
@export var resonance_effect_params: Dictionary = {}
@export var resonance_gain_id: String = ""
@export var resonance_gain_params: Dictionary = {}
@export var resonance_gain_description: String = ""
@export var passive_skill_id: String = ""
@export var passive_skill_params: Dictionary = {}
@export var sort_order: int = 0
