extends "res://scripts/v2/deck_view.gd"

const RelicView = preload("res://scripts/v2/relic_view.gd")

func _init() -> void:
	super()
	name = "RelicGrid"

func _create_card_view(catalog, value: Dictionary, _combat = null) -> Control:
	var view := RelicView.new()
	view.configure(catalog, value)
	return view

func get_relic_views() -> Array[Control]:
	return get_card_views()
