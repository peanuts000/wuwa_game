extends SceneTree

# Pass -- --capture to also render screenshots using a real graphics driver.
var app
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	for scroll in app.find_children("*", "ScrollContainer", true, false):
		check(not scroll.get_h_scroll_bar().is_visible_in_tree() and not scroll.get_v_scroll_bar().is_visible_in_tree(), "Scrollbars stay hidden on " + name)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.save_png("res://tests/artifacts/" + name + ".png")

func _perform_board_hint() -> bool:
	var move: Array = app.combat.board.hint()
	if move.size() == 1:
		app._click_cell(move[0])
		app._activate_selected()
	elif move.size() == 2:
		app._click_cell(move[0])
		app._click_cell(move[1])
	else:
		check(false, "Live board provides a swap or special-ball action")
		return false
	return true

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("res://tests/artifacts/ui_save.cfg" + suffix)
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path = "res://tests/artifacts/ui_save.cfg"
	app.legacy_save_path = "res://tests/artifacts/missing_legacy.cfg"
	app.apply_display_settings = false
	root.add_child(app)
	check(app.screen == "menu", "Startup shows main menu")
	check(app.find_children("*", "Button", true, false).size() == 5, "Menu contains five buttons")
	check(not app.store.has_active(), "No fixture save disables continue")
	await _capture("v2_menu")
	app._navigate("characters")
	await _capture("v2_characters")
	app._select_role(1)
	check(app.role_index == 0, "Unavailable character cannot be selected")
	var disabled_role = null
	for button in app.find_children("Role_*", "TextureButton", true, false):
		if button.get_meta("role_id") == "diffraction_phoebe":
			disabled_role = button
	check(disabled_role != null and disabled_role.disabled, "Unavailable character button is disabled")
	app._select_role(0)
	app._show_attribute_dialog(true)
	check(app.screen == "characters" and is_instance_valid(app.modal), "Attributes open over character page")
	await _capture("v2_attributes_dialog")
	app._confirm_attributes(true)
	check(app.store.has_active(), "New run checkpoint exists")
	await _capture("v2_map")
	app._enter_node(app.run_state.available[0])
	await _capture("v2_battle")
	check(app.battle_view.hand_view.is_collapsed(), "Before matching, hand is tucked below the board")
	if not _perform_board_hint():
		quit(1)
		return
	var frames := 0
	while (app.combat.phase == "resolving" or app.resolving_ui) and frames < 1000:
		check(not app.combat.board.pending_rainbow and not is_instance_valid(app.modal), "Fresh board resolves without a rainbow choice")
		await create_timer(0.01).timeout
		frames += 1
	if app.combat.phase != "play":
		push_error("UI board resolution did not finish")
		quit(1)
		return
	await _capture("v2_play")
	check(not app.battle_view.hand_view.is_collapsed(), "Completing matching expands the hand")
	app._show_deck()
	var deck_view = app.modal.find_child("DeckView", true, false)
	check(deck_view != null and deck_view.get_card_views().size() == app.run_state.deck.size(), "Deck inspection shows every card instance")
	await _capture("v2_deck")
	app._close_modal()
	app._show_rules()
	await _capture("v2_rules")
	app._close_modal()
	await app._end_turn()
	check(app.combat.phase == "board" and app.battle_view.hand_view.is_collapsed(), "Enemy action returns to a collapsed hand")
	await _capture("v2_next_turn")
	if not _perform_board_hint():
		quit(1)
		return
	frames = 0
	while (app.combat.phase == "resolving" or app.resolving_ui) and frames < 1000:
		check(not app.combat.board.pending_rainbow and not is_instance_valid(app.modal), "Next turn resolves without a rainbow choice")
		await create_timer(0.01).timeout
		frames += 1
	if app.combat.phase != "play":
		push_error("Second turn board resolution did not finish")
		quit(1)
		return
	# UI fixtures exercise long descriptions and the real card-button -> victory path.
	app.combat.hand.clear()
	for id in ["c05", "g03", "g06", "g07", "g09"]:
		app.combat.hand.append({"id": id, "upgraded": true, "uid": 100 + app.combat.hand.size()})
	for kind in app.catalog.ATTRIBUTES:
		app.combat.mana[kind] = 20
	app._render()
	await _capture("v2_complex_cards")
	app.combat.enemy_hp = 1
	app.combat.enemy_guard = 0
	await app._play_card_uid(int(app.combat.hand[0].uid))
	if app.run_state.phase not in ["rewards", "map"]:
		push_error("Lethal card did not route UI into rewards or complete an empty reward node")
		quit(1)
		return
	await _capture("v2_rewards")
	while not app.run_state.rewards.is_empty():
		app.run_state.accept_reward()
	app._complete_node()
	# Visit every non-combat screen with real generated state.
	app.run_state.enter_node(app.run_state.available[0])
	app.run_state.phase = "shop"
	app.run_state._generate_shop()
	app._render()
	await _capture("v2_shop")
	app.run_state.phase = "rest"
	app._render()
	app._choose_deck(true)
	await _capture("v2_upgrade")
	var upgrade_text: String = app.catalog.card_text({"id": "c06", "upgraded": true})
	var upgrade_view = app.modal.find_child("DeckView", true, false)
	for card in upgrade_view.get_card_views():
		if card.full_text == upgrade_text:
			card.activation_requested.emit(card.uid)
			break
	if not app.run_state.deck[9].upgraded or app.run_state.phase != "map":
		push_error("Upgrade card did not modify chosen copy and complete node")
		quit(1)
		return
	app.run_state.enter_node(app.run_state.available[0])
	app.run_state.phase = "event"
	app.run_state.event_id = "trade_life"
	app._render()
	await _capture("v2_event")
	app.run_state.end_run("victory")
	app._state_changed()
	check(app.store.data.history.size() == 1, "One history record after terminal run")
	app._state_changed()
	check(app.store.data.history.size() == 1, "Repeated terminal refresh is idempotent")
	await _capture("v2_summary")
	app._navigate("history")
	await _capture("v2_history")
	app._navigate("settings")
	await _capture("v2_settings")
	print("GAMEPLAY_V2_UI_SMOKE: menu, characters, attribute dialog, map, battle, cards, turn, rewards, shop, rest, event, history, settings; %d failures" % failures)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("res://tests/artifacts/ui_save.cfg" + suffix)
	quit(1 if failures else 0)
