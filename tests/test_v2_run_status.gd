extends SceneTree

# Test checkpoints are separate from the player's user:// save.
const SAVE_PATH := "res://tests/artifacts/run_status_save.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 960)]
const LifeHearts = preload("res://scripts/v2/life_hearts.gd")
var app
var checks := 0
var failures := 0
var dimensions_label := "1280x720"
var losses: Array[int] = []
var finished := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("RUN_STATUS [%s]: %s" % [dimensions_label, message])

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _new_app():
	var instance = load("res://scenes/Main.tscn").instantiate()
	instance.save_path = SAVE_PATH
	instance.legacy_save_path = "res://tests/artifacts/missing_run_status_legacy.cfg"
	instance.apply_display_settings = false
	root.add_child(instance)
	return instance

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.1).timeout

func _wait_finished(hearts) -> void:
	var steps := 0
	while hearts.is_animating() and steps < 160:
		await create_timer(0.025).timeout
		steps += 1
	check(not hearts.is_animating(), "Heart loss animation completes within four seconds")

func _record_losses(hearts) -> void:
	if not hearts.loss_started.is_connected(_on_loss_started):
		hearts.loss_started.connect(_on_loss_started)
	if not hearts.loss_finished.is_connected(_on_loss_finished):
		hearts.loss_finished.connect(_on_loss_finished)

func _on_loss_started(index: int) -> void:
	losses.append(index)

func _on_loss_finished(_index: int) -> void:
	finished += 1

func _snapshot() -> Dictionary:
	return {
		"run": app.run_state.to_snapshot(),
		"combat": app.combat.to_snapshot() if app.combat != null else null,
		"store": app.store.data.duplicate(true),
		"metadata": app.metadata.duplicate(true),
		"file": FileAccess.get_file_as_string(SAVE_PATH),
		"backup": FileAccess.get_file_as_string(SAVE_PATH + ".bak") if FileAccess.file_exists(SAVE_PATH + ".bak") else "",
	}

func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var suffix := "" if dimensions_label == "1280x720" else "_" + dimensions_label
	check(root.get_texture().get_image().save_png("res://tests/artifacts/" + name + suffix + ".png") == OK, "Status screenshot saves: " + name)

func _check_status(expected_lives: int, fixed_bar: bool = false) -> void:
	var status = app.run_status
	var hearts = status.get_hearts()
	check(status.is_visible_in_tree() and hearts.get_lives() == expected_lives, "Visible HUD uses the current exploration life value")
	check(not hearts.is_animating() and hearts.get_visible_heart_count() == expected_lives, "Each remaining life is exactly one visible heart")
	check(status.amount.text == str(app.run_state.shells), "Currency displays the exact current balance")
	check(app.get_global_rect().grow(1).encloses(status.get_global_rect()), "Status fits inside the game canvas")
	check(status.get_global_rect().grow(1).encloses(hearts.get_global_rect()) and status.get_global_rect().grow(1).encloses(status.amount.get_global_rect()), "Hearts and balance fit inside the status region; compact=%s status=%s minimum=%s hearts=%s minimum=%s amount=%s minimum=%s" % [status.is_compact(), status.get_global_rect(), status.get_combined_minimum_size(), hearts.get_global_rect(), hearts.get_combined_minimum_size(), status.amount.get_global_rect(), status.amount.get_combined_minimum_size()])
	if fixed_bar:
		check(status.position.is_equal_approx(Vector2(20, 14)) and status.size.is_equal_approx(Vector2(300, 52)), "Map, shop, and rewards use the same fixed upper-left status region")
	var no_life_fraction := true
	for label in app.find_children("*", "Label", true, false):
		no_life_fraction = no_life_fraction and not (label.text.contains("探索生命") and label.text.contains("/"))
	check(no_life_fraction, "Exploration life has no numeric current / maximum label")

func _node_of_type(kind: String) -> String:
	for id in app.run_state.nodes:
		if app.run_state.nodes[id].type == kind and id not in app.run_state.visited:
			return id
	# Some random maps contain no event or shop: use an existing valid node as a fixture.
	var first: String = str(app.run_state.nodes.keys()[0])
	app.run_state.nodes[first].type = kind
	return first

func _enter_fixture(kind: String) -> void:
	var id := _node_of_type(kind)
	app.run_state.available = [id]
	app._enter_node(id)
	await _settle()
	check(app.run_state.phase == kind and app.save_error.is_empty(), "Valid checkpoint opens the " + kind + " fixture")

func _new_run(lives: int = 3) -> void:
	app._commit_run()
	if lives != 3:
		app.run_state.lives = lives
		app._return_menu()
		app._continue_run()
	await _settle()
	check(not app.run_status.get_hearts().is_animating(), "New and resumed runs initialize hearts without replaying a loss")

func _standalone_hearts() -> void:
	var hearts = LifeHearts.new()
	root.add_child(hearts)
	hearts.position = Vector2(24, 24)
	hearts.size = Vector2(156, 48)
	_record_losses(hearts)
	var heart_texture: AtlasTexture = hearts.get_heart_texture()
	check(heart_texture.region == Rect2(324, 390, 100, 80) and heart_texture.atlas.resource_path == "res://assets/ui/status/settlement_atlas.png", "Heart uses exactly the red-heart region from the supplied atlas")
	check(heart_texture.atlas.get_size() == Vector2(1024, 512) and heart_texture.get_size() == Vector2(100, 80), "Heart atlas and extracted texture keep the source dimensions")
	for value in [0, 1, 2, 3]:
		hearts.set_lives(value)
		check(hearts.get_lives() == value and hearts.get_visible_heart_count() == value and not hearts.is_animating(), "Static life value %d renders that many hearts" % value)
	losses.clear()
	hearts.set_lives(2, true)
	check(hearts.is_animating() and hearts.get_breaking_index() == 2 and losses == [2], "A single loss breaks the rightmost third heart")
	await create_timer(0.12).timeout
	var progress: float = hearts.get_break_progress()
	hearts.set_lives(2, true)
	check(losses == [2] and hearts.get_break_progress() >= progress and progress > 0, "Repeated refresh during a loss does not restart it or reset its progress")
	await _wait_finished(hearts)
	check(hearts.get_visible_heart_count() == 2, "Broken heart disappears after a single loss")
	losses.clear()
	hearts.set_lives(3, true)
	check(not hearts.is_animating() and hearts.get_visible_heart_count() == 3 and losses.is_empty(), "Healing adds a whole heart without a break animation")
	hearts.set_lives(0, true)
	check(hearts.is_animating() and hearts.get_breaking_index() == 2, "Losing all life starts at the rightmost heart")
	await _wait_finished(hearts)
	check(losses == [2, 1, 0] and hearts.get_visible_heart_count() == 0, "Multiple lost lives break each heart from right to left exactly once")
	hearts.set_lives(3)
	losses.clear()
	hearts.set_lives(1, true)
	hearts.cancel_animation()
	var canceled_losses: Array[int] = losses.duplicate()
	await create_timer(0.8).timeout
	check(not hearts.is_animating() and hearts.get_visible_heart_count() == 1 and losses == canceled_losses, "Cancellation applies the final life count and stops queued breaks")
	root.remove_child(hearts)
	hearts.queue_free()
	await process_frame

func _layout_pages() -> void:
	await _new_run()
	check(app.run_status.coin.texture.resource_path == "res://assets/ui/status/shell_coin.png" and app.run_status.coin.texture.get_size() == Vector2(256, 256), "Currency uses the supplied coin texture at its original dimensions")
	_check_status(3, true)
	await _capture("run_status_map")
	var persistent_status = app.run_status
	var persistent_hearts = persistent_status.get_hearts()
	app._select_run_tab("deck")
	await _settle()
	check(app.run_status == persistent_status and app.run_status.get_hearts() == persistent_hearts, "Browser tabs preserve the same status and hearts")
	_check_status(3, true)
	app._select_run_tab("map")
	await _enter_fixture("shop")
	_check_status(3, true)
	var supplied_price_icons := 0
	for price in app.shop_view.get_price_labels():
		for child in price.get_parent().get_children():
			if child is TextureRect and child.texture.resource_path == "res://assets/ui/status/shell_coin.png" and child.size.is_equal_approx(Vector2(32, 32)):
				supplied_price_icons += 1
	check(supplied_price_icons == app.run_state.stock.size(), "Every real shop price uses the supplied coin texture at 32 by 32 pixels")
	await _capture("run_status_shop")
	await _new_run()
	await _enter_fixture("event")
	_check_status(3)
	await _capture("run_status_event")
	await _new_run()
	await _enter_fixture("rest")
	_check_status(3)
	await _new_run()
	await _enter_fixture("battle")
	_check_status(3)
	var battle_rect: Rect2 = app.battle_view.get_run_status_rect()
	check(app.run_status.position.is_equal_approx(app.battle_view.position + battle_rect.position) and app.run_status.size.is_equal_approx(battle_rect.size), "Battle resources occupy their reserved compact player-panel row")
	await _capture("run_status_battle")

func _event_loss_and_resume() -> void:
	await _new_run()
	await _enter_fixture("event")
	app.run_state.event_id = "trade_life"
	app._state_changed()
	await _settle()
	var persistent_status = app.run_status
	var hearts = persistent_status.get_hearts()
	_record_losses(hearts)
	losses.clear()
	app._event_choice(0)
	check(app.run_state.lives == 2 and app.save_error.is_empty(), "Real life-trade event pays one life and checkpoints its reward")
	check(app.run_status == persistent_status and hearts.is_animating() and losses == [2], "Event page transition preserves the rightmost-heart break")
	await create_timer(0.25).timeout
	await _capture("run_status_heart_break")
	var before := _snapshot()
	app._render()
	app._render()
	check(app.run_status == persistent_status and losses == [2], "Repeated page refresh preserves the animation without replay")
	await _wait_finished(hearts)
	check(losses == [2] and _snapshot() == before, "Completing a visual heart loss does not mutate exploration, combat, RNG, or save")
	_check_status(2, app.run_state.phase == "rewards")
	app._return_menu()
	check(not persistent_status.is_visible_in_tree() and not hearts.is_animating(), "Main menu hides exploration status")
	app._continue_run()
	await _settle()
	check(app.run_state.lives == 2 and not hearts.is_animating() and losses == [2], "Continue displays saved lives without replaying the completed loss")
	# Restore in a fresh app too: the persisted life value has no previous display baseline.
	await _drop_app()
	app = _new_app()
	app._continue_run()
	await _settle()
	_record_losses(app.run_status.get_hearts())
	losses.clear()
	_check_status(2, app.run_state.phase == "rewards")
	check(losses.is_empty(), "Fresh-app save restoration never invents a heart-loss animation")

func _rest_recovery() -> void:
	await _new_run(2)
	await _enter_fixture("rest")
	var hearts = app.run_status.get_hearts()
	_record_losses(hearts)
	losses.clear()
	check(app.run_state.rest_heal(), "Real rest recovers one exploration life")
	app._state_changed()
	await _settle()
	_check_status(3, true)
	check(losses.is_empty() and app.save_error.is_empty(), "Rest recovery adds a whole heart without breaking or save error")

func _battle_loss(kind: String, initial_lives: int) -> void:
	await _new_run(initial_lives)
	await _enter_fixture(kind)
	var status = app.run_status
	var hearts = status.get_hearts()
	_record_losses(hearts)
	losses.clear()
	# End a genuine combat through the normal enemy-turn action.
	var battle = app.combat
	battle.phase = "play"
	battle.hp = 1
	battle.guard = 0
	battle.intent = {"type": "attack", "damage": 1, "hits": 1}
	app._end_turn()
	var waits := 0
	while losses.is_empty() and waits < 80:
		await create_timer(0.025).timeout
		waits += 1
	var expected := 0 if kind == "boss" else maxi(0, initial_lives - 1)
	check(battle.result == "defeat" and app.run_state.lives == expected and app.save_error.is_empty(), "Real %s defeat applies the expected exploration life cost" % kind)
	check(app.run_status == status and hearts.is_animating() and not losses.is_empty() and losses[0] == initial_lives - 1, "Battle transition keeps the existing rightmost-heart break visible")
	var before := _snapshot()
	await _wait_finished(hearts)
	var expected_losses: Array[int] = []
	for index in range(initial_lives - 1, expected - 1, -1):
		expected_losses.append(index)
	check(losses == expected_losses and hearts.get_visible_heart_count() == expected, "Defeat breaks exactly its lost hearts in descending order")
	check(_snapshot() == before, "Defeat animation does not write a second reward, history record, or save")
	_check_status(expected, app.run_state.phase in ["rewards", "map"])
	if expected == 0:
		check(app.run_state.phase == "ended" and app.run_state.outcome == "defeat" and not app.store.has_active(), "Final heart loss finishes and leaves only the defeat summary")
		await _capture("run_status_zero_hearts")

func _interruption() -> void:
	await _new_run()
	await _enter_fixture("event")
	app.run_state.event_id = "trade_life"
	app._state_changed()
	var hearts = app.run_status.get_hearts()
	_record_losses(hearts)
	losses.clear()
	app._event_choice(0)
	check(hearts.is_animating(), "Interruption fixture starts a real event life loss")
	app._return_menu()
	var before := _snapshot()
	var canceled: Array[int] = losses.duplicate()
	await create_timer(0.8).timeout
	check(not app.run_status.is_visible_in_tree() and not hearts.is_animating() and losses == canceled and _snapshot() == before, "Returning to menu cancels queued animation without stale actions")
	app._continue_run()
	await _settle()
	_check_status(2, app.run_state.phase == "rewards")
	check(losses == canceled and not hearts.is_animating(), "Resuming an interrupted visual loss initializes the saved heart count")
	app.run_state.lives = 1
	app._state_changed()
	check(hearts.is_animating(), "Replacement fixture has a pending life loss")
	app._commit_run()
	await _settle()
	_check_status(3, true)
	check(not hearts.is_animating(), "A new run cancels the old run's pending loss and initializes three whole hearts")

func _drop_app() -> void:
	root.remove_child(app)
	app.queue_free()
	await process_frame
	app = null

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await _standalone_hearts()
	for dimensions in RESOLUTIONS:
		dimensions_label = "%dx%d" % [dimensions.x, dimensions.y]
		_clean()
		root.size = dimensions
		await _settle()
		app = _new_app()
		await _settle()
		await _layout_pages()
		await _drop_app()
	_clean()
	root.size = Vector2i(1280, 720)
	dimensions_label = "1280x720"
	await _settle()
	app = _new_app()
	await _event_loss_and_resume()
	await _rest_recovery()
	await _battle_loss("battle", 3)
	await _battle_loss("battle", 1)
	await _battle_loss("boss", 3)
	await _interruption()
	await _drop_app()
	_clean()
	print("V2_RUN_STATUS: %d checks, %d failures; hearts, currency, four sizes, event/rest/battle/boss, persistence, animation/lifecycle" % [checks, failures])
	quit(0 if failures == 0 else 1)
