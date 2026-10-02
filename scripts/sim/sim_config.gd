extends RefCounted
## Loads v0.2 prototype_config.json. Numbers are prototype rates, not balance promises.

const PATH := "res://docs/design_v0_2/prototype_config.json"

var raw: Dictionary = {}


func _init() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	assert(not text.is_empty(), "Missing %s" % PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "prototype_config.json must be an object")
	raw = parsed


func land() -> Dictionary:
	return raw["land"]


func spring() -> Dictionary:
	return raw["spring"]


func time() -> Dictionary:
	return raw["time"]


func farming() -> Dictionary:
	return raw["farming"]


func stock() -> Dictionary:
	return raw["stock"]


func research() -> Dictionary:
	return raw["research"]


func loot() -> Dictionary:
	return raw["loot"]


func offline_cap_minutes() -> float:
	return float(time()["offline_cap_minutes"])
