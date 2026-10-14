extends "res://scripts/v2/relic_grid.gd"

var item_kind := "relic"

func _create_card_view(catalog, value: Dictionary, _combat = null) -> Control:
	var view := RelicView.new()
	view.item_kind = item_kind
	view.configure(catalog, value)
	return view
