extends SceneTree

const CardView = preload("res://scripts/v2/card_view.gd")
const SAVE_PATH := "res://tests/artifacts/deck_ui_save.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 960)]
const BASE_IDS := ["c01", "c01", "c06", "g01", "g02", "g03", "g05", "g07"]
var app
var deck_view
var checks := 0
var failures := 0
var dimensions_label := "1280x720"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("DECK_UI [%s]: %s" % [dimensions_label, message])

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_deck_ui_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.22).timeout

func _snapshot() -> Dictionary:
	return {"run": app.run_state.to_snapshot(), "combat": app.combat.to_snapshot() if app.combat != null else null}

func _new_context(kind: String, ids: Array = BASE_IDS, upgraded_indices: Array = [2], event_id: String = "") -> void:
	var node_id := ""
	for _attempt in range(12):
		app._commit_run()
		if kind == "map":
			break
		for id in app.run_state.nodes:
			if app.run_state.nodes[id].type == kind:
				node_id = id
				break
		if not node_id.is_empty():
			break
	check(kind == "map" or not node_id.is_empty(), "Fixture has a genuine " + kind + " node")
	app.run_state.deck.clear()
	app.run_state.next_card_uid = 0
	for id in ids:
		app.run_state.add_card(id)
	for index in upgraded_indices:
		if index < app.run_state.deck.size():
			app.run_state.deck[index].upgraded = true
	app._state_changed()
	if kind != "map" and not node_id.is_empty():
		app.run_state.available = [node_id]
		app._enter_node(node_id)
	if event_id != "":
		app.run_state.event_id = event_id
		app._state_changed()
	await _settle()
	check(app.run_state.phase == kind and app.save_error.is_empty(), "Fixture enters and checkpoints the correct " + kind + " context")

func _open_readonly() -> void:
	app._show_deck()
	await _settle()
	_find_view()

func _find_view() -> void:
	deck_view = app.modal.find_child("DeckView", true, false) if is_instance_valid(app.modal) else null
	check(is_instance_valid(deck_view), "Modal contains the reusable DeckView")

func _card(uid: int):
	for card in deck_view.get_card_views():
		if int(card.uid) == uid:
			return card
	return null

func _close_button():
	return app.modal.find_child("CloseDeckButton", true, false) if is_instance_valid(app.modal) else null

func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame

func _raw_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _drag(start: Vector2, finish: Vector2) -> void:
	await _motion(start)
	var press := InputEventMouseButton.new()
	press.position = start
	press.global_position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	await _motion(finish)
	var release := InputEventMouseButton.new()
	release.position = finish
	release.global_position = finish
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func _wheel(point: Vector2) -> void:
	await _motion(point)
	for _step in range(3):
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			event.pressed = pressed
			root.push_input(event, true)
			await process_frame

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var suffix := "" if dimensions_label == "1280x720" else "_" + dimensions_label
	check(root.get_texture().get_image().save_png("res://tests/artifacts/" + name + suffix + ".png") == OK, "Deck screenshot saves: " + name)

func _fixed_bounds() -> void:
	var close: Button = _close_button()
	var scroll: ScrollContainer = deck_view.get_scroll_container()
	check(app.size.is_equal_approx(Vector2(1280, 720)) and app.get_global_rect().grow(1).encloses(deck_view.get_global_rect()), "Deck modal stays inside its logical canvas at this window size")
	check(close != null and close.is_visible_in_tree() and app.get_global_rect().grow(1).encloses(close.get_global_rect()) and not scroll.is_ancestor_of(close), "Return button is visible outside the internal card scroll area")
	check(app.modal.find_children("*", "ScrollContainer", true, false).size() == 1, "Only cards scroll; the title and return button do not")
	check(not scroll.get_v_scroll_bar().is_visible_in_tree() and not scroll.get_h_scroll_bar().is_visible_in_tree(), "Both deck scrollbars stay hidden in the actual control tree")

func _readonly_case(kind: String, capture: bool = false) -> void:
	await _new_context(kind)
	var before: Dictionary = _snapshot()
	await _open_readonly()
	_fixed_bounds()
	var cards: Array = deck_view.get_card_views()
	check(cards.size() == app.run_state.deck.size(), kind + " deck displays every card instance")
	var actual_uids: Array = []
	var expected_uids: Array = []
	var faces_exact := true
	var costs_exact := true
	var displayed_kinds: Dictionary = {}
	for original in app.run_state.deck:
		expected_uids.append(int(original.uid))
	for view in cards:
		actual_uids.append(int(view.uid))
		var original: Dictionary = app.run_state.deck.filter(func(card: Dictionary): return int(card.uid) == view.uid)[0]
		faces_exact = faces_exact and view.get_script() == CardView and view.paper_style and view.card == original and view.full_text == app.catalog.card_text(original) and view.tooltip_text.is_empty()
		var cost: Dictionary = app.catalog.cost(original)
		costs_exact = costs_exact and view._cost_row.get_child_count() == cost.size()
		var index := 0
		for attribute in cost:
			var badge: Control = view._cost_row.get_child(index)
			var icon: Control = badge.get_child(0)
			var number: Label = badge.get_child(1)
			costs_exact = costs_exact and icon.get_texture() != null and icon.kind == attribute and icon.get_texture().resource_path == "res://assets/ui/board/" + attribute + ".png" and number.text == str(int(cost[attribute]))
			displayed_kinds[attribute] = true
			index += 1
	check(actual_uids == expected_uids and actual_uids.size() == 8, "Deck instances retain their real UIDs and original order")
	check(faces_exact, "Every card uses its actual upgraded face and readable effect without a detailed tooltip")
	check(costs_exact and displayed_kinds.size() == 6, "Mixed-attribute deck shows all six correct icons and integer costs")
	check(_card(1).card.id == "c01" and _card(2).card.id == "c01" and _card(1) != _card(2), "Duplicate card IDs remain separate card views")
	check(_card(3)._title.text.ends_with(" +") and _card(3)._cost_row.get_child(0).get_child(1).text == "1", "Upgraded crystal shot shows plus and its reduced cost")
	if capture:
		await _capture("deck_idle")
	var first: Control = _card(1)
	var resting_scale: Vector2 = first.scale
	await _motion(_center(first))
	await _settle()
	check(first.scale.x > resting_scale.x and first.tooltip_text.is_empty(), "Readonly deck card grows on actual hover without a detailed popup")
	check(deck_view.get_scroll_container().get_global_rect().grow(1).encloses(first.get_global_rect()), "Hovered card remains completely visible in the card viewport")
	if capture:
		await _capture("deck_hover")
	_raw_click(_center(first))
	first.activation_requested.emit(int(first.uid))
	check(_snapshot() == before, kind + " readonly mouse and keyboard card activation neither edits nor plays a card")
	_raw_click(_center(_close_button()))
	check(not is_instance_valid(app.modal) and _snapshot() == before, "Closing readonly deck keeps the model and RNG unchanged")
	await _settle()

func _empty_and_long() -> void:
	await _new_context("map", [], [])
	await _open_readonly()
	_fixed_bounds()
	var has_empty_text := false
	for label in app.modal.find_children("*", "Label", true, false):
		has_empty_text = has_empty_text or label.text.contains("空")
	check(deck_view.get_card_views().is_empty() and has_empty_text, "Empty deck shows an empty-state message and no invented cards")
	app._close_modal()
	var ids: Array = []
	for index in range(28):
		ids.append(BASE_IDS[index % BASE_IDS.size()])
	await _new_context("map", ids, [2, 10, 18, 26])
	var before: Dictionary = _snapshot()
	await _open_readonly()
	var scroll: ScrollContainer = deck_view.get_scroll_container()
	var close_rect: Rect2 = _close_button().get_global_rect()
	check(deck_view.get_card_views().size() == 28 and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "Long deck remains complete inside its own scroll area")
	check(not scroll.get_v_scroll_bar().is_visible_in_tree() and not scroll.get_h_scroll_bar().is_visible_in_tree(), "Long deck hides both scrollbars while retaining its scroll range")
	var last: Control = _card(28)
	await _wheel(scroll.get_global_transform_with_canvas() * Vector2(12, scroll.size.y * 0.5))
	check(scroll.scroll_vertical > 0 and _close_button().get_global_rect() == close_rect, "Actual wheel input scrolls the deck with hidden bars and keeps the return button fixed")
	scroll.scroll_vertical = 0
	await _settle()
	var max_scroll := roundi(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	for _step in range(12):
		if scroll.scroll_vertical >= max_scroll:
			break
		var start: Vector2 = scroll.get_global_transform_with_canvas() * Vector2(12, scroll.size.y - 20)
		var finish: Vector2 = scroll.get_global_transform_with_canvas() * Vector2(12, 20)
		await _drag(start, finish)
	await _settle()
	check(scroll.scroll_vertical >= max_scroll and scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "Actual blank-area dragging reaches the last card without visible scrollbars")
	scroll.ensure_control_visible(last)
	await _settle()
	check(scroll.scroll_vertical > 0 and scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "Internal scrolling makes the last card fully visible")
	check(_close_button().get_global_rect() == close_rect and _close_button().is_visible_in_tree(), "Return button stays fixed and visible at the end of a long deck")
	await _capture("deck_long")
	check(_snapshot() == before, "Viewing and scrolling a long deck preserves model and RNG")
	# Leave while a hover tween is still running, then deliver an old view callback.
	await _motion(_center(last))
	var old_view = deck_view
	app._return_menu()
	old_view.card_selected.emit(28)
	await _settle()
	check(app.screen == "menu" and not is_instance_valid(old_view) and app.find_children("Card_*", "Control", true, false).is_empty(), "Page switch removes old cards and their active hover animation")
	check(_snapshot() == before, "Old deck callbacks cannot mutate paused exploration")

func _selection_cases() -> void:
	var ids: Array = ["c01", "c01", "c06", "g06", "g05"]
	await _new_context("event", ids, [1, 4], "workbench")
	app.run_state.shells = 100
	app._state_changed()
	var before: Dictionary = _snapshot()
	app._choose_deck(true, 15)
	await _settle()
	_find_view()
	var uids: Array = []
	var previews_upgraded := true
	for card in deck_view.get_card_views():
		uids.append(int(card.uid))
		previews_upgraded = previews_upgraded and card.card.upgraded and card.full_text == app.catalog.card_text(card.card)
	check(uids == [1, 3, 4] and previews_upgraded, "Upgrade selection includes only unupgraded real UIDs and previews their upgraded effects")
	check(_card(3)._cost_row.get_child(0).get_child(1).text == "1" and not app.run_state.deck[2].upgraded, "Upgrade preview shows reduced crystal-shot cost without modifying its source card")
	var cancelled = deck_view
	_raw_click(_center(_close_button()))
	cancelled.card_selected.emit(1)
	check(_snapshot() == before and not is_instance_valid(app.modal), "Upgrade cancel and old selection callback grant nothing and charge nothing")
	app._choose_deck(true, 15)
	await _settle()
	_find_view()
	var target: Control = _card(1)
	await _drag(_center(target), _center(target) + Vector2(0, -24))
	check(_snapshot() == before, "Dragging over a selectable upgrade card does not submit it")
	# Reorder the real instances while this modal is open: commit must still use UID.
	app.run_state.deck.reverse()
	var old_view = deck_view
	_raw_click(_center(target))
	var committed: Dictionary = _snapshot()
	old_view.card_selected.emit(3)
	check(app.run_state.deck.back().uid == 1 and app.run_state.deck.back().upgraded and not app.run_state.deck.filter(func(card: Dictionary): return int(card.uid) == 3)[0].upgraded, "Upgrade commits the selected UID after index changes, never its old neighbor")
	check(app.run_state.phase == "map" and app.run_state.shells == 85 and app.run_state.visited.count(app.run_state.current) == 1 and _snapshot() == committed, "Upgrade charges once, completes once, and ignores repeated old callbacks")
	await _new_context("event", ["c01", "c01", "g06"], [1], "prune")
	before = _snapshot()
	app._choose_deck(false)
	await _settle()
	_find_view()
	check(deck_view.get_card_views().size() == 3 and _card(2).card.upgraded, "Removal selection includes every real instance, including upgraded duplicates")
	cancelled = deck_view
	_raw_click(_center(_close_button()))
	cancelled.card_selected.emit(1)
	check(_snapshot() == before, "Removal cancel and its stale callback leave the deck unchanged")
	app._choose_deck(false)
	await _settle()
	_find_view()
	target = _card(1)
	app.run_state.deck.reverse()
	old_view = deck_view
	_raw_click(_center(target))
	committed = _snapshot()
	old_view.card_selected.emit(2)
	var remaining: Array = []
	for card in app.run_state.deck:
		remaining.append(int(card.uid))
	check(remaining == [3, 2] and app.run_state.deck.back().id == "c01", "Removal targets one UID after reordering and retains its duplicate")
	check(app.run_state.phase == "map" and app.run_state.shells == before.run.shells and app.run_state.visited.count(app.run_state.current) == 1 and _snapshot() == committed, "Removal commits once without payment or a second stale removal")
	await _new_context("rest", ["c01", "c02"], [0, 1])
	before = _snapshot()
	app._choose_deck(true)
	await _settle()
	_find_view()
	var empty = deck_view.find_child("DeckEmpty", true, false)
	check(deck_view.get_card_views().is_empty() and empty != null and empty.text == "没有符合条件的牌。", "An entirely upgraded deck reports no eligible cards rather than an empty deck")
	_raw_click(_center(_close_button()))
	check(_snapshot() == before, "Closing an upgrade selection with no candidates preserves the rest node")

func _pile_case() -> void:
	await _new_context("battle")
	var before: Dictionary = _snapshot()
	app._show_piles()
	await _settle()
	var tabs = app.modal.find_child("PileTabs", true, false)
	var views: Array = []
	for node in app.modal.find_children("*", "Control", true, false):
		if node.get_script() == load("res://scripts/v2/deck_view.gd"):
			views.append(node)
	check(tabs != null and views.size() == 2 and _close_button() != null, "Pile tabs reuse two card grids and a fixed return button")
	var sorted_names := true
	for view in views:
		var names: Array = []
		for card in view.get_card_views():
			names.append(str(app.catalog.cards[card.card.id].name) + (" +" if card.card.upgraded else ""))
		var sorted: Array = names.duplicate()
		sorted.sort()
		sorted_names = sorted_names and names == sorted
	check(sorted_names and _snapshot() == before, "Pile card faces are sorted copies and never change the real draw or discard order")
	await _capture("deck_piles")
	app._close_modal()

func _bottom_selection_case() -> void:
	var ids: Array = []
	for index in range(12):
		ids.append(BASE_IDS[index % BASE_IDS.size()])
	await _new_context("event", ids, [], "workbench")
	app.run_state.shells = 40
	app._state_changed()
	app._choose_deck(true, 15)
	await _settle()
	_find_view()
	var viewport: Rect2 = deck_view.get_scroll_container().get_global_rect()
	var partial: Control
	for card in deck_view.get_card_views():
		var rect: Rect2 = card.get_global_rect()
		var visible: Rect2 = rect.intersection(viewport)
		if visible.size.y > 20 and rect.position.y < viewport.end.y and rect.end.y > viewport.end.y:
			partial = card
			break
	check(partial != null, "Upgrade fixture exposes a partially visible card at the viewport's lower edge")
	if partial == null:
		app._close_modal()
		return
	var uid: int = partial.uid
	var visible_center: Vector2 = partial.get_global_rect().intersection(viewport).get_center()
	var local: Vector2 = partial.get_global_transform().affine_inverse() * visible_center
	await _motion(partial.get_global_transform_with_canvas() * local)
	await _settle()
	check(viewport.grow(1).encloses(partial.get_global_rect()), "Hover brings the lower-edge card fully inside its viewport")
	await _capture("deck_select_hover")
	# Click twelve local pixels below the enlarged top edge. Focus acquisition must
	# preserve that hover position so the subsequent release still hits this UID.
	var point: Vector2 = partial.get_global_transform_with_canvas() * Vector2(75, 12)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	var upgraded: Array = app.run_state.deck.filter(func(card: Dictionary): return card.upgraded)
	check(app.run_state.phase == "map" and app.run_state.shells == 25 and upgraded.size() == 1 and upgraded[0].uid == uid, "A real upper-edge click on the hovered lower-row card upgrades exactly its UID once")

func _drop_app() -> void:
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = null
	deck_view = null

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for dimensions in RESOLUTIONS:
		dimensions_label = "%dx%d" % [dimensions.x, dimensions.y]
		_clean()
		root.size = dimensions
		await _settle()
		app = _new_app()
		await _readonly_case("map", true)
		await _empty_and_long()
		if dimensions == Vector2i(1280, 720):
			await _readonly_case("shop")
			await _readonly_case("battle")
			await _selection_cases()
			await _bottom_selection_case()
			await _pile_case()
		await _drop_app()
	_clean()
	print("V2_DECK_UI: %d checks, %d failures; instances, upgraded faces/costs, four sizes, readonly/selection/scroll/lifecycle" % [checks, failures])
	quit(0 if failures == 0 else 1)
