extends SceneTree

const Combat = preload("res://scripts/v2/combat.gd")
const HandView = preload("res://scripts/v2/hand_view.gd")
const CardView = preload("res://scripts/v2/card_view.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CARD_FACE: " + message)

func _run() -> void:
	var battle = Combat.new()
	battle.phase = "play"
	battle.enemy_hp = 999
	for kind in battle.catalog.ATTRIBUTES:
		battle.mana[kind] = 20
	battle.hand = [{"id": "g01", "uid": 1, "upgraded": false},
		{"id": "c04", "uid": 2, "upgraded": false},
		{"id": "g06", "uid": 3, "upgraded": false},
		{"id": "c02", "uid": 4, "upgraded": false},
		{"id": "c06", "uid": 5, "upgraded": true}]
	var hand = HandView.new()
	hand.size = Vector2(800, 300)
	hand.configure(battle.catalog, battle)
	root.add_child(hand)
	hand.update_hand(battle.hand, func(_uid): return true)
	await process_frame
	check(hand.get_card_view(2)._effect.text.contains("造成 6 点伤害。"), "Initial damage is calculated inside the description")
	check(battle.play_card(0), "Attack buff is playable")
	hand.update_hand(battle.hand, func(_uid): return true)
	check(hand.get_card_view(2)._effect.text.contains("造成 10 点伤害。"), "Description damage refreshes after attack and sequence change")
	var old_hp: int = battle.enemy_hp
	check(battle.play_card(0) and old_hp - battle.enemy_hp == 10, "Displayed damage equals real resolution")
	check(battle.play_card(0), "Guard buff is playable")
	hand.update_hand(battle.hand, func(_uid): return true)
	check(hand.get_card_view(4)._effect.text.contains("获得 8 格挡。"), "Description guard preview includes the pending guard buff")
	check(hand.get_card_view(5)._effect.text.contains("造成 20 点伤害。"), "Upgraded description uses buffed attack")
	var cost_badge: Control = hand.get_card_view(5)._cost_row.get_child(0)
	check(cost_badge.get_child(1).text == "1", "Upgrade changes the actual cost overlay")
	var before: Dictionary = battle.to_snapshot()
	battle.card_values({"id": "g07", "uid": 9, "upgraded": true})
	check(before == battle.to_snapshot(), "Preview does not consume resources or change battle state")
	battle.level = 4
	battle.guard = 7
	battle.next_damage = 0.75
	battle.relics = ["r04"]
	hand.update_hand(battle.hand, func(_uid): return true)
	check(hand.get_card_view(5)._effect.text.contains("造成 38 点伤害。"), "Description combines level, next damage, relic and guard conditions with ceiling rounding")
	check(is_equal_approx(battle.card_values({"id": "g02", "upgraded": false}).extra_damage, 8.25), "Deferred damage retains fractional precision until the next attack")
	hand.dispose()
	hand.queue_free()
	await process_frame
	# A compound cost fixture checks the layout even though the current catalog
	# contains only single-attribute cards.
	var catalog = battle.catalog
	catalog.cards.c01.cost = {"condensation": 2, "thermal": 3}
	var face = CardView.new()
	face.configure(catalog, {"id": "c01", "uid": 10, "upgraded": false}, battle)
	root.add_child(face)
	await process_frame
	await process_frame
	var first: Control = face._cost_row.get_child(0)
	var second: Control = face._cost_row.get_child(1)
	check(second.position.y >= first.position.y + first.size.y, "Costs stack downward")
	check(first.get_child(0).get_rect().is_equal_approx(first.get_child(1).get_rect()), "Number overlays the entire ball texture")
	check(face._cost_row.position.x < 10 and face._cost_row.position.y < 10, "Cost column is in the upper left")
	check(face._title.position.y < 15 and face._title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Card name is centered in the top heading")
	check(face._title.position.x >= 40 and face._title.get_rect().end.x <= CardView.CARD_SIZE.x - 8, "Starlit title sits inside its plate to the right of the fixed cost rail")
	check(not face._title.get_rect().intersects(face._cost_row.get_rect()), "Top heading and stacked costs do not overlap")
	check(face.paper_style, "Shared card faces default to the same paper artwork as battle")
	for count in [0, 1, 2, 3, 6]:
		var costs := {}
		for i in range(count):
			costs[catalog.ATTRIBUTES[i]] = i + 1
		catalog.cards.c01.cost = costs
		face.configure(catalog, {"id": "c01", "uid": 10, "upgraded": false}, battle)
		await process_frame
		await process_frame
		check(face._cost_row.get_child_count() == count, "Every attribute has exactly one cost badge")
		var previous_bottom := 0.0
		for i in range(count):
			var badge: Control = face._cost_row.get_child(i)
			var icon: Control = badge.get_child(0)
			var number: Label = badge.get_child(1)
			check(badge.position.y >= previous_bottom and is_zero_approx(badge.position.x), "Costs align vertically without overlap")
			check(icon.get_rect().is_equal_approx(number.get_rect()) and number.text == str(i + 1), "Each amount directly overlays its own attribute icon")
			var badge_rect := Rect2(face._cost_row.position + badge.position, badge.size)
			check(Rect2(Vector2.ZERO, CardView.CARD_SIZE).encloses(badge_rect), "Up to six attribute costs stay within card")
			if count > 2:
				check(not badge_rect.intersects(face._effect.get_rect()) and not badge_rect.intersects(face._type_label.get_rect()), "Extended cost rail never covers description or category")
			previous_bottom = badge.position.y + badge.size.y
	catalog.cards.c01.cost = {"condensation": 2, "thermal": 3}
	var attack_ids := ["c01", "c03", "c04", "c05", "c06", "g03", "g04", "g07", "g08", "g11", "g12"]
	for id in catalog.cards:
		for upgraded in [false, true]:
			face.configure(catalog, {"id": id, "uid": 10, "upgraded": upgraded}, battle)
			var expected_type := "攻击" if id in attack_ids else "技能"
			check(face._type == expected_type and face._type_label.text == expected_type, "Card %s has one exact category tag%s" % [id, " after upgrade" if upgraded else ""])
			check(face._title.text == str(catalog.cards[id].name) + (" +" if upgraded else ""), "Top heading retains the card name and upgrade marker")
			check(not face._effect.text.contains("A"), "Card %s describes calculated values without damage formulas" % id)
			await process_frame
			check(face._effect.get_rect().end.y <= 198, "Card %s description stays inside the Starlit paper area" % id)
	# The current catalog has no battle-long card. Check the ability label with
	# an isolated content fixture without changing any existing card's duration.
	catalog.cards["test_ability"] = {"id": "test_ability", "name": "能力示例", "type": "ability", "cost": {}, "effect": "本场战斗持续生效。"}
	face.configure(catalog, {"id": "test_ability", "uid": 99, "upgraded": false}, battle)
	check(face._type == "能力" and face._type_label.text == "能力", "Battle-long cards support a single ability label")
	catalog.cards.erase("test_ability")
	face.queue_free()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1000, 540)
		root.content_scale_size = Vector2i(1000, 540)
		var background := ColorRect.new()
		background.color = Color("101b2a")
		background.size = Vector2(1000, 540)
		root.add_child(background)
		var examples := ["c01", "c06", "c04", "c02", "g06", "g01"]
		for i in range(examples.size()):
			var sample = CardView.new()
			sample.configure(catalog, {"id": examples[i], "uid": 20 + i, "upgraded": i == 1}, battle)
			sample.set_available(true)
			sample.position = Vector2(25 + (i % 3) * 325, 20 + (i / 3) * 255)
			sample.scale = Vector2.ONE * 1.12
			root.add_child(sample)
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://tests/artifacts/v2_card_face.png") == OK, "Card preview captured")
	print("V2_CARD_FACE: %d failures; live descriptions, real resolution, pure preview, upper-left costs, top names and single category tags" % failures)
	quit(0 if failures == 0 else 1)
