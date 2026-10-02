extends RefCounted
## 息壤 / terrain-expansion points. Idle and offline share one closed-form advance.

const DEFAULTS := {
	"label": "息壤",
	"initial_points": 96.0,
	"idle_points_per_minute": 1.2,
	"offline_points_per_minute": 1.2,
	"cell_area": 1.0,
	"island_thickness": 4.0,
	"cost_per_volume": 0.25,
	"refund_ratio": 0.5,
	"soft_cap_cells": 80,
	"soft_cap_exponent": 1.5,
	"soft_cap_extra": 1.0,
}

var cfg: Dictionary = DEFAULTS.duplicate()
var points: float = 96.0


func configure(raw: Dictionary = {}) -> void:
	cfg = DEFAULTS.duplicate()
	for key in raw.keys():
		cfg[key] = raw[key]
	points = float(cfg["initial_points"])


func volume_per_cell() -> float:
	return float(cfg["cell_area"]) * float(cfg["island_thickness"])


func advance(dt_minutes: float, offline: bool = false) -> void:
	if dt_minutes <= 0.0:
		return
	var rate := float(cfg["offline_points_per_minute"] if offline else cfg["idle_points_per_minute"])
	points += dt_minutes * rate


func soft_multiplier(island_cells: int) -> float:
	var cap := maxi(int(cfg["soft_cap_cells"]), 1)
	if island_cells <= cap:
		return 1.0
	var over := float(island_cells - cap) / float(cap)
	return 1.0 + pow(over, float(cfg["soft_cap_exponent"])) * float(cfg["soft_cap_extra"])


func quote_add(island_cells_after: int, cell_count: int = 1) -> float:
	return volume_per_cell() * float(cfg["cost_per_volume"]) * soft_multiplier(island_cells_after) * float(cell_count)


func quote_remove(cell_count: int = 1) -> float:
	return volume_per_cell() * float(cfg["cost_per_volume"]) * float(cfg["refund_ratio"]) * float(cell_count)


func quote_volume(volume: float, island_cells_after: int = 0) -> float:
	var soft := 1.0 if island_cells_after <= 0 else soft_multiplier(island_cells_after)
	return maxf(volume, 0.0) * float(cfg["cost_per_volume"]) * soft


func quote_remove_volume(volume: float) -> float:
	return maxf(volume, 0.0) * float(cfg["cost_per_volume"]) * float(cfg["refund_ratio"])


func can_afford(cost: float) -> bool:
	return cost <= points + 1e-6


func try_spend(cost: float) -> bool:
	if cost <= 1e-9:
		return true
	if not can_afford(cost):
		return false
	points = maxf(0.0, points - cost)
	return true


func credit(amount: float) -> void:
	if amount > 0.0:
		points += amount


func added_volume(cell_count: int) -> float:
	return volume_per_cell() * float(cell_count)


## Exploration-sourced special terrain. Place or decompose later; only the data shape is locked now.
static func piece_defaults() -> Dictionary:
	return {
		"id": "",
		"label": "",
		"cells": [],
		"polygon": PackedVector2Array(),
		"rarity": 1.0,
		"kind": "terrain_piece",
	}


static func piece_volume(piece: Dictionary, thickness: float = 4.0) -> float:
	var cells: Array = piece.get("cells", [])
	if cells.size() > 0:
		return float(cells.size()) * thickness
	var polygon: Variant = piece.get("polygon", PackedVector2Array())
	if polygon is PackedVector2Array and polygon.size() >= 3:
		return absf(_area(polygon)) * thickness
	return 0.0


func decompose_piece(piece: Dictionary) -> float:
	var rarity := maxf(float(piece.get("rarity", 1.0)), 0.0)
	var gained := piece_volume(piece, float(cfg["island_thickness"])) * float(cfg["cost_per_volume"]) * rarity
	credit(gained)
	return gained


func place_piece(_piece: Dictionary) -> String:
	# Future: stamp cells or a polygon into an island, then rebuild that island only.
	return "not_implemented"


func to_dict() -> Dictionary:
	return {"points": points}


func from_dict(data: Dictionary) -> void:
	if data.has("points"):
		points = maxf(0.0, float(data["points"]))


static func _area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5
