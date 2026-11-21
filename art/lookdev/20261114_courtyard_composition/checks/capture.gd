extends "res://art/lookdev/20261113_cliff_join/checks/capture.gd"

func _source_hashes() -> Dictionary:
	var hashes: Dictionary = super._source_hashes()
	hashes["res://art/lookdev/20261114_courtyard_composition/checks/capture.gd"] = FileAccess.get_sha256("res://art/lookdev/20261114_courtyard_composition/checks/capture.gd")
	return hashes

func _capture(label: String, time_progress: float) -> void:
	await super._capture(label, time_progress)
	if label == "whole":
		_frame(Vector2(-2, -1), 32, 16, 62)
		await super._capture("overview", time_progress)
