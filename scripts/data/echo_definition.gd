extends Resource
class_name EchoDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var texture: Texture2D
@export var clicked_texture: Texture2D
@export var click_effect_id: String = ""
@export var click_effect_params: Dictionary = {}
@export var can_swap: bool = false
@export var affected_by_gravity: bool = true
@export var can_match: bool = false
@export_multiline var description: String = ""
