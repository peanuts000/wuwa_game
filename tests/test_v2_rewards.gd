extends SceneTree

const Run = preload("res://scripts/v2/run.gd")
const Store = preload("res://scripts/v2/save_store.gd")
const ATTRS = ["condensation", "thermal", "conductive", "aero"]
var checks := 0
var failures := 0
var test_path := ""

func _initialize() -> void:
	test_path = "user://test_v2_rewards_%d.cfg" % Time.get_ticks_usec()
	_test_deferred_drops()
	_test_indexed_claims()
	_test_choices_and_failures()
	_test_persistence()
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	print("V2_REWARDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func reward_run():
	var run_state = Run.new()
	run_state.setup(ATTRS, 20261007)
	run_state.enter_node(run_state.available[0])
	run_state.finish_battle(true)
	run_state.rewards.clear()
	return run_state

func _test_deferred_drops() -> void:
	var run_state = reward_run()
	var initial_shells: int = run_state.shells
	for _drop in range(5):
		run_state.queue_relic()
	check(run_state.relics.is_empty(), "Generating relic rewards does not grant their effects")
	check(run_state.rewards.size() == 5 and run_state.unowned_relics().is_empty(), "Five pending relics reserve the whole pool")
	var ids: Dictionary = {}
	for reward in run_state.rewards:
		check(reward.type == "relic" and not ids.has(reward.id), "Pending relic drops are unique")
		ids[reward.id] = true
	run_state.queue_relic()
	check(run_state.shells == initial_shells + 15 and run_state.rewards.back().type == "notice", "Exhausted pending pool retains the 15-shell conversion")
	var pending_id: String = run_state.rewards[3].id
	check(run_state.accept_reward_at(3, pending_id), "A middle relic can be selected first")
	check(run_state.relics == [pending_id] and run_state.rewards.size() == 5, "Only the clicked relic is granted and removed")
	var before: Dictionary = run_state.to_snapshot()
	check(not run_state.accept_reward_at(3, pending_id) and run_state.to_snapshot() == before, "Stale relic claim cannot grant a second pending item")
	check(run_state.accept_reward_at(0), "An unwanted pending relic can be skipped")
	check(run_state.unowned_relics().size() == 1, "Skipping releases its reservation")

func _test_indexed_claims() -> void:
	var run_state = reward_run()
	run_state.rewards = [
		{"type": "notice", "text": "贝币已结算"},
		{"type": "card", "options": ["c01", "g01"]},
		{"type": "supply", "id": "guard_vial"},
		{"type": "relic", "id": "r02"}
	]
	check(run_state.accept_reward_at(2, "guard_vial"), "Supply is claimable while earlier notice and card remain")
	check(run_state.supplies == ["healing_vial", "guard_vial"] and run_state.rewards.size() == 3, "Supply is added only on claim")
	check(run_state.rewards[0].type == "notice" and run_state.rewards[1].type == "card", "Claiming out of order preserves the other list entries")
	var deck_size: int = run_state.deck.size()
	check(run_state.accept_reward_at(1, "g01") and run_state.deck.size() == deck_size + 1, "Indexed card selection still adds one copy")
	check(run_state.accept_reward_at(1, "r02") and run_state.relics == ["r02"], "Relic can be claimed before acknowledgement notice")
	check(run_state.accept_reward() and run_state.rewards.is_empty(), "Legacy first-item API delegates for notice acknowledgement")
	var before: Dictionary = run_state.to_snapshot()
	check(not run_state.accept_reward_at(0, "r02") and run_state.to_snapshot() == before, "Consumed list cannot be claimed again")
	check(run_state.complete_node(), "Node advances only after the full list is resolved")

func _test_choices_and_failures() -> void:
	var run_state = reward_run()
	run_state.rewards = [
		{"type": "relic", "options": ["r01", "r03"]},
		{"type": "supply", "options": ["guard_vial", "energy_vial"]},
		{"type": "choice", "options": [{"type": "relic", "id": "r05"}, {"type": "supply", "id": "healing_vial"}]}
	]
	check("r01" not in run_state.unowned_relics() and "r03" not in run_state.unowned_relics() and "r05" not in run_state.unowned_relics(), "All same-type and mixed relic alternatives are reserved")
	check(run_state.accept_reward_at(0, "r03") and run_state.relics == ["r03"] and run_state.rewards.size() == 2, "Relic choice consumes the whole group")
	check("r01" in run_state.unowned_relics(), "Unchosen relic option disappears and returns to the pool")
	check(run_state.accept_reward_at(0, "energy_vial") and run_state.supplies == ["healing_vial", "energy_vial"], "Supply choice grants only the clicked option")
	check(run_state.accept_reward_at(0, "r05") and run_state.rewards.is_empty() and "r05" in run_state.relics, "Mixed choice can grant a relic without granting its supply alternative")
	run_state.rewards = [{"type": "choice", "options": [{"type": "relic", "id": "r04"}, {"type": "supply", "id": "guard_vial"}]}]
	check(run_state.accept_reward_at(0, "guard_vial") and "r04" not in run_state.relics, "Mixed choice can grant a supply instead of the relic")
	run_state.rewards = [{"type": "supply", "options": ["healing_vial", "energy_vial"]}]
	var before: Dictionary = run_state.to_snapshot()
	check(not run_state.accept_reward_at(0, "healing_vial") and run_state.to_snapshot() == before, "Full supply slots leave group untouched")
	check(not run_state.accept_reward_at(0, "healing_vial", 3) and run_state.to_snapshot() == before, "Invalid replacement leaves all state unchanged")
	check(run_state.accept_reward_at(0, "healing_vial", 1) and run_state.rewards.is_empty() and run_state.supplies[1] == "healing_vial", "A valid replacement claims the group atomically")
	run_state.rewards = [{"type": "relic", "id": "r03"}]
	before = run_state.to_snapshot()
	check(not run_state.accept_reward_at(0, "r03") and run_state.to_snapshot() == before, "Already-owned relic cannot be duplicated")
	check(not run_state.accept_reward_at(-1, "r03") and not run_state.accept_reward_at(1, "r03") and run_state.to_snapshot() == before, "Invalid reward indexes do not mutate the run")
	check(not run_state.accept_reward_at(0, "unknown_id") and run_state.to_snapshot() == before, "Wrong choice ID does not mutate the run")
	check(run_state.accept_reward_at(0), "Skipping an owned stale relic remains available")
	run_state.rewards = [{"type": "relic", "id": "r04"}]
	run_state.phase = "map"
	before = run_state.to_snapshot()
	check(not run_state.accept_reward_at(0, "r04") and not run_state.accept_reward("r04") and run_state.to_snapshot() == before, "Both APIs reject claims outside rewards phase")
	run_state.phase = "rewards"
	run_state.rewards = [{"type": "relic", "id": "unknown_id"}]
	before = run_state.to_snapshot()
	check(not run_state.accept_reward_at(0, "unknown_id") and not run_state.accept_reward_at(0) and run_state.to_snapshot() == before, "Invalid pending reward cannot change ownership or queue")

func _test_persistence() -> void:
	var run_state = reward_run()
	run_state.rewards = [
		{"type": "notice", "text": "旧版已领取藏品通知"},
		{"type": "card", "options": ["c01", "g02"]},
		{"type": "supply", "id": "healing_vial"},
		{"type": "relic", "id": "r01"},
		{"type": "relic", "options": ["r02", "r03"]},
		{"type": "supply", "options": ["guard_vial", "energy_vial"]},
		{"type": "choice", "options": [{"type": "relic", "id": "r04"}, {"type": "supply", "id": "energy_vial"}]}
	]
	var metadata := {"run_id": "reward-run", "role_id": "condensation_coletta", "started_at": 1791360000}
	var store = Store.new(test_path, test_path + ".missing_legacy")
	check(store.load_store() == OK and store.checkpoint(run_state, null, metadata) == OK, "Save mixed old and new pending reward shapes")
	var reopened = Store.new(test_path, test_path + ".missing_legacy")
	check(reopened.load_store() == OK, "Load pending reward file")
	var restored: Dictionary = reopened.restore_active()
	check(not restored.is_empty() and restored.run.to_snapshot() == run_state.to_snapshot(), "All reward shapes, ordering, and RNG survive disk")
	check(restored.run.relics.is_empty(), "Restoring pending relics does not grant them")
	check(restored.run.accept_reward_at(6, "r04") and store.checkpoint(restored.run, null, metadata) == OK, "Claim and persist a mixed option in the last list row")
	check(reopened.load_store() == OK and "r04" in reopened.restore_active().run.relics and reopened.restore_active().run.rewards.size() == 6, "Claim survives restart without its unchosen option")
	var base: Dictionary = run_state.to_snapshot()
	var invalid_shapes: Array = [
		{"type": "relic", "options": ["r01", "r01"]},
		{"type": "supply", "options": ["guard_vial", "unknown_id"]},
		{"type": "relic", "id": "r01", "options": ["r02"]},
		{"type": "choice", "options": [{"type": "relic", "id": "r01"}, {"type": "relic", "id": "r01"}]},
		{"type": "choice", "options": [{"type": "card", "id": "c01"}]},
		{"type": "choice", "options": []},
		{"type": "supply", "options": ["healing_vial", "guard_vial", "energy_vial", "healing_vial"]}
	]
	for shape in invalid_shapes:
		var bad: Dictionary = base.duplicate(true)
		bad.rewards = [shape]
		var candidate = Run.new()
		check(candidate.restore_snapshot(bad) == ERR_INVALID_DATA, "Invalid option schema is rejected by snapshot restore")
	var old: Dictionary = base.duplicate(true)
	old.relics = ["r05"]
	old.rewards = [{"type": "notice", "text": "获得藏品：旧通知"}]
	var legacy_run = Run.new()
	check(legacy_run.restore_snapshot(old) == OK and legacy_run.accept_reward() and legacy_run.relics == ["r05"], "Old auto-granted notice restores without granting a second copy")
