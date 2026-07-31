extends Resource
class_name SpecialEffectDefinition

@export var id: String = ""
@export var display_name: String = ""
@export_enum("line", "area", "color_clear") var effect_type: String = "line"
@export var radius: int = 0
@export_enum("horizontal", "vertical", "auto", "none") var direction_strategy: String = "none"
@export var base_score: int = 0
@export var marker: String = ""
@export var marker_color: Color = Color.WHITE

