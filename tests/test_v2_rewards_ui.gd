extends SceneTree

const CardView = preload("res://scripts/v2/card_view.gd")
const SAVE_PATH := "res://tests/artifacts/rewards_ui_save.cfg"
const LEGACY_PATH := "res://tests/artifacts/rewards_ui_missing_legacy.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 960)]
var app
var checks := 0
var failures := 0
var dimensions_label := "1280x720"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[%s] %s" % [dimensions_label, message])

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.25).timeout

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = LEGACY_PATH
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _drop_app() -> void:
	if is_instance_valid(app):
		root.remove_child(app)
		app.queue_free()
	await process_frame
	app = null

func _begin_rewards() -> void:
	app._commit_run()
	check(app.run_state != null and app.run_state.phase == "map", "Fixture starts a real exploration")
	app._enter_node(app.run_state.available[0])
	check(app.combat != null, "Fixture enters a real battle node")
	check(app.run_state.finish_battle(true), "Real battle node transitions to rewards")
	app.combat = null
	app.run_state.relics.clear()
	app.run_state.supplies = ["healing_vial"]

func _set_rewards(rewards: Array) -> void:
	if app.run_state.phase != "rewards":
		# Auto-completion visits the old node. Start a fresh real node rather than
		# forcing that visited node back into rewards, retaining the tested inventory.
		var inventory: Dictionary = {}
		for key in ["deck", "relics", "supplies", "next_card_uid", "shells"]:
			var value: Variant = app.run_state.get(key)
			inventory[key] = value.duplicate(true) if value is Array else value
		_begin_rewards()
		for key in inventory:
			app.run_state.set(key, inventory[key])
	app.run_state.phase = "rewards"
	app.run_state.rewards = rewards.duplicate(true)
	app._state_changed()
	await _settle()
	check(app.save_error == "", "Reward fixture checkpoint saves")
	var claimable := false
	for reward in rewards:
		claimable = claimable or reward.type != "notice"
	if claimable:
		check(app.run_state.phase == "rewards" and is_instance_valid(app.reward_view), "Claimable rewards keep RewardView active")
	else:
		_check_map("Empty or summary-only rewards complete automatically")

func _item(index: int, choice: String = ""):
	if not is_instance_valid(app.reward_view):
		return null
	for item in app.reward_view.get_reward_items():
		if int(item.get_meta("reward_index", -1)) == index and str(item.get_meta("choice", "")) == choice:
			return item
	return null

func _card(choice: String):
	if not is_instance_valid(app.reward_view):
		return null
	for card in app.reward_view.get_card_views():
		if str(card.get_meta("choice", "")) == choice:
			return card
	return null

func _button(name: String, subtree: Node = null):
	return (subtree if subtree != null else app.reward_view).find_child(name, true, false)

func _press(button) -> void:
	check(button != null, "Requested reward control exists")
	if button != null:
		button.pressed.emit()

func _mouse_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame

func _mouse_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _hover_item(button, lookup: Dictionary) -> void:
	check(button != null, "Hover item exists")
	if button == null:
		return
	button.mouse_entered.emit()
	await _settle()
	var tooltip: String = app.reward_view.get_reward_tooltip_text()
	check(tooltip.contains(lookup.name) and tooltip.contains(lookup.effect), "Hover shows item name and full effect")
	var panel: Control = app.reward_view.get_tooltip_panel()
	check(panel != null and panel.is_visible_in_tree(), "Hover tooltip is visible")
	if panel != null:
		check(app.get_global_rect().grow(1).encloses(panel.get_global_rect()), "Hover tooltip remains in canvas")

func _bounds() -> void:
	var bounds: Rect2 = app.get_global_rect()
	check(app.size.is_equal_approx(Vector2(1280, 720)), "Logical reward canvas stays 1280 by 720")
	check(bounds.grow(1).encloses(app.reward_view.get_global_rect()), "RewardView stays in canvas")
	for control in app.reward_view.find_children("*", "BaseButton", true, false):
		if control.is_visible_in_tree():
			check(bounds.grow(1).encloses(control.get_global_rect()), "Reward control stays in canvas: " + control.name)
	for card in app.reward_view.get_card_views():
		check(bounds.grow(1).encloses(card.get_global_rect()), "Reward card stays in canvas")
		check(card.paper_style, "Rewards share battle card artwork")

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var suffix := "" if dimensions_label == "1280x720" else "_" + dimensions_label
	check(image.save_png("res://tests/artifacts/" + name + suffix + ".png") == OK, "Reward screenshot saved")

func _show_cards(index: int) -> void:
	if app.reward_view.get_card_views().is_empty():
		_press(_item(index))
	await _settle()
	check(app.reward_view.get_card_views().size() == app.run_state.rewards[index].options.size(), "Card selection displays every option")
	check(not is_instance_valid(app.modal), "Card selection opens without a confirmation modal")

func _reload_exact(expected: Dictionary) -> void:
	await _drop_app()
	app = _new_app()
	check(app.store.has_active(), "Fresh app offers saved reward state")
	app._continue_run()
	await _settle()
	check(app.run_state.to_snapshot() == expected, "Reward checkpoint restores exact state and RNG")
	if expected.phase == "rewards":
		check(app.run_state.phase == "rewards" and is_instance_valid(app.reward_view), "Restored pending rewards are immediately usable")
	else:
		_check_map("Restored completed rewards return directly to map")

func _check_map(message: String) -> void:
	check(app.screen == "run" and app.run_state.phase == "map" and app.run_state.rewards.is_empty() and not is_instance_valid(app.reward_view), message)
	check(app.run_state.visited.count(app.run_state.current) == 1 and app.run_state.available == app.run_state.nodes[app.run_state.current].next, "Reward completion visits the node once and exposes its next routes")

func _check_direct_cards(count: int, message: String) -> void:
	check(app.run_state.phase == "rewards" and is_instance_valid(app.reward_view) and app.reward_view.get_card_views().size() == count, message)
	if not is_instance_valid(app.reward_view):
		return
	check(app.reward_view.get_reward_items().is_empty() and _button("RewardListPanel") == null, "Card-only rewards create no empty item list")
	check(_button("BackButton") == null and _button("FinishButton") == null, "Card-only selection has no route back to an empty item page")

func _layout_examples() -> void:
	await _set_rewards([
		{"type": "relic", "id": "r01"},
		{"type": "supply", "id": "guard_vial"},
		{"type": "card", "options": ["c05", "g03", "g09"]},
	])
	check(app.reward_view.get_reward_items().size() == 3, "Different pending rewards share one list")
	await _hover_item(_item(0, "r01"), app.catalog.relics.r01)
	_bounds()
	await _capture("reward_items")
	app.reward_view.get_reward_items()[0].mouse_exited.emit()
	await _show_cards(2)
	_bounds()
	await _capture("reward_cards")
	_press(_button("BackButton"))
	await _settle()
	check(app.run_state.rewards.size() == 3, "Leaving card selection does not consume the reward")
	await _set_rewards([{"type": "choice", "options": [{"type": "relic", "id": "r02"}, {"type": "supply", "id": "energy_vial"}]}])
	check(app.reward_view.get_reward_items().size() == 2, "Two-choice reward exposes both items")
	await _hover_item(_item(0, "r02"), app.catalog.relics.r02)
	_bounds()
	await _capture("reward_choice")
	await _set_rewards([{"type": "notice", "text": "战斗胜利"}, {"type": "card", "options": ["c01", "c02", "g03"]}])
	_check_direct_cards(3, "Notice plus cards opens card selection directly at every resolution")
	_bounds()
	await _capture("reward_cards_direct")

func _functional_cases() -> void:
	await _set_rewards([{"type": "relic", "id": "r01"}, {"type": "supply", "id": "guard_vial"}])
	_press(_item(0, "r01"))
	check("r01" in app.run_state.relics and app.run_state.rewards.size() == 1, "Item click immediately grants the relic")
	check(not is_instance_valid(app.modal), "Item claim has no confirmation step")
	var saved: Dictionary = app.run_state.to_snapshot()
	await _reload_exact(saved)
	check(app.run_state.relics.count("r01") == 1, "Resume does not grant claimed relic again")
	app.run_state.supplies.clear()
	await _set_rewards([{"type": "supply", "id": "guard_vial"}, {"type": "supply", "id": "guard_vial"}])
	var old_item = _item(0, "guard_vial")
	_press(old_item)
	_press(old_item)
	check(app.run_state.supplies == ["guard_vial"] and app.run_state.rewards.size() == 1, "Stale repeated input cannot claim shifted identical reward")
	await _settle()
	_press(_item(0, "guard_vial"))
	check(app.run_state.supplies == ["guard_vial", "guard_vial"] and app.run_state.rewards.is_empty(), "New control can claim the remaining identical reward")
	_check_map("Last identical item claim returns directly to map")
	app.run_state.relics.clear()
	app.run_state.supplies = ["healing_vial"]
	await _set_rewards([{"type": "choice", "options": [{"type": "relic", "id": "r02"}, {"type": "supply", "id": "energy_vial"}]}])
	var alternate = _item(0, "energy_vial")
	_press(_item(0, "r02"))
	_press(alternate)
	check(app.run_state.relics == ["r02"] and app.run_state.supplies == ["healing_vial"], "Two-choice click grants exactly one item")
	_check_map("Choosing the sole two-choice item removes both alternatives and returns to map")
	await _set_rewards([{"type": "card", "options": ["c05", "g03", "g09"]}, {"type": "relic", "id": "r03"}])
	var before_deck: int = app.run_state.deck.size()
	await _show_cards(0)
	var chosen_card = _card("c05")
	var alternate_card = _card("g09")
	check(chosen_card != null and chosen_card.get_script() == CardView, "Reward selection reuses CardView")
	if chosen_card != null:
		var resting_scale: Vector2 = chosen_card.scale
		await _mouse_motion(chosen_card.get_global_transform_with_canvas() * Vector2(75, 105))
		await _settle()
		check(chosen_card.scale.x > resting_scale.x, "Reward card grows on hover")
		check(chosen_card.full_text.contains(app.catalog.cards.c05.name) and chosen_card.full_text.contains(app.catalog.cards.c05.effect), "Reward card retains its full readable name and effect")
		check(chosen_card.tooltip_text.is_empty(), "Reward card hover shows no redundant name or effect tooltip")
		_bounds()
		await _capture("reward_cards_no_tooltip")
		_mouse_click(chosen_card.get_global_transform_with_canvas() * Vector2(75, 105))
		if alternate_card != null:
			alternate_card.activation_requested.emit(int(alternate_card.uid))
	check(app.run_state.deck.size() == before_deck + 1 and app.run_state.deck.back().id == "c05", "Click adds exactly the chosen card without confirmation")
	check(app.run_state.rewards.size() == 1 and app.run_state.rewards[0].id == "r03", "Card choice consumes only its reward entry")
	app._skip_reward(0)
	check(app.run_state.rewards.is_empty() and "r03" not in app.run_state.relics, "Skip discards reward without granting it")
	_check_map("Skipping the last remaining item returns directly to map")
	await _set_rewards([{"type": "card", "options": ["c01", "c02"]}])
	await _show_cards(0)
	var before_skip: int = app.run_state.deck.size()
	_press(_button("SkipButton"))
	check(app.run_state.rewards.is_empty() and app.run_state.deck.size() == before_skip, "Card-page skip grants no card")
	_check_map("Skipping the last card group returns directly to map")
	app.run_state.supplies = ["healing_vial", "guard_vial", "energy_vial"]
	await _set_rewards([{"type": "supply", "id": "energy_vial"}])
	var before_full: Dictionary = app.run_state.to_snapshot()
	_press(_item(0, "energy_vial"))
	await _settle()
	check(is_instance_valid(app.modal), "Full supply slots open replacement choices")
	check(app.run_state.to_snapshot() == before_full, "Opening replacement consumes nothing")
	var cancel
	var replacement
	var cancelled_replacement
	if is_instance_valid(app.modal):
		for button in app.modal.find_children("*", "Button", true, false):
			check(not button.text.contains("确认"), "Replacement requires no separate confirmation")
			check(app.get_global_rect().grow(1).encloses(button.get_global_rect()), "Replacement button stays in canvas")
			if button.text == "取消":
				cancel = button
			if button.text == "替换 " + app.catalog.supplies.guard_vial.name:
				cancelled_replacement = button
	_press(cancel)
	check(app.run_state.to_snapshot() == before_full and not is_instance_valid(app.modal), "Cancel preserves full reward and inventory")
	check(not app.reward_view._locked, "Cancel unlocks reward interactions")
	_press(cancelled_replacement)
	check(app.run_state.to_snapshot() == before_full, "Cancelled replacement callback cannot consume the reward")
	_press(_item(0, "energy_vial"))
	await _settle()
	if is_instance_valid(app.modal):
		for button in app.modal.find_children("*", "Button", true, false):
			if button.text == "替换 " + app.catalog.supplies.guard_vial.name:
				replacement = button
	_press(replacement)
	check(app.run_state.supplies == ["healing_vial", "energy_vial", "energy_vial"] and app.run_state.rewards.is_empty(), "Replacement click directly claims into chosen slot")
	check(not is_instance_valid(app.modal), "Replacement closes after successful claim")
	_check_map("Claiming the last supply through replacement returns to map")
	for slot in [0, 2]:
		var originals: Array = ["healing_vial", "guard_vial", "energy_vial"]
		app.run_state.supplies = originals.duplicate()
		await _set_rewards([{"type": "supply", "id": "energy_vial"}])
		_press(_item(0, "energy_vial"))
		await _settle()
		var slot_button
		for button in app.modal.find_children("*", "Button", true, false):
			if button.text == "替换 " + app.catalog.supplies[originals[slot]].name:
				slot_button = button
		_press(slot_button)
		var expected: Array = originals.duplicate()
		expected[slot] = "energy_vial"
		check(app.run_state.supplies == expected and app.run_state.rewards.is_empty(), "Slot %d callback replaces only its selected supply" % slot)
		_check_map("Replacement slot %d completes the final reward" % slot)
	await _reload_exact(app.run_state.to_snapshot())
	await _set_rewards([{"type": "card", "options": ["c01", "c02", "c03"]}])
	await _show_cards(0)
	var hovering = _card("c02")
	if hovering != null:
		await _mouse_motion(hovering.get_global_transform_with_canvas() * Vector2(75, 105))
	var paused: Dictionary = app.run_state.to_snapshot()
	var old_view = app.reward_view
	app._return_menu()
	await _settle()
	check(app.screen == "menu" and not is_instance_valid(old_view), "Page switch disposes reward hover animation")
	check(app.run_state.to_snapshot() == paused, "Old hover callbacks cannot mutate paused rewards")
	app._continue_run()
	await _settle()
	check(app.run_state.to_snapshot() == paused and is_instance_valid(app.reward_view), "Continue restores unclaimed rewards without granting")
	var deck_before_finish: Array = app.run_state.deck.duplicate(true)
	app._finish_rewards()
	check(app.run_state.phase == "map" and app.run_state.rewards.is_empty(), "Finish skips remaining rewards and returns to map")
	check(app.run_state.deck == deck_before_finish, "Finish skips pending card without adding it")
	var finished: Dictionary = app.run_state.to_snapshot()
	app._finish_rewards()
	check(app.run_state.to_snapshot() == finished, "Repeated finish cannot complete the node twice")

func _direct_reward_cases() -> void:
	# Existing inventory does not count as a dropped item in this reward batch.
	app.run_state.relics = ["r01"]
	app.run_state.supplies = ["healing_vial", "guard_vial", "energy_vial"]
	var inventory: Dictionary = {"relics": app.run_state.relics.duplicate(), "supplies": app.run_state.supplies.duplicate()}
	await _set_rewards([{"type": "notice", "text": "战斗胜利\n此前已有藏品与补给"}, {"type": "card", "options": ["c04", "g10"]}])
	_check_direct_cards(2, "Owning relics and supplies still opens card selection directly when none dropped")
	var before_deck: int = app.run_state.deck.size()
	var selected = _card("c04")
	var stale_alternative = _card("g10")
	check(selected != null, "Direct card selection provides the requested card")
	if selected != null:
		var point: Vector2 = selected.get_global_transform_with_canvas() * Vector2(75, 105)
		await _mouse_motion(point)
		_mouse_click(point)
		if stale_alternative != null:
			stale_alternative.activation_requested.emit(int(stale_alternative.uid))
	check(app.run_state.deck.size() == before_deck + 1 and app.run_state.deck.back().id == "c04", "Selecting the final card adds exactly one card")
	_check_map("Choosing the final card automatically skips summaries and returns to map")
	check(app.run_state.relics == inventory.relics and app.run_state.supplies == inventory.supplies, "Card-only routing preserves existing item inventory")
	await _reload_exact(app.run_state.to_snapshot())
	await _set_rewards([{"type": "card", "options": ["c01", "c02"]}])
	_check_direct_cards(2, "A sole card reward opens selection directly")
	var deck_before_skip: Array = app.run_state.deck.duplicate(true)
	_press(_button("SkipButton"))
	_check_map("Skipping the final direct card selection returns to map")
	check(app.run_state.deck == deck_before_skip, "Skipping final cards grants none")
	# Multiple card groups advance to the next direct selection, then finish once.
	await _set_rewards([
		{"type": "notice", "text": "战斗胜利"},
		{"type": "card", "options": ["c02", "c03"]},
		{"type": "card", "options": ["g01", "g02", "g03"]},
	])
	_check_direct_cards(2, "Multiple card rewards open the first group directly")
	var first_group = _card("c03")
	check(first_group != null, "First card reward group is available")
	var multiple_before: int = app.run_state.deck.size()
	if first_group != null:
		first_group.activation_requested.emit(int(first_group.uid))
	_check_direct_cards(3, "Claiming the first card group opens the next group without an item page")
	check(app.run_state.rewards.size() == 2 and app.run_state.rewards[1].options == ["g01", "g02", "g03"], "Card selection preserves the notice index until all claimable rewards finish")
	_press(_button("SkipButton"))
	_check_map("Skipping the last of several card groups completes the node")
	check(app.run_state.deck.size() == multiple_before + 1 and app.run_state.deck.back().id == "c03", "Several card groups grant only the chosen first card")
	# Lists stay available while this batch still contains a supply or relic.
	await _set_rewards([{"type": "supply", "id": "guard_vial"}, {"type": "card", "options": ["c01", "c02"]}])
	check(app.reward_view.get_card_views().is_empty() and app.reward_view.get_reward_items().size() == 2 and _button("RewardListPanel") != null, "A dropped supply keeps the item list even with pending cards")
	app.run_state.supplies.clear()
	_press(_item(0, "guard_vial"))
	_check_direct_cards(2, "Claiming the final dropped item advances directly to the remaining card group")
	_press(_button("SkipButton"))
	_check_map("Skipping the card after item claim returns to map")
	await _set_rewards([{"type": "notice", "text": "战斗胜利\n未掉落卡牌、补给或藏品"}])
	_check_map("A notice-only reward batch never opens an empty item page")
	await _capture("reward_empty_map")
	await _set_rewards([])
	_check_map("An empty reward batch returns directly to map")
	# Simulate a previous version's persisted summary-only rewards without calling
	# the new normalization, then verify continue migrates it to a saved map state.
	_begin_rewards()
	app.run_state.relics = ["r02"]
	app.run_state.supplies = ["energy_vial"]
	app.run_state.rewards = [{"type": "notice", "text": "旧版战斗结算\n已经领取藏品"}]
	var before_legacy: Dictionary = app.run_state.to_snapshot()
	check(app.store.checkpoint(app.run_state, null, app.metadata) == OK, "Previous summary-only reward checkpoint is a valid isolated fixture")
	await _drop_app()
	app = _new_app()
	check(app.store.has_active(), "Previous summary-only checkpoint offers continue")
	app._continue_run()
	await _settle()
	_check_map("Continuing a previous summary-only reward checkpoint enters map directly")
	check(app.run_state.relics == before_legacy.relics and app.run_state.supplies == before_legacy.supplies and app.run_state.deck == before_legacy.deck, "Summary-only checkpoint migration grants and discards no inventory")
	var restored: Dictionary = app.store.restore_active()
	check(restored.get("run") != null and restored.run.to_snapshot() == app.run_state.to_snapshot(), "Summary-only continue saves the completed map checkpoint immediately")

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
		_begin_rewards()
		await _layout_examples()
		if dimensions == Vector2i(1280, 720):
			await _functional_cases()
			await _direct_reward_cases()
		await _drop_app()
	_clean()
	print("GAMEPLAY_V2_REWARDS_UI: %d checks, %d failures; direct claims, choices, cards, replacement, recovery, four resolutions" % [checks, failures])
	quit(1 if failures else 0)
