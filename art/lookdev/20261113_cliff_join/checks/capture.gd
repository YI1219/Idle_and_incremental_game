extends "res://art/lookdev/20261113_cliff_foot/checks/capture.gd"

func _source_hashes() -> Dictionary:
	var hashes: Dictionary = super._source_hashes()
	for path: String in ["res://scripts/terrain_editor/cliff_shoulder_join.gd","res://art/lookdev/20261113_cliff_join/checks/capture.gd"]:
		hashes[path]=FileAccess.get_sha256(path)
	return hashes
