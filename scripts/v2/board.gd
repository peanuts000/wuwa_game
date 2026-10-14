extends RefCounted

# Rainbows use their own kind unless a swap supplies a target for that piece UID.
# Only a paused version-1 save still needs its already-started rainbow choice.
const SIZE = 8
var rng := RandomNumberGenerator.new()
var kinds: Array = []
var cells: Array = []
var serial := 0
var resolving := false
var pending_rainbow := false
var legacy_rainbow_choice := false
var rainbow_targets: Dictionary = {}
var queue: Array = []
var action_yields: Dictionary = {}
var cascades := 0
var reshuffled := false
var preferred: Array = []

func to_snapshot() -> Dictionary:
	return {
		"version": 2, "rng": {"seed": rng.seed, "state": rng.state},
		"kinds": kinds.duplicate(), "cells": cells.duplicate(true), "serial": serial,
		"resolving": resolving, "pending_rainbow": pending_rainbow,
		"legacy_rainbow_choice": legacy_rainbow_choice, "rainbow_targets": rainbow_targets.duplicate(),
		"queue": queue.duplicate(), "action_yields": action_yields.duplicate(),
		"cascades": cascades, "reshuffled": reshuffled, "preferred": preferred.duplicate()
	}

func restore_snapshot(snapshot: Dictionary) -> Error:
	# Validate everything before changing the live model.
	if typeof(snapshot.get("version")) != TYPE_INT or snapshot.get("version") not in [1, 2] or not _valid_rng(snapshot.get("rng")):
		return ERR_INVALID_DATA
	var legacy_choice := false
	var targets: Dictionary = {}
	if snapshot.version == 2:
		if typeof(snapshot.get("legacy_rainbow_choice")) != TYPE_BOOL or typeof(snapshot.get("rainbow_targets")) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		legacy_choice = snapshot.legacy_rainbow_choice
		targets = snapshot.rainbow_targets
		if legacy_choice != snapshot.get("pending_rainbow"):
			return ERR_INVALID_DATA
	for key in ["kinds", "cells", "queue", "preferred"]:
		if typeof(snapshot.get(key)) != TYPE_ARRAY:
			return ERR_INVALID_DATA
	for key in ["resolving", "pending_rainbow", "reshuffled"]:
		if typeof(snapshot.get(key)) != TYPE_BOOL:
			return ERR_INVALID_DATA
	if snapshot.version == 1:
		legacy_choice = snapshot.pending_rainbow
	for key in ["serial", "cascades"]:
		if typeof(snapshot.get(key)) != TYPE_INT or snapshot[key] < 0:
			return ERR_INVALID_DATA
	var saved_kinds: Array = snapshot.kinds
	if saved_kinds.size() != 6 or not "star" in saved_kinds or not "guard" in saved_kinds:
		return ERR_INVALID_DATA
	var unique_kinds: Dictionary = {}
	for kind in saved_kinds:
		if typeof(kind) != TYPE_STRING or kind not in ["condensation", "thermal", "conductive", "aero", "diffraction", "annihilation", "star", "guard"] or unique_kinds.has(kind):
			return ERR_INVALID_DATA
		unique_kinds[kind] = true
	if snapshot.cells.size() != SIZE * SIZE or (snapshot.pending_rainbow and not snapshot.resolving):
		return ERR_INVALID_DATA
	if not snapshot.resolving and (not snapshot.queue.is_empty() or snapshot.pending_rainbow):
		return ERR_INVALID_DATA
	var seen: Dictionary = {}
	var rainbow_uids: Dictionary = {}
	for cell in snapshot.cells:
		if cell == null:
			if not snapshot.resolving:
				return ERR_INVALID_DATA
			continue
		if typeof(cell) != TYPE_DICTIONARY or typeof(cell.get("uid")) != TYPE_INT or cell.uid <= 0 or cell.uid > snapshot.serial or seen.has(cell.uid):
			return ERR_INVALID_DATA
		if cell.get("kind") not in saved_kinds or cell.get("special") not in ["", "stripe", "bomb", "rainbow"] or cell.get("axis") not in ["h", "v"]:
			return ERR_INVALID_DATA
		seen[cell.uid] = true
		if cell.special == "rainbow":
			rainbow_uids[cell.uid] = true
	if not snapshot.resolving and not targets.is_empty():
		return ERR_INVALID_DATA
	for uid in targets:
		if typeof(uid) != TYPE_INT or not rainbow_uids.has(uid) or typeof(targets[uid]) != TYPE_STRING or targets[uid] not in saved_kinds:
			return ERR_INVALID_DATA
	for key in ["queue", "preferred"]:
		for index in snapshot[key]:
			if typeof(index) != TYPE_INT or index < 0 or index >= SIZE * SIZE:
				return ERR_INVALID_DATA
	if typeof(snapshot.get("action_yields")) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	for kind in snapshot.action_yields:
		if kind not in saved_kinds or typeof(snapshot.action_yields[kind]) != TYPE_INT or snapshot.action_yields[kind] < 0:
			return ERR_INVALID_DATA
	rng.seed = snapshot.rng.seed
	rng.state = snapshot.rng.state
	for key in ["kinds", "cells", "queue", "preferred", "action_yields"]:
		set(key, snapshot[key].duplicate(true))
	for key in ["serial", "resolving", "pending_rainbow", "cascades", "reshuffled"]:
		set(key, snapshot[key])
	legacy_rainbow_choice = legacy_choice
	rainbow_targets = targets.duplicate()
	return OK

func _valid_rng(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY and typeof(value.get("seed")) == TYPE_INT and typeof(value.get("state")) == TYPE_INT

func setup(attributes: Array, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	kinds = attributes.duplicate()
	kinds.append_array(["star", "guard"])
	generate()

func piece(kind: String, special: String = "", axis: String = "h") -> Dictionary:
	serial += 1
	return {"uid": serial, "kind": kind, "special": special, "axis": axis}

func generate() -> void:
	cells.clear()
	for i in range(SIZE * SIZE):
		var options: Array = kinds.duplicate()
		if i % SIZE >= 2 and cells[i-1].kind == cells[i-2].kind:
			options.erase(cells[i-1].kind)
		if i >= SIZE * 2 and cells[i-SIZE].kind == cells[i-SIZE*2].kind:
			options.erase(cells[i-SIZE].kind)
		cells.append(piece(options[rng.randi_range(0, options.size()-1)]))
	if not has_action():
		generate()

func adjacent(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and a < 64 and b < 64 and absi(a % SIZE - b % SIZE) + absi(a / SIZE - b / SIZE) == 1

func matches() -> Array:
	var runs: Array = []
	for axis in ["h", "v"]:
		for line in range(SIZE):
			var streak: Array = []
			var last := ""
			for pos in range(SIZE + 1):
				var idx: int = line * SIZE + pos if axis == "h" else pos * SIZE + line
				var kind: String = cells[idx].kind if pos < SIZE and cells[idx] != null else ""
				if kind != last or kind == "":
					if streak.size() >= 3:
						runs.append({"indices": streak.duplicate(), "axis": axis})
					streak.clear()
				if kind != "":
					streak.append(idx)
				last = kind
	return runs

func _swap(a: int, b: int) -> void:
	var temp: Variant = cells[a]
	cells[a] = cells[b]
	cells[b] = temp

func legal_swap(a: int, b: int) -> bool:
	if not adjacent(a, b):
		return false
	if cells[a].special != "" or cells[b].special != "":
		return true
	_swap(a, b)
	var valid: bool = not matches().is_empty()
	_swap(a, b)
	return valid

func has_action() -> bool:
	for cell in cells:
		if cell != null and cell.special != "":
			return true
	return not hint().is_empty()

func hint() -> Array:
	for i in range(cells.size()):
		if cells[i] != null and cells[i].special != "":
			return [i]
	for i in range(cells.size()):
		for j in [i+1 if i % SIZE < SIZE-1 else -1, i+SIZE]:
			if j >= 0 and j < cells.size() and legal_swap(i, j):
				return [i, j]
	return []

func _begin() -> void:
	resolving = true
	pending_rainbow = false
	legacy_rainbow_choice = false
	rainbow_targets.clear()
	action_yields.clear()
	queue.clear()
	cascades = 0
	reshuffled = false

func start_swap(a: int, b: int) -> bool:
	if resolving or not legal_swap(a, b):
		return false
	_begin()
	if cells[a].special == "rainbow":
		rainbow_targets[cells[a].uid] = cells[b].kind
	if cells[b].special == "rainbow":
		rainbow_targets[cells[b].uid] = cells[a].kind
	_swap(a, b)
	preferred = [b, a]
	for i in [a, b]:
		if cells[i].special != "":
			queue.append(i)
	if queue.is_empty():
		_queue_matches(matches())
	return true

func start_activate(index: int) -> bool:
	if resolving or index < 0 or index >= cells.size() or cells[index].special == "":
		return false
	_begin()
	preferred.clear()
	queue.append(index)
	return true

func _queue_matches(runs: Array) -> void:
	if runs.is_empty():
		return
	cascades += 1
	var groups: Array = []
	for run in runs:
		var group: Dictionary = {"indices": run.indices.duplicate(), "runs": [run]}
		var changed := true
		while changed:
			changed = false
			for n in range(groups.size()-1, -1, -1):
				var overlaps := false
				for idx in groups[n].indices:
					if idx in group.indices:
						overlaps = true
						break
				if overlaps:
					for idx in groups[n].indices:
						if idx not in group.indices:
							group.indices.append(idx)
					group.runs.append_array(groups[n].runs)
					groups.remove_at(n)
					changed = true
		groups.append(group)
	for group in groups:
		var axes: Dictionary = {}
		var longest := 0
		var axis := "h"
		for run in group.runs:
			axes[run.axis] = true
			if run.indices.size() > longest:
				longest = run.indices.size()
				axis = run.axis
		var special: String = "bomb" if axes.size() > 1 else ("rainbow" if longest >= 5 else ("stripe" if longest == 4 else ""))
		var anchor := -1
		if special != "":
			var candidates: Array = preferred.duplicate()
			candidates.append_array(group.indices)
			for idx in candidates:
				if idx in group.indices and cells[idx].special == "":
					anchor = idx
					break
			if anchor >= 0:
				cells[anchor].special = special
				cells[anchor].axis = axis
		for idx in group.indices:
			if idx != anchor:
				queue.append(idx)
	preferred.clear()

func choose_rainbow(kind: String) -> bool:
	if not pending_rainbow or not legacy_rainbow_choice or kind not in kinds:
		return false
	pending_rainbow = false
	legacy_rainbow_choice = false
	for i in range(cells.size()):
		if cells[i] != null and cells[i].kind == kind:
			queue.append(i)
	return true

func advance() -> Dictionary:
	var gained: Dictionary = {}
	var removed: Array = []
	if not resolving or pending_rainbow:
		return {"gained": gained, "removed": removed}
	while not queue.is_empty():
		var idx: int = queue.pop_front()
		if cells[idx] == null:
			continue
		var cell: Dictionary = cells[idx]
		var rainbow_kind: String = rainbow_targets.get(cell.uid, cell.kind)
		rainbow_targets.erase(cell.uid)
		cells[idx] = null
		removed.append(idx)
		gained[cell.kind] = int(gained.get(cell.kind, 0)) + 1
		action_yields[cell.kind] = int(action_yields.get(cell.kind, 0)) + 1
		match cell.special:
			"stripe":
				for p in range(SIZE):
					queue.append((idx / SIZE) * SIZE + p if cell.axis == "h" else p * SIZE + idx % SIZE)
			"bomb":
				for y in range(maxi(0, idx / SIZE - 1), mini(SIZE, idx / SIZE + 2)):
					for x in range(maxi(0, idx % SIZE - 1), mini(SIZE, idx % SIZE + 2)):
						queue.append(y * SIZE + x)
			"rainbow":
				for i in range(cells.size()):
					if cells[i] != null and cells[i].kind == rainbow_kind:
						queue.append(i)
	if not removed.is_empty():
		return {"gained": gained, "removed": removed}
	for x in range(SIZE):
		var column: Array = []
		for y in range(SIZE-1, -1, -1):
			if cells[y*SIZE+x] != null:
				column.append(cells[y*SIZE+x])
		for y in range(SIZE-1, -1, -1):
			var pos: int = SIZE-1-y
			cells[y*SIZE+x] = column[pos] if pos < column.size() else piece(kinds[rng.randi_range(0, kinds.size()-1)])
	var runs: Array = matches()
	if not runs.is_empty():
		_queue_matches(runs)
	else:
		resolving = false
		if not has_action():
			reshuffled = true
			generate()
	return {"gained": gained, "removed": removed}
