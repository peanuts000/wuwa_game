extends RefCounted

const Run = preload("res://scripts/v2/run.gd")
const Combat = preload("res://scripts/v2/combat.gd")
const SAVE_VERSION := 1
const CONTENT_VERSION := 1
const STAT_KEYS := ["runs", "wins", "battles_won", "battles_lost"]

var path: String
var legacy_path: String
var data: Dictionary
var load_message := ""
var _writable := true
var _primary_valid := false

func _init(save_path: String = "user://gameplay_v2.cfg", old_path: String = "user://save.cfg") -> void:
	path = save_path
	legacy_path = old_path
	data = _defaults()

func _zero_statistics() -> Dictionary:
	return {"runs": 0, "wins": 0, "battles_won": 0, "battles_lost": 0}

func _defaults() -> Dictionary:
	return {
		"save_version": SAVE_VERSION, "content_version": CONTENT_VERSION,
		"settings": {"fullscreen": false, "resolution": Vector2i(1280, 720)},
		"history": [], "statistics": _zero_statistics(), "legacy_statistics": _zero_statistics(), "active": {}
	}

func load_store() -> Error:
	load_message = ""
	_writable = true
	_primary_valid = false
	var primary_exists := FileAccess.file_exists(path)
	var backup_exists := FileAccess.file_exists(path + ".bak")
	if primary_exists:
		var loaded := _read_file(path)
		if not loaded.is_empty():
			data = loaded
			_primary_valid = true
			return OK
	if backup_exists:
		var backup := _read_file(path + ".bak")
		if not backup.is_empty():
			data = backup
			load_message = "主存档不可用，已从上一次有效备份恢复。"
			return OK
	if primary_exists or backup_exists:
		data = _defaults()
		_writable = false
		load_message = "存档损坏或版本不兼容，无法继续。原存档已保留。"
		return ERR_FILE_CORRUPT
	data = _defaults()
	var legacy := ConfigFile.new()
	if legacy.load(legacy_path) == OK:
		for key in STAT_KEYS:
			var value: Variant = legacy.get_value("gameplay_v2", key, 0)
			if typeof(value) == TYPE_INT and value >= 0:
				data.legacy_statistics[key] = value
				data.statistics[key] = value
	var error := _commit(data)
	if error != OK:
		load_message = "无法创建存档，错误码 %d。" % error
	return error

func has_active() -> bool:
	return not data.active.is_empty() and not _restore_active_value(data.active).is_empty()

func checkpoint(run_state, combat, metadata: Dictionary) -> Error:
	if run_state == null or run_state.phase == "ended" or not _valid_metadata(metadata):
		return ERR_INVALID_PARAMETER
	var candidate := data.duplicate(true)
	candidate.active = {
		"metadata": metadata.duplicate(true), "run": run_state.to_snapshot(),
		"combat": combat.to_snapshot() if combat != null and run_state.phase in ["battle", "boss"] else null
	}
	if _restore_active_value(candidate.active).is_empty():
		return ERR_INVALID_DATA
	return _commit(candidate)

func restore_active() -> Dictionary:
	return _restore_active_value(data.active)

func finalize_run(run_state, metadata: Dictionary) -> Error:
	if run_state == null or run_state.phase != "ended" or not _valid_metadata(metadata):
		return ERR_INVALID_PARAMETER
	var validated = Run.new()
	if validated.restore_snapshot(run_state.to_snapshot()) != OK:
		return ERR_INVALID_DATA
	for record in data.history:
		if record.run_id == metadata.run_id:
			return OK
	if not data.active.is_empty() and data.active.metadata.run_id != metadata.run_id:
		return ERR_INVALID_PARAMETER
	var candidate := data.duplicate(true)
	var reached_row := 0
	for id in run_state.visited:
		reached_row = maxi(reached_row, int(run_state.nodes[id].row))
	if run_state.current != "":
		reached_row = maxi(reached_row, int(run_state.nodes[run_state.current].row))
	candidate.history.append({
		"run_id": metadata.run_id, "role_id": metadata.role_id,
		"started_at": metadata.started_at, "ended_at": int(Time.get_unix_time_from_system()),
		"outcome": run_state.outcome, "floor": reached_row, "reached_row": reached_row,
		"attributes": run_state.attributes.duplicate(), "battles_won": run_state.battles_won,
		"battles_lost": run_state.battles_lost, "shells": run_state.shells,
		"deck_count": run_state.deck.size(), "relic_count": run_state.relics.size()
	})
	candidate.statistics.runs += 1
	candidate.statistics.wins += int(run_state.outcome == "victory")
	candidate.statistics.battles_won += run_state.battles_won
	candidate.statistics.battles_lost += run_state.battles_lost
	candidate.active = {}
	return _commit(candidate)

func save_settings(settings: Dictionary) -> Error:
	if not _valid_settings(settings):
		return ERR_INVALID_PARAMETER
	var candidate := data.duplicate(true)
	candidate.settings = settings.duplicate(true)
	return _commit(candidate)

func _valid_metadata(metadata: Variant) -> bool:
	return typeof(metadata) == TYPE_DICTIONARY and typeof(metadata.get("run_id")) == TYPE_STRING and not metadata.run_id.is_empty() and metadata.run_id.length() <= 128 and metadata.get("role_id") == "condensation_coletta" and typeof(metadata.get("started_at")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(metadata.started_at)) and metadata.started_at >= 0

func _valid_settings(settings: Variant) -> bool:
	return typeof(settings) == TYPE_DICTIONARY and typeof(settings.get("fullscreen")) == TYPE_BOOL and typeof(settings.get("resolution")) == TYPE_VECTOR2I and settings.resolution.x >= 640 and settings.resolution.y >= 360 and settings.resolution.x <= 16384 and settings.resolution.y <= 16384

func _restore_active_value(active: Variant) -> Dictionary:
	if typeof(active) != TYPE_DICTIONARY or active.is_empty() or not _valid_metadata(active.get("metadata")) or typeof(active.get("run")) != TYPE_DICTIONARY or not active.has("combat"):
		return {}
	var restored_run = Run.new()
	if restored_run.restore_snapshot(active.run) != OK or restored_run.phase == "ended":
		return {}
	var restored_combat = null
	if restored_run.phase in ["battle", "boss"]:
		if typeof(active.combat) != TYPE_DICTIONARY:
			return {}
		restored_combat = Combat.new()
		if restored_combat.restore_snapshot(active.combat) != OK or restored_combat.phase == "ended":
			return {}
		var attributes: Array = restored_combat.board.kinds.duplicate()
		attributes.erase("star")
		attributes.erase("guard")
		if attributes != restored_run.attributes or restored_combat.relics != restored_run.relics:
			return {}
		if (restored_run.phase == "boss") != (restored_combat.enemy.id == "boss"):
			return {}
		var deck_by_uid: Dictionary = {}
		for card in restored_run.deck:
			deck_by_uid[card.uid] = card
		var count := 0
		for group in [restored_combat.hand, restored_combat.draw_pile, restored_combat.discard]:
			for card in group:
				if not deck_by_uid.has(card.uid) or deck_by_uid[card.uid] != card:
					return {}
				count += 1
		if count != restored_run.deck.size():
			return {}
	elif active.combat != null:
		return {}
	return {"run": restored_run, "combat": restored_combat, "metadata": active.metadata.duplicate(true)}

func _valid_statistics(statistics: Variant) -> bool:
	if typeof(statistics) != TYPE_DICTIONARY:
		return false
	for key in STAT_KEYS:
		if typeof(statistics.get(key)) != TYPE_INT or statistics[key] < 0:
			return false
	return statistics.wins <= statistics.runs

func _valid_data(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.get("save_version") != SAVE_VERSION or value.get("content_version") != CONTENT_VERSION or not _valid_settings(value.get("settings")):
		return false
	if not _valid_statistics(value.get("statistics")) or not _valid_statistics(value.get("legacy_statistics")) or typeof(value.get("history")) != TYPE_ARRAY or typeof(value.get("active")) != TYPE_DICTIONARY:
		return false
	var seen: Dictionary = {}
	var expected: Dictionary = value.legacy_statistics.duplicate()
	for record in value.history:
		if not _valid_metadata(record) or seen.has(record.run_id) or record.get("outcome") not in ["victory", "defeat", "abandoned"] or typeof(record.get("ended_at")) != TYPE_INT:
			return false
		for key in ["floor", "reached_row", "battles_won", "battles_lost", "shells", "deck_count", "relic_count"]:
			if typeof(record.get(key)) != TYPE_INT or record[key] < 0:
				return false
		if record.floor != record.reached_row or record.reached_row > 11 or typeof(record.get("attributes")) != TYPE_ARRAY or record.attributes.size() != 4:
			return false
		var attributes_seen: Dictionary = {}
		for kind in record.attributes:
			if typeof(kind) != TYPE_STRING or kind not in ["condensation", "thermal", "conductive", "aero", "diffraction", "annihilation"] or attributes_seen.has(kind):
				return false
			attributes_seen[kind] = true
		seen[record.run_id] = true
		expected.runs += 1
		expected.wins += int(record.outcome == "victory")
		expected.battles_won += record.battles_won
		expected.battles_lost += record.battles_lost
	for key in STAT_KEYS:
		if value.statistics[key] != expected[key]:
			return false
	if not value.active.is_empty():
		if _restore_active_value(value.active).is_empty() or seen.has(value.active.metadata.run_id):
			return false
	return true

func _read_file(file_path: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(file_path) != OK:
		return {}
	if not config.has_section_key("gameplay_v2", "data"):
		return {}
	var value: Variant = config.get_value("gameplay_v2", "data")
	return value if _valid_data(value) else {}

func _commit(candidate: Dictionary) -> Error:
	if not _writable:
		return ERR_FILE_CORRUPT
	if not _valid_data(candidate):
		return ERR_INVALID_DATA
	var config := ConfigFile.new()
	config.set_value("gameplay_v2", "data", candidate)
	var temporary := path + ".tmp"
	var error := config.save(temporary)
	if error != OK:
		return error
	if _read_file(temporary).is_empty():
		return ERR_FILE_CORRUPT
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".bak"
	if _primary_valid and FileAccess.file_exists(path):
		# Keep a complete previous generation before promoting the temporary file.
		if FileAccess.file_exists(path + ".bak"):
			error = DirAccess.remove_absolute(backup)
			if error != OK:
				return error
		error = DirAccess.rename_absolute(absolute, backup)
		if error != OK:
			return error
		_primary_valid = false
	elif FileAccess.file_exists(path):
		# A corrupt primary must never replace a valid recovery backup.
		var corrupt := absolute + ".corrupt"
		if FileAccess.file_exists(path + ".corrupt"):
			error = DirAccess.remove_absolute(corrupt)
			if error != OK:
				return error
		error = DirAccess.rename_absolute(absolute, corrupt)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	if error != OK:
		return error
	data = candidate.duplicate(true)
	_primary_valid = true
	return OK
