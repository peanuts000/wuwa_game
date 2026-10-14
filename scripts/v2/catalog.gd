extends RefCounted

const ATTRIBUTES = ["condensation", "thermal", "conductive", "aero", "diffraction", "annihilation"]
const NAMES = {"condensation": "冷凝", "thermal": "热熔", "conductive": "导电", "aero": "气动", "diffraction": "衍射", "annihilation": "湮灭", "star": "经验", "guard": "防御"}
const COLORS = {"condensation": Color("65c9f4"), "thermal": Color("f48364"), "conductive": Color("b4a1ff"), "aero": Color("65d7b0"), "diffraction": Color("f5d481"), "annihilation": Color("e48cba"), "star": Color("f1b94f"), "guard": Color("a2b6cb")}
# Attack: direct damage; ability: a lasting effect for this battle; skill: other effects.
const CARD_TYPE_NAMES := {"attack": "攻击", "skill": "技能", "ability": "能力"}
var data: Dictionary
var cards: Dictionary = {}
var relics: Dictionary = {}
var supplies: Dictionary = {}
var enemies: Dictionary = {}

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay_v2.json"))
	for group in ["cards", "relics", "supplies", "enemies"]:
		var lookup: Dictionary = get(group)
		for entry in data[group]:
			lookup[entry.id] = entry

func card_type(card: Dictionary) -> String:
	var entry: Dictionary = cards.get(card.get("id", ""), {})
	return CARD_TYPE_NAMES.get(str(entry.get("type", "skill")), "技能")

func cost(card: Dictionary) -> Dictionary:
	var entry: Dictionary = cards[card.id]
	if card.get("upgraded", false):
		return entry.upgrade.get("cost", entry.cost)
	return entry.cost

func card_text(card: Dictionary) -> String:
	var entry: Dictionary = cards[card.id]
	var effect: String = entry.effect
	if card.get("upgraded", false):
		effect = entry.upgrade.effect
		if effect.contains("其余相同") or effect.contains("其他相同") or effect.contains("门槛"):
			effect = entry.effect + "\n升级：" + effect
	var costs: Array[String] = []
	for kind in cost(card):
		costs.append("%s %d" % [NAMES[kind], cost(card)[kind]])
	return "%s%s\n%s\n\n%s" % [entry.name, " +" if card.get("upgraded", false) else "", " / ".join(costs), effect]
