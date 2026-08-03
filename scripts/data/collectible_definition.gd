extends Resource
class_name CollectibleDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var texture: Texture2D
@export var effect_id: String = ""
@export var effect_params: Dictionary = {}
@export var rarity: String = "common"
@export_multiline var description: String = ""
@export var shop_price: int = 10
@export var pool_weight: int = 1
@export var max_stack: int = 0
