extends SceneTree

const SAVE_PATH := "res://tests/artifacts/shop_ui_save.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 960)]
var app
var shop
var checks := 0
var failures := 0
var dimensions_label := "1280x720"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SHOP_UI [%s]: %s" % [dimensions_label, message])

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_shop_ui_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.22).timeout

func _find_shop() -> void:
	shop = app.find_child("ShopView", true, false)
	check(is_instance_valid(shop) and app.run_state.phase == "shop", "ShopView is active at a real shop node")

func _stock() -> Array:
	var result: Array = []
	for id in ["c01", "c05", "g03", "g06"]:
		result.append({"type": "card", "id": id, "price": 20, "sold": false})
	for id in ["r01", "r02"]:
		result.append({"type": "relic", "id": id, "price": 45, "sold": false})
	for id in ["healing_vial", "energy_vial"]:
		result.append({"type": "supply", "id": id, "price": int(app.catalog.supplies[id].price), "sold": false})
	return result

func _begin_shop() -> void:
	var shop_id := ""
	for _attempt in range(12):
		app._commit_run()
		for id in app.run_state.nodes:
			if app.run_state.nodes[id].type == "shop":
				shop_id = id
				break
		if not shop_id.is_empty():
			break
	check(not shop_id.is_empty(), "Generated map provides a genuine shop node")
	if shop_id.is_empty():
		return
	# Expose the generated node in this fixture, then enter it through the real app.
	app.run_state.available = [shop_id]
	app._enter_node(shop_id)
	app.run_state.stock = _stock()
	app.run_state.shells = 200
	app.run_state.relics.clear()
	app.run_state.supplies = ["healing_vial"]
	app._state_changed()
	await _settle()
	_find_shop()
	check(app.run_state.current == shop_id and shop_id not in app.run_state.visited and app.run_state.nodes[shop_id].type == "shop", "Fixture current is a valid, unvisited shop node")
	check(app.save_error.is_empty(), "Shop fixture checkpoints without touching player progress")

func _point(control: Control, local: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas() * local

func _center(control: Control) -> Vector2:
	return _point(control, control.size * 0.5)

func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	root.push_input(event, true)
	await process_frame

func _mouse(point: Vector2, pressed: bool, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button_index
	event.pressed = pressed
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

func _click(control: Control) -> void:
	await _motion(_center(control))
	_raw_click(_center(control))
	await _settle()

func _drag(start: Vector2, finish: Vector2) -> void:
	await _motion(start)
	await _mouse(start, true)
	await _motion(finish, finish - start)
	await _mouse(finish, false)

func _card(index: int):
	for card in shop.get_card_views():
		if int(card.get_meta("stock_index", -1)) == index:
			return card
	return null

func _item(index: int):
	for item in shop.get_item_buttons():
		if int(item.get_meta("stock_index", -1)) == index:
			return item
	return null

func _price(index: int):
	for label in shop.get_price_labels():
		if int(label.get_meta("stock_index", -1)) == index:
			return label
	return null

func _nav(prefix: String):
	var navigation = app.find_child("ShopNavigation", true, false)
	if navigation == null:
		return null
	for button in navigation.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix) or button.tooltip_text.begins_with(prefix):
			return button
	return null

func _visible(control: Control) -> void:
	check(control.is_visible_in_tree() and shop.get_global_rect().grow(1).encloses(control.get_global_rect()), "Requested shop control is visible without moving the page")
	await _settle()

func _product_rects() -> Dictionary:
	var result: Dictionary = {}
	for index in range(8):
		var control: Control = _card(index) if index < 4 else _item(index)
		result[index] = control.get_global_rect()
		result["price_%d" % index] = _price(index).get_global_rect()
	result.leave = shop.get_leave_button().get_global_rect()
	return result

func _same_rects(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.keys() != expected.keys():
		return false
	for key in expected:
		var actual_rect: Rect2 = actual[key]
		var expected_rect: Rect2 = expected[key]
		if not actual_rect.is_equal_approx(expected_rect):
			print("SHOP_GEOMETRY %s expected=%s actual=%s" % [key, expected_rect, actual_rect])
			return false
	return true

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var suffix := "" if dimensions_label == "1280x720" else "_" + dimensions_label
	check(root.get_texture().get_image().save_png("res://tests/artifacts/" + name + suffix + ".png") == OK, "Shop screenshot saves: " + name)

func _layout() -> void:
	var navigation: Control = app.find_child("ShopNavigation", true, false)
	var life = app.run_status.get_hearts()
	var shells: Label = app.run_status.amount
	check(navigation != null and life != null and shells != null, "Shop fixed navigation exposes life and currency")
	if navigation == null or life == null or shells == null:
		return
	check(app.size.is_equal_approx(Vector2(1280, 720)) and is_equal_approx(navigation.size.y, 80) and is_equal_approx(shop.position.y, 80), "Shop uses the 1280 by 720 canvas beneath an 80-pixel fixed navigation")
	check(life.get_global_rect().position.x < 400 and shells.get_global_rect().position.x < 500 and life.get_lives() == app.run_state.lives and life.get_visible_heart_count() == app.run_state.lives and shells.text == str(app.run_state.shells), "Heart lives and balance appear at upper left")
	for prefix in ["地图", "商店", "牌组", "藏品", "主界面"]:
		var button = _nav(prefix)
		check(button != null and navigation.get_global_rect().grow(1).encloses(button.get_global_rect()), "Shop navigation contains " + prefix)
	var last_tab_x := -INF
	for id in ["map", "deck", "relics", "shop"]:
		var tab: Button = app.run_navigation.get_tab_button(id)
		check(tab != null, "Shop navigation exposes the " + id + " tab")
		if tab == null:
			continue
		var rect := tab.get_global_rect()
		check(rect.position.x > last_tab_x and absf(rect.end.y - navigation.get_global_rect().end.y) <= 2.0, "Shop browser tabs follow their order and meet the content edge: " + id)
		last_tab_x = rect.position.x
	_check_selected_tab("shop")
	var no_old_copy := true
	for label in app.find_children("*", "Label", true, false):
		no_old_copy = no_old_copy and not label.text.contains("晶域行旅") and not label.text.contains("旅途商店") and not label.text.contains("每件商品限购")
	check(no_old_copy, "Shop removes the old title and explanatory text")
	check(shop.get_card_views().size() == 4 and shop.get_item_buttons().size() == 4 and shop.get_price_labels().size() == 8, "Shop displays four card faces and four item icons with eight prices")
	check(shop.get_card_views().all(func(card): return card.paper_style), "Shop shares battle card artwork")
	var ordered_cards := true
	var card_y := -1.0
	var last_x := -INF
	var cards_bottom := -INF
	for index in range(4):
		var card: Control = _card(index)
		var rect := card.get_global_rect()
		if card_y < 0:
			card_y = rect.position.y
		ordered_cards = ordered_cards and is_equal_approx(rect.position.y, card_y) and rect.position.x > last_x
		last_x = rect.position.x
		cards_bottom = maxf(cards_bottom, rect.end.y)
		check(card.get_meta("type") == "card" and card.get_meta("id") == app.run_state.stock[index].id and card.tooltip_text.is_empty(), "Card %d has stable stock metadata and no detailed popup" % index)
		check(card.is_visible_in_tree() and shop.get_global_rect().grow(1).encloses(rect), "Card %d fits the initial one-screen shop" % index)
		var label: Label = _price(index)
		check(label != null and label.text.contains(str(app.run_state.stock[index].price)) and label.get_global_rect().position.y >= rect.end.y - 1, "Card %d price is displayed beneath its face" % index)
		check(label.is_visible_in_tree() and shop.get_global_rect().grow(1).encloses(label.get_global_rect()), "Card %d price is initially visible" % index)
	check(ordered_cards, "All four cards form one ordered upper row")
	var ordered_items := true
	last_x = -INF
	for index in range(4, 8):
		var item: Button = _item(index)
		var rect := item.get_global_rect()
		ordered_items = ordered_items and rect.position.x > last_x and rect.position.y > cards_bottom
		last_x = rect.position.x
		check(item.get_meta("type") == ("relic" if index < 6 else "supply") and item.get_meta("id") == app.run_state.stock[index].id, "Item %d follows the two-relic, two-supply lower row" % index)
		check(item.is_visible_in_tree() and shop.get_global_rect().grow(1).encloses(rect), "Item %d fits the initial one-screen shop" % index)
		var price: Label = _price(index)
		check(price != null and price.text.contains(str(app.run_state.stock[index].price)) and price.get_global_rect().position.y >= rect.end.y - 1, "Item %d price is below its icon" % index)
		check(price.is_visible_in_tree() and shop.get_global_rect().grow(1).encloses(price.get_global_rect()), "Item %d price is initially visible" % index)
	check(ordered_items, "Item icons occupy an ordered row below cards")
	check(shop.get_class() == "Control" and shop.find_children("*", "ScrollBar", true, false).is_empty(), "One-screen shop has no scrolling container or scrollbar controls")
	var leave: Button = shop.get_leave_button()
	check(leave.is_visible_in_tree() and shop.get_global_rect().grow(1).encloses(leave.get_global_rect()), "Leave shop is visible and clickable on the initial page")
	var gap: Vector2 = shop.get_global_rect().end - leave.get_global_rect().end
	check(gap.is_equal_approx(Vector2(20, 20)), "Leave shop stays twenty pixels from the lower-right corner (actual gap %s, rect %s)" % [gap, leave.get_global_rect()])

func _check_selected_tab(id: String) -> void:
	var selected := 0
	var navigation = app.run_navigation
	for tab_id in ["map", "shop", "deck", "relics"]:
		var button: Button = navigation.get_tab_button(tab_id)
		if button != null and button.button_pressed:
			selected += 1
	check(app.run_tab == id and selected == 1 and navigation.get_tab_button(id).button_pressed, "Exactly the current shop browser tab is selected: " + id)

func _tab_switching() -> void:
	var before: Dictionary = app.run_state.to_snapshot()
	var persistent_shop = shop
	var product_rects: Dictionary = _product_rects()
	var navigation = app.run_navigation
	var fixed_rect: Rect2 = navigation.get_global_rect()
	await _click(navigation.get_tab_button("map"))
	_check_selected_tab("map")
	var preview = app.run_tab_content.find_child("RunTabMap", true, false) if is_instance_valid(app.run_tab_content) else null
	check(preview != null and not is_instance_valid(app.modal), "Shop map tab shows the route inside the page")
	check(not shop.is_visible_in_tree() and shop._locked, "Map preview hides and locks the persistent shop")
	if preview != null:
		var disabled_nodes := true
		for node in preview.map_view.find_children("*", "Button", true, false):
			disabled_nodes = disabled_nodes and node.disabled and not bool(node.get_meta("available"))
			node.pressed.emit()
		check(disabled_nodes, "Shop route preview keeps all route nodes unavailable")
		preview.node_selected.emit(app.run_state.current)
		var start: Vector2 = _point(preview, Vector2(400, 24))
		await _drag(start, _point(preview, Vector2(180, 24)))
		check(preview.scroll_horizontal > 150, "Shop route preview remains draggable while route entry is disabled")
	shop.buy_requested.emit(0)
	shop.leave_requested.emit()
	check(app.run_state.to_snapshot() == before and app.run_state.phase == "shop" and app.combat == null, "Preview route activation and hidden shop callbacks cannot enter, buy, or finish a node")
	await _capture("shop_tab_map")
	for id in ["deck", "relics"]:
		await _click(navigation.get_tab_button(id))
		_check_selected_tab(id)
		check(is_instance_valid(app.run_tab_content) and app.run_tab_content.is_visible_in_tree() and not is_instance_valid(app.modal), "Shop browser tab changes the visible content directly: " + id)
		check(navigation.get_global_rect() == fixed_rect and app.run_state.to_snapshot() == before and not shop.is_visible_in_tree(), "Shop tab switches preserve products, exploration, RNG, and the fixed navigation: " + id)
		if id == "deck" and is_instance_valid(app.run_tab_content):
			var deck = app.run_tab_content.find_child("DeckView", true, false)
			check(deck != null and deck.get_card_views().size() == app.run_state.deck.size(), "Shop deck tab shows the real inventory")
		await _capture("shop_tab_" + id)
	await _click(navigation.get_tab_button("shop"))
	_check_selected_tab("shop")
	check(shop == persistent_shop and shop.is_visible_in_tree() and not shop._locked and not is_instance_valid(app.run_tab_content), "Shop tab restores the same unlocked purchase view")
	check(_same_rects(_product_rects(), product_rects) and app.run_state.to_snapshot() == before, "Returning to shop preserves product positions, stock, money, and RNG")

func _drag_and_hover() -> void:
	var before: Dictionary = app.run_state.to_snapshot()
	var navigation: Control = app.find_child("ShopNavigation", true, false)
	var fixed_rect: Rect2 = navigation.get_global_rect()
	var positions: Dictionary = _product_rects()
	var start: Vector2 = _point(shop, Vector2(24, 450))
	var finish: Vector2 = _point(shop, Vector2(24, 200))
	await _drag(start, finish)
	check(_same_rects(_product_rects(), positions) and navigation.get_global_rect() == fixed_rect, "Blank shop drag leaves all products, prices, and navigation fixed")
	check(app.run_state.to_snapshot() == before and not shop._pressed and not shop._dragged, "Blank drag release buys nothing and clears interaction state")
	await _capture("shop_after_drag")
	await _settle()
	var card: Control = _card(0)
	var point: Vector2 = _center(card)
	var delta: Vector2 = _point(shop, Vector2(0, -24)) - _point(shop, Vector2.ZERO)
	await _drag(point, point + delta)
	check(app.run_state.to_snapshot() == before, "Dragging from a card never buys it")
	await _motion(start)
	await _settle()
	check(_same_rects(_product_rects(), positions), "Card drag leaves every product in its original layout after hover ends")
	var item: Button = _item(4)
	await _visible(item)
	point = _center(item)
	await _drag(point, point + delta)
	check(app.run_state.to_snapshot() == before, "Dragging from an item icon never buys it")
	await _motion(_point(shop, Vector2(24, 320)))
	await _settle()
	check(_same_rects(_product_rects(), positions), "Item drag leaves every product and price fixed")
	card = _card(1)
	var base_scale: Vector2 = card.scale
	await _motion(_center(card))
	await _settle()
	check(card.scale.x > base_scale.x and card.tooltip_text.is_empty(), "Shop card hover enlarges the face without a detailed popup")
	check(card.full_text.contains(app.catalog.cards[card.card.id].name) and card.full_text.contains(app.catalog.cards[card.card.id].effect), "Hovered card preserves its complete readable name and effect")
	await _capture("shop_hover")
	item = _item(4)
	await _visible(item)
	await _motion(_center(item))
	await _settle()
	var text: String = shop.get_shop_tooltip_text()
	var panel: Control = shop.get_tooltip_panel()
	check(text.contains(app.catalog.relics.r01.name) and text.contains(app.catalog.relics.r01.effect), "Item hover shows the full name and effect")
	check(panel != null and panel.is_visible_in_tree() and app.get_global_rect().grow(1).encloses(panel.get_global_rect()), "Item effect panel stays visible within the canvas")
	await _capture("shop_item_hover")
	item = _item(6)
	await _visible(item)
	await _motion(_center(item))
	await _settle()
	text = shop.get_shop_tooltip_text()
	check(text.contains(app.catalog.supplies.healing_vial.name) and text.contains(app.catalog.supplies.healing_vial.effect), "Supply icon hover also shows its full name and effect")
	await _motion(start)
	await _settle()
	await _mouse(start, true, MOUSE_BUTTON_WHEEL_DOWN)
	await _mouse(start, false, MOUSE_BUTTON_WHEEL_DOWN)
	await _mouse(start, true, MOUSE_BUTTON_WHEEL_UP)
	await _mouse(start, false, MOUSE_BUTTON_WHEEL_UP)
	check(_same_rects(_product_rects(), positions) and navigation.get_global_rect() == fixed_rect, "Wheel input cannot move one-screen products, prices, leave button, or navigation")
	check(app.run_state.to_snapshot() == before, "Shop hover and wheel input do not mutate inventory or money")

func _purchases() -> void:
	await _settle()
	var old_view = shop
	var old_navigation = app.run_navigation
	var money: int = app.run_state.shells
	var deck_size: int = app.run_state.deck.size()
	var price: int = app.run_state.stock[0].price
	_raw_click(_center(_price(0)))
	check(app.run_state.deck.size() == deck_size + 1 and app.run_state.deck.back().id == "c01" and app.run_state.shells == money - price and app.run_state.stock[0].sold, "Clicking the card price buys exactly one card at its displayed price")
	var bought: Dictionary = app.run_state.to_snapshot()
	old_view.buy_requested.emit(1)
	old_navigation.tab_selected.emit("map")
	check(app.run_state.to_snapshot() == bought, "A disposed shop view callback cannot buy a different item")
	check(app.run_tab == "shop" and not is_instance_valid(app.run_tab_content), "Disposed navigation callback cannot change the refreshed shop tab")
	await _settle()
	_find_shop()
	check(str(_price(0).text).contains("已售出"), "Purchased card is visibly marked sold")
	check(_nav("牌组").text.contains(str(app.run_state.deck.size())) and app.run_status.amount.text == str(app.run_state.shells), "Purchase refreshes browser-tab inventory count and the fixed balance")
	await _click(_price(0))
	app._buy(0)
	check(app.run_state.to_snapshot() == bought, "Repeated sold-item clicks and direct requests cannot charge again")
	for index in [4, 5, 6]:
		var item_price: int = app.run_state.stock[index].price
		var before_money: int = app.run_state.shells
		var id: String = app.run_state.stock[index].id
		var control: Control = _item(index) if index != 5 else _price(index)
		await _visible(control)
		var item_rect: Rect2 = _item(index).get_global_rect()
		var leave_rect: Rect2 = shop.get_leave_button().get_global_rect()
		await _click(control)
		_find_shop()
		check(_item(index).get_global_rect() == item_rect and shop.get_leave_button().get_global_rect() == leave_rect, "Buying item %d keeps products and the lower-right leave button fixed" % index)
		check(app.run_state.stock[index].sold and app.run_state.shells == before_money - item_price, "Item %d click charges exactly its displayed price" % index)
		check(id in app.run_state.relics if index < 6 else app.run_state.supplies.count(id) == 2, "Item %d click grants its selected inventory entry" % index)

func _replacement() -> void:
	app.run_state.supplies = ["healing_vial", "guard_vial", "energy_vial"]
	app.run_state.shells = 150
	app._state_changed()
	await _settle()
	_find_shop()
	var before: Dictionary = app.run_state.to_snapshot()
	await _visible(_item(7))
	var item_rect: Rect2 = _item(7).get_global_rect()
	var leave_rect: Rect2 = shop.get_leave_button().get_global_rect()
	await _click(_item(7))
	check(is_instance_valid(app.modal) and app.run_state.to_snapshot() == before, "Buying into full supply slots opens replacement without charging")
	var cancel
	var old_replacement
	if is_instance_valid(app.modal):
		for button in app.modal.find_children("*", "Button", true, false):
			if button.text == "取消":
				cancel = button
			elif button.text == "替换 " + app.catalog.supplies.guard_vial.name:
				old_replacement = button
	check(cancel != null and old_replacement != null, "Full-slot modal exposes cancel and the chosen replacement slot")
	if cancel != null:
		_raw_click(_center(cancel))
		if old_replacement != null:
			old_replacement.pressed.emit()
	check(not is_instance_valid(app.modal) and app.run_state.to_snapshot() == before, "Cancel and its stale replacement callback preserve the whole purchase state")
	await _settle()
	check(not shop._locked, "Cancelling replacement unlocks shop interactions")
	await _click(_item(7))
	var replacement
	if is_instance_valid(app.modal):
		for button in app.modal.find_children("*", "Button", true, false):
			if button.text == "替换 " + app.catalog.supplies.guard_vial.name:
				replacement = button
	check(replacement != null, "Replacement slot is available after reopening")
	if replacement != null:
		_raw_click(_center(replacement))
		var after: Dictionary = app.run_state.to_snapshot()
		replacement.pressed.emit()
		check(app.run_state.to_snapshot() == after, "Repeated replacement callback charges no second purchase")
	await _settle()
	_find_shop()
	check(app.run_state.supplies == ["healing_vial", "energy_vial", "energy_vial"] and app.run_state.shells == 150 - int(app.run_state.stock[7].price) and app.run_state.stock[7].sold and not is_instance_valid(app.modal), "Successful replacement grants only the chosen slot and charges once")
	check(_item(7).get_global_rect() == item_rect and shop.get_leave_button().get_global_rect() == leave_rect, "Successful replacement keeps the one-screen shop layout fixed")

func _poor_and_resume() -> void:
	app.run_state.shells = 0
	app._state_changed()
	await _settle()
	_find_shop()
	await _settle()
	var card: Control = _card(1)
	var base_scale: Vector2 = card.scale
	await _motion(_center(card))
	await _settle()
	check(not card.available and card.scale.x > base_scale.x and card.full_text.contains(app.catalog.cards.c05.effect), "Insufficient funds disable buying while keeping card hover and readable effects")
	check(not card.tooltip_text.contains(app.catalog.cards.c05.name) and not card.tooltip_text.contains(app.catalog.cards.c05.effect), "Unavailable card tooltip includes no redundant detailed text")
	await _capture("shop_poor_hover")
	var before: Dictionary = app.run_state.to_snapshot()
	_raw_click(_center(_price(1)))
	card.activation_requested.emit(int(card.uid))
	app._buy(1)
	check(app.run_state.to_snapshot() == before and not is_instance_valid(app.modal), "Unaffordable mouse, keyboard, and direct purchase requests charge nothing")
	var old_view = shop
	app._return_menu()
	old_view.buy_requested.emit(2)
	check(app.run_state.to_snapshot() == before and app.screen == "menu", "Old purchase callback cannot run after menu navigation")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = _new_app()
	check(app.store.has_active(), "Restart offers the isolated shop checkpoint")
	app._continue_run()
	await _settle()
	_find_shop()
	check(app.run_state.to_snapshot() == before, "Restart restores exact shop stock, sold flags, balance, inventory, and RNG")
	check(app.run_status.amount.text == "0", "Resumed fixed navigation shows the saved balance")
	for index in [0, 4, 5, 6, 7]:
		check(str(_price(index).text).contains("已售出"), "Resumed stock %d remains visibly sold" % index)
	await _visible(shop.get_leave_button())
	var departed = shop
	_raw_click(_center(shop.get_leave_button()))
	var finished: Dictionary = app.run_state.to_snapshot()
	departed.leave_requested.emit()
	app._complete_node()
	check(app.run_state.phase == "map" and app.run_state.visited.count(app.run_state.current) == 1 and app.run_state.available == app.run_state.nodes[app.run_state.current].next, "Leaving shop completes its node exactly once and exposes the next routes")
	check(app.run_state.to_snapshot() == finished and app.run_state.shells == 0 and app.run_state.stock == before.stock, "Repeated leave preserves purchases and does not complete twice")

func _drop_app() -> void:
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = null
	shop = null

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
		await _begin_shop()
		_layout()
		await _capture("shop_idle")
		await _tab_switching()
		await _drag_and_hover()
		if dimensions == Vector2i(1280, 720):
			await _purchases()
			await _replacement()
			await _poor_and_resume()
		await _drop_app()
	_clean()
	print("V2_SHOP_UI: %d checks, %d failures; four resolutions, one-screen cards/items, fixed leave, drag/wheel guards, purchases and save recovery" % [checks, failures])
	quit(0 if failures == 0 else 1)
