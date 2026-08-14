extends Resource
class_name BossDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 300
@export var defense: int = 20
@export var texture: Texture2D
@export var skill_effect_id: String = ""
@export var skill_effect_params: Dictionary = {}
@export var skill_interval: int = 3
@export var skill_chance: float = 0.3
@export_multiline var description: String = ""
