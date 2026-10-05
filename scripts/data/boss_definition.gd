extends Resource
class_name BossDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 300
@export var defense: int = 20
@export var encounter_type: String = "boss"
@export var hp_growth_per_floor: float = 0.2
@export var enrage_hp_ratio: float = 0.0
@export var enrage_skill_interval: int = 2
@export var enrage_skill_chance: float = 1.0
@export var enrage_skill_effect_id: String = "none"
@export var enrage_skill_effect_params: Dictionary = {}
@export var texture: Texture2D
@export var skill_effect_id: String = ""
@export var skill_effect_params: Dictionary = {}
@export var skill_interval: int = 3
@export var skill_chance: float = 0.3
@export_multiline var description: String = ""
