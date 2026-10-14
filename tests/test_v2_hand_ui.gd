extends SceneTree

const FIXTURE := "res://tests/artifacts/hand_ui_save.cfg"
var failures := 0
var submissions: Array[int] = []
var app
var hand

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("HAND_UI: " + message)

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".corrupt"]:
		var path: String = FIXTURE + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame

func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _resting_point(uid: int, relative: Vector2 = Vector2(-45, 45)) -> Vector2:
	var local: Vector2 = hand._home_transforms[uid] * relative
	return hand.get_global_transform_with_canvas() * local

func _visible_point(uid: int) -> Vector2:
	return hand.get_card_view(uid).get_global_transform_with_canvas() * Vector2(75, 105)

func _has_card_detail_popup(node: Node, card_name: String, card_text: String, in_popup: bool = false) -> bool:
	var popup := in_popup or (node is Window and node != root)
	if popup and node is Label and node.is_visible_in_tree():
		if node.text == card_text or node.text.contains(card_name):
			return true
	for child in node.get_children(true):
		if _has_card_detail_popup(child, card_name, card_text, popup):
			return true
	return false

func _set_hand(cards: Array) -> void:
	app.combat.hand = cards.duplicate(true)
	app.battle_view.refresh()
	await create_timer(0.22).timeout

func _actual_top() -> float:
	var top := INF
	for uid in hand._order:
		var view: Control = hand.get_card_view(uid)
		for corner in [Vector2.ZERO, Vector2(150, 0), Vector2(150, 210), Vector2(0, 210)]:
			var point: Vector2 = view.get_global_transform() * corner
			top = minf(top, point.y)
	return top

func _test_collapsed(cards: Array) -> void:
	var baseline := submissions.size()
	app.combat.phase = "play"
	await _set_hand(cards.slice(0, 5))
	_check(not hand.is_collapsed(), "The play phase expands the real hand")
	_check(is_equal_approx(hand.get_expanded_top(), _actual_top()), "Expanded top includes the exact fan rotation")
	var expanded_y: float = hand.get_card_view(101).position.y
	var predicted_top: float = hand.get_expanded_top()
	hand.set_locked(true)
	await create_timer(0.2).timeout
	_check(not hand.is_collapsed(), "A play-animation lock does not collapse the hand")
	_check(is_equal_approx(hand.get_card_view(101).position.y, expanded_y), "A locked play-phase hand stays expanded")
	hand.set_locked(false)
	# Collapse with a playable model to verify this interface independently blocks input.
	hand.set_collapsed(true)
	_check(hand.get_card_view(101).position.y < hand.size.y - 28, "Collapse starts a tween instead of jumping to its target")
	await create_timer(0.26).timeout
	_check(hand.is_collapsed(), "The public collapsed state is readable")
	_check(is_equal_approx(hand.get_expanded_top(), predicted_top), "Expanded-top prediction is independent of collapsed state")
	_check(is_equal_approx(hand.get_collapsed_top(), _actual_top()), "Collapsed top matches the visible card edge")
	_check(is_equal_approx(hand.get_collapsed_top(), hand.get_global_rect().end.y - 28), "Only 28 pixels peek above the hand's bottom edge")
	var view: Control = hand.get_card_view(101)
	var tucked_y: float = view.position.y
	var peek: Vector2 = view.get_global_transform_with_canvas() * Vector2(75, 12)
	await _motion(peek)
	hand._on_hover(101)
	hand.request_play(101)
	view.activation_requested.emit(101)
	await _button(peek, true)
	await _motion(hand._play_zone.get_center())
	await _button(hand._play_zone.get_center(), false)
	await create_timer(0.2).timeout
	_check(submissions.size() == baseline, "Collapsed cards reject click, drag, direct and keyboard requests")
	_check(hand._hovered_uid == -1 and not hand._dragged, "Collapsed cards never raise or begin a drag")
	_check(is_equal_approx(view.position.y, tucked_y), "Collapsed hover leaves the card tucked")
	_check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.focus_mode == Control.FOCUS_NONE, "Collapsed cards cannot capture pointer or keyboard focus")
	hand.set_collapsed(false)
	_check(view.position.y > expanded_y, "Expansion starts from the current tucked position")
	await create_timer(0.26).timeout
	_check(is_equal_approx(view.position.y, expanded_y), "Expansion returns to the normal fan")
	_check(view.mouse_filter == Control.MOUSE_FILTER_STOP and view.focus_mode == Control.FOCUS_ALL, "Expansion restores card interactions")
	await _motion(_resting_point(101))
	await create_timer(0.2).timeout
	_check(is_equal_approx(view.position.y, expanded_y - 60), "Hover raising works again after expansion")
	await _button(_visible_point(101), true)
	await _motion(hand._play_zone.get_center())
	_check(hand._dragged, "The expanded hand permits a drag")
	hand.set_collapsed(true)
	hand.set_collapsed(false)
	await _button(hand._play_zone.get_center(), false)
	_check(submissions.size() == baseline, "Collapsing during a drag prevents a stale release from playing")
	_check(hand._pressed_uid == -1 and not hand._dragged, "Collapse cancels pending drag state immediately")
	for iteration in range(10):
		hand.set_collapsed(iteration % 2 == 0)
	await create_timer(0.26).timeout
	_check(not hand.is_collapsed() and is_equal_approx(view.position.y, expanded_y), "Rapid toggles settle at the latest state")
	for phase in ["board", "resolving", "enemy"]:
		app.combat.phase = phase
		await _set_hand(cards.slice(0, 5))
		_check(hand.is_collapsed(), "The %s phase collapses through BattleView" % phase)
		await _motion(_resting_point(101))
		_check(hand._hovered_uid == -1, "The %s phase cannot hover a card" % phase)
	for count in range(11):
		await _set_hand(cards.slice(0, count))
		_check(hand.is_collapsed() and hand._views.size() == count, "The collapsed hand supports %d cards" % count)
		if count > 0:
			_check(is_equal_approx(_actual_top(), hand.get_global_rect().end.y - 28), "A %d-card collapsed hand exposes only the top strip" % count)
		else:
			_check(is_equal_approx(hand.get_collapsed_top(), hand.get_global_rect().end.y), "An empty collapsed hand reserves no card height")
	app.combat.phase = "play"
	await _set_hand([])
	_check(not hand.is_collapsed() and hand._views.is_empty(), "An empty hand expands safely into the play phase")
	await _set_hand(cards.slice(0, 5))
	hand.set_collapsed(true)
	await process_frame
	var paused_y: float = hand.get_card_view(101).position.y
	hand.dispose()
	await create_timer(0.26).timeout
	_check(is_equal_approx(hand.get_card_view(101).position.y, paused_y), "Dispose terminates an in-flight collapse tween")
	_check(hand._tweens.is_empty() and hand._departure_tweens.is_empty(), "Dispose stops tracked layout and departure animations")
	hand.set_collapsed(false)
	hand.request_play(101)
	_check(hand.is_collapsed() and submissions.size() == baseline, "Disposed controls cannot be reactivated by late calls")

func _run() -> void:
	_cleanup()
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path = FIXTURE
	app.legacy_save_path = "res://tests/artifacts/hand_ui_legacy_missing.cfg"
	app.apply_display_settings = false
	root.add_child(app)
	await process_frame
	app._start_run()
	app._enter_node(app.run_state.available[0])
	await process_frame
	hand = app.battle_view.hand_view
	# Count view intent in isolation: this test never writes manipulated combat state.
	for connection in hand.play_requested.get_connections():
		hand.play_requested.disconnect(connection.callable)
	hand.play_requested.connect(func(uid: int): submissions.append(uid))
	app.combat.phase = "play"
	for kind in app.catalog.ATTRIBUTES:
		app.combat.mana[kind] = 20
	var cards: Array = []
	for i in range(10):
		cards.append({"id": "c01", "uid": 101 + i, "upgraded": false})
	cards[1] = {"id": "g06", "uid": 102, "upgraded": true}
	await _set_hand(cards.slice(0, 5))
	var resting: Vector2 = hand.get_card_view(101).position
	var playable = hand.get_card_view(101)
	_check(playable.available and playable.tooltip_text.is_empty(), "A playable card has no detail tooltip")
	_check(playable.full_text == app.catalog.card_text(cards[0]), "The internal full card text remains available")
	await _motion(_resting_point(101))
	await create_timer(0.65).timeout
	_check(is_equal_approx(hand.get_card_view(101).position.y, resting.y - 60), "Hover raises the real card by 60")
	_check(is_equal_approx(hand.get_card_view(101).scale.x, 1.12), "Hover enlarges the real card")
	_check(playable.tooltip_text.is_empty() and not _has_card_detail_popup(root, app.catalog.cards.c01.name, playable.full_text), "Real hover produces no card-name or effect popup")
	# Move the pointer where the card rested; lifting must not toggle hover repeatedly.
	await _motion(_resting_point(101))
	await create_timer(0.2).timeout
	_check(hand._hovered_uid == 101, "Hover remains stable after raising")
	var pointer := _visible_point(101)
	await _button(pointer, true)
	await _button(pointer, false)
	_check(submissions == [101], "Click submits exactly one uid")
	await _motion(_resting_point(101))
	await create_timer(0.2).timeout
	pointer = _visible_point(101)
	await _button(pointer, true)
	var drop: Vector2 = hand._play_zone.get_center()
	await _motion(drop)
	_check(hand._dragged, "Mouse movement starts a real drag")
	await _button(drop, false)
	_check(submissions == [101, 101], "A valid drag submits once without a second click")
	await create_timer(0.2).timeout
	await _motion(_resting_point(101))
	await create_timer(0.2).timeout
	pointer = _visible_point(101)
	await _button(pointer, true)
	await _motion(Vector2(30, 30))
	await _button(Vector2(30, 30), false)
	await create_timer(0.2).timeout
	_check(submissions.size() == 2, "An invalid drop never submits")
	_check(hand._pressed_uid == -1 and not hand._dragged, "An invalid drop cancels drag state")
	_check(is_equal_approx(hand.get_card_view(101).position.y, resting.y), "An invalid drop returns to the fan")
	hand.set_locked(true)
	hand.request_play(101)
	await _button(_visible_point(101), true)
	await _button(_visible_point(101), false)
	_check(submissions.size() == 2, "Input lock blocks both direct requests and mouse clicks")
	hand.set_locked(false)
	await _motion(_resting_point(101))
	await create_timer(0.2).timeout
	await _button(_visible_point(101), true)
	await _motion(drop)
	hand.size.x -= 10
	await process_frame
	_check(hand._pressed_uid == -1 and not hand._dragged, "Resizing cancels an active drag")
	await _button(drop, false)
	_check(submissions.size() == 2, "Release after resizing cannot submit")
	app.battle_view._position_controls()
	var old_view = hand.get_card_view(101)
	hand.set_locked(true)
	await hand.animate_play(101)
	_check(is_zero_approx(old_view.modulate.a), "Play animation fades the played card")
	hand.update_hand(app.combat.hand, app.battle_view._can_play_uid, app.battle_view._unavailable_reason, 101)
	_check(hand.get_card_view(101) != old_view, "Immediately redrawn uid gets a new presentation instance")
	await create_timer(0.22).timeout
	_check(is_equal_approx(hand.get_card_view(101).modulate.a, 1.0), "Redrawn card completes its entry animation")
	hand.set_locked(false)
	app.combat.mana.conductive = 0
	await _set_hand([cards[1]])
	var unavailable = hand.get_card_view(102)
	_check(not unavailable.available, "A real resource shortage disables play")
	var original_y: float = unavailable.position.y
	await _motion(_resting_point(102, Vector2(0, 45)))
	await create_timer(0.2).timeout
	_check(is_equal_approx(unavailable.position.y, original_y - 60), "An unavailable card can still be raised and inspected")
	var text: String = app.catalog.card_text(cards[1])
	_check(unavailable.full_text == text, "An unavailable card retains its internal full text")
	var live_block: int = app.combat.card_values(cards[1]).block
	_check(unavailable._effect.text.contains("获得 %d 格挡" % live_block), "An unavailable card still shows its current guard result on the face")
	_check(unavailable._effect.text.contains("本回合下一张直接获得格挡的牌额外获得 4 格挡。"), "The upgraded next-card guard bonus remains in the description")
	_check(unavailable._effect.position.y + unavailable._effect.size.y <= 210.1, "Long upgraded effect fits inside the visible card")
	_check(unavailable._effect.get_line_count() >= 3, "Long upgraded effect is actually wrapped on the face")
	_check(not unavailable.unavailable_reason.is_empty() and unavailable.tooltip_text == unavailable.unavailable_reason, "Unavailable tooltip contains only the play-blocking reason")
	_check(not unavailable.tooltip_text.contains(unavailable.full_text) and not unavailable.tooltip_text.contains(app.catalog.cards.g06.name) and not unavailable.tooltip_text.contains(unavailable._effect.text), "Unavailable tooltip contains no card name or detailed effect")
	await create_timer(0.65).timeout
	_check(not _has_card_detail_popup(root, app.catalog.cards.g06.name, text), "Unavailable hover never opens a detailed card popup")
	hand.request_play(102)
	_check(submissions.size() == 2, "An unavailable card never submits")
	for amount in unavailable._cost_row.find_children("*", "Label", true, false):
		_check(not amount.text.contains("."), "Cost badges show integer values")
	app.combat.mana.conductive = 20
	for count in range(11):
		await _set_hand(cards.slice(0, count))
		_check(hand._views.size() == count, "The hand supports %d cards" % count)
		for uid in hand._order:
			var view: Control = hand.get_card_view(uid)
			for corner in [Vector2.ZERO, Vector2(150, 0), Vector2(150, 210), Vector2(0, 210)]:
				var point: Vector2 = view.get_transform() * corner
				_check(point.x >= -1 and point.x <= hand.size.x + 1, "A %d-card fan stays inside its horizontal region" % count)
	var attack_ids := ["c01", "c03", "c04", "c05", "c06", "g03", "g04", "g07", "g08", "g11", "g12"]
	for id in app.catalog.cards:
		await _set_hand([{"id": id, "uid": 999, "upgraded": true}])
		var expected_type := "攻击" if id in attack_ids else "技能"
		var classified = hand.get_card_view(999)
		_check(classified._type == expected_type and classified._type_label.text == expected_type, "Upgraded card %s shows one exact category tag" % id)
	await _test_collapsed(cards)
	app.queue_free()
	await process_frame
	_cleanup()
	if failures == 0:
		print("V2_HAND_UI: hover, readable upgrade, click/drag, locks, resize, same-uid refill, 0-10 cards, phase collapse/expand, rapid input, disposal OK")
	quit(0 if failures == 0 else 1)
