extends RefCounted
class_name SaveManager

const SAVE_PATH := "user://save.cfg"

var high_score: int = 0
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var roster_ids: PackedStringArray = PackedStringArray()
var unlocked_piece_ids: PackedStringArray = PackedStringArray()
var run_best_floor: int = 0
var run_total_shells: int = 0
var seen_collectible_ids: PackedStringArray = PackedStringArray()

func load_save(default_roster: PackedStringArray) -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_PATH)
	if err != OK:
		roster_ids = default_roster
		return
	high_score = int(config.get_value("progress", "high_score", 0))
	music_volume = float(config.get_value("settings", "music_volume", 0.8))
	sfx_volume = float(config.get_value("settings", "sfx_volume", 0.8))
	roster_ids = PackedStringArray(config.get_value("progress", "roster_ids", default_roster))
	unlocked_piece_ids = PackedStringArray(config.get_value("progress", "unlocked_piece_ids", PackedStringArray()))
	run_best_floor = int(config.get_value("progress", "run_best_floor", 0))
	run_total_shells = int(config.get_value("progress", "run_total_shells", 0))
	seen_collectible_ids = PackedStringArray(config.get_value("progress", "seen_collectible_ids", PackedStringArray()))
	if roster_ids.is_empty():
		roster_ids = default_roster

func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "high_score", high_score)
	config.set_value("progress", "roster_ids", roster_ids)
	config.set_value("progress", "unlocked_piece_ids", unlocked_piece_ids)
	config.set_value("progress", "run_best_floor", run_best_floor)
	config.set_value("progress", "run_total_shells", run_total_shells)
	config.set_value("progress", "seen_collectible_ids", seen_collectible_ids)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.save(SAVE_PATH)
